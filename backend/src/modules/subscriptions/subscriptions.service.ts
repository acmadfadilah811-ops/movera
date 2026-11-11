import { BadRequestException, ForbiddenException, Injectable, Logger, NotFoundException, UnauthorizedException } from '@nestjs/common';
import { PaymentStatus, Prisma, SubscriptionStatus } from '@prisma/client';
import { randomBytes } from 'crypto';
import { AuditService } from '../../common/audit.service';
import { addDays, dateKey, operationalDate } from '../../common/jakarta-time';
import { PrismaService } from '../../common/prisma.service';
import { renewalStartDate, subscriptionEndDate } from '../quotas/quota-policy';
import { MidtransNotification, PaymentGateway } from './payment-gateway';

@Injectable()
export class SubscriptionsService {
  private readonly log = new Logger(SubscriptionsService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly gateway: PaymentGateway,
    private readonly audit: AuditService,
  ) {}

  listPlans() {
    return this.prisma.subscriptionPlan.findMany({ where: { isActive: true }, orderBy: { price: 'asc' } });
  }

  /** Langganan yang berlaku hari ini dan perpanjangan yang menunggu, plus kuota [days] hari ke depan. */
  async current(userId: string, days = 7, now = new Date()) {
    const today = operationalDate(now);
    const subs = await this.prisma.subscription.findMany({
      where: { userId, status: SubscriptionStatus.ACTIVE, endDate: { gte: today } },
      orderBy: { startDate: 'asc' },
      include: { plan: { select: { id: true, name: true } } },
    });
    const quotas = [];
    for (let i = 0; i < days; i++) {
      const day = addDays(today, i);
      const sub = subs.find((s) => s.startDate <= day && s.endDate >= day);
      if (!sub) continue;
      const q = await this.prisma.dailyQuota.findUnique({ where: { subscriptionId_quotaDate: { subscriptionId: sub.id, quotaDate: day } } });
      const total = q?.total ?? sub.dailyQuota;
      const reserved = q?.reserved ?? 0;
      const consumed = q?.consumed ?? 0;
      quotas.push({ date: dateKey(day), total, reserved, consumed, remaining: total - reserved - consumed });
    }
    return { subscriptions: subs, quotas };
  }

  history(userId: string) {
    return this.prisma.subscription.findMany({
      where: { userId },
      orderBy: { startDate: 'desc' },
      include: { plan: { select: { name: true } }, payment: { select: { status: true, amount: true, paidAt: true } } },
    });
  }

  async checkout(userId: string, planId: string) {
    const [plan, user] = await Promise.all([
      this.prisma.subscriptionPlan.findFirst({ where: { id: planId, isActive: true } }),
      this.prisma.user.findUniqueOrThrow({ where: { id: userId } }),
    ]);
    if (!plan) throw new NotFoundException('Paket tidak ditemukan.');
    const orderId = `MOV-${Date.now()}-${randomBytes(3).toString('hex')}`;
    const checkout = await this.gateway.createCheckout({
      orderId,
      amount: plan.price,
      customer: { name: user.fullName, email: user.email, phone: user.phone },
      itemName: plan.name,
    });
    if (checkout.provider === 'simulation' && !this.gateway.simulationAllowed) {
      throw new BadRequestException('Pembayaran belum dikonfigurasi.');
    }
    const payment = await this.prisma.payment.create({
      data: { userId, planId, amount: plan.price, provider: checkout.provider, providerRef: orderId },
    });
    await this.audit.log({ actorId: userId, action: 'payment.checkout', entity: 'payment', entityId: payment.id, data: { planId, amount: plan.price } });
    return { paymentId: payment.id, orderId, amount: plan.price, provider: checkout.provider, redirectUrl: checkout.redirectUrl, token: checkout.token };
  }

