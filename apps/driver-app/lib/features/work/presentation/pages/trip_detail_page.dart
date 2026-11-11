import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/mock/mock_work_backend.dart';
import '../../../../core/presentation/widgets/movera_widgets.dart';
import '../../../../core/theme/movera_colors.dart';
import '../../../../core/utils/tanggal.dart';
import '../../data/work_models.dart';
import '../cubit/work_cubit.dart';
import 'incident_report_page.dart';

class TripDetailPage extends StatefulWidget {
  final String tripId;
  const TripDetailPage({super.key, required this.tripId});

  @override
  State<TripDetailPage> createState() => _TripDetailPageState();
}

class _TripDetailPageState extends State<TripDetailPage> {
  static const _rejectReasons = ['Kendaraan bermasalah', 'Baterai tidak cukup', 'Bentrok dengan tugas lain', 'Kondisi darurat pribadi'];
  Timer? _ticker;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // Perbarui hitung mundur tunggu penumpang.
    _ticker = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<WorkCubit>().state;
    final trip = state.trips.where((t) => t.id == widget.tripId).firstOrNull ??
        state.history.where((t) => t.id == widget.tripId).firstOrNull;
    return Scaffold(
      backgroundColor: MoveraColors.bg,
      appBar: AppBar(
        backgroundColor: MoveraColors.bg,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text('Manifest Tugas', style: moveraText(size: 18, weight: FontWeight.w700)),
        actions: [
          if (trip != null && trip.status.isOpen)
            IconButton(
              tooltip: 'Laporkan insiden',
              icon: const Icon(Icons.report_problem_outlined),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => IncidentReportPage(tripId: trip.id)),
              ),
            ),
        ],
      ),
      body: trip == null ? const EmptyState(icon: Icons.search_off_rounded, title: 'Tugas tidak ditemukan', message: '') : _body(context, trip, state),
    );
  }

  Widget _body(BuildContext context, Trip trip, WorkState state) {
    final next = trip.nextStop;
    final battery = state.shift?.batteryPercent ?? 0;
    final range = state.shift?.vehicle.rangeAt(battery) ?? 0;
    final lowBattery = trip.status.isOpen && range < trip.estimatedKm * 1.5;
    final stops = [...trip.stops]..sort((a, b) => a.sequence.compareTo(b.sequence));

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
      children: [
        MoveraCard(
          highlighted: trip.status == TripStatus.inProgress,
          padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text('Jemput ${formatJam(trip.scheduledAt)}', style: moveraText(size: 22, weight: FontWeight.w800))),
              StatusChip(trip.status.label, color: tripStatusColor(trip.status)),
            ]),
            const SizedBox(height: 4),
            Text(formatTanggalPanjang(trip.scheduledAt), style: moveraText(size: 13, color: MoveraColors.textMuted)),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [
              StatusChip(trip.shared ? 'Berbagi' : 'Individual', color: MoveraColors.textMuted),
              StatusChip('${trip.passengerTotal} penumpang', color: MoveraColors.textMuted),
              StatusChip('± ${trip.estimatedKm.toStringAsFixed(0)} km', color: MoveraColors.textMuted),
            ]),
            if (trip.rejectReason != null) ...[
              const SizedBox(height: 10),
              Text('Alasan ditolak: ${trip.rejectReason}', style: moveraText(size: 12, color: MoveraColors.danger)),
            ],
          ]),
        ),
        if (lowBattery) ...[
          const SizedBox(height: 10),
          MoveraCard(
            child: Row(children: [
              const Icon(Icons.battery_alert_rounded, color: MoveraColors.warning),
              const SizedBox(width: 12),
              Expanded(
                child: Text('Sisa jarak tempuh ±$range km kurang longgar untuk trip ini. Pertimbangkan mengecas atau hubungi operasional.',
                    style: moveraText(size: 12, color: MoveraColors.warning, height: 1.4)),
              ),
            ]),
          ),
        ],
        const SizedBox(height: 14),
        ClipRRect(borderRadius: BorderRadius.circular(18), child: SizedBox(height: 190, child: _map(stops))),
        const SizedBox(height: 18),
        if (trip.status == TripStatus.assigned) ...[
          PrimaryButton(label: 'Konfirmasi Tugas', busy: _busy, onPressed: () => _act(context, () => context.read<WorkCubit>().acceptTrip(trip.id), 'Tugas dikonfirmasi.')),
          const SizedBox(height: 8),
          SecondaryButton(label: 'Tolak', color: MoveraColors.danger, onPressed: () => _reject(context, trip)),
          const SizedBox(height: 18),
        ] else if (trip.status == TripStatus.accepted) ...[
          SecondaryButton(label: 'Tolak tugas', color: MoveraColors.danger, onPressed: () => _reject(context, trip)),
          const SizedBox(height: 18),
        ],
        const SectionLabel('Urutan titik'),
        for (final s in stops) _stopCard(context, trip, s, isNext: next?.id == s.id),
      ],
    );
  }

  Widget _map(List<TripStop> stops) {
    final points = [for (final s in stops) LatLng(s.place.latitude, s.place.longitude)];
    return FlutterMap(
      options: MapOptions(initialCameraFit: CameraFit.coordinates(coordinates: points, padding: const EdgeInsets.all(36))),
      children: [
        TileLayer(
          urlTemplate: 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
          subdomains: const ['a', 'b', 'c', 'd'],
          userAgentPackageName: 'id.movera.driver',
        ),
        PolylineLayer(polylines: [Polyline(points: points, strokeWidth: 3, color: MoveraColors.accent.withValues(alpha: 0.6))]),
        MarkerLayer(markers: [
          for (final s in stops)
            Marker(
              point: LatLng(s.place.latitude, s.place.longitude),
              width: 30,
              height: 30,
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: s.type == StopType.pickup ? MoveraColors.accent : Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.black, width: 2),
                ),
                child: Text('${s.sequence}', style: moveraText(size: 12, weight: FontWeight.w800, color: Colors.black)),
              ),
            ),
        ]),
      ],
    );
  }

  Widget _stopCard(BuildContext context, Trip trip, TripStop s, {required bool isNext}) {
    final isPickup = s.type == StopType.pickup;
    final canWork = isNext && (trip.status == TripStatus.accepted || trip.status == TripStatus.inProgress);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Opacity(
        opacity: s.status.isFinal ? 0.55 : 1,
        child: MoveraCard(
          highlighted: canWork,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              CircleAvatar(
                radius: 13,
                backgroundColor: isPickup ? MoveraColors.accent : Colors.white,
                child: Text('${s.sequence}', style: moveraText(size: 12, weight: FontWeight.w800, color: Colors.black)),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(isPickup ? 'Jemput' : 'Antar', style: moveraText(size: 15, weight: FontWeight.w700))),
              if (s.hasChild) const Padding(padding: EdgeInsets.only(right: 6), child: StatusChip('Anak', color: MoveraColors.warning)),
              StatusChip(s.status.label, color: s.status == StopStatus.done ? MoveraColors.textMuted : MoveraColors.accent),
            ]),
            const SizedBox(height: 10),
            Text(s.place.address, style: moveraText(size: 14, weight: FontWeight.w600)),
            if (s.place.label.isNotEmpty) Text(s.place.label, style: moveraText(size: 12, color: MoveraColors.textMuted)),
            const SizedBox(height: 8),
            Text('${s.passengerNames.join(', ')} · pemesan ${s.customerName}', style: moveraText(size: 13, color: MoveraColors.textMuted)),
            if (s.note.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('Catatan: ${s.note}', style: moveraText(size: 13, color: MoveraColors.text)),
            ],
            if (s.hasChild && s.emergencyPhone.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('Kontak darurat: ${s.emergencyName} · ${s.emergencyPhone}', style: moveraText(size: 12, color: MoveraColors.warning)),
            ],
            if (!s.status.isFinal) ...[
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: SecondaryButton(label: 'Navigasi', icon: Icons.navigation_rounded, onPressed: () => _navigate(context, s.place)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SecondaryButton(label: 'Telepon', icon: Icons.call_rounded, onPressed: () => _call(context, s.customerPhone)),
                ),
              ]),
            ],
            if (canWork) ...[const SizedBox(height: 10), ..._actions(context, trip, s)],
          ]),
        ),
      ),
    );
  }

  List<Widget> _actions(BuildContext context, Trip trip, TripStop s) {
    final cubit = context.read<WorkCubit>();
    if (s.status == StopStatus.pending) {
      return [
        PrimaryButton(
          label: 'Tiba di Lokasi',
          busy: _busy,
          onPressed: () => _act(context, () => cubit.arrive(trip.id, s.id), 'Ditandai tiba di lokasi.'),
        ),
      ];
    }
    if (s.type == StopType.pickup) {
      final waited = s.arrivedAt == null ? 0 : DateTime.now().difference(s.arrivedAt!).inMinutes;
      final left = cubit.noShowWaitMinutes - waited;
      return [
        PrimaryButton(label: 'Verifikasi PIN Penumpang', icon: Icons.pin_rounded, busy: _busy, onPressed: () => _pin(context, trip, s)),
        const SizedBox(height: 8),
        SecondaryButton(
          label: left > 0 ? 'Tidak hadir (tunggu $left menit lagi)' : 'Penumpang tidak hadir',
          color: left > 0 ? MoveraColors.textFaint : MoveraColors.danger,
          onPressed: left > 0 ? null : () => _noShow(context, trip, s),
        ),
      ];
    }
    return [
      PrimaryButton(label: 'Penumpang Sudah Turun', busy: _busy, onPressed: () => _dropoff(context, trip, s)),
    ];
  }

  Future<void> _act(BuildContext context, Future<Object?> Function() action, String success) async {
    setState(() => _busy = true);
    try {
      await action();
      if (context.mounted) showMoveraSnack(context, success);
    } on WorkException catch (e) {
      if (context.mounted) showMoveraSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pin(BuildContext context, Trip trip, TripStop s) async {
    final controller = TextEditingController();
    final pin = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: MoveraColors.card,
        title: Text('PIN dari penumpang', style: moveraText(size: 17, weight: FontWeight.w700)),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Minta ${s.customerName} menyebutkan PIN di aplikasinya.', style: moveraText(size: 13, color: MoveraColors.textMuted)),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
            style: moveraText(size: 28, weight: FontWeight.w800).copyWith(letterSpacing: 10),
            decoration: const InputDecoration(counterText: ''),
          ),
          if (AppConfig.useMock) ...[
            const SizedBox(height: 8),
            Text('Mode data contoh: PIN ${MockWorkBackend.demoPins[s.bookingId] ?? '-'}',
                style: moveraText(size: 11, color: MoveraColors.textFaint)),
          ],
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.pop(c, controller.text), child: const Text('Verifikasi')),
        ],
      ),
    );
    if (pin == null || !context.mounted) return;
    await _act(context, () => context.read<WorkCubit>().confirmPickup(trip.id, s.id, pin), 'PIN cocok. Penumpang naik.');
  }

  Future<void> _noShow(BuildContext context, Trip trip, TripStop s) async {
    final ok = await _confirm(
      context,
      'Penumpang tidak hadir?',
      'Pastikan sudah mencoba menelepon ${s.customerName}. Titik antar untuk booking ini akan dilewati.',
    );
    if (ok && context.mounted) {
      await _act(context, () => context.read<WorkCubit>().markNoShow(trip.id, s.id), 'Dicatat: penumpang tidak hadir.');
    }
  }

  Future<void> _dropoff(BuildContext context, Trip trip, TripStop s) async {
    if (s.hasChild) {
      final ok = await _confirm(
        context,
        'Antar penumpang anak',
        'Layanan tidak termasuk serah terima. Pastikan anak masuk ke area tujuan dengan aman. '
            'Jika tidak ada penerima dan anak tidak boleh ditinggal, jangan konfirmasi: hubungi kontak darurat '
            '(${s.emergencyPhone}) dan laporkan insiden.',
        confirmLabel: 'Anak sudah turun dengan aman',
      );
      if (!ok) return;
    }
    if (context.mounted) {
      await _act(context, () => context.read<WorkCubit>().confirmDropoff(trip.id, s.id), 'Penumpang turun.');
    }
  }

  Future<bool> _confirm(BuildContext context, String title, String message, {String confirmLabel = 'Ya'}) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: MoveraColors.card,
        title: Text(title, style: moveraText(size: 17, weight: FontWeight.w700)),
        content: Text(message, style: moveraText(size: 13, color: MoveraColors.textMuted, height: 1.5)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: Text(confirmLabel)),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _reject(BuildContext context, Trip trip) async {
    final reason = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: MoveraColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Tolak tugas', style: moveraText(size: 18, weight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text('Tugas akan dikembalikan ke dispatcher untuk ditugaskan ulang.', style: moveraText(size: 13, color: MoveraColors.textMuted)),
            const SizedBox(height: 10),
            for (final r in _rejectReasons)
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
    if (reason == null || !context.mounted) return;
    await _act(context, () => context.read<WorkCubit>().rejectTrip(trip.id, reason), 'Tugas ditolak.');
  }

  Future<void> _navigate(BuildContext context, StopPlace p) async {
    final uri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${p.latitude},${p.longitude}&travelmode=driving');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) && context.mounted) {
      showMoveraSnack(context, 'Tidak bisa membuka aplikasi peta.', error: true);
    }
  }

  Future<void> _call(BuildContext context, String phone) async {
    final uri = Uri(scheme: 'tel', path: phone.replaceAll(RegExp(r'[^0-9+]'), ''));
    if (!await launchUrl(uri) && context.mounted) {
      showMoveraSnack(context, 'Tidak bisa membuka aplikasi telepon.', error: true);
    }
  }
}

Color tripStatusColor(TripStatus s) => switch (s) {
      TripStatus.assigned => MoveraColors.warning,
      TripStatus.rejected => MoveraColors.danger,
      TripStatus.completed => MoveraColors.textMuted,
      _ => MoveraColors.accent,
    };
