/**
 * Tes end-to-end memakai database terpisah dari TEST_DATABASE_URL (jangan arahkan ke database produksi).
 * Database dikosongkan dan dimigrasi ulang sebelum tes.
 */
import { execSync } from 'child_process';
import { existsSync, readFileSync } from 'fs';
import { join } from 'path';

const envFile = join(__dirname, '..', '.env.test');
if (existsSync(envFile)) {
  for (const line of readFileSync(envFile, 'utf8').split(/\r?\n/)) {
    const m = line.match(/^([A-Z0-9_]+)=(.*)$/);
    if (m && process.env[m[1]] === undefined) process.env[m[1]] = m[2].replace(/^"(.*)"$/, '$1');
  }
}

const url = process.env.TEST_DATABASE_URL;
if (!url) throw new Error('Isi TEST_DATABASE_URL di backend/.env.test untuk menjalankan tes e2e.');
if (!/test/i.test(new URL(url).pathname)) throw new Error('Nama database tes harus mengandung kata "test".');

process.env.DATABASE_URL = url;
process.env.JWT_ACCESS_SECRET ??= 'rahasia-tes-akses';
process.env.ALLOW_PAYMENT_SIMULATION = 'true';
process.env.MIDTRANS_SERVER_KEY ??= '';

if (!(global as { __dbReset?: boolean }).__dbReset) {
  execSync('npx --no-install prisma migrate reset --force --skip-seed --skip-generate', {
    cwd: join(__dirname, '..'),
    env: { ...process.env, DATABASE_URL: url },
    stdio: 'ignore',
  });
  (global as { __dbReset?: boolean }).__dbReset = true;
}
