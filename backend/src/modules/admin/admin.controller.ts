import { BadRequestException, Body, Controller, Get, HttpCode, Injectable, Module, NotFoundException, Param, ParseUUIDPipe, Patch, Post, Put, Query } from '@nestjs/common';
import { BookingStatus, Prisma, Role, ShiftStatus, SubscriptionStatus, TripStatus, VehicleStatus } from '@prisma/client';
import { ArrayMinSize, IsArray, IsBoolean, IsDateString, IsEmail, IsEnum, IsInt, IsOptional, IsString, IsUUID, Length, Max, MaxLength, Min, MinLength } from 'class-validator';
import { AuditService } from '../../common/audit.service';
import { AuthUser, CurrentUser, Roles } from '../../common/auth.decorators';
import { addDays, operationalDate, parseDateKey } from '../../common/jakarta-time';
import { PrismaService } from '../../common/prisma.service';
import { AuthService, publicUser } from '../auth/auth.service';
import { BookingsModule } from '../bookings/bookings.controller';
import { BookingsService } from '../bookings/bookings.service';
import { DispatchService } from '../dispatch/dispatch.service';
import { SETTING_DEFAULTS, SettingKey, SettingsService } from '../settings/settings.service';

// ---------- DTO ----------

class PlanDto {
  @IsString() @Length(2, 80) name: string;
  @IsOptional() @IsString() @MaxLength(300) description?: string;
  @IsInt() @Min(0) price: number;
  @IsInt() @Min(1) @Max(366) durationDays: number;
  @IsInt() @Min(1) @Max(20) dailyQuota: number;
  @IsOptional() @IsBoolean() isActive?: boolean;
}

class VehicleDto {
  @IsString() @Length(3, 15) plateNumber: string;
  @IsString() @Length(2, 80) model: string;
  @IsInt() @Min(1) @Max(16) seats: number;
  @IsInt() @Min(10) @Max(1500) fullRangeKm: number;
  @IsOptional() @IsEnum(VehicleStatus) status?: VehicleStatus;
  @IsOptional() @IsInt() @Min(0) @Max(100) batteryPercent?: number;
  @IsOptional() @IsInt() @Min(0) odometer?: number;
}

class CreateDriverDto {
  @IsEmail() email: string;
  @IsString() @Length(2, 100) fullName: string;
  @IsOptional() @IsString() phone?: string;
  /** Sandi awal; driver diminta menggantinya. */
  @IsString() @MinLength(8) password: string;
  @IsString() @Length(2, 20) employeeCode: string;
  @IsString() @Length(3, 30) licenseNumber: string;
  @IsDateString() licenseExpiry: string;
}

class ShiftDto {
  @IsUUID('4') driverId: string;
  @IsUUID('4') vehicleId: string;
  /** "YYYY-MM-DD" (WIB) */
  @IsString() date: string;
}

class ManualDispatchDto {
  @IsArray() @ArrayMinSize(1) @IsUUID('4', { each: true }) bookingIds: string[];
  @IsUUID('4') driverId: string;
}

class AutoDispatchDto {
  @IsString() date: string;
}

class ReassignDto {
  @IsUUID('4') driverId: string;
}

class AdminCancelDto {
  @IsString() @Length(3, 200) reason: string;
}

class SettingsDto {
  @IsOptional() @IsInt() @Min(0) @Max(1440) 'booking.cancel_cutoff_minutes'?: number;
  @IsOptional() @IsInt() @Min(0) @Max(1440) 'booking.min_lead_minutes'?: number;
  @IsOptional() @IsInt() @Min(1) @Max(31) 'booking.routine_window_days'?: number;
  @IsOptional() @IsInt() @Min(1) @Max(8) 'booking.max_passengers'?: number;
  @IsOptional() @IsInt() @Min(0) @Max(60) 'driver.no_show_wait_minutes'?: number;
  @IsOptional() @IsInt() @Min(0) @Max(100) 'driver.min_battery_percent'?: number;
}

const dateOrToday = (s?: string) => (s ? parseDateKey(s) : operationalDate(new Date()));
const dayRange = (d: Date) => ({ gte: new Date(d.getTime() - 7 * 3_600_000), lt: new Date(addDays(d, 1).getTime() - 7 * 3_600_000) });

// ---------- service ----------

