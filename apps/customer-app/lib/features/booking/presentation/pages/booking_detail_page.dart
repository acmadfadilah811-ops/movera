import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/presentation/widgets/movera_widgets.dart';
import '../../../../core/theme/movera_colors.dart';
import '../../../../core/utils/tanggal.dart';
import '../../../subscription/presentation/cubit/subscription_cubit.dart';
import '../../data/booking_models.dart';
import '../cubit/booking_cubit.dart';
import 'booking_list_page.dart';
import 'trip_tracking_page.dart';

class BookingDetailPage extends StatelessWidget {
  final String bookingId;
  const BookingDetailPage({super.key, required this.bookingId});

  static const _cancelReasons = [
    'Jadwal berubah',
    'Sudah ada kendaraan lain',
    'Salah memasukkan alamat atau jam',
    'Lainnya',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MoveraColors.bg,
      appBar: AppBar(
        backgroundColor: MoveraColors.bg,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text('Detail Booking', style: moveraText(size: 18, weight: FontWeight.w700)),
      ),
      body: BlocBuilder<BookingCubit, BookingState>(
        builder: (context, state) {
          final b = state.bookings.where((x) => x.id == bookingId).firstOrNull;
          if (b == null) {
            return const EmptyState(icon: Icons.search_off_rounded, title: 'Booking tidak ditemukan', message: '');
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
            children: [
              MoveraCard(
                highlighted: b.status.isActive,
                padding: const EdgeInsets.all(20),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  StatusChip(b.status.label, color: statusColor(b.status)),
                  const SizedBox(height: 12),
                  Text(formatTanggalPanjang(b.scheduledAt), style: moveraText(size: 13, color: MoveraColors.textMuted)),
                  Text('Jemput ${formatJam(b.scheduledAt)}', style: moveraText(size: 24, weight: FontWeight.w800)),
                  const SizedBox(height: 16),
                  RouteLines(pickup: b.pickup, destination: b.destination),
                ]),
              ),
              if (b.status.isActive) ...[
                const SizedBox(height: 14),
                _pinCard(b),
              ],
              const SizedBox(height: 14),
              _driverCard(b),
              const SizedBox(height: 14),
              MoveraCard(
                child: Column(children: [
                  _row('Jenis', b.type == BookingType.routine ? 'Rutin mingguan' : 'Sekali jalan'),
                  _row('Preferensi', b.rideMode == RideMode.shared ? 'Bersedia berbagi (maks. +${b.maxDetourMinutes} menit)' : 'Sendiri'),
                  _row('Penumpang',
                      b.passengerNames.isEmpty ? '${b.passengerCount} orang' : '${b.passengerCount} orang: ${b.passengerNames.join(', ')}'),
                  if (b.note.isNotEmpty) _row('Catatan', b.note),
                  _row('Dibuat', '${formatTanggalPendek(b.createdAt)} ${formatJam(b.createdAt)}'),
                ]),
              ),
              if (b.status == BookingStatus.cancelled) ...[
                const SizedBox(height: 14),
                MoveraCard(
                  child: Column(children: [
                    _row('Alasan batal', b.cancelReason ?? '-'),
                    if (b.cancelledAt != null) _row('Dibatalkan', '${formatTanggalPendek(b.cancelledAt!)} ${formatJam(b.cancelledAt!)}'),
                    _row('Kuota', b.quotaOutcome == QuotaOutcome.released ? 'Dikembalikan' : 'Hangus (lewat batas waktu)'),
                  ]),
                ),
              ],
              const SizedBox(height: 24),
              if (b.driverName != null && b.status.isActive) ...[
                PrimaryButton(
                  label: 'Lacak Mobil',
                  icon: Icons.map_rounded,
                  onPressed: () => Navigator.push(
                      context, MaterialPageRoute(builder: (_) => TripTrackingPage(bookingId: b.id))),
                ),
                const SizedBox(height: 10),
              ],
              if (b.status.isActive && b.status != BookingStatus.inProgress)
                SecondaryButton(
                  label: 'Batalkan Booking',
                  color: MoveraColors.danger,
                  icon: Icons.close_rounded,
                  onPressed: () => _cancel(context, b),
                ),
              if (AppConfig.useMock && b.status.isActive) ...[
                const SizedBox(height: 10),
                SecondaryButton(
                  label: 'Simulasi: perjalanan selesai',
                  icon: Icons.science_outlined,
                  color: MoveraColors.textMuted,
                  onPressed: () async {
                    await context.read<BookingCubit>().simulateComplete(b.id);
                    if (context.mounted) await context.read<SubscriptionCubit>().load();
                  },
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _pinCard(Booking b) => MoveraCard(
        child: Row(children: [
          const Icon(Icons.pin_rounded, color: MoveraColors.accent),
          const SizedBox(width: 12),
          Expanded(
            child: Text('Sebutkan PIN ini ke driver saat dijemput.',
                style: moveraText(size: 13, color: MoveraColors.textMuted, height: 1.4)),
          ),
          Text(b.pickupPin, style: moveraText(size: 24, weight: FontWeight.w800).copyWith(letterSpacing: 4)),
        ]),
      );

  Widget _driverCard(Booking b) {
    final assigned = b.driverName != null;
    return MoveraCard(
      child: Row(children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(color: MoveraColors.accent.withValues(alpha: 0.1), shape: BoxShape.circle),
          child: Icon(assigned ? Icons.person_rounded : Icons.hourglass_top_rounded, color: MoveraColors.accent),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(assigned ? b.driverName! : 'Driver belum ditugaskan', style: moveraText(weight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(
              assigned ? 'Mobil listrik · ${b.vehiclePlate}' : 'Penugasan dilakukan menjelang waktu jemput.',
              style: moveraText(size: 12, color: MoveraColors.textMuted),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _row(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 100, child: Text(k, style: moveraText(size: 13, color: MoveraColors.textMuted))),
          Expanded(child: Text(v, style: moveraText(size: 13, weight: FontWeight.w600))),
        ]),
      );

  Future<void> _cancel(BuildContext context, Booking b) async {
    final bookingCubit = context.read<BookingCubit>();
    final subCubit = context.read<SubscriptionCubit>();
    final cutoff = bookingCubit.cancelCutoffMinutes;
    final beforeCutoff = DateTime.now().isBefore(b.scheduledAt.subtract(Duration(minutes: cutoff)));
    final reason = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: MoveraColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Batalkan booking?', style: moveraText(size: 18, weight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(
              beforeCutoff
                  ? 'Kuota tanggal ini akan dikembalikan.'
                  : 'Sudah lewat batas pembatalan ($cutoff menit sebelum jemput). Kuota tanggal ini hangus.',
              style: moveraText(size: 13, color: beforeCutoff ? MoveraColors.textMuted : MoveraColors.warning, height: 1.45),
            ),
            const SizedBox(height: 14),
            Text('Pilih alasan:', style: moveraText(size: 13, weight: FontWeight.w600)),
            const SizedBox(height: 8),
            for (final r in _cancelReasons)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(r, style: moveraText(size: 14)),
                trailing: const Icon(Icons.chevron_right_rounded, color: MoveraColors.textFaint),
                onTap: () => Navigator.pop(c, r),
              ),
          ]),
        ),
      ),
    );
    if (reason == null) return;
    try {
      final updated = await bookingCubit.cancel(b.id, reason);
      await subCubit.load();
      if (context.mounted) {
        showMoveraSnack(context,
            updated.quotaOutcome == QuotaOutcome.released ? 'Booking dibatalkan, kuota dikembalikan.' : 'Booking dibatalkan, kuota hangus.');
      }
    } on BookingException catch (e) {
      if (context.mounted) showMoveraSnack(context, e.message, error: true);
    }
  }
}
