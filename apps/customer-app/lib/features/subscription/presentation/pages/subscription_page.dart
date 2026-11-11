import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/presentation/widgets/movera_widgets.dart';
import '../../../../core/theme/movera_colors.dart';
import '../../../../core/utils/rupiah.dart';
import '../../../../core/utils/tanggal.dart';
import '../../data/subscription_models.dart';
import '../cubit/subscription_cubit.dart';

class SubscriptionPage extends StatelessWidget {
  const SubscriptionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MoveraColors.bg,
      body: SafeArea(
        child: BlocBuilder<SubscriptionCubit, SubscriptionState>(
          builder: (context, state) {
            return RefreshIndicator(
              color: MoveraColors.accent,
              onRefresh: () => context.read<SubscriptionCubit>().load(),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
                children: [
                  Text('Langganan', style: moveraText(size: 26, weight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text('Paket, masa aktif, dan kuota harian Anda.', style: moveraText(size: 13, color: MoveraColors.textMuted)),
                  const SizedBox(height: 24),
                  if (state.loading && state.plans.isEmpty)
                    const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator(color: MoveraColors.accent)))
                  else if (state.error != null)
                    Text(state.error!, style: moveraText(color: MoveraColors.danger))
                  else ...[
                    if (state.current != null) ...[
                      _ActiveCard(sub: state.current!, upcoming: state.upcoming),
                      const SizedBox(height: 24),
                      const SectionLabel('Kuota 7 hari ke depan'),
                      _QuotaWeek(quotas: state.quotas),
                      const SizedBox(height: 28),
                      SectionLabel(state.upcoming == null ? 'Perpanjang paket' : 'Paket tersedia'),
                    ] else ...[
                      const _NoSubscriptionBanner(),
                      const SizedBox(height: 24),
                      const SectionLabel('Pilih paket'),
                    ],
                    for (final p in state.plans) _PlanCard(plan: p, isRenewal: state.current != null),
                    const SizedBox(height: 12),
                    const _RulesCard(),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ActiveCard extends StatelessWidget {
  final Subscription sub;
  final Subscription? upcoming;
  const _ActiveCard({required this.sub, this.upcoming});

  @override
  Widget build(BuildContext context) {
    final left = sub.daysLeft(DateTime.now());
    return MoveraCard(
      highlighted: true,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(sub.plan.name, style: moveraText(size: 18, weight: FontWeight.w700))),
              const StatusChip('Aktif'),
            ],
          ),
          const SizedBox(height: 14),
          _row('Masa aktif', '${formatTanggalPendek(sub.startDate)} - ${formatTanggalPendek(sub.endDate)}'),
          _row('Sisa', '$left hari'),
          _row('Kuota', '${sub.plan.dailyQuota} booking per hari'),
          if (left <= 5 && upcoming == null) ...[
            const SizedBox(height: 10),
            Text('Masa aktif hampir habis. Perpanjang agar booking tidak terputus.',
                style: moveraText(size: 12, color: MoveraColors.warning, height: 1.4)),
          ],
          if (upcoming != null) ...[
            const SizedBox(height: 10),
            Text('Perpanjangan aktif mulai ${formatTanggalPendek(upcoming!.startDate)} sampai ${formatTanggalPendek(upcoming!.endDate)}.',
                style: moveraText(size: 12, color: MoveraColors.textMuted, height: 1.4)),
          ],
        ],
      ),
    );
  }

  Widget _row(String k, String v) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          children: [
            SizedBox(width: 90, child: Text(k, style: moveraText(size: 13, color: MoveraColors.textMuted))),
            Expanded(child: Text(v, style: moveraText(size: 13, weight: FontWeight.w600))),
          ],
        ),
      );
}

class _QuotaWeek extends StatelessWidget {
  final List<DailyQuota> quotas;
  const _QuotaWeek({required this.quotas});