@Injectable()
export class AdminService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly auth: AuthService,
    private readonly audit: AuditService,
  ) {}

  async dashboard(date: Date) {
    const today = dayRange(date);
    const [activeSubs, paid30, bookingsToday, pending, vehicles, openIncidents] = await Promise.all([
      this.prisma.subscription.count({ where: { status: SubscriptionStatus.ACTIVE, startDate: { lte: date }, endDate: { gte: date } } }),
      this.prisma.payment.aggregate({ _sum: { amount: true }, where: { status: 'PAID', paidAt: { gte: addDays(date, -30) } } }),
      this.prisma.booking.groupBy({ by: ['status'], _count: true, where: { scheduledAt: today } }),
      this.prisma.booking.count({ where: { status: BookingStatus.PENDING_DISPATCH, scheduledAt: today } }),
      this.prisma.vehicle.findMany({ select: { status: true, batteryPercent: true } }),
      this.prisma.incident.count({ where: { resolvedAt: null } }),
    ]);
    return {
      activeSubscriptions: activeSubs,
      revenueLast30Days: paid30._sum.amount ?? 0,
      bookingsToday: Object.fromEntries(bookingsToday.map((g) => [g.status, g._count])),
      pendingDispatchToday: pending,
      vehicles: {
        total: vehicles.length,
        active: vehicles.filter((v) => v.status === VehicleStatus.ACTIVE).length,
        lowBattery: vehicles.filter((v) => v.status === VehicleStatus.ACTIVE && v.batteryPercent < 25).length,
      },
      openIncidents,
    };
  }

  async createDriver(dto: CreateDriverDto, actorId: string) {
    const email = dto.email.trim().toLowerCase();
    if (await this.prisma.user.findUnique({ where: { email } })) throw new BadRequestException('Email sudah dipakai.');
    const driver = await this.prisma.driver.create({
      data: {
        employeeCode: dto.employeeCode.trim(),
        licenseNumber: dto.licenseNumber.trim(),
        licenseExpiry: parseDateKey(dto.licenseExpiry.slice(0, 10)),
        user: {
          create: { email, fullName: dto.fullName.trim(), phone: dto.phone, passwordHash: await this.auth.hashPassword(dto.password), roles: [Role.DRIVER] },
        },
      },
      include: { user: true },
    });
    await this.audit.log({ actorId, action: 'driver.create', entity: 'driver', entityId: driver.id });
    return { ...driver, user: publicUser(driver.user) };
  }

  async createShift(dto: ShiftDto, actorId: string) {
    const date = parseDateKey(dto.date);
    const vehicleBusy = await this.prisma.driverShift.findFirst({ where: { vehicleId: dto.vehicleId, shiftDate: date, driverId: { not: dto.driverId } } });
    if (vehicleBusy) throw new BadRequestException('Kendaraan sudah dipakai driver lain pada tanggal itu.');
    const shift = await this.prisma.driverShift.upsert({
      where: { driverId_shiftDate: { driverId: dto.driverId, shiftDate: date } },
      create: { driverId: dto.driverId, vehicleId: dto.vehicleId, shiftDate: date },
      update: { vehicleId: dto.vehicleId },
    });
    if (shift.status !== ShiftStatus.SCHEDULED && shift.vehicleId !== dto.vehicleId) {
      throw new BadRequestException('Shift sudah berjalan, kendaraan tidak bisa diganti.');
    }
    await this.audit.log({ actorId, action: 'shift.assign', entity: 'driver_shift', entityId: shift.id, data: { ...dto } });
    return shift;
  }

  async liveTracking() {
    const shifts = await this.prisma.driverShift.findMany({
      where: { shiftDate: operationalDate(new Date()), status: { in: [ShiftStatus.AVAILABLE, ShiftStatus.ON_BREAK, ShiftStatus.CHARGING] } },
      include: { driver: { include: { user: { select: { fullName: true } } } }, vehicle: true },
    });
    return Promise.all(
      shifts.map(async (s) => ({
        driverId: s.driverId,
        driverName: s.driver.user.fullName,
        vehicle: s.vehicle.plateNumber,
        batteryPercent: s.vehicle.batteryPercent,
        status: s.status,
        lastLocation: await this.prisma.driverLocation.findFirst({ where: { driverId: s.driverId }, orderBy: { recordedAt: 'desc' } }),
      })),
    );
  }
}

// ---------- controller ----------

const OPS = [Role.OPERATIONS_ADMIN];

@Controller('admin')
export class AdminController {
  constructor(
    private readonly admin: AdminService,
    private readonly prisma: PrismaService,
    private readonly dispatch: DispatchService,
    private readonly bookings: BookingsService,
    private readonly settings: SettingsService,
    private readonly audit: AuditService,
  ) {}

  @Roles(Role.OPERATIONS_ADMIN, Role.FINANCE_ADMIN, Role.FLEET_ADMIN, Role.CUSTOMER_SUPPORT)
  @Get('dashboard')
  dashboard(@Query('date') date?: string) {
    return this.admin.dashboard(dateOrToday(date));
  }

