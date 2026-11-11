import { BadRequestException, ConflictException, Injectable, NotFoundException } from '@nestjs/common';
import {
  Booking,
  BookingStatus,
  BookingType,
  Prisma,
  QuotaAction,
  QuotaOutcome,
  RecurringSchedule,
  RideMode,
  SubscriptionStatus,
} from '@prisma/client';
import { randomUUID } from 'crypto';
import { AuditService } from '../../common/audit.service';
import { dateKey, operationalDate } from '../../common/jakarta-time';
import { PrismaService } from '../../common/prisma.service';
import { cancellationOutcome, generatePin, meetsLeadTime, routineInstanceTimes } from '../quotas/quota-policy';
import { QuotaError, QuotaService } from '../quotas/quota.service';
import { SettingsService } from '../settings/settings.service';
import { CreateBookingDto, PlaceDto } from './bookings.dto';

type Tx = Prisma.TransactionClient;

const ACTIVE_STATUSES: BookingStatus[] = [
  BookingStatus.PENDING_DISPATCH,
  BookingStatus.ASSIGNED,
  BookingStatus.ON_THE_WAY,
  BookingStatus.IN_PROGRESS,
];

/** Status yang masih boleh dibatalkan pelanggan. Perjalanan yang sudah berjalan tidak bisa dibatalkan. */
const CANCELLABLE: BookingStatus[] = [BookingStatus.PENDING_DISPATCH, BookingStatus.ASSIGNED, BookingStatus.ON_THE_WAY];

interface BookingFields {
  rideMode: RideMode;
  pickup: PlaceDto;
  destination: PlaceDto;
  passengerCount: number;
  passengerNames: string[];
  maxDetourMinutes: number;
  note: string;
}

