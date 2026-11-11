import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/presentation/widgets/movera_widgets.dart';
import '../../../../core/theme/movera_colors.dart';
import '../../../../core/utils/tanggal.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../booking/presentation/cubit/booking_cubit.dart';
import '../../../booking/presentation/pages/booking_list_page.dart';
import '../../../subscription/presentation/cubit/subscription_cubit.dart';

class BerandaPage extends StatelessWidget {
  final VoidCallback onCreateBooking;
  final VoidCallback onOpenSubscription;
  final VoidCallback onOpenBookings;

  const BerandaPage({
    super.key,
    required this.onCreateBooking,
    required this.onOpenSubscription,
    required this.onOpenBookings,
  });

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 11) return 'Selamat pagi';
    if (h < 15) return 'Selamat siang';
    if (h < 18) return 'Selamat sore';
    return 'Selamat malam';
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthBloc>().state;
    final name = auth is AuthAuthenticated ? auth.user.fullName.split(' ').first : '';
    final sub = context.watch<SubscriptionCubit>().state;
    final booking = context.watch<BookingCubit>().state;

    return Scaffold(
      backgroundColor: MoveraColors.bg,
      body: SafeArea(
        child: RefreshIndicator(
          color: MoveraColors.accent,
          onRefresh: () async {
            await context.read<SubscriptionCubit>().load();
            if (context.mounted) await context.read<BookingCubit>().load();
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
            children: [
              Text(name.isEmpty ? _greeting() : '${_greeting()}, $name', style: moveraText(size: 14, color: MoveraColors.textMuted)),
              const SizedBox(height: 2),
              Text(formatTanggalPanjang(DateTime.now()), style: moveraText(size: 22, weight: FontWeight.w800)),
              if (AppConfig.useMock) ...[
                const SizedBox(height: 10),
                const StatusChip('Mode data contoh', color: MoveraColors.warning),
              ],
              const SizedBox(height: 22),
              if (sub.current == null)
                MoveraCard(
                  highlighted: true,
                  padding: const EdgeInsets.all(20),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Icon(Icons.electric_car_rounded, color: MoveraColors.accent, size: 32),
                    const SizedBox(height: 12),
                    Text('Mulai berlangganan', style: moveraText(size: 18, weight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text('Antar-jemput mobil listrik untuk kerja, sekolah, dan kebutuhan harian dengan satu paket bulanan.',
                        style: moveraText(size: 13, color: MoveraColors.textMuted, height: 1.5)),
                    const SizedBox(height: 16),
                    PrimaryButton(label: 'Lihat Paket', onPressed: onOpenSubscription),
                  ]),
                )
              else
                _todayQuota(sub),
              const SizedBox(height: 24),
              SectionLabel(
                'Perjalanan berikutnya',
                trailing: booking.upcoming.length > 1
                    ? GestureDetector(
                        onTap: onOpenBookings,
                        child: Text('Lihat semua', style: moveraText(size: 12, weight: FontWeight.w600, color: MoveraColors.accent)),
                      )
                    : null,
              ),
              if (booking.next != null)
                BookingTile(booking: booking.next!)
              else
                MoveraCard(
                  child: Row(children: [
                    const Icon(Icons.event_available_rounded, color: MoveraColors.textFaint),
                    const SizedBox(width: 12),
                    Expanded(child: Text('Belum ada booking mendatang.', style: moveraText(size: 13, color: MoveraColors.textMuted))),
                  ]),
                ),
              if (sub.current != null) ...[
                const SizedBox(height: 20),
                PrimaryButton(label: 'Buat Booking', icon: Icons.add_rounded, onPressed: onCreateBooking),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _todayQuota(SubscriptionState sub) {
    final q = sub.todayQuota;
    final s = sub.current!;
    return MoveraCard(
      highlighted: true,
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text('Kuota hari ini', style: moveraText(size: 13, color: MoveraColors.textMuted))),
          Text('${s.daysLeft(DateTime.now())} hari tersisa', style: moveraText(size: 12, color: MoveraColors.textMuted)),
        ]),
        const SizedBox(height: 6),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('${q?.remaining ?? 0}', style: moveraText(size: 40, weight: FontWeight.w800, color: MoveraColors.accent, height: 1)),
          const SizedBox(width: 6),
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text('dari ${q?.total ?? s.plan.dailyQuota} booking', style: moveraText(size: 14, color: MoveraColors.textMuted)),
          ),
        ]),
        const SizedBox(height: 14),
        if (q != null) QuotaBar(total: q.total, reserved: q.reserved, consumed: q.consumed),
        const SizedBox(height: 10),
        Text('${q?.reserved ?? 0} dipesan · ${q?.consumed ?? 0} terpakai', style: moveraText(size: 12, color: MoveraColors.textFaint)),
      ]),
    );
  }
}