  // Paket
  @Roles(Role.FINANCE_ADMIN)
  @Get('plans')
  plans() {
    return this.prisma.subscriptionPlan.findMany({ orderBy: { createdAt: 'asc' } });
  }

  @Roles(Role.FINANCE_ADMIN)
  @Post('plans')
  async createPlan(@CurrentUser() u: AuthUser, @Body() dto: PlanDto) {
    const p = await this.prisma.subscriptionPlan.create({ data: dto });
    await this.audit.log({ actorId: u.id, action: 'plan.create', entity: 'plan', entityId: p.id, data: { ...dto } });
    return p;
  }

  /** Mengubah paket tidak mengubah langganan yang sudah dibeli (harga dan kuota disalin saat pembelian). */
  @Roles(Role.FINANCE_ADMIN)
  @Patch('plans/:id')
  async updatePlan(@CurrentUser() u: AuthUser, @Param('id', ParseUUIDPipe) id: string, @Body() dto: PlanDto) {
    const p = await this.prisma.subscriptionPlan.update({ where: { id }, data: dto });
    await this.audit.log({ actorId: u.id, action: 'plan.update', entity: 'plan', entityId: id, data: { ...dto } });
    return p;
  }

  // Armada
  @Roles(Role.FLEET_ADMIN, Role.OPERATIONS_ADMIN)
  @Get('vehicles')
  vehicles() {
    return this.prisma.vehicle.findMany({ orderBy: { plateNumber: 'asc' } });
  }

  @Roles(Role.FLEET_ADMIN)
  @Post('vehicles')
  async createVehicle(@CurrentUser() u: AuthUser, @Body() dto: VehicleDto) {
    const v = await this.prisma.vehicle.create({ data: { ...dto, plateNumber: dto.plateNumber.toUpperCase().trim() } });
    await this.audit.log({ actorId: u.id, action: 'vehicle.create', entity: 'vehicle', entityId: v.id });
    return v;
  }

  @Roles(Role.FLEET_ADMIN)
  @Patch('vehicles/:id')
  async updateVehicle(@CurrentUser() u: AuthUser, @Param('id', ParseUUIDPipe) id: string, @Body() dto: VehicleDto) {
    const v = await this.prisma.vehicle.update({ where: { id }, data: { ...dto, plateNumber: dto.plateNumber.toUpperCase().trim() } });
    await this.audit.log({ actorId: u.id, action: 'vehicle.update', entity: 'vehicle', entityId: id, data: { ...dto } });
    return v;
  }

  // Driver & shift
  @Roles(...OPS, Role.FLEET_ADMIN)
  @Get('drivers')
  async drivers() {
    const list = await this.prisma.driver.findMany({ include: { user: true }, orderBy: { employeeCode: 'asc' } });
    return list.map((d) => ({ ...d, user: publicUser(d.user) }));
  }

  @Roles(...OPS)
  @Post('drivers')
  createDriver(@CurrentUser() u: AuthUser, @Body() dto: CreateDriverDto) {
    return this.admin.createDriver(dto, u.id);
  }

  @Roles(...OPS)
  @Get('shifts')
  shifts(@Query('date') date?: string) {
    return this.prisma.driverShift.findMany({
      where: { shiftDate: dateOrToday(date) },
      include: { driver: { include: { user: { select: { fullName: true } } } }, vehicle: true },
    });
  }

  @Roles(...OPS)
  @Post('shifts')
  createShift(@CurrentUser() u: AuthUser, @Body() dto: ShiftDto) {
    return this.admin.createShift(dto, u.id);
  }

  // Dispatch
  @Roles(...OPS)
  @Get('dispatch/queue')
  queue(@Query('date') date?: string) {
    return this.dispatch.queue(dateOrToday(date));
  }

  @Roles(...OPS)
  @Post('dispatch/manual')
  manual(@CurrentUser() u: AuthUser, @Body() dto: ManualDispatchDto) {
    return this.dispatch.assign(dto.bookingIds, dto.driverId, u.id);
  }

  @Roles(...OPS)
  @HttpCode(200)
  @Post('dispatch/auto')
  auto(@CurrentUser() u: AuthUser, @Body() dto: AutoDispatchDto) {
    return this.dispatch.autoAssign(parseDateKey(dto.date), u.id);
  }

  @Roles(...OPS)
  @Get('trips')
  trips(@Query('date') date?: string) {
    return this.prisma.trip.findMany({
      where: { scheduledAt: dayRange(dateOrToday(date)) },
      orderBy: { scheduledAt: 'asc' },
      include: { stops: { orderBy: { sequence: 'asc' } }, driver: { include: { user: { select: { fullName: true } } } }, vehicle: true },
    });
  }

