import { BadRequestException, ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { BookingStatus, IncidentType, Prisma, QuotaAction, ShiftStatus, StopStatus, StopType, TripStatus } from '@prisma/client';
import { AuditService } from '../../common/audit.service';
import { operationalDate } from '../../common/jakarta-time';
import { PrismaService } from '../../common/prisma.service';
import { QuotaService } from '../quotas/quota.service';
import { SettingsService } from '../settings/settings.service';

type Tx = Prisma.TransactionClient;

export interface ChecklistItemInput {
  key: string;
  label: string;
  critical: boolean;
  ok: boolean;
}

const ON_DUTY: ShiftStatus[] = [ShiftStatus.AVAILABLE, ShiftStatus.ON_BREAK, ShiftStatus.CHARGING];
const FINAL_STOP: StopStatus[] = [StopStatus.DONE, StopStatus.NO_SHOW, StopStatus.SKIPPED];

/** Aksi aplikasi driver. Setiap aksi memeriksa bahwa trip memang milik driver yang login (blueprint 12.2). */
@Injectable()
export class DriverService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly quota: QuotaService,
    private readonly settings: SettingsService,
    private readonly audit: AuditService,
  ) {}

  private async driverOf(userId: string) {
    const d = await this.prisma.driver.findUnique({ where: { userId } });
    if (!d) throw new ForbiddenException('Akun ini bukan driver.');
    return d;
  }

  private async shiftToday(driverId: string, now = new Date()) {
    return this.prisma.driverShift.findUnique({
      where: { driverId_shiftDate: { driverId, shiftDate: operationalDate(now) } },
      include: { vehicle: true },
    });
  }

  private tripInclude = {
    stops: {
      orderBy: { sequence: 'asc' as const },
      include: {
        booking: {
          select: {
            id: true,
            pickupLabel: true,
            pickupAddress: true,
            pickupLat: true,
            pickupLng: true,
            destinationLabel: true,
            destinationAddress: true,
            destinationLat: true,
            destinationLng: true,
            passengerCount: true,
            passengerNames: true,
            note: true,
            user: { select: { fullName: true, phone: true } },
          },
        },
      },
    },
  };

  async today(userId: string, now = new Date()) {
    const driver = await this.driverOf(userId);
    const shift = await this.shiftToday(driver.id, now);
    const trips = shift
      ? await this.prisma.trip.findMany({ where: { shiftId: shift.id }, orderBy: { scheduledAt: 'asc' }, include: this.tripInclude })
      : [];
    const incidents = await this.prisma.incident.findMany({ where: { driverId: driver.id, createdAt: { gte: new Date(now.getTime() - 86_400_000) } } });
    return { shift, trips, incidents };
  }

  async startShift(userId: string, input: { checklist: ChecklistItemInput[]; batteryPercent: number; odometer: number }, now = new Date()) {
    const driver = await this.driverOf(userId);
    const shift = await this.shiftToday(driver.id, now);
    if (!shift) throw new BadRequestException('Belum ada jadwal shift hari ini. Hubungi operasional.');
    if (shift.status !== ShiftStatus.SCHEDULED) throw new BadRequestException('Shift hari ini sudah dimulai.');
    const failed = input.checklist.filter((c) => c.critical && !c.ok);
    if (failed.length) {
      throw new BadRequestException(`Kendaraan belum layak jalan: ${failed.map((c) => c.label).join(', ')}. Laporkan ke operasional.`);
    }
    if (input.odometer < shift.vehicle.odometer) {
      throw new BadRequestException(`Odometer tidak boleh lebih kecil dari catatan terakhir (${shift.vehicle.odometer} km).`);
    }
    const [updated] = await this.prisma.$transaction([
      this.prisma.driverShift.update({
        where: { id: shift.id },
        data: {
          status: ShiftStatus.AVAILABLE,
          startedAt: now,
          startBattery: input.batteryPercent,
          startOdometer: input.odometer,
          checklist: input.checklist as unknown as Prisma.InputJsonValue,
        },
      }),
      this.prisma.vehicle.update({ where: { id: shift.vehicleId }, data: { batteryPercent: input.batteryPercent, odometer: input.odometer } }),
    ]);
    return updated;
  }

  private async hasRunningTrip(shiftId: string) {
    return (await this.prisma.trip.count({ where: { shiftId, status: TripStatus.IN_PROGRESS } })) > 0;
  }

  async setStatus(userId: string, target: 'BREAK' | 'AVAILABLE' | 'CHARGING', now = new Date()) {
    const driver = await this.driverOf(userId);
    const shift = await this.shiftToday(driver.id, now);
    if (!shift || !ON_DUTY.includes(shift.status)) throw new BadRequestException('Mulai shift dulu.');
    if (target !== 'AVAILABLE' && (await this.hasRunningTrip(shift.id))) {
      throw new BadRequestException('Selesaikan perjalanan yang berjalan dulu.');
    }
    const status = target === 'BREAK' ? ShiftStatus.ON_BREAK : target === 'CHARGING' ? ShiftStatus.CHARGING : ShiftStatus.AVAILABLE;
    return this.prisma.driverShift.update({ where: { id: shift.id }, data: { status } });
  }

  async updateBattery(userId: string, batteryPercent: number, finishCharging: boolean, now = new Date()) {
    const driver = await this.driverOf(userId);
    const shift = await this.shiftToday(driver.id, now);
    if (!shift || !ON_DUTY.includes(shift.status)) throw new BadRequestException('Mulai shift dulu.');
    if (finishCharging) {
      if (shift.status !== ShiftStatus.CHARGING) throw new BadRequestException('Kendaraan tidak sedang dicas.');
      if (batteryPercent < shift.vehicle.batteryPercent) {
        throw new BadRequestException(`Baterai setelah cas tidak boleh lebih rendah dari sebelumnya (${shift.vehicle.batteryPercent}%).`);
      }
      await this.prisma.driverShift.update({ where: { id: shift.id }, data: { status: ShiftStatus.AVAILABLE } });
    }
    return this.prisma.vehicle.update({ where: { id: shift.vehicleId }, data: { batteryPercent } });
  }

  async endShift(userId: string, input: { batteryPercent: number; odometer: number; note?: string }, now = new Date()) {
    const driver = await this.driverOf(userId);
    const shift = await this.shiftToday(driver.id, now);
    if (!shift || !ON_DUTY.includes(shift.status)) throw new BadRequestException('Shift belum berjalan.');
    if (await this.hasRunningTrip(shift.id)) throw new BadRequestException('Masih ada perjalanan yang berjalan.');
    if (input.odometer < (shift.startOdometer ?? 0)) {
      throw new BadRequestException(`Odometer akhir tidak boleh lebih kecil dari awal (${shift.startOdometer}).`);
    }
    const [updated] = await this.prisma.$transaction([
      this.prisma.driverShift.update({
        where: { id: shift.id },
        data: { status: ShiftStatus.ENDED, endedAt: now, endBattery: input.batteryPercent, endOdometer: input.odometer, endNote: input.note ?? '' },
      }),
      this.prisma.vehicle.update({ where: { id: shift.vehicleId }, data: { batteryPercent: input.batteryPercent, odometer: input.odometer } }),
    ]);
    return updated;
  }

  /** Mengunci trip milik driver dan memeriksa shift sedang bertugas. */
  private async lockTrip(tx: Tx, userId: string, tripId: string, requireAvailable = true) {
    await tx.$queryRaw`SELECT "id" FROM "trips" WHERE "id" = ${tripId}::uuid FOR UPDATE`;
    const trip = await tx.trip.findUnique({ where: { id: tripId }, include: { stops: { orderBy: { sequence: 'asc' } }, shift: true, driver: true } });
    if (!trip || trip.driver.userId !== userId) throw new NotFoundException('Tugas tidak ditemukan.');
    if (requireAvailable) {
      const s = trip.shift?.status;
      if (s === ShiftStatus.ON_BREAK) throw new BadRequestException('Anda sedang istirahat. Lanjutkan bertugas dulu.');
      if (s === ShiftStatus.CHARGING) throw new BadRequestException('Kendaraan sedang dicas.');
      if (s !== ShiftStatus.AVAILABLE) throw new BadRequestException('Mulai shift dulu.');
    }
    return trip;
  }

  async accept(userId: string, tripId: string) {
    return this.prisma.$transaction(async (tx) => {
      const trip = await this.lockTrip(tx, userId, tripId);
      if (trip.status !== TripStatus.ASSIGNED) throw new BadRequestException('Tugas ini sudah dikonfirmasi atau ditutup.');
      return tx.trip.update({ where: { id: tripId }, data: { status: TripStatus.ACCEPTED } });
    });
  }

  /** Tugas yang ditolak kembali ke antrean dispatcher. */
  async reject(userId: string, tripId: string, reason: string) {
    if (!reason.trim()) throw new BadRequestException('Alasan penolakan wajib diisi.');
    return this.prisma.$transaction(async (tx) => {
      const trip = await this.lockTrip(tx, userId, tripId, false);
      if (trip.status !== TripStatus.ASSIGNED && trip.status !== TripStatus.ACCEPTED) {
        throw new BadRequestException('Tugas yang sudah berjalan tidak bisa ditolak.');
      }
      await tx.booking.updateMany({ where: { tripId, status: BookingStatus.ASSIGNED }, data: { status: BookingStatus.PENDING_DISPATCH, tripId: null } });
      await this.audit.log({ actorId: userId, action: 'trip.reject', entity: 'trip', entityId: tripId, data: { reason } }, tx);
      return tx.trip.update({ where: { id: tripId }, data: { status: TripStatus.REJECTED, rejectReason: reason.trim() } });
    });
  }

  private nextStop(trip: { stops: { id: string; status: StopStatus; sequence: number }[] }) {
    return trip.stops.filter((s) => !FINAL_STOP.includes(s.status)).sort((a, b) => a.sequence - b.sequence)[0];
  }

  private requireNext(trip: { status: TripStatus; stops: { id: string; status: StopStatus; sequence: number }[] }, stopId: string) {
    if (trip.status !== TripStatus.ACCEPTED && trip.status !== TripStatus.IN_PROGRESS) throw new BadRequestException('Konfirmasi tugas ini dulu.');
    const next = this.nextStop(trip);
    if (!next || next.id !== stopId) throw new BadRequestException('Kerjakan titik sesuai urutan manifest.');
    return next;
  }

  /** Menutup trip jika semua titik selesai. */
  private async finishIfDone(tx: Tx, tripId: string, now: Date) {
    const stops = await tx.tripStop.findMany({ where: { tripId } });
    if (stops.some((s) => !FINAL_STOP.includes(s.status))) return;
    await tx.trip.update({ where: { id: tripId }, data: { status: TripStatus.COMPLETED, completedAt: now } });
  }

  async arrive(userId: string, tripId: string, stopId: string, now = new Date()) {
    return this.prisma.$transaction(async (tx) => {
      const trip = await this.lockTrip(tx, userId, tripId);
      const stop = this.requireNext(trip, stopId);
      if (stop.status === StopStatus.ARRIVED) return trip;
      await tx.tripStop.update({ where: { id: stopId }, data: { status: StopStatus.ARRIVED, arrivedAt: now } });
      if (trip.status === TripStatus.ACCEPTED) {
        await tx.trip.update({ where: { id: tripId }, data: { status: TripStatus.IN_PROGRESS, startedAt: now } });
        await tx.booking.updateMany({ where: { tripId, status: BookingStatus.ASSIGNED }, data: { status: BookingStatus.ON_THE_WAY } });
      }
      return tx.trip.findUniqueOrThrow({ where: { id: tripId }, include: this.tripInclude });
    });
  }

  async confirmPickup(userId: string, tripId: string, stopId: string, pin: string, now = new Date()) {
    return this.prisma.$transaction(async (tx) => {
      const trip = await this.lockTrip(tx, userId, tripId);
      this.requireNext(trip, stopId);
      const stop = await tx.tripStop.findUniqueOrThrow({ where: { id: stopId }, include: { booking: true } });
      if (stop.type !== StopType.PICKUP) throw new BadRequestException('Titik ini bukan titik jemput.');
      if (stop.status !== StopStatus.ARRIVED) throw new BadRequestException('Tandai tiba di lokasi dulu.');
      if (stop.booking.pickupPin !== pin.trim()) throw new BadRequestException('PIN tidak cocok. Minta penumpang mengecek PIN di aplikasinya.');
      await tx.tripStop.update({ where: { id: stopId }, data: { status: StopStatus.DONE, doneAt: now } });
      await tx.booking.update({ where: { id: stop.bookingId }, data: { status: BookingStatus.IN_PROGRESS } });
      await this.finishIfDone(tx, tripId, now);
      return tx.trip.findUniqueOrThrow({ where: { id: tripId }, include: this.tripInclude });
    });
  }

  /** Penumpang tidak hadir: kuota hangus (blueprint 8.3), titik antarnya dilewati. */
  async markNoShow(userId: string, tripId: string, stopId: string, now = new Date()) {
    const wait = await this.settings.getNumber('driver.no_show_wait_minutes');
    return this.prisma.$transaction(async (tx) => {
      const trip = await this.lockTrip(tx, userId, tripId);
      this.requireNext(trip, stopId);
      const stop = await tx.tripStop.findUniqueOrThrow({ where: { id: stopId }, include: { booking: true } });
      if (stop.type !== StopType.PICKUP || stop.status !== StopStatus.ARRIVED || !stop.arrivedAt) {
        throw new BadRequestException('Penumpang tidak hadir hanya bisa dicatat di titik jemput setelah tiba.');
      }
      const waited = Math.floor((now.getTime() - stop.arrivedAt.getTime()) / 60_000);
      if (waited < wait) throw new BadRequestException(`Tunggu minimal ${wait} menit sejak tiba (baru ${waited} menit).`);
      await tx.tripStop.update({ where: { id: stopId }, data: { status: StopStatus.NO_SHOW, doneAt: now } });
      await tx.tripStop.updateMany({
        where: { tripId, bookingId: stop.bookingId, type: StopType.DROPOFF },
        data: { status: StopStatus.SKIPPED, doneAt: now },
      });
      await this.quota.settle(tx, stop.booking.dailyQuotaId, stop.bookingId, QuotaAction.FORFEIT, userId);
      await tx.booking.update({ where: { id: stop.bookingId }, data: { status: BookingStatus.NO_SHOW, quotaOutcome: 'FORFEITED' } });
      await this.finishIfDone(tx, tripId, now);
      return tx.trip.findUniqueOrThrow({ where: { id: tripId }, include: this.tripInclude });
    });
  }

  /** Penumpang turun: booking selesai dan cadangan kuota menjadi terpakai. */
  async confirmDropoff(userId: string, tripId: string, stopId: string, now = new Date()) {
    return this.prisma.$transaction(async (tx) => {
      const trip = await this.lockTrip(tx, userId, tripId);
      this.requireNext(trip, stopId);
      const stop = await tx.tripStop.findUniqueOrThrow({ where: { id: stopId }, include: { booking: true } });
      if (stop.type !== StopType.DROPOFF) throw new BadRequestException('Titik ini bukan titik antar.');
      if (stop.status !== StopStatus.ARRIVED) throw new BadRequestException('Tandai tiba di lokasi dulu.');
      await tx.tripStop.update({ where: { id: stopId }, data: { status: StopStatus.DONE, doneAt: now } });
      await this.quota.settle(tx, stop.booking.dailyQuotaId, stop.bookingId, QuotaAction.CONSUME, userId);
      await tx.booking.update({ where: { id: stop.bookingId }, data: { status: BookingStatus.COMPLETED } });
      await this.finishIfDone(tx, tripId, now);
      return tx.trip.findUniqueOrThrow({ where: { id: tripId }, include: this.tripInclude });
    });
  }

  async reportIncident(userId: string, input: { type: IncidentType; description: string; tripId?: string; emergency?: boolean }) {
    const driver = await this.driverOf(userId);
    if (input.description.trim().length < 10) throw new BadRequestException('Ceritakan kejadiannya minimal 10 karakter.');
    if (input.tripId) {
      const t = await this.prisma.trip.findUnique({ where: { id: input.tripId } });
      if (!t || t.driverId !== driver.id) throw new NotFoundException('Tugas tidak ditemukan.');
    }
    const incident = await this.prisma.incident.create({
      data: { driverId: driver.id, tripId: input.tripId, type: input.type, description: input.description.trim(), emergency: input.emergency ?? false },
    });
    await this.audit.log({ actorId: userId, action: 'incident.report', entity: 'incident', entityId: incident.id, data: { emergency: incident.emergency } });
    return incident;
  }

  /** Lokasi hanya diterima untuk trip milik driver yang sedang berjalan. */
  async recordLocation(userId: string, input: { latitude: number; longitude: number; accuracy?: number; tripId?: string; recordedAt?: string }) {
    const driver = await this.driverOf(userId);
    if (input.tripId) {
      const t = await this.prisma.trip.findUnique({ where: { id: input.tripId } });
      if (!t || t.driverId !== driver.id || t.status !== TripStatus.IN_PROGRESS) throw new ForbiddenException('Trip tidak sedang berjalan.');
    }
    const recordedAt = input.recordedAt ? new Date(input.recordedAt) : new Date();
    if (Math.abs(Date.now() - recordedAt.getTime()) > 10 * 60_000) throw new BadRequestException('Waktu lokasi tidak wajar.');
    await this.prisma.driverLocation.create({
      data: { driverId: driver.id, tripId: input.tripId, latitude: input.latitude, longitude: input.longitude, accuracy: input.accuracy, recordedAt },
    });
    return { ok: true };
  }

  async history(userId: string) {
    const driver = await this.driverOf(userId);
    return this.prisma.trip.findMany({
      where: { driverId: driver.id, status: { in: [TripStatus.COMPLETED, TripStatus.REJECTED, TripStatus.CANCELLED] } },
      orderBy: { scheduledAt: 'desc' },
      take: 100,
      include: this.tripInclude,
    });
  }
}
