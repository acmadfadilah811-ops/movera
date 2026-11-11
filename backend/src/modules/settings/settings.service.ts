import { Global, Injectable, Module } from '@nestjs/common';
import { PrismaService } from '../../common/prisma.service';

/** Kebijakan operasional yang bisa diubah admin. Nilai bawaan dipakai kalau belum diatur. */
export const SETTING_DEFAULTS = {
  'booking.cancel_cutoff_minutes': 60,
  'booking.min_lead_minutes': 60,
  'booking.routine_window_days': 7,
  'booking.max_passengers': 4,
  'driver.no_show_wait_minutes': 5,
  'driver.min_battery_percent': 25,
} as const;

export type SettingKey = keyof typeof SETTING_DEFAULTS;

@Injectable()
export class SettingsService {
  constructor(private readonly prisma: PrismaService) {}

  async getNumber(key: SettingKey): Promise<number> {
    const row = await this.prisma.systemSetting.findUnique({ where: { key } });
    const v = row?.value;
    return typeof v === 'number' ? v : SETTING_DEFAULTS[key];
  }

  async all(): Promise<Record<SettingKey, number>> {
    const rows = await this.prisma.systemSetting.findMany();
    const result = { ...SETTING_DEFAULTS } as Record<SettingKey, number>;
    for (const r of rows) {
      if (r.key in result && typeof r.value === 'number') result[r.key as SettingKey] = r.value;
    }
    return result;
  }

  async setNumber(key: SettingKey, value: number, actorId?: string) {
    return this.prisma.systemSetting.upsert({
      where: { key },
      create: { key, value, updatedBy: actorId },
      update: { value, updatedBy: actorId },
    });
  }
}

@Global()
@Module({ providers: [SettingsService], exports: [SettingsService] })
export class SettingsModule {}
