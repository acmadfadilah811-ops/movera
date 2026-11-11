import { Body, Controller, Get, HttpCode, Module, Param, ParseUUIDPipe, Post, Query } from '@nestjs/common';
import { Role } from '@prisma/client';
import { IsUUID } from 'class-validator';
import { AuthUser, CurrentUser, Public, Roles } from '../../common/auth.decorators';
import { MidtransNotification, PaymentGateway } from './payment-gateway';
import { SubscriptionsService } from './subscriptions.service';

class CheckoutDto {
  @IsUUID('4', { message: 'Paket tidak valid.' })
  planId: string;
}

@Controller()
export class SubscriptionsController {
  constructor(private readonly subs: SubscriptionsService) {}

  @Public()
  @Get('plans')
  plans() {
    return this.subs.listPlans();
  }

  @Roles(Role.CUSTOMER)
  @Get('subscriptions/current')
  current(@CurrentUser() user: AuthUser, @Query('days') days?: string) {
    const d = Math.min(Math.max(Number(days) || 7, 1), 31);
    return this.subs.current(user.id, d);
  }

  @Roles(Role.CUSTOMER)
  @Get('subscriptions/history')
  history(@CurrentUser() user: AuthUser) {
    return this.subs.history(user.id);
  }

  @Roles(Role.CUSTOMER)
  @Post('payments/checkout')
  checkout(@CurrentUser() user: AuthUser, @Body() dto: CheckoutDto) {
    return this.subs.checkout(user.id, dto.planId);
  }

  @Roles(Role.CUSTOMER)
  @Get('payments/:id')
  payment(@CurrentUser() user: AuthUser, @Param('id', ParseUUIDPipe) id: string) {
    return this.subs.getPayment(user.id, id);
  }

  /** Hanya aktif jika ALLOW_PAYMENT_SIMULATION=true. Jangan aktifkan di produksi. */
  @Roles(Role.CUSTOMER)
  @Post('payments/:id/simulate-paid')
  simulate(@CurrentUser() user: AuthUser, @Param('id', ParseUUIDPipe) id: string) {
    return this.subs.simulatePaid(user.id, id);
  }

  /** Callback Midtrans. Aktivasi langganan hanya lewat jalur ini, bukan redirect halaman bayar. */
  @Public()
  @HttpCode(200)
  @Post('webhooks/payment/midtrans')
  midtrans(@Body() body: MidtransNotification) {
    return this.subs.handleMidtransWebhook(body);
  }
}

@Module({
  controllers: [SubscriptionsController],
  providers: [SubscriptionsService, PaymentGateway],
  exports: [SubscriptionsService],
})
export class SubscriptionsModule {}
