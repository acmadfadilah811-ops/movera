import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/presentation/widgets/movera_widgets.dart';
import '../../../../core/theme/movera_colors.dart';
import '../../data/booking_models.dart';
import '../cubit/booking_cubit.dart';

/// Peta posisi mobil untuk booking yang sudah punya driver.
/// Mode data contoh: posisi mobil disimulasikan bergerak menuju titik jemput.
/// TODO(backend): ambil posisi dari event Socket.IO `driver:location` untuk trip ini.
class TripTrackingPage extends StatefulWidget {
  final String bookingId;
  const TripTrackingPage({super.key, required this.bookingId});

  @override
  State<TripTrackingPage> createState() => _TripTrackingPageState();
}

class _TripTrackingPageState extends State<TripTrackingPage> {
  static const _simSteps = 40;
  final _distance = const Distance();
  Timer? _timer;
  int _step = 0;
  LatLng? _vehicle;
  LatLng? _start;

  @override
  void initState() {
    super.initState();
    if (AppConfig.useMock) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (_step < _simSteps) setState(() => _step++);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  LatLng _simulatedPosition(LatLng pickup) {
    // Mobil mulai sekitar 2 km di timur laut titik jemput.
    _start ??= LatLng(pickup.latitude + 0.013, pickup.longitude + 0.013);
    final t = _step / _simSteps;
    return LatLng(
      _start!.latitude + (pickup.latitude - _start!.latitude) * t,
      _start!.longitude + (pickup.longitude - _start!.longitude) * t,
    );
  }

  @override
  Widget build(BuildContext context) {
    final b = context.watch<BookingCubit>().state.bookings.where((x) => x.id == widget.bookingId).firstOrNull;
    return Scaffold(
      backgroundColor: MoveraColors.bg,
      appBar: AppBar(
        backgroundColor: MoveraColors.bg,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text('Lacak Mobil', style: moveraText(size: 18, weight: FontWeight.w700)),
      ),
      body: b == null ? const SizedBox.shrink() : _body(b),
    );
  }

  Widget _body(Booking b) {
    final pickup = LatLng(b.pickup.latitude, b.pickup.longitude);
    final dest = LatLng(b.destination.latitude, b.destination.longitude);
    _vehicle = AppConfig.useMock ? _simulatedPosition(pickup) : _vehicle;
    final meters = _vehicle == null ? null : _distance.as(LengthUnit.Meter, _vehicle!, pickup);
    final arrived = meters != null && meters < 50;
    // Perkiraan kasar 25 km/jam di dalam kota.
    final etaMinutes = meters == null ? null : (meters / 1000 / 25 * 60).ceil();

    return Column(children: [
      Expanded(
        child: FlutterMap(
          options: MapOptions(initialCenter: pickup, initialZoom: 14),
          children: [
            TileLayer(
              urlTemplate: 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
              subdomains: const ['a', 'b', 'c', 'd'],
              userAgentPackageName: 'id.movera.pelanggan',
            ),
            PolylineLayer(polylines: [
              Polyline(points: [pickup, dest], strokeWidth: 4, color: MoveraColors.accent.withValues(alpha: 0.6)),
            ]),
            MarkerLayer(markers: [
              Marker(point: pickup, width: 40, height: 40, child: const Icon(Icons.trip_origin_rounded, color: MoveraColors.accent, size: 28)),
              Marker(point: dest, width: 40, height: 40, child: const Icon(Icons.location_on_rounded, color: Colors.white, size: 32)),
              if (_vehicle != null)
                Marker(
                  point: _vehicle!,
                  width: 44,
                  height: 44,
                  child: Container(
                    decoration: const BoxDecoration(color: MoveraColors.accent, shape: BoxShape.circle),
                    child: const Icon(Icons.electric_car_rounded, color: Colors.black, size: 24),
                  ),
                ),
            ]),
            const RichAttributionWidget(attributions: [TextSourceAttribution('OpenStreetMap, CARTO')]),
          ],
        ),
      ),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
        decoration: const BoxDecoration(
          color: MoveraColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              _vehicle == null
                  ? 'Menunggu lokasi mobil...'
                  : arrived
                      ? 'Mobil sudah tiba di titik jemput'
                      : 'Mobil menuju titik jemput · sekitar $etaMinutes menit',
              style: moveraText(size: 16, weight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Row(children: [
              const Icon(Icons.person_rounded, color: MoveraColors.accent),
              const SizedBox(width: 10),
              Expanded(
                child: Text('${b.driverName ?? '-'} · ${b.vehiclePlate ?? '-'}',
                    style: moveraText(size: 14, color: MoveraColors.textMuted)),
              ),
              Text('PIN ${b.pickupPin}', style: moveraText(size: 16, weight: FontWeight.w800).copyWith(letterSpacing: 2)),
            ]),
            if (AppConfig.useMock) ...[
              const SizedBox(height: 10),
              Text('Mode data contoh: pergerakan mobil disimulasikan.', style: moveraText(size: 11, color: MoveraColors.textFaint)),
            ],
          ]),
        ),
      ),
    ]);
  }
}
