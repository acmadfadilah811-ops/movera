import { BadRequestException, ConflictException, Injectable, NotFoundException } from '@nestjs/common';
import { BookingStatus, EmploymentStatus, Prisma, RideMode, ShiftStatus, TripStatus, VehicleStatus } from '@prisma/client';
import { AuditService } from '../../common/audit.service';
import { addDays, operationalDate } from '../../common/jakarta-time';
import { PrismaService } from '../../common/prisma.service';
import { batteryEnough, BookingForTrip, checkTripBookings, overlaps, planStops, routeKm, tripDurationMinutes } from './dispatch-policy';

type Tx = Prisma.TransactionClient;

const OPEN_TRIP: TripStatus[] = [TripStatus.ASSIGNED, TripStatus.ACCEPTED, TripStatus.IN_PROGRESS];

const toTripBooking = (b: {
  id: string;
  pickupLat: number;
  pickupLng: number;
  destinationLat: number;
  destinationLng: number;
  passengerCount: number;
  rideMode: RideMode;
  maxDetourMinutes: number;
}): BookingForTrip => ({
  id: b.id,
  pickup: { lat: b.pickupLat, lng: b.pickupLng },
  destination: { lat: b.destinationLat, lng: b.destinationLng },
  passengerCount: b.passengerCount,
  shared: b.rideMode === RideMode.SHARED,
  maxDetourMinutes: b.maxDetourMinutes,
});

