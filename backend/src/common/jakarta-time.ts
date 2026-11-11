/**
 * Waktu operasional Movera memakai Asia/Jakarta (UTC+7, tanpa daylight saving).
 * Tanggal operasional disimpan sebagai Date pada tengah malam UTC (kolom @db.Date).
 */
const OFFSET_MS = 7 * 60 * 60 * 1000;
const DAY_MS = 24 * 60 * 60 * 1000;

/** Tanggal operasional (WIB) dari sebuah waktu. */
export function operationalDate(at: Date): Date {
  const shifted = new Date(at.getTime() + OFFSET_MS);
  return new Date(Date.UTC(shifted.getUTCFullYear(), shifted.getUTCMonth(), shifted.getUTCDate()));
}

export function addDays(date: Date, days: number): Date {
  return new Date(date.getTime() + days * DAY_MS);
}

/** Hari dalam minggu (1 = Senin ... 7 = Minggu) untuk tanggal operasional. */
export function isoWeekday(date: Date): number {
  const d = date.getUTCDay();
  return d === 0 ? 7 : d;
}

/** Waktu UTC untuk jam:menit WIB pada tanggal operasional tertentu. */
export function atJakartaTime(date: Date, hour: number, minute: number): Date {
  return new Date(date.getTime() + (hour * 60 + minute) * 60 * 1000 - OFFSET_MS);
}

/** "2026-11-12" */
export function dateKey(date: Date): string {
  return date.toISOString().slice(0, 10);
}

/** Tanggal operasional dari string "YYYY-MM-DD". */
export function parseDateKey(key: string): Date {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(key)) throw new Error(`Format tanggal tidak valid: ${key}`);
  return new Date(`${key}T00:00:00.000Z`);
}
