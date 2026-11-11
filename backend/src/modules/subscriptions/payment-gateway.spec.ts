import { ConfigService } from '@nestjs/config';
import { createHash } from 'crypto';
import { MidtransNotification, PaymentGateway } from './payment-gateway';

const SERVER_KEY = 'SB-Mid-server-uji';

function gateway(env: Record<string, string> = { MIDTRANS_SERVER_KEY: SERVER_KEY }) {
  return new PaymentGateway(new ConfigService(env));
}

function notification(overrides: Partial<MidtransNotification> = {}): MidtransNotification {
  const base = { order_id: 'MOV-1', status_code: '200', gross_amount: '300000.00', transaction_status: 'settlement', ...overrides };
  const signature_key =
    overrides.signature_key ??
    createHash('sha512').update(`${base.order_id}${base.status_code}${base.gross_amount}${SERVER_KEY}`).digest('hex');
  return { ...base, signature_key };
}

describe('PaymentGateway Midtrans', () => {
  it('menerima signature yang benar', () => {
    expect(gateway().verifyMidtrans(notification())).toBe(true);
  });

  it('menolak signature palsu atau nominal yang diubah', () => {
    expect(gateway().verifyMidtrans(notification({ signature_key: 'palsu' }))).toBe(false);
    const n = notification();
    expect(gateway().verifyMidtrans({ ...n, gross_amount: '1.00' })).toBe(false);
  });

  it('menolak semua webhook kalau server key belum diatur', () => {
    expect(gateway({}).verifyMidtrans(notification())).toBe(false);
  });

  it('memetakan status transaksi', () => {
    expect(PaymentGateway.midtransOutcome(notification())).toBe('PAID');
    expect(PaymentGateway.midtransOutcome(notification({ transaction_status: 'capture', fraud_status: 'accept' }))).toBe('PAID');
    expect(PaymentGateway.midtransOutcome(notification({ transaction_status: 'capture', fraud_status: 'challenge' }))).toBe('PENDING');
    expect(PaymentGateway.midtransOutcome(notification({ transaction_status: 'expire' }))).toBe('EXPIRED');
    expect(PaymentGateway.midtransOutcome(notification({ transaction_status: 'deny' }))).toBe('FAILED');
    expect(PaymentGateway.midtransOutcome(notification({ transaction_status: 'pending' }))).toBe('PENDING');
  });

  it('tanpa server key, checkout memakai mode simulasi', async () => {
    const r = await gateway({}).createCheckout({ orderId: 'MOV-1', amount: 300000, customer: { name: 'A', email: 'a@b.c' }, itemName: 'Paket' });
    expect(r.provider).toBe('simulation');
  });
});
