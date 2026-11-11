import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { APP_GUARD } from '@nestjs/core';
import { ThrottlerGuard, ThrottlerModule } from '@nestjs/throttler';
import { AuditModule } from './common/audit.service';
import { AdminModule } from './modules/admin/admin.controller';
import { DriverModule } from './modules/driver/driver.controller';
import { AuthGuard } from './common/auth.guard';
import { PrismaModule } from './common/prisma.service';
import { AuthModule } from './modules/auth/auth.controller';
import { BookingsModule } from './modules/bookings/bookings.controller';
import { CustomersModule } from './modules/customers/customers.controller';
import { QuotaModule } from './modules/quotas/quota.service';
import { SettingsModule } from './modules/settings/settings.service';
import { SubscriptionsModule } from './modules/subscriptions/subscriptions.controller';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    ThrottlerModule.forRoot([{ ttl: 60_000, limit: 120 }]),
    PrismaModule,
    AuditModule,
    SettingsModule,
    QuotaModule,
    AuthModule,
    SubscriptionsModule,
    BookingsModule,
    CustomersModule,
    DriverModule,
    AdminModule,
  ],
  providers: [
    { provide: APP_GUARD, useClass: ThrottlerGuard },
    { provide: APP_GUARD, useClass: AuthGuard },
  ],
})
export class AppModule {}