  @override
  Widget build(BuildContext context) {
    return MoveraCard(
      child: Column(
        children: [
          for (final q in quotas)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(
                children: [
                  SizedBox(
                    width: 92,
                    child: Text(
                      samaTanggal(q.date, DateTime.now()) ? 'Hari ini' : '${namaHariPendek(q.date.weekday)}, ${q.date.day}',
                      style: moveraText(size: 13, weight: FontWeight.w600),
                    ),
                  ),
                  Expanded(child: QuotaBar(total: q.total, reserved: q.reserved, consumed: q.consumed)),
                  SizedBox(
                    width: 64,
                    child: Text('${q.remaining} sisa',
                        textAlign: TextAlign.right, style: moveraText(size: 12, color: MoveraColors.textMuted)),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              _legend(MoveraColors.accent, 'Sisa'),
              _legend(MoveraColors.accent.withValues(alpha: 0.45), 'Dipesan'),
              _legend(MoveraColors.textFaint, 'Terpakai'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legend(Color c, String label) => Padding(
        padding: const EdgeInsets.only(right: 14),
        child: Row(children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3))),
          const SizedBox(width: 6),
          Text(label, style: moveraText(size: 11, color: MoveraColors.textMuted)),
        ]),
      );
}

class _NoSubscriptionBanner extends StatelessWidget {
  const _NoSubscriptionBanner();

  @override
  Widget build(BuildContext context) {
    return MoveraCard(
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: MoveraColors.warning),
          const SizedBox(width: 12),
          Expanded(
            child: Text('Anda belum punya langganan aktif. Beli paket untuk mulai membuat booking.',
                style: moveraText(size: 13, color: MoveraColors.textMuted, height: 1.45)),
          ),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final SubscriptionPlan plan;
  final bool isRenewal;
  const _PlanCard({required this.plan, required this.isRenewal});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: MoveraCard(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(plan.name, style: moveraText(size: 17, weight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(plan.description, style: moveraText(size: 13, color: MoveraColors.textMuted)),
            const SizedBox(height: 14),
            Text(formatRupiah(plan.price), style: moveraText(size: 26, weight: FontWeight.w800, color: MoveraColors.accent)),
            Text('per ${plan.durationDays} hari', style: moveraText(size: 12, color: MoveraColors.textMuted)),
            const SizedBox(height: 14),
            _point(Icons.event_available_rounded, 'Maksimal ${plan.dailyQuota} booking per hari'),
            _point(Icons.electric_car_rounded, 'Mobil listrik milik Movera dengan driver karyawan'),
            _point(Icons.repeat_rounded, 'Booking rutin dan fleksibel'),
            const SizedBox(height: 16),
            PrimaryButton(
              label: isRenewal ? 'Perpanjang' : 'Beli Paket',
              onPressed: () => _checkout(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _point(IconData icon, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: [
          Icon(icon, size: 18, color: MoveraColors.accent),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: moveraText(size: 13))),
        ]),
      );

  Future<void> _checkout(BuildContext context) async {
    final cubit = context.read<SubscriptionCubit>();
    final ok = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: MoveraColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _CheckoutSheet(plan: plan),
    );
    if (ok != true || !context.mounted) return;
    try {
      final paymentId = await cubit.checkout(plan.id);
      if (!AppConfig.useMock) {
        // TODO(backend): buka halaman pembayaran dari payment gateway, langganan aktif lewat webhook.
        if (context.mounted) showMoveraSnack(context, 'Menunggu pembayaran.');
        return;
      }
      final sub = await cubit.confirmMockPayment(paymentId);
      if (context.mounted) {
        showMoveraSnack(context, 'Pembayaran berhasil. Aktif ${formatTanggalPendek(sub.startDate)} - ${formatTanggalPendek(sub.endDate)}.');
      }
    } catch (e) {
      if (context.mounted) showMoveraSnack(context, '$e', error: true);
    }
  }
}

class _CheckoutSheet extends StatelessWidget {
  final SubscriptionPlan plan;
  const _CheckoutSheet({required this.plan});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Konfirmasi Pembelian', style: moveraText(size: 18, weight: FontWeight.w700)),
            const SizedBox(height: 16),
            MoveraCard(
              child: Row(
                children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(plan.name, style: moveraText(weight: FontWeight.w600)),
                      Text('${plan.durationDays} hari · ${plan.dailyQuota} booking/hari',
                          style: moveraText(size: 12, color: MoveraColors.textMuted)),
                    ]),
                  ),
                  Text(formatRupiah(plan.price), style: moveraText(size: 16, weight: FontWeight.w700)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              AppConfig.useMock
                  ? 'Mode data contoh: pembayaran disimulasikan dan langsung berhasil.'
                  : 'Anda akan diarahkan ke halaman pembayaran. Langganan aktif setelah pembayaran terverifikasi.',
              style: moveraText(size: 12, color: MoveraColors.textMuted, height: 1.45),
            ),
            const SizedBox(height: 20),
            PrimaryButton(label: 'Bayar ${formatRupiah(plan.price)}', onPressed: () => Navigator.pop(context, true)),
            const SizedBox(height: 8),
            SecondaryButton(label: 'Batal', onPressed: () => Navigator.pop(context, false)),
          ],
        ),
      ),
    );
  }
}

class _RulesCard extends StatelessWidget {
  const _RulesCard();

  @override
  Widget build(BuildContext context) {
    const rules = [
      'Satu booking = satu perjalanan dari titik jemput ke tujuan. Contoh: rumah ke kantor = 1 booking.',
      'Kuota dihitung per tanggal dan tidak bisa dipindah ke hari lain.',
      'Kuota dicadangkan saat booking dibuat, dan tercatat terpakai saat perjalanan selesai.',
      'Pembatalan sebelum batas waktu mengembalikan kuota. Setelah batas waktu, kuota hangus.',
    ];
    return MoveraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Aturan kuota', style: moveraText(weight: FontWeight.w700)),
          const SizedBox(height: 10),
          for (final r in rules)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Padding(
                  padding: const EdgeInsets.only(top: 7),
                  child: Container(width: 5, height: 5, decoration: const BoxDecoration(color: MoveraColors.accent, shape: BoxShape.circle)),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(r, style: moveraText(size: 12, color: MoveraColors.textMuted, height: 1.5))),
              ]),
            ),
        ],
      ),
    );
  }
}