  @Roles(...OPS)
  @HttpCode(200)
  @Post('trips/:id/reassign')
  reassign(@CurrentUser() u: AuthUser, @Param('id', ParseUUIDPipe) id: string, @Body() dto: ReassignDto) {
    return this.dispatch.reassign(id, dto.driverId, u.id);
  }

  @Roles(...OPS)
  @Get('live-tracking')
  live() {
    return this.admin.liveTracking();
  }

  // Booking & pelanggan
  @Roles(...OPS, Role.CUSTOMER_SUPPORT)
  @Get('bookings')
  bookingsList(@Query('date') date?: string, @Query('status') status?: BookingStatus) {
    const where: Prisma.BookingWhereInput = { scheduledAt: dayRange(dateOrToday(date)) };
    if (status) where.status = status;
    return this.prisma.booking.findMany({ where, orderBy: { scheduledAt: 'asc' }, include: { user: { select: { fullName: true, phone: true } } } });
  }

  @Roles(...OPS, Role.CUSTOMER_SUPPORT)
  @HttpCode(200)
  @Post('bookings/:id/cancel')
  cancelBooking(@CurrentUser() u: AuthUser, @Param('id', ParseUUIDPipe) id: string, @Body() dto: AdminCancelDto) {
    return this.bookings.cancelByCompany(id, dto.reason, u.id);
  }

  @Roles(Role.CUSTOMER_SUPPORT, Role.FINANCE_ADMIN, ...OPS)
  @Get('customers')
  async customers(@Query('q') q?: string) {
    const users = await this.prisma.user.findMany({
      where: {
        roles: { has: Role.CUSTOMER },
        ...(q ? { OR: [{ fullName: { contains: q, mode: 'insensitive' } }, { email: { contains: q, mode: 'insensitive' } }, { phone: { contains: q } }] } : {}),
      },
      take: 100,
      orderBy: { createdAt: 'desc' },
      include: { subscriptions: { where: { status: SubscriptionStatus.ACTIVE }, select: { startDate: true, endDate: true } } },
    });
    return users.map((x) => ({ ...publicUser(x), subscriptions: x.subscriptions }));
  }

  // Insiden
  @Roles(...OPS, Role.FLEET_ADMIN)
  @Get('incidents')
  incidents(@Query('open') open?: string) {
    return this.prisma.incident.findMany({
      where: open === 'true' ? { resolvedAt: null } : {},
      orderBy: [{ emergency: 'desc' }, { createdAt: 'desc' }],
      take: 200,
      include: { driver: { include: { user: { select: { fullName: true, phone: true } } } } },
    });
  }

  @Roles(...OPS, Role.FLEET_ADMIN)
  @HttpCode(200)
  @Post('incidents/:id/resolve')
  async resolve(@CurrentUser() u: AuthUser, @Param('id', ParseUUIDPipe) id: string) {
    const r = await this.prisma.incident.updateMany({ where: { id, resolvedAt: null }, data: { resolvedAt: new Date() } });
    if (r.count === 0) throw new NotFoundException('Insiden tidak ditemukan atau sudah selesai.');
    await this.audit.log({ actorId: u.id, action: 'incident.resolve', entity: 'incident', entityId: id });
    return { ok: true };
  }

  // Pengaturan & job
  @Roles(Role.SUPER_ADMIN)
  @Get('settings')
  getSettings() {
    return this.settings.all();
  }

  @Roles(Role.SUPER_ADMIN)
  @Put('settings')
  async putSettings(@CurrentUser() u: AuthUser, @Body() dto: SettingsDto) {
    for (const [k, v] of Object.entries(dto)) {
      if (k in SETTING_DEFAULTS && typeof v === 'number') await this.settings.setNumber(k as SettingKey, v, u.id);
    }
    await this.audit.log({ actorId: u.id, action: 'settings.update', entity: 'settings', data: { ...dto } });
    return this.settings.all();
  }

  /** Dijalankan cron harian, bisa juga manual. */
  @Roles(...OPS)
  @HttpCode(200)
  @Post('jobs/generate-routines')
  generate() {
    return this.bookings.generateAllRoutines();
  }

  @Roles(Role.SUPER_ADMIN)
  @Get('audit-logs')
  async auditLogs(@Query('entity') entity?: string, @Query('entityId') entityId?: string) {
    const rows = await this.prisma.auditLog.findMany({ where: { entity, entityId }, orderBy: { createdAt: 'desc' }, take: 200 });
    return rows.map((r) => ({ ...r, id: r.id.toString() }));
  }
}

@Module({
  imports: [BookingsModule],
  controllers: [AdminController],
  providers: [AdminService, DispatchService],
})
export class AdminModule {}
