import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { createHash, timingSafeEqual } from 'crypto';

export interface CheckoutResult {
  provider: string;
  /** Halaman pembayaran untuk dibuka aplikasi. */
  redirectUrl?: string;
  token?: string;
}

export interface MidtransNotification {
  order_id: string;
  status_code: string;
  gross_amount: string;
  signature_key: string;
  transaction_status: string;
  fraud_status?: string;
  transaction_id?: string;
}

export type PaymentOutcome = 'PAID' | 'FAILED' | 'EXPIRED' | 'PENDING';

/**
 * Integrasi Midtrans Snap. Tanpa MIDTRANS_SERVER_KEY, checkout memakai provider "simulation"
 * yang hanya boleh dipakai di lingkungan uji (ALLOW_PAYMENT_SIMULATION=true).
 */
@Injectable()
export class PaymentGateway {
  private readonly log = new Logger(PaymentGateway.name);

  constructor(private readonly config: ConfigService) {}

  get serverKey(): string | undefined {
    return this.config.get<string>('MIDTRANS_SERVER_KEY') || undefined;
  }

  get simulationAllowed(): boolean {
    return this.config.get<string>('ALLOW_PAYMENT_SIMULATION') === 'true';
  }

  async createCheckout(p: { orderId: string; amount: number; customer: { name: string; email: string; phone?: string | null }; itemName: string }): Promise<CheckoutResult> {
    if (!this.serverKey) return { provider: 'simulation' };
    const sandbox = this.config.get<string>('MIDTRANS_PRODUCTION') !== 'true';
    const base = sandbox ? 'https://app.sandbox.midtrans.com' : 'https://app.midtrans.com';
    const res = await fetch(`${base}/snap/v1/transactions`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Accept: 'application/json',
        Authorization: `Basic ${Buffer.from(`${this.serverKey}:`).toString('base64')}`,
      },
      body: JSON.stringify({
        transaction_details: { order_id: p.orderId, gross_amount: p.amount },
        item_details: [{ id: 'langganan', price: p.amount, quantity: 1, name: p.itemName.slice(0, 50) }],
        customer_details: { first_name: p.customer.name, email: p.customer.email, phone: p.customer.phone ?? undefined },
      }),
    });
    if (!res.ok) {
      this.log.error(`Midtrans checkout gagal: HTTP ${res.status}`);
      throw new Error('Gagal membuat pembayaran. Coba lagi.');
    }
    const body = (await res.json()) as { token: string; redirect_url: string };
    return { provider: 'midtrans', token: body.token, redirectUrl: body.redirect_url };
  }

  /** Verifikasi signature_key = SHA512(order_id + status_code + gross_amount + server key). */
  verifyMidtrans(n: MidtransNotification): boolean {
    if (!this.serverKey || !n.signature_key) return false;
    const expected = createHash('sha512').update(`${n.order_id}${n.status_code}${n.gross_amount}${this.serverKey}`).digest('hex');
    const a = Buffer.from(expected);
    const b = Buffer.from(n.signature_key);
    return a.length === b.length && timingSafeEqual(a, b);
  }

  static midtransOutcome(n: MidtransNotification): PaymentOutcome {
    switch (n.transaction_status) {
      case 'settlement':
        return 'PAID';
      case 'capture':
        return n.fraud_status === 'accept' || !n.fraud_status ? 'PAID' : 'PENDING';
      case 'expire':
        return 'EXPIRED';
      case 'cancel':
      case 'deny':
      case 'failure':
        return 'FAILED';
      default:
        return 'PENDING';
    }
  }
}
