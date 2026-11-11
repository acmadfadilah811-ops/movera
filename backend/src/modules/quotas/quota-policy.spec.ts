import { QuotaOutcome } from '@prisma/client';
import { atJakartaTime, dateKey, isoWeekday, operationalDate, parseDateKey } from '../../common/jakarta-time';
import { cancellationOutcome, generatePin, meetsLeadTime, renewalStartDate, routineInstanceTimes, subscriptionEndDate } from './quota-policy';

/** Kamis 12 Nov 2026 06.00 WIB = 11 Nov 23.00 UTC */
const now = new Date('2026-11-11T23:00:00Z');

describe('waktu operasional WIB', () => {
  it('tanggal operasional mengikuti WIB, bukan UTC', () => {
    expect(dateKey(operationalDate(now))).toBe('2026-11-12');
    expect(dateKey(operationalDate(new Date('2026-11-12T16:59:00Z')))).toBe('2026-11-12'); // 23.59 WIB
    expect(dateKey(operationalDate(new Date('2026-11-12T17:00:00Z')))).toBe('2026-11-13'); // 00.00 WIB
  });

  it('jam WIB pada tanggal tertentu dikonversi ke UTC', () => {
    expect(atJakartaTime(parseDateKey('2026-11-12'), 7, 30).toISOString()).toBe('2026-11-12T00:30:00.000Z');
  });

  it('hari dalam minggu 1=Senin sampai 7=Minggu', () => {
    expect(isoWeekday(parseDateKey('2026-11-16'))).toBe(1);
    expect(isoWeekday(parseDateKey('2026-11-15'))).toBe(7);
  });

  it('format tanggal tidak valid ditolak', () => {
    expect(() => parseDateKey('12-11-2026')).toThrow();
  });
});

describe('aturan kuota dan booking', () => {
  const at = new Date('2026-11-12T03:00:00Z'); // 10.00 WIB

  it('batal tepat di batas waktu masih mengembalikan kuota, lewat sedikit hangus', () => {
    expect(cancellationOutcome(new Date('2026-11-12T02:00:00Z'), at, 60)).toBe(QuotaOutcome.RELEASED);
    expect(cancellationOutcome(new Date('2026-11-12T02:00:01Z'), at, 60)).toBe(QuotaOutcome.FORFEITED);
  });

  it('booking harus memenuhi waktu minimal dari sekarang', () => {
    expect(meetsLeadTime(now, new Date(now.getTime() + 60 * 60_000), 60)).toBe(true);
    expect(meetsLeadTime(now, new Date(now.getTime() + 59 * 60_000), 60)).toBe(false);
  });

  it('langganan baru mulai hari ini; perpanjangan mulai setelah masa aktif terakhir', () => {
    expect(dateKey(renewalStartDate(now, []))).toBe('2026-11-12');
    expect(dateKey(renewalStartDate(now, [parseDateKey('2026-11-20'), parseDateKey('2026-12-19')]))).toBe('2026-12-20');
    // Langganan yang sudah berakhir diabaikan.
    expect(dateKey(renewalStartDate(now, [parseDateKey('2026-11-01')]))).toBe('2026-11-12');
  });

  it('masa aktif 30 hari termasuk hari mulai', () => {
    expect(dateKey(subscriptionEndDate(parseDateKey('2026-11-12'), 30))).toBe('2026-12-11');
  });

  it('jadwal rutin Senin/Rabu/Jumat 07.00 untuk 7 hari, melewati jadwal yang terlalu dekat', () => {
    const times = routineInstanceTimes({ weekdays: [1, 3, 5], hour: 7, minute: 0 }, now, 7, 60);
    expect(times.map((t) => dateKey(operationalDate(t)))).toEqual(['2026-11-13', '2026-11-16', '2026-11-18']);
    // Kamis 06.00 WIB, jadwal Kamis 06.30 terlalu dekat (kurang dari 60 menit).
    expect(routineInstanceTimes({ weekdays: [4], hour: 6, minute: 30 }, now, 7, 60)).toHaveLength(0);
    expect(routineInstanceTimes({ weekdays: [4], hour: 7, minute: 0 }, now, 7, 60)).toHaveLength(1);
  });

  it('PIN selalu 4 digit', () => {
    expect(generatePin(() => 0)).toBe('1000');
    expect(generatePin(() => 0.99999)).toBe('9999');
  });
});
