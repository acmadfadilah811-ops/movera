import { Global, Injectable, Module } from '@nestjs/common';
import { Prisma, QuotaAction } from '@prisma/client';
import { operationalDate } from '../../common/jakarta-time';

type Tx = Prisma.TransactionClient;

export class QuotaError extends Error {}

/**
 * Operasi kuota harian. Semua perubahan memakai UPDATE bersyarat di database sehingga dua request
 * bersamaan untuk kuota terakhir tidak bisa sama-sama berhasil (blueprint 8.2, DoD "concurrent booking").
 * Wajib dipanggil di dalam transaksi bersama pembuatan/perubahan booking.
 */
@Injectable()
export class QuotaService {
  /** Mencadangkan 1 kuota pada tanggal operasional [at]. Mengembalikan id DailyQuota. */
  async reserve(tx: Tx, sub: { id: string; dailyQuota: number }, at: Date, bookingId: string, actorId?: string): Promise<string> {
    const day = operationalDate(at);
    await tx.$executeRaw`
      INSERT INTO "daily_quotas" ("id", "subscriptionId", "quotaDate", "total", "reserved", "consumed")
      VALUES (gen_random_uuid(), ${sub.id}::uuid, ${day}::date, ${sub.dailyQuota}, 0, 0)
      ON CONFLICT ("subscriptionId", "quotaDate") DO NOTHING`;
    const updated = await tx.$queryRaw<{ id: string }[]>`
      UPDATE "daily_quotas" SET "reserved" = "reserved" + 1
      WHERE "subscriptionId" = ${sub.id}::uuid AND "quotaDate" = ${day}::date AND "reserved" + "consumed" < "total"
      RETURNING "id"`;
    if (updated.length === 0) throw new QuotaError('Kuota tanggal ini sudah habis.');
    const dailyQuotaId = updated[0].id;
    await tx.quotaTransaction.create({ data: { dailyQuotaId, bookingId, action: QuotaAction.RESERVE, actorId } });
    return dailyQuotaId;
  }

  /**
   * Menutup cadangan: RELEASE (kuota kembali), CONSUME (perjalanan selesai), FORFEIT (batal lewat batas, kuota hangus).
   * Aman dipanggil berulang: kalau cadangan sudah 0 tidak ada yang berubah.
   */
  async settle(tx: Tx, dailyQuotaId: string, bookingId: string, action: Exclude<QuotaAction, 'RESERVE'>, actorId?: string) {
    const addConsumed = action === QuotaAction.RELEASE ? 0 : 1;
    const updated = await tx.$queryRaw<{ id: string }[]>`
      UPDATE "daily_quotas" SET "reserved" = "reserved" - 1, "consumed" = "consumed" + ${addConsumed}
      WHERE "id" = ${dailyQuotaId}::uuid AND "reserved" > 0
      RETURNING "id"`;
    if (updated.length === 0) return false;
    await tx.quotaTransaction.create({ data: { dailyQuotaId, bookingId, action, actorId } });
    return true;
  }
}

@Global()
@Module({ providers: [QuotaService], exports: [QuotaService] })
export class QuotaModule {}