@Injectable()
export class BookingsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly quota: QuotaService,
    private readonly settings: SettingsService,
    private readonly audit: AuditService,
  ) {}

  private async subscriptionFor(tx: Tx | PrismaService, userId: string, at: Date) {
    const day = operationalDate(at);
    return tx.subscription.findFirst({
      where: { userId, status: SubscriptionStatus.ACTIVE, startDate: { lte: day }, endDate: { gte: day } },
    });
  }

  private placeColumns(fields: BookingFields) {
    return {
      rideMode: fields.rideMode,
      pickupLabel: fields.pickup.label ?? '',
      pickupAddress: fields.pickup.address,
      pickupLat: fields.pickup.latitude,
      pickupLng: fields.pickup.longitude,
      destinationLabel: fields.destination.label ?? '',
      destinationAddress: fields.destination.address,
      destinationLat: fields.destination.latitude,
      destinationLng: fields.destination.longitude,
      passengerCount: fields.passengerCount,
      passengerNames: fields.passengerNames,
      maxDetourMinutes: fields.rideMode === RideMode.SHARED ? fields.maxDetourMinutes : 0,
      note: fields.note,
    };
  }

  /** Membuat satu booking dan mencadangkan kuotanya dalam transaksi yang sama. */
  private async createOne(tx: Tx, userId: string, at: Date, type: BookingType, fields: BookingFields, scheduleId?: string) {
    const sub = await this.subscriptionFor(tx, userId, at);
    if (!sub) throw new QuotaError(`Tidak ada langganan aktif pada ${dateKey(operationalDate(at))}.`);
    const id = randomUUID();
    const dailyQuotaId = await this.quota.reserve(tx, sub, at, id, userId);
    return tx.booking.create({
      data: {
        id,
        userId,
        subscriptionId: sub.id,
        dailyQuotaId,
        type,
        scheduledAt: at,
        pickupPin: generatePin(),
        recurringScheduleId: scheduleId,
        ...this.placeColumns(fields),
      },
    });
  }

  async create(userId: string, dto: CreateBookingDto, now = new Date()) {
    const maxPassengers = await this.settings.getNumber('booking.max_passengers');
    const minLead = await this.settings.getNumber('booking.min_lead_minutes');
    if (dto.passengerCount > maxPassengers) throw new BadRequestException(`Maksimal ${maxPassengers} penumpang per booking.`);
    if (dto.pickup.latitude === dto.destination.latitude && dto.pickup.longitude === dto.destination.longitude) {
      throw new BadRequestException('Titik jemput dan tujuan tidak boleh sama.');
    }
    const fields: BookingFields = {
      rideMode: dto.rideMode,
      pickup: dto.pickup,
      destination: dto.destination,
      passengerCount: dto.passengerCount,
      passengerNames: (dto.passengerNames ?? []).map((n) => n.trim()).filter(Boolean),
      maxDetourMinutes: dto.maxDetourMinutes ?? 15,
      note: dto.note?.trim() ?? '',
    };

    if (dto.type === BookingType.FLEXIBLE) {
      if (!dto.scheduledAt) throw new BadRequestException('Waktu jemput wajib diisi.');
      const at = new Date(dto.scheduledAt);
      if (!meetsLeadTime(now, at, minLead)) throw new BadRequestException(`Booking paling cepat ${minLead} menit dari sekarang.`);
      try {
        const booking = await this.prisma.$transaction((tx) => this.createOne(tx, userId, at, BookingType.FLEXIBLE, fields));
        return { created: [booking], skipped: [] as string[] };
      } catch (e) {
        if (e instanceof QuotaError) throw new ConflictException(e.message);
        throw e;
      }
    }

    if (!dto.weekdays?.length || dto.hour === undefined) throw new BadRequestException('Pilih hari dan jam untuk jadwal rutin.');
    const p = this.placeColumns(fields);
    const schedule = await this.prisma.recurringSchedule.create({
      data: {
        userId,
        weekdays: [...new Set(dto.weekdays)].sort(),
        hour: dto.hour,
        minute: dto.minute ?? 0,
        ...p,
      },
    });
    await this.audit.log({ actorId: userId, action: 'schedule.create', entity: 'recurring_schedule', entityId: schedule.id });
    const result = await this.generateForSchedule(schedule, now);
    return { schedule, ...result };
  }

  /** Membuat booking dari jadwal rutin untuk jendela hari ke depan. Aman dipanggil berulang (job harian). */
  async generateForSchedule(schedule: RecurringSchedule, now = new Date()) {
    const windowDays = await this.settings.getNumber('booking.routine_window_days');
    const minLead = await this.settings.getNumber('booking.min_lead_minutes');
    const created: Booking[] = [];
    const skipped: string[] = [];
    const fields: BookingFields = {
      rideMode: schedule.rideMode,
      pickup: { label: schedule.pickupLabel, address: schedule.pickupAddress, latitude: schedule.pickupLat, longitude: schedule.pickupLng },
      destination: {
        label: schedule.destinationLabel,
        address: schedule.destinationAddress,
        latitude: schedule.destinationLat,
        longitude: schedule.destinationLng,
      },
      passengerCount: schedule.passengerCount,
      passengerNames: schedule.passengerNames,
      maxDetourMinutes: schedule.maxDetourMinutes,
      note: schedule.note,
    };
    for (const at of routineInstanceTimes(schedule, now, windowDays, minLead)) {
      const exists = await this.prisma.booking.findUnique({
        where: { recurringScheduleId_scheduledAt: { recurringScheduleId: schedule.id, scheduledAt: at } },
      });
      if (exists) continue;
      try {
        created.push(await this.prisma.$transaction((tx) => this.createOne(tx, schedule.userId, at, BookingType.ROUTINE, fields, schedule.id)));
      } catch (e) {
        if (e instanceof QuotaError) skipped.push(`${dateKey(operationalDate(at))}: ${e.message}`);
        else if (e instanceof Prisma.PrismaClientKnownRequestError && e.code === 'P2002') continue; // dibuat proses lain
        else throw e;
      }
    }
    return { created, skipped };
  }

  /** Job: jalankan generator untuk semua jadwal rutin aktif. */
  async generateAllRoutines(now = new Date()) {
    const schedules = await this.prisma.recurringSchedule.findMany({ where: { isActive: true } });
    let created = 0;
    for (const s of schedules) created += (await this.generateForSchedule(s, now)).created.length;
    return { schedules: schedules.length, created };
  }

  list(userId: string, scope: 'upcoming' | 'history' | 'all' = 'all') {
    const where: Prisma.BookingWhereInput = { userId };
    if (scope === 'upcoming') where.status = { in: ACTIVE_STATUSES };
    if (scope === 'history') where.status = { notIn: ACTIVE_STATUSES };
    return this.prisma.booking.findMany({
      where,
      orderBy: { scheduledAt: scope === 'history' ? 'desc' : 'asc' },
      take: 200,
      include: { trip: { select: { id: true, driver: { select: { user: { select: { fullName: true } } } }, vehicle: { select: { plateNumber: true } } } } },
    });
  }

  async detail(userId: string, id: string) {
    const b = await this.prisma.booking.findUnique({
      where: { id },
      include: { trip: { select: { id: true, status: true, driver: { select: { user: { select: { fullName: true } } } }, vehicle: { select: { plateNumber: true, model: true } } } } },
    });
    if (!b || b.userId !== userId) throw new NotFoundException('Booking tidak ditemukan.');
    return b;
  }

  /** Pembatalan oleh pelanggan. Baris booking dikunci supaya pembatalan ganda tidak menggeser kuota dua kali. */
  async cancel(userId: string, id: string, reason: string, now = new Date(), actorId = userId) {
    const cutoff = await this.settings.getNumber('booking.cancel_cutoff_minutes');
    return this.prisma.$transaction(async (tx) => {
      await tx.$queryRaw`SELECT "id" FROM "bookings" WHERE "id" = ${id}::uuid FOR UPDATE`;
      const b = await tx.booking.findUnique({ where: { id } });
      if (!b || b.userId !== userId) throw new NotFoundException('Booking tidak ditemukan.');
      if (!CANCELLABLE.includes(b.status)) throw new BadRequestException('Booking ini tidak bisa dibatalkan.');
      const outcome = cancellationOutcome(now, b.scheduledAt, cutoff);
      await this.quota.settle(tx, b.dailyQuotaId, b.id, outcome === QuotaOutcome.RELEASED ? QuotaAction.RELEASE : QuotaAction.FORFEIT, actorId);
      const updated = await tx.booking.update({
        where: { id },
        data: { status: BookingStatus.CANCELLED, cancelReason: reason.trim(), cancelledAt: now, cancelledById: actorId, quotaOutcome: outcome },
      });
      // Titik di trip yang belum berjalan ikut dilewati.
      await tx.tripStop.updateMany({ where: { bookingId: id, status: 'PENDING' }, data: { status: 'SKIPPED', doneAt: now } });
      await this.audit.log({ actorId, action: 'booking.cancel', entity: 'booking', entityId: id, data: { reason, outcome } }, tx);
      return updated;
    });
  }

  /**
   * Pembatalan oleh perusahaan (misalnya tidak ada armada). Kuota selalu dikembalikan karena kegagalan
   * penyediaan layanan bukan kesalahan pelanggan (blueprint 8.2).
   */
  async cancelByCompany(id: string, reason: string, actorId: string, now = new Date()) {
    return this.prisma.$transaction(async (tx) => {
      await tx.$queryRaw`SELECT "id" FROM "bookings" WHERE "id" = ${id}::uuid FOR UPDATE`;
      const b = await tx.booking.findUnique({ where: { id } });
      if (!b) throw new NotFoundException('Booking tidak ditemukan.');
      if (!CANCELLABLE.includes(b.status)) throw new BadRequestException('Booking ini tidak bisa dibatalkan.');
      await this.quota.settle(tx, b.dailyQuotaId, b.id, QuotaAction.RELEASE, actorId);
      await tx.tripStop.updateMany({ where: { bookingId: id, status: 'PENDING' }, data: { status: 'SKIPPED', doneAt: now } });
      const updated = await tx.booking.update({
        where: { id },
        data: { status: BookingStatus.CANCELLED, cancelReason: reason.trim(), cancelledAt: now, cancelledById: actorId, quotaOutcome: QuotaOutcome.RELEASED },
      });
      await this.audit.log({ actorId, action: 'booking.cancel_by_company', entity: 'booking', entityId: id, data: { reason } }, tx);
      return updated;
    });
  }

  listSchedules(userId: string) {
    return this.prisma.recurringSchedule.findMany({ where: { userId, isActive: true }, orderBy: { createdAt: 'desc' } });
  }

  /** Menonaktifkan jadwal rutin. Booking turunan yang belum lewat batas pembatalan ikut dibatalkan (kuota kembali). */
  async deactivateSchedule(userId: string, id: string, now = new Date()) {
    const s = await this.prisma.recurringSchedule.findUnique({ where: { id } });
    if (!s || s.userId !== userId) throw new NotFoundException('Jadwal tidak ditemukan.');
    await this.prisma.recurringSchedule.update({ where: { id }, data: { isActive: false } });
    const cutoff = await this.settings.getNumber('booking.cancel_cutoff_minutes');
    const pending = await this.prisma.booking.findMany({
      where: {
        recurringScheduleId: id,
        status: { in: [BookingStatus.PENDING_DISPATCH, BookingStatus.ASSIGNED] },
        scheduledAt: { gte: new Date(now.getTime() + cutoff * 60_000) },
      },
      select: { id: true },
    });
    for (const b of pending) await this.cancel(userId, b.id, 'Jadwal rutin dihentikan', now);
    await this.audit.log({ actorId: userId, action: 'schedule.deactivate', entity: 'recurring_schedule', entityId: id });
    return { cancelled: pending.length };
  }
}
