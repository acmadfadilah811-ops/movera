import { QuotaOutcome } from '@prisma/client';
import { addDays, atJakartaTime, isoWeekday, operationalDate } from '../../common/jakarta-time';

/** Aturan kuota dan booking dalam bentuk fungsi murni, supaya mudah dites (blueprint 8.1-8.3). */

/** Pembatalan sebelum batas waktu mengembalikan kuota, sesudahnya hangus. */
export function cancellationOutcome(now: Date, scheduledAt: Date, cutoffMinutes: number): QuotaOutcome {
  return now.getTime() <= scheduledAt.getTime() - cutoffMinutes * 60_000 ? QuotaOutcome.RELEASED : QuotaOutcome.FORFEITED;
}

/** Booking paling cepat [minLeadMinutes] menit dari sekarang. */
export function meetsLeadTime(now: Date, scheduledAt: Date, minLeadMinutes: number): boolean {
  return scheduledAt.getTime() >= now.getTime() + minLeadMinutes * 60_000;
}

/** Langganan baru mulai hari ini, atau sehari setelah langganan aktif terakhir berakhir (perpanjangan). */
export function renewalStartDate(now: Date, activeEndDates: Date[]): Date {
  const today = operationalDate(now);
  const lastEnd = activeEndDates.filter((d) => d.getTime() >= today.getTime()).sort((a, b) => b.getTime() - a.getTime())[0];
  return lastEnd ? addDays(lastEnd, 1) : today;
}

export function subscriptionEndDate(start: Date, durationDays: number): Date {
  return addDays(start, durationDays - 1);
}

/** Waktu jemput booking rutin dalam jendela [windowDays] hari mulai hari ini, yang masih memenuhi batas minimal waktu. */
export function routineInstanceTimes(
  schedule: { weekdays: number[]; hour: number; minute: number },
  now: Date,
  windowDays: number,
  minLeadMinutes: number,
): Date[] {
  const today = operationalDate(now);
  const result: Date[] = [];
  for (let i = 0; i < windowDays; i++) {
    const day = addDays(today, i);
    if (!schedule.weekdays.includes(isoWeekday(day))) continue;
    const at = atJakartaTime(day, schedule.hour, schedule.minute);
    if (meetsLeadTime(now, at, minLeadMinutes)) result.push(at);
  }
  return result;
}

/** PIN jemput 4 digit. */
export function generatePin(random: () => number = Math.random): string {
  return String(1000 + Math.floor(random() * 9000));
}
