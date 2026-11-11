import { INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import { PrismaClient, Role } from '@prisma/client';
import request from 'supertest';
import { AppModule } from '../src/app.module';
import { addDays, atJakartaTime, dateKey, isoWeekday, operationalDate } from '../src/common/jakarta-time';
import { configureApp } from '../src/main';

const prisma = new PrismaClient();
let app: INestApplication;
let http: ReturnType<typeof request>;

const tomorrow = addDays(operationalDate(new Date()), 1);
const at = (dayOffset: number, hour: number, minute = 0) => atJakartaTime(addDays(tomorrow, dayOffset), hour, minute).toISOString();

const place = (n: number) => ({ label: `Titik ${n}`, address: `Jl. Uji ${n}, Cilacap`, latitude: -7.72 + n / 1000, longitude: 109.01 + n / 1000 });
const flexible = (scheduledAt: string) => ({
  type: 'FLEXIBLE',
  rideMode: 'INDIVIDUAL',
  pickup: place(1),
  destination: place(2),
  passengerCount: 1,
  passengerNames: ['Uji'],
  scheduledAt,
});

let seq = 0;
async function newCustomer() {
  seq += 1;
  const res = await http.post('/api/v1/auth/register').send({ email: `pelanggan${seq}@uji.test`, password: 'sandi-uji-123', fullName: `Pelanggan ${seq}` });
  expect(res.status).toBe(201);
  return { token: res.body.accessToken as string, refresh: res.body.refreshToken as string, id: res.body.user.id as string };
}

async function subscribe(token: string) {
  const plans = await http.get('/api/v1/plans');
  const checkout = await http.post('/api/v1/payments/checkout').set('Authorization', `Bearer ${token}`).send({ planId: plans.body[0].id });
  expect(checkout.status).toBe(201);
  const paid = await http.post(`/api/v1/payments/${checkout.body.paymentId}/simulate-paid`).set('Authorization', `Bearer ${token}`);
  expect(paid.status).toBe(201);
  return paid.body;
}

beforeAll(async () => {
  await prisma.subscriptionPlan.create({ data: { name: 'Paket Bulanan', price: 300000, durationDays: 30, dailyQuota: 4 } });
  const mod = await Test.createTestingModule({ imports: [AppModule] }).compile();
  app = mod.createNestApplication();
  configureApp(app);
  await app.init();
  http = request(app.getHttpServer());
});

afterAll(async () => {
  await app?.close();
  await prisma.$disconnect();
});

describe('auth', () => {
  it('daftar, login, profil, rotasi refresh token, dan deteksi pemakaian ulang token', async () => {
    const c = await newCustomer();
    const me = await http.get('/api/v1/auth/me').set('Authorization', `Bearer ${c.token}`);
    expect(me.body.roles).toEqual(['CUSTOMER']);

    const wrong = await http.post('/api/v1/auth/login').send({ email: `pelanggan${seq}@uji.test`, password: 'salah-sandi' });
    expect(wrong.status).toBe(401);

    const r1 = await http.post('/api/v1/auth/refresh').send({ refreshToken: c.refresh });
    expect(r1.status).toBe(200);
    // Token lama dipakai lagi: semua sesi dicabut, termasuk token baru.
    expect((await http.post('/api/v1/auth/refresh').send({ refreshToken: c.refresh })).status).toBe(401);
    expect((await http.post('/api/v1/auth/refresh').send({ refreshToken: r1.body.refreshToken })).status).toBe(401);
  });

  it('endpoint tanpa token ditolak, peran yang salah ditolak', async () => {
    expect((await http.get('/api/v1/bookings')).status).toBe(401);
    const driver = await prisma.user.create({
      data: { email: 'driver@uji.test', fullName: 'Driver', passwordHash: await (await import('bcryptjs')).hash('sandi-driver-1', 4), roles: [Role.DRIVER] },
    });
    const login = await http.post('/api/v1/auth/login').send({ email: driver.email, password: 'sandi-driver-1' });
    const res = await http.post('/api/v1/bookings').set('Authorization', `Bearer ${login.body.accessToken}`).send(flexible(at(0, 10)));
    expect(res.status).toBe(403);
  });
});

describe('langganan dan kuota', () => {
  it('booking ditolak tanpa langganan', async () => {
    const c = await newCustomer();
    const res = await http.post('/api/v1/bookings').set('Authorization', `Bearer ${c.token}`).send(flexible(at(0, 10)));
    expect(res.status).toBe(409);
  });

  it('aktivasi ganda tidak membuat langganan ganda; kuota 4 per hari', async () => {
    const c = await newCustomer();
    const sub = await subscribe(c.token);
    const again = await http.post(`/api/v1/payments/${sub.paymentId}/simulate-paid`).set('Authorization', `Bearer ${c.token}`);
    expect(again.body.id).toBe(sub.id);
    const current = await http.get('/api/v1/subscriptions/current').set('Authorization', `Bearer ${c.token}`);
    expect(current.body.subscriptions).toHaveLength(1);
    expect(current.body.quotas[0]).toMatchObject({ total: 4, remaining: 4 });
  });

  it('kuota terakhir tidak bisa dipesan dua request bersamaan', async () => {
    const c = await newCustomer();
    await subscribe(c.token);
    const results = await Promise.all(
      Array.from({ length: 8 }, (_, i) =>
        http.post('/api/v1/bookings').set('Authorization', `Bearer ${c.token}`).send(flexible(at(1, 8, i * 5))),
      ),
    );
    const ok = results.filter((r) => r.status === 201).length;
    const full = results.filter((r) => r.status === 409).length;
    expect(ok).toBe(4);
    expect(full).toBe(4);
    const q = await prisma.dailyQuota.findFirstOrThrow({ where: { subscription: { userId: c.id }, quotaDate: addDays(tomorrow, 1) } });
    expect(q.reserved).toBe(4);
  });

  it('batal sebelum batas waktu mengembalikan kuota dan tercatat; pembatalan kedua ditolak', async () => {
    const c = await newCustomer();
    await subscribe(c.token);
    const created = await http.post('/api/v1/bookings').set('Authorization', `Bearer ${c.token}`).send(flexible(at(2, 9)));
    const id = created.body.created[0].id;
    const cancel = await http.post(`/api/v1/bookings/${id}/cancel`).set('Authorization', `Bearer ${c.token}`).send({ reason: 'Jadwal berubah' });
    expect(cancel.status).toBe(200);
    expect(cancel.body.quotaOutcome).toBe('RELEASED');
    expect((await http.post(`/api/v1/bookings/${id}/cancel`).set('Authorization', `Bearer ${c.token}`).send({ reason: 'lagi' })).status).toBe(400);
    const tx = await prisma.quotaTransaction.findMany({ where: { bookingId: id }, orderBy: { createdAt: 'asc' } });
    expect(tx.map((t) => t.action)).toEqual(['RESERVE', 'RELEASE']);
  });

  it('pelanggan lain tidak bisa melihat atau membatalkan booking orang lain', async () => {
    const a = await newCustomer();
    const b = await newCustomer();
    await subscribe(a.token);
    const created = await http.post('/api/v1/bookings').set('Authorization', `Bearer ${a.token}`).send(flexible(at(3, 9)));
    const id = created.body.created[0].id;
    expect((await http.get(`/api/v1/bookings/${id}`).set('Authorization', `Bearer ${b.token}`)).status).toBe(404);
    expect((await http.post(`/api/v1/bookings/${id}/cancel`).set('Authorization', `Bearer ${b.token}`).send({ reason: 'x' })).status).toBe(404);
  });

  it('jadwal rutin membuat booking per tanggal, generator tidak menggandakan, dihentikan mengembalikan kuota', async () => {
    const c = await newCustomer();
    await subscribe(c.token);
    const weekday = isoWeekday(addDays(tomorrow, 1));
    const res = await http
      .post('/api/v1/bookings')
      .set('Authorization', `Bearer ${c.token}`)
      .send({ type: 'ROUTINE', rideMode: 'SHARED', pickup: place(3), destination: place(4), passengerCount: 1, weekdays: [weekday], hour: 7, minute: 0 });
    expect(res.status).toBe(201);
    expect(res.body.created).toHaveLength(1);
    expect(dateKey(operationalDate(new Date(res.body.created[0].scheduledAt)))).toBe(dateKey(addDays(tomorrow, 1)));

    const list1 = await http.get('/api/v1/bookings?scope=upcoming').set('Authorization', `Bearer ${c.token}`);
    expect(list1.body).toHaveLength(1);

    const stop = await http.delete(`/api/v1/recurring-schedules/${res.body.schedule.id}`).set('Authorization', `Bearer ${c.token}`);
    expect(stop.body.cancelled).toBe(1);
    const current = await http.get('/api/v1/subscriptions/current').set('Authorization', `Bearer ${c.token}`);
    const q = current.body.quotas.find((x: { date: string }) => x.date === dateKey(addDays(tomorrow, 1)));
    expect(q.remaining).toBe(4);
  });

  it('penumpang anak wajib punya kontak darurat', async () => {
    const c = await newCustomer();
    const bad = await http.post('/api/v1/me/passengers').set('Authorization', `Bearer ${c.token}`).send({ name: 'Rafi', relation: 'Anak', isChild: true });
    expect(bad.status).toBe(400);
    const ok = await http
      .post('/api/v1/me/passengers')
      .set('Authorization', `Bearer ${c.token}`)
      .send({ name: 'Rafi', relation: 'Anak', isChild: true, emergencyName: 'Ibu Rina', emergencyPhone: '081234567890' });
    expect(ok.status).toBe(201);
  });
});

describe('dispatch dan driver', () => {
  async function adminToken() {
    const bcrypt = await import('bcryptjs');
    await prisma.user.upsert({
      where: { email: 'ops@uji.test' },
      create: { email: 'ops@uji.test', fullName: 'Ops', passwordHash: await bcrypt.hash('sandi-ops-123', 4), roles: [Role.OPERATIONS_ADMIN, Role.FLEET_ADMIN] },
      update: {},
    });
    return (await http.post('/api/v1/auth/login').send({ email: 'ops@uji.test', password: 'sandi-ops-123' })).body.accessToken as string;
  }

  it('alur penuh: armada, shift, booking, dispatch, PIN, selesai, kuota terpakai', async () => {
    const ops = await adminToken();
    const auth = (t: string) => ({ Authorization: `Bearer ${t}` });

    const vehicle = await http.post('/api/v1/admin/vehicles').set(auth(ops)).send({ plateNumber: 'R 9001 UJ', model: 'EV uji', seats: 4, fullRangeKm: 300, batteryPercent: 90 });
    expect(vehicle.status).toBe(201);
    const driver = await http.post('/api/v1/admin/drivers').set(auth(ops)).send({
      email: 'drv-flow@uji.test', fullName: 'Driver Alur', password: 'sandi-driver-9', employeeCode: 'DRV-UJI', licenseNumber: 'SIM-UJI-1', licenseExpiry: '2030-01-01',
    });
    expect(driver.status).toBe(201);

    // Shift untuk hari ini (driver memulai shift) dan besok (tanggal booking).
    const todayKey = dateKey(operationalDate(new Date()));
    for (const date of [todayKey, dateKey(tomorrow)]) {
      const r = await http.post('/api/v1/admin/shifts').set(auth(ops)).send({ driverId: driver.body.id, vehicleId: vehicle.body.id, date });
      expect(r.status).toBe(201);
    }

    const c = await newCustomer();
    await subscribe(c.token);
    const booked = await http.post('/api/v1/bookings').set(auth(c.token)).send(flexible(at(0, 15)));
    const booking = booked.body.created[0];

    const queue = await http.get(`/api/v1/admin/dispatch/queue?date=${dateKey(tomorrow)}`).set(auth(ops));
    expect(queue.body.map((b: { id: string }) => b.id)).toContain(booking.id);

    // Customer tidak boleh mengakses dispatch.
    expect((await http.post('/api/v1/admin/dispatch/manual').set(auth(c.token)).send({ bookingIds: [booking.id], driverId: driver.body.id })).status).toBe(403);

    const trip = await http.post('/api/v1/admin/dispatch/manual').set(auth(ops)).send({ bookingIds: [booking.id], driverId: driver.body.id });
    expect(trip.status).toBe(201);
    expect(trip.body.stops.map((s: { type: string }) => s.type)).toEqual(['PICKUP', 'DROPOFF']);
    // Booking yang sama tidak bisa masuk dua trip.
    expect((await http.post('/api/v1/admin/dispatch/manual').set(auth(ops)).send({ bookingIds: [booking.id], driverId: driver.body.id })).status).toBe(409);

    // Trip besok dipindah ke shift hari ini supaya bisa dijalankan dalam tes.
    const todayShift = await prisma.driverShift.findFirstOrThrow({ where: { driverId: driver.body.id, shiftDate: operationalDate(new Date()) } });
    await prisma.trip.update({ where: { id: trip.body.id }, data: { shiftId: todayShift.id } });

    const d = (await http.post('/api/v1/auth/login').send({ email: 'drv-flow@uji.test', password: 'sandi-driver-9' })).body.accessToken;
    const checklist = [{ key: 'rem', label: 'Rem', critical: true, ok: false }];
    expect((await http.post('/api/v1/driver/shift/start').set(auth(d)).send({ checklist, batteryPercent: 90, odometer: 100 })).status).toBe(400);
    checklist[0].ok = true;
    expect((await http.post('/api/v1/driver/shift/start').set(auth(d)).send({ checklist, batteryPercent: 90, odometer: 100 })).status).toBe(200);

    const tripId = trip.body.id;
    const [pickup, drop] = trip.body.stops;
    expect((await http.post(`/api/v1/driver/trips/${tripId}/accept`).set(auth(d))).status).toBe(200);
    expect((await http.post(`/api/v1/driver/trips/${tripId}/stops/${drop.id}/arrive`).set(auth(d))).status).toBe(400);
    expect((await http.post(`/api/v1/driver/trips/${tripId}/stops/${pickup.id}/arrive`).set(auth(d))).status).toBe(200);
    expect((await http.post(`/api/v1/driver/trips/${tripId}/stops/${pickup.id}/pickup`).set(auth(d)).send({ pin: '0000' === booking.pickupPin ? '1111' : '0000' })).status).toBe(400);
    expect((await http.post(`/api/v1/driver/trips/${tripId}/stops/${pickup.id}/pickup`).set(auth(d)).send({ pin: booking.pickupPin })).status).toBe(200);
    expect((await http.post(`/api/v1/driver/trips/${tripId}/stops/${drop.id}/arrive`).set(auth(d))).status).toBe(200);
    const done = await http.post(`/api/v1/driver/trips/${tripId}/stops/${drop.id}/dropoff`).set(auth(d));
    expect(done.body.status).toBe('COMPLETED');

    const b = await prisma.booking.findUniqueOrThrow({ where: { id: booking.id }, include: { dailyQuota: true } });
    expect(b.status).toBe('COMPLETED');
    expect(b.dailyQuota.reserved).toBe(0);
    expect(b.dailyQuota.consumed).toBe(1);

    // Driver lain tidak bisa mengakses trip ini.
    const other = await http.post('/api/v1/admin/drivers').set(auth(ops)).send({
      email: 'drv-other@uji.test', fullName: 'Driver Lain', password: 'sandi-driver-8', employeeCode: 'DRV-UJI2', licenseNumber: 'SIM-UJI-2', licenseExpiry: '2030-01-01',
    });
    expect(other.status).toBe(201);
    const d2 = (await http.post('/api/v1/auth/login').send({ email: 'drv-other@uji.test', password: 'sandi-driver-8' })).body.accessToken;
    expect((await http.post(`/api/v1/driver/trips/${tripId}/accept`).set(auth(d2))).status).toBe(404);
  });
});

