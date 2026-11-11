import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/presentation/widgets/movera_widgets.dart';
import '../../../../core/theme/movera_colors.dart';
import '../../../../core/utils/tanggal.dart';
import '../../data/work_models.dart';
import '../cubit/work_cubit.dart';
import 'trip_detail_page.dart';

class TaskListPage extends StatelessWidget {
  const TaskListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<WorkCubit>().state;
    final open = state.openTrips;
    final closed = state.trips.where((t) => !t.status.isOpen).toList();
    return Scaffold(
      backgroundColor: MoveraColors.bg,
      body: SafeArea(
        child: RefreshIndicator(
          color: MoveraColors.accent,
          onRefresh: () => context.read<WorkCubit>().load(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
            children: [
              Text('Tugas Hari Ini', style: moveraText(size: 26, weight: FontWeight.w800)),
              const SizedBox(height: 18),
              const SectionLabel('Belum selesai'),
              if (open.isEmpty)
                const EmptyState(icon: Icons.task_alt_rounded, title: 'Semua tugas beres', message: 'Tugas baru dari dispatcher akan muncul di sini.')
              else
                for (final t in open) Padding(padding: const EdgeInsets.only(bottom: 10), child: TripTile(trip: t)),
              if (closed.isNotEmpty) ...[
                const SizedBox(height: 12),
                const SectionLabel('Sudah ditutup'),
                for (final t in closed) Padding(padding: const EdgeInsets.only(bottom: 10), child: TripTile(trip: t)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class TripTile extends StatelessWidget {
  final Trip trip;
  final bool showDate;
  const TripTile({super.key, required this.trip, this.showDate = false});

  @override
  Widget build(BuildContext context) {
    final stops = [...trip.stops]..sort((a, b) => a.sequence.compareTo(b.sequence));
    final pickups = stops.where((s) => s.type == StopType.pickup).length;
    final first = stops.first;
    final last = stops.last;
    return MoveraCard(
      highlighted: trip.status == TripStatus.inProgress,
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TripDetailPage(tripId: trip.id))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(showDate ? formatJadwal(trip.scheduledAt) : formatJam(trip.scheduledAt),
                style: moveraText(size: 16, weight: FontWeight.w800)),
          ),
          StatusChip(trip.status.label, color: tripStatusColor(trip.status)),
        ]),
        const SizedBox(height: 10),
        _line(Icons.trip_origin_rounded, first.place.address),
        const SizedBox(height: 6),
        _line(Icons.location_on_rounded, last.place.address),
        const SizedBox(height: 10),
        Text(
          '${trip.shared ? 'Berbagi · $pickups titik jemput' : 'Individual'} · ${trip.passengerTotal} penumpang · ±${trip.estimatedKm.toStringAsFixed(0)} km',
          style: moveraText(size: 12, color: MoveraColors.textFaint),
        ),
      ]),
    );
  }

  Widget _line(IconData icon, String text) => Row(children: [
        Icon(icon, size: 16, color: MoveraColors.accent),
        const SizedBox(width: 10),
        Expanded(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: moveraText(size: 13, color: MoveraColors.textMuted))),
      ]);
}

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final history = context.watch<WorkCubit>().state.history;
    return Scaffold(
      backgroundColor: MoveraColors.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
          children: [
            Text('Riwayat', style: moveraText(size: 26, weight: FontWeight.w800)),
            const SizedBox(height: 18),
            if (history.isEmpty)
              const EmptyState(icon: Icons.history_rounded, title: 'Belum ada riwayat', message: 'Trip yang selesai atau ditolak tercatat di sini.')
            else
              for (final t in history) Padding(padding: const EdgeInsets.only(bottom: 10), child: TripTile(trip: t, showDate: true)),
          ],
        ),
      ),
    );
  }
}