  /**
   * Mengaktifkan langganan setelah pembayaran terverifikasi. Idempotent: pembayaran yang sudah PAID
   * mengembalikan langganan yang sama. Baris pembayaran dikunci supaya webhook paralel tidak membuat dua langganan.
   */
  async activate(paymentId: string, now = new Date()) {
    return this.prisma.$transaction(async (tx) => {
      const locked = await tx.$queryRaw<{ id: string }[]>`SELECT "id" FROM "payments" WHERE "id" = ${paymentId}::uuid FOR UPDATE`;
      if (locked.length === 0) throw new NotFoundException('Pembayaran tidak ditemukan.');
      const payment = await tx.payment.findUniqueOrThrow({ where: { id: paymentId }, include: { plan: true, subscription: true } });
      if (payment.status === PaymentStatus.PAID && payment.subscription) return payment.subscription;
      if (payment.status !== PaymentStatus.PENDING) throw new BadRequestException(`Pembayaran berstatus ${payment.status}.`);

      // Kunci langganan pengguna supaya dua aktivasi bersamaan tidak memakai tanggal mulai yang sama.
      await tx.$queryRaw`SELECT "id" FROM "users" WHERE "id" = ${payment.userId}::uuid FOR UPDATE`;
      const active = await tx.subscription.findMany({
        where: { userId: payment.userId, status: SubscriptionStatus.ACTIVE },
        select: { endDate: true },
      });
      const start = renewalStartDate(now, active.map((a) => a.endDate));
      const sub = await tx.subscription.create({
        data: {
          userId: payment.userId,
          planId: payment.planId,
          price: payment.amount,
          dailyQuota: payment.plan.dailyQuota,
          startDate: start,
          endDate: subscriptionEndDate(start, payment.plan.durationDays),
          status: SubscriptionStatus.ACTIVE,
          paymentId: payment.id,
        },
      });
      await tx.payment.update({ where: { id: payment.id }, data: { status: PaymentStatus.PAID, paidAt: now } });
      await this.audit.log({ action: 'subscription.activate', entity: 'subscription', entityId: sub.id, data: { paymentId } }, tx);
      return sub;
    });
  }

  /** Webhook Midtrans. Signature diverifikasi; event yang sama hanya diproses sekali. */
  async handleMidtransWebhook(n: MidtransNotification) {
    if (!this.gateway.verifyMidtrans(n)) throw new UnauthorizedException('Signature tidak valid.');
    const eventKey = `midtrans:${n.order_id}:${n.transaction_status}:${n.status_code}`;
    try {
      await this.prisma.webhookEvent.create({ data: { provider: 'midtrans', eventKey, payload: n as unknown as Prisma.InputJsonValue } });
    } catch (e) {
      if (e instanceof Prisma.PrismaClientKnownRequestError && e.code === 'P2002') return { status: 'duplicate' };
      throw e;
    }
    const payment = await this.prisma.payment.findUnique({ where: { providerRef: n.order_id } });
    if (!payment) return this.markWebhook(eventKey, 'Pembayaran tidak dikenal');
    if (Math.round(Number(n.gross_amount)) !== payment.amount) {
      this.log.warn(`Nominal webhook tidak cocok untuk ${n.order_id}`);
      return this.markWebhook(eventKey, 'Nominal tidak cocok');
    }
    const outcome = PaymentGateway.midtransOutcome(n);
    if (outcome === 'PAID') await this.activate(payment.id);
    else if ((outcome === 'FAILED' || outcome === 'EXPIRED') && payment.status === PaymentStatus.PENDING) {
      await this.prisma.payment.update({ where: { id: payment.id }, data: { status: outcome } });
    }
    return this.markWebhook(eventKey);
  }

  private async markWebhook(eventKey: string, error?: string) {
    await this.prisma.webhookEvent.update({ where: { eventKey }, data: { processedAt: new Date(), error } });
    return { status: error ? 'ignored' : 'ok' };
  }

  /** Hanya untuk lingkungan uji tanpa payment gateway. */
  async simulatePaid(userId: string, paymentId: string) {
    if (!this.gateway.simulationAllowed) throw new ForbiddenException('Simulasi pembayaran tidak aktif.');
    const payment = await this.prisma.payment.findUnique({ where: { id: paymentId } });
    if (!payment || payment.userId !== userId) throw new NotFoundException('Pembayaran tidak ditemukan.');
    if (payment.provider !== 'simulation') throw new BadRequestException('Pembayaran ini memakai payment gateway asli.');
    return this.activate(paymentId);
  }

  async getPayment(userId: string, paymentId: string) {
    const payment = await this.prisma.payment.findUnique({ where: { id: paymentId }, include: { subscription: true } });
    if (!payment || payment.userId !== userId) throw new NotFoundException('Pembayaran tidak ditemukan.');
    return payment;
  }
}
