import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/presentation/widgets/movera_widgets.dart';
import '../../../../core/theme/movera_colors.dart';
import '../../../../core/utils/tanggal.dart';
import '../../../subscription/presentation/cubit/subscription_cubit.dart';
import '../../data/booking_models.dart';
import '../cubit/booking_cubit.dart';
import 'booking_detail_page.dart';

class BookingListPage extends StatefulWidget {
  const BookingListPage({super.key});

  @override
  State<BookingListPage> createState() => _BookingListPageState();
}

class _BookingListPageState extends State<BookingListPage> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MoveraColors.bg,
      body: SafeArea(
        child: BlocBuilder<BookingCubit, BookingState>(
          builder: (context, state) {
            final tabs = ['Mendatang', 'Rutin', 'Riwayat'];
            return RefreshIndicator(
              color: MoveraColors.accent,
              onRefresh: () async {
                await context.read<BookingCubit>().load();
                if (context.mounted) await context.read<SubscriptionCubit>().load();
              },
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
                children: [
                  Text('Booking', style: moveraText(size: 26, weight: FontWeight.w800)),
                  const SizedBox(height: 16),
                  Row(children: [
                    for (var i = 0; i < tabs.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(tabs[i]),
                          selected: _tab == i,
                          onSelected: (_) => setState(() => _tab = i),
                          selectedColor: MoveraColors.accent,
                          backgroundColor: MoveraColors.card,
                          side: BorderSide(color: MoveraColors.border),
                          showCheckmark: false,
                          labelStyle: moveraText(
                              size: 13, weight: FontWeight.w600, color: _tab == i ? MoveraColors.onAccent : MoveraColors.textMuted),
                        ),
                      ),
                  ]),
                  const SizedBox(height: 18),
                  if (state.loading && state.bookings.isEmpty)
                    const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator(color: MoveraColors.accent)))
                  else if (state.error != null)
                    Text(state.error!, style: moveraText(color: MoveraColors.danger))
                  else if (_tab == 0)
                    ..._bookingList(context, state.upcoming, 'Belum ada booking mendatang', 'Tekan tombol mobil di bawah untuk membuat booking.')
                  else if (_tab == 1)
                    ..._scheduleList(context, state)
                  else
                    ..._bookingList(context, state.history, 'Belum ada riwayat', 'Perjalanan yang selesai atau dibatalkan muncul di sini.'),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  List<Widget> _bookingList(BuildContext context, List<Booking> list, String emptyTitle, String emptyMessage) {
    if (list.isEmpty) return [EmptyState(icon: Icons.event_note_rounded, title: emptyTitle, message: emptyMessage)];
    return [for (final b in list) Padding(padding: const EdgeInsets.only(bottom: 10), child: BookingTile(booking: b))];
  }

  List<Widget> _scheduleList(BuildContext context, BookingState state) {
    final list = state.activeSchedules;
    if (list.isEmpty) {
      return const [
        EmptyState(
          icon: Icons.repeat_rounded,
          title: 'Belum ada jadwal rutin',
          message: 'Buat booking jenis "Rutin mingguan" untuk perjalanan yang berulang, misalnya antar sekolah setiap pagi.',
        ),
      ];
    }
    return [
      for (final s in list)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: MoveraCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                  child: Text(
                    '${s.weekdays.map(namaHariPendek).join(', ')} · ${s.hour.toString().padLeft(2, '0')}.${s.minute.toString().padLeft(2, '0')}',
                    style: moveraText(size: 15, weight: FontWeight.w700),
                  ),
                ),
                StatusChip(s.rideMode == RideMode.shared ? 'Berbagi' : 'Sendiri', color: MoveraColors.textMuted),
              ]),
              const SizedBox(height: 10),
              RouteLines(pickup: s.pickup, destination: s.destination),
              const SizedBox(height: 12),
              SecondaryButton(
                label: 'Hentikan jadwal',
                color: MoveraColors.danger,
                onPressed: () => _confirmStop(context, s),
              ),
            ]),
          ),
        ),
    ];
  }

  Future<void> _confirmStop(BuildContext context, RecurringSchedule s) async {
    final bookingCubit = context.read<BookingCubit>();
    final subCubit = context.read<SubscriptionCubit>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: MoveraColors.card,
        title: Text('Hentikan jadwal rutin?', style: moveraText(size: 17, weight: FontWeight.w700)),
        content: Text(
          'Booking turunan yang belum lewat batas pembatalan (${bookingCubit.cancelCutoffMinutes} menit sebelum jemput) akan dibatalkan dan kuotanya dikembalikan. '
          'Booking yang sudah dekat waktunya tetap berjalan.',
          style: moveraText(size: 13, color: MoveraColors.textMuted, height: 1.5),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Hentikan')),
        ],
      ),
    );
    if (ok != true) return;
    await bookingCubit.deactivateSchedule(s.id);
    await subCubit.load();
    if (context.mounted) showMoveraSnack(context, 'Jadwal rutin dihentikan.');
  }
}

class BookingTile extends StatelessWidget {
  final Booking booking;
  const BookingTile({super.key, required this.booking});

  @override
  Widget build(BuildContext context) {
    final b = booking;
    return MoveraCard(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => BookingDetailPage(bookingId: b.id))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(formatJadwal(b.scheduledAt), style: moveraText(size: 15, weight: FontWeight.w700))),
          StatusChip(b.status.label, color: statusColor(b.status)),
        ]),
        const SizedBox(height: 10),
        RouteLines(pickup: b.pickup, destination: b.destination),
        const SizedBox(height: 10),
        Row(children: [
          Icon(b.type == BookingType.routine ? Icons.repeat_rounded : Icons.event_rounded, size: 14, color: MoveraColors.textFaint),
          const SizedBox(width: 6),
          Text(
            '${b.type == BookingType.routine ? 'Rutin' : 'Sekali jalan'} · ${b.rideMode == RideMode.shared ? 'Berbagi' : 'Sendiri'} · ${b.passengerCount} orang',
            style: moveraText(size: 12, color: MoveraColors.textFaint),
          ),
        ]),
      ]),
    );
  }
}

Color statusColor(BookingStatus s) => switch (s) {
      BookingStatus.cancelled || BookingStatus.noShow => MoveraColors.danger,
      BookingStatus.completed => MoveraColors.textMuted,
      BookingStatus.pendingDispatch => MoveraColors.warning,
      _ => MoveraColors.accent,
    };

class RouteLines extends StatelessWidget {
  final Place pickup;
  final Place destination;
  const RouteLines({super.key, required this.pickup, required this.destination});

  @override
  Widget build(BuildContext context) {
    Widget line(IconData icon, Place p) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 16, color: MoveraColors.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(p.label.isEmpty ? p.address : '${p.label} · ${p.address}',
                maxLines: 1, overflow: TextOverflow.ellipsis, style: moveraText(size: 13, color: MoveraColors.textMuted)),
          ),
        ]);
    return Column(children: [
      line(Icons.trip_origin_rounded, pickup),
      const SizedBox(height: 6),
      line(Icons.location_on_rounded, destination),
    ]);
  }
}