@Injectable()
export class DispatchService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: AuditService,
  ) {}

  /** Booking yang menunggu penugasan pada satu tanggal operasional. */
  queue(date: Date) {
    return this.prisma.booking.findMany({
      where: { status: BookingStatus.PENDING_DISPATCH, scheduledAt: { gte: this.dayStart(date), lt: this.dayStart(addDays(date, 1)) } },
      orderBy: { scheduledAt: 'asc' },
      include: { user: { select: { fullName: true, phone: true } } },
    });
  }

  private dayStart(date: Date) {
    // 00.00 WIB = 17.00 UTC hari sebelumnya.
    return new Date(date.getTime() - 7 * 60 * 60 * 1000);
  }

  /**
   * Memeriksa semua syarat wajib lalu membuat trip dalam satu transaksi (blueprint 8.4 dan 11.2).
   * Booking dikunci supaya tidak masuk dua trip.
   */
  async assign(bookingIds: string[], driverId: string, actorId: string, tx?: Tx) {
    const run = async (t: Tx) => {
      if (new Set(bookingIds).size !== bookingIds.length) throw new BadRequestException('Booking ganda dalam penugasan.');
      await t.$queryRaw`SELECT "id" FROM "bookings" WHERE "id" = ANY(${bookingIds}::uuid[]) FOR UPDATE`;
      const bookings = await t.booking.findMany({ where: { id: { in: bookingIds } } });
      if (bookings.length !== bookingIds.length) throw new NotFoundException('Ada booking yang tidak ditemukan.');
      if (bookings.some((b) => b.status !== BookingStatus.PENDING_DISPATCH)) {
        throw new ConflictException('Ada booking yang sudah ditugaskan atau tidak aktif.');
      }
      const scheduledAt = new Date(Math.min(...bookings.map((b) => b.scheduledAt.getTime())));
      const day = operationalDate(scheduledAt);
      if (bookings.some((b) => operationalDate(b.scheduledAt).getTime() !== day.getTime())) {
        throw new BadRequestException('Booking dalam satu trip harus pada tanggal yang sama.');
      }

      const driver = await t.driver.findUnique({ where: { id: driverId } });
      if (!driver || driver.employmentStatus !== EmploymentStatus.ACTIVE) throw new BadRequestException('Driver tidak aktif.');
      if (driver.licenseExpiry < day) throw new BadRequestException('SIM driver sudah habis masa berlakunya.');
      const shift = await t.driverShift.findUnique({ where: { driverId_shiftDate: { driverId, shiftDate: day } }, include: { vehicle: true } });
      if (!shift || shift.status === ShiftStatus.ENDED) throw new BadRequestException('Driver tidak punya shift pada tanggal ini.');
      if (shift.vehicle.status !== VehicleStatus.ACTIVE) throw new BadRequestException('Kendaraan sedang tidak beroperasi atau dalam perawatan.');

      const items = bookings.map(toTripBooking);
      const check = checkTripBookings(items, shift.vehicle.seats);
      if (!check.ok) throw new BadRequestException(check.problems.join(' '));

      const stops = planStops(items);
      const km = routeKm(stops);
      const minutes = tripDurationMinutes(km, stops.length);
      if (!batteryEnough(shift.vehicle.batteryPercent, shift.vehicle.fullRangeKm, km)) {
        throw new BadRequestException(`Baterai kendaraan (${shift.vehicle.batteryPercent}%) tidak cukup untuk trip ini.`);
      }

      const others = await t.trip.findMany({
        where: { status: { in: OPEN_TRIP }, OR: [{ driverId }, { vehicleId: shift.vehicleId }] },
        include: { stops: true },
      });
      const conflict = others.find((o) => overlaps(o.scheduledAt, tripDurationMinutes(o.estimatedKm, o.stops.length), scheduledAt, minutes));
      if (conflict) throw new ConflictException('Driver atau kendaraan sudah punya tugas di waktu yang bertabrakan.');

      const trip = await t.trip.create({
        data: {
          driverId,
          vehicleId: shift.vehicleId,
          shiftId: shift.id,
          scheduledAt,
          shared: bookings.length > 1,
          estimatedKm: km,
          assignedById: actorId,
          stops: { create: stops.map((s, i) => ({ bookingId: s.bookingId, sequence: i + 1, type: s.type })) },
        },
        include: { stops: true },
      });
      await t.booking.updateMany({ where: { id: { in: bookingIds } }, data: { status: BookingStatus.ASSIGNED, tripId: trip.id } });
      await this.audit.log({ actorId, action: 'dispatch.assign', entity: 'trip', entityId: trip.id, data: { bookingIds, driverId } }, t);
      return trip;
    };
    return tx ? run(tx) : this.prisma.$transaction(run);
  }

  /**
   * Penugasan otomatis versi MVP: tiap booking yang menunggu diberikan ke driver yang memenuhi syarat
   * dengan tugas paling sedikit hari itu. Penggabungan shared ride tetap manual oleh dispatcher.
   * Booking tanpa kandidat tetap di antrean admin (blueprint 11.4 langkah 10).
   */
  async autoAssign(date: Date, actorId: string) {
    const pending = await this.queue(date);
    const shifts = await this.prisma.driverShift.findMany({
      where: { shiftDate: date, status: { not: ShiftStatus.ENDED } },
      include: { trips: { where: { status: { in: OPEN_TRIP } } } },
    });
    const load = new Map(shifts.map((s) => [s.driverId, s.trips.length]));
    const assigned: string[] = [];
    const unassigned: { bookingId: string; reason: string }[] = [];
    for (const b of pending) {
      const candidates = [...load.entries()].sort((a, c) => a[1] - c[1]).map(([id]) => id);
      let done = false;
      let lastReason = 'Tidak ada driver dengan shift pada tanggal ini.';
      for (const driverId of candidates) {
        try {
          await this.assign([b.id], driverId, actorId);
          load.set(driverId, (load.get(driverId) ?? 0) + 1);
          assigned.push(b.id);
          done = true;
          break;
        } catch (e) {
          lastReason = e instanceof Error ? e.message : String(e);
        }
      }
      if (!done) unassigned.push({ bookingId: b.id, reason: lastReason });
    }
    return { assigned: assigned.length, unassigned };
  }

  /** Mengganti driver: trip lama dibatalkan, booking dikembalikan lalu ditugaskan ulang dalam satu transaksi. */
  async reassign(tripId: string, driverId: string, actorId: string) {
    return this.prisma.$transaction(async (tx) => {
      await tx.$queryRaw`SELECT "id" FROM "trips" WHERE "id" = ${tripId}::uuid FOR UPDATE`;
      const trip = await tx.trip.findUnique({ where: { id: tripId }, include: { bookings: true } });
      if (!trip) throw new NotFoundException('Trip tidak ditemukan.');
      if (trip.status !== TripStatus.ASSIGNED && trip.status !== TripStatus.ACCEPTED && trip.status !== TripStatus.REJECTED) {
        throw new BadRequestException('Trip yang sudah berjalan tidak bisa dipindah.');
      }
      const bookingIds = trip.bookings.filter((b) => b.status === BookingStatus.ASSIGNED).map((b) => b.id);
      if (bookingIds.length === 0) throw new BadRequestException('Tidak ada booking aktif di trip ini.');
      await tx.trip.update({ where: { id: tripId }, data: { status: TripStatus.CANCELLED } });
      await tx.booking.updateMany({ where: { id: { in: bookingIds } }, data: { status: BookingStatus.PENDING_DISPATCH, tripId: null } });
      await this.audit.log({ actorId, action: 'dispatch.reassign', entity: 'trip', entityId: tripId, data: { driverId } }, tx);
      return this.assign(bookingIds, driverId, actorId, tx);
    });
  }
}
