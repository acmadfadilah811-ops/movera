/**
 * Data awal: paket langganan, akun super admin, satu kendaraan dan satu driver contoh.
 * Jalankan: npm run db:seed (sandi diambil dari SEED_ADMIN_PASSWORD / SEED_DRIVER_PASSWORD).
 */
import { PrismaClient, Role } from '@prisma/client';
import * as bcrypt from 'bcryptjs';

const prisma = new PrismaClient();

async function main() {
  const adminPassword = process.env.SEED_ADMIN_PASSWORD;
  const driverPassword = process.env.SEED_DRIVER_PASSWORD;
  if (!adminPassword || adminPassword.length < 12) throw new Error('Isi SEED_ADMIN_PASSWORD minimal 12 karakter.');

  const planCount = await prisma.subscriptionPlan.count();
  if (planCount === 0) {
    await prisma.subscriptionPlan.create({
      data: { name: 'Paket Bulanan', description: 'Antar-jemput mobil listrik selama 30 hari.', price: 300000, durationDays: 30, dailyQuota: 4 },
    });
  }

  await prisma.user.upsert({
    where: { email: 'admin@movera.local' },
    create: {
      email: 'admin@movera.local',
      fullName: 'Admin Movera',
      passwordHash: await bcrypt.hash(adminPassword, 12),
      roles: [Role.SUPER_ADMIN],
    },
    update: {},
  });

  const vehicle = await prisma.vehicle.upsert({
    where: { plateNumber: 'R 1204 MV' },
    create: { plateNumber: 'R 1204 MV', model: 'Mobil listrik 5 kursi', seats: 4, fullRangeKm: 300, batteryPercent: 82 },
    update: {},
  });

  if (driverPassword) {
    const user = await prisma.user.upsert({
      where: { email: 'driver1@movera.local' },
      create: {
        email: 'driver1@movera.local',
        fullName: 'Budi Santoso',
        passwordHash: await bcrypt.hash(driverPassword, 12),
        roles: [Role.DRIVER],
      },
      update: {},
    });
    await prisma.driver.upsert({
      where: { userId: user.id },
      create: { userId: user.id, employeeCode: 'DRV-001', licenseNumber: 'SIM-A-0000', licenseExpiry: new Date('2030-01-01') },
      update: {},
    });
  }

  console.log(`Seed selesai. Kendaraan contoh: ${vehicle.plateNumber}`);
}

main()
  .catch((e) => {
    console.error(e);
    process.exitCode = 1;
  })
  .finally(() => prisma.$disconnect());
