import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/presentation/widgets/movera_widgets.dart';
import '../../../../core/theme/movera_colors.dart';
import '../../../../core/utils/tanggal.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../data/work_models.dart';
import '../cubit/work_cubit.dart';
import 'start_shift_page.dart';
import 'task_list_page.dart';

class DriverHomePage extends StatelessWidget {
  final VoidCallback onOpenTasks;
  const DriverHomePage({super.key, required this.onOpenTasks});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthBloc>().state.currentUser;
    final state = context.watch<WorkCubit>().state;
    final shift = state.shift;
    return Scaffold(
      backgroundColor: MoveraColors.bg,
      body: SafeArea(
        child: RefreshIndicator(
          color: MoveraColors.accent,
          onRefresh: () => context.read<WorkCubit>().load(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
            children: [
              Text('Halo, ${(user?.fullName ?? 'Driver').split(' ').first}', style: moveraText(size: 14, color: MoveraColors.textMuted)),
              Text(formatTanggalPanjang(DateTime.now()), style: moveraText(size: 22, weight: FontWeight.w800)),
              if (AppConfig.useMock) ...[
                const SizedBox(height: 10),
                const StatusChip('Mode data contoh', color: MoveraColors.warning),
              ],
              const SizedBox(height: 20),
              if (state.loading && shift == null)
                const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator(color: MoveraColors.accent)))
              else if (state.error != null)
                Text(state.error!, style: moveraText(color: MoveraColors.danger))
              else if (shift != null) ...[
                _ShiftCard(shift: shift, minBattery: context.read<WorkCubit>().minBatteryPercent),
                const SizedBox(height: 22),
                SectionLabel(
                  state.activeTrip != null ? 'Perjalanan berjalan' : 'Tugas berikutnya',
                  trailing: GestureDetector(
                    onTap: onOpenTasks,
                    child: Text('Semua tugas', style: moveraText(size: 12, weight: FontWeight.w600, color: MoveraColors.accent)),
                  ),
                ),
                if (state.nextTrip != null)
                  TripTile(trip: state.nextTrip!)
                else
                  MoveraCard(
                    child: Text('Tidak ada tugas tersisa hari ini.', style: moveraText(size: 13, color: MoveraColors.textMuted)),
                  ),
                const SizedBox(height: 22),
                const SectionLabel('Hari ini'),
                Row(children: [
                  Expanded(child: _stat('${state.completedToday}', 'Trip selesai')),
                  const SizedBox(width: 10),
                  Expanded(child: _stat('${state.openTrips.length}', 'Tugas tersisa')),
                  const SizedBox(width: 10),
                  Expanded(child: _stat('${state.incidents.length}', 'Laporan')),
                ]),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _stat(String value, String label) => MoveraCard(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        child: Column(children: [
          Text(value, style: moveraText(size: 22, weight: FontWeight.w800)),
          Text(label, textAlign: TextAlign.center, style: moveraText(size: 11, color: MoveraColors.textMuted)),
        ]),
      );
}

class _ShiftCard extends StatelessWidget {
  final Shift shift;
  final int minBattery;
  const _ShiftCard({required this.shift, required this.minBattery});

  @override
  Widget build(BuildContext context) {
    final low = shift.batteryPercent < minBattery;
    return MoveraCard(
      highlighted: shift.status == ShiftStatus.available,
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(shift.status.label, style: moveraText(size: 18, weight: FontWeight.w700))),
          StatusChip(shift.vehicle.plate, color: MoveraColors.textMuted),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          Icon(
            shift.status == ShiftStatus.charging ? Icons.battery_charging_full_rounded : Icons.battery_5_bar_rounded,
            color: low ? MoveraColors.warning : MoveraColors.accent,
          ),
          const SizedBox(width: 8),
          Text('${shift.batteryPercent}%', style: moveraText(size: 22, weight: FontWeight.w800, color: low ? MoveraColors.warning : MoveraColors.text)),
          const SizedBox(width: 10),
          Text('± ${shift.vehicle.rangeAt(shift.batteryPercent)} km', style: moveraText(size: 13, color: MoveraColors.textMuted)),
        ]),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: shift.batteryPercent / 100,
            minHeight: 8,
            backgroundColor: Colors.white10,
            color: low ? MoveraColors.warning : MoveraColors.accent,
          ),
        ),
        if (low && shift.status.isOnDuty) ...[
          const SizedBox(height: 8),
          Text('Baterai di bawah $minBattery%. Segera cas sebelum mengambil tugas berikutnya.',
              style: moveraText(size: 12, color: MoveraColors.warning)),
        ],
        if (shift.startedAt != null) ...[
          const SizedBox(height: 10),
          Text(
            'Mulai ${formatJam(shift.startedAt!)}${shift.endedAt != null ? ' · selesai ${formatJam(shift.endedAt!)}' : ''}'
            '${shift.endOdometer != null && shift.startOdometer != null ? ' · ${shift.endOdometer! - shift.startOdometer!} km' : ''}',
            style: moveraText(size: 12, color: MoveraColors.textMuted),
          ),
        ],
        const SizedBox(height: 16),
        ..._buttons(context),
      ]),
    );
  }

  List<Widget> _buttons(BuildContext context) {
    final cubit = context.read<WorkCubit>();
    switch (shift.status) {
      case ShiftStatus.notStarted:
        return [
          PrimaryButton(
            label: 'Mulai Shift',
            icon: Icons.play_arrow_rounded,
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StartShiftPage())),
          ),
        ];
      case ShiftStatus.available:
        return [
          Row(children: [
            Expanded(child: SecondaryButton(label: 'Istirahat', icon: Icons.coffee_rounded, onPressed: () => _run(context, () => cubit.setBreak(true)))),
            const SizedBox(width: 8),
            Expanded(child: SecondaryButton(label: 'Mulai Cas', icon: Icons.ev_station_rounded, onPressed: () => _run(context, cubit.startCharging))),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: SecondaryButton(
                label: 'Ubah Baterai',
                icon: Icons.edit_rounded,
                onPressed: () async {
                  final v = await askBattery(context, 'Persentase baterai sekarang', shift.batteryPercent);
                  if (v != null && context.mounted) await _run(context, () => cubit.updateBattery(v));
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SecondaryButton(
                label: 'Selesai Shift',
                icon: Icons.stop_rounded,
                color: MoveraColors.danger,
                onPressed: () => _endShift(context),
              ),
            ),
          ]),
        ];
      case ShiftStatus.onBreak:
        return [PrimaryButton(label: 'Lanjut Bertugas', onPressed: () => _run(context, () => cubit.setBreak(false)))];
      case ShiftStatus.charging:
        return [
          PrimaryButton(
            label: 'Selesai Mengecas',
            icon: Icons.battery_full_rounded,
            onPressed: () async {
              final v = await askBattery(context, 'Baterai setelah dicas', shift.batteryPercent);
              if (v != null && context.mounted) await _run(context, () => cubit.finishCharging(v));
            },
          ),
        ];
      case ShiftStatus.ended:
        return [Text('Terima kasih. Sampai jumpa di shift berikutnya.', style: moveraText(size: 13, color: MoveraColors.textMuted))];
    }
  }

  Future<void> _run(BuildContext context, Future<void> Function() action) async {
    try {
      await action();
    } on WorkException catch (e) {
      if (context.mounted) showMoveraSnack(context, e.message, error: true);
    }
  }

  Future<void> _endShift(BuildContext context) async {
    final cubit = context.read<WorkCubit>();
    final battery = TextEditingController(text: '${shift.batteryPercent}');
    final odo = TextEditingController();
    final note = TextEditingController();
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: MoveraColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (c) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(c).viewInsets.bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Selesai Shift', style: moveraText(size: 18, weight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text('Periksa kendaraan, colokkan ke pengecas di pool, lalu isi kondisi akhir.',
              style: moveraText(size: 13, color: MoveraColors.textMuted, height: 1.45)),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: numberField(battery, 'Baterai (%)', max: 3)),
            const SizedBox(width: 10),
            Expanded(child: numberField(odo, 'Odometer (km)', max: 7)),
          ]),
          const SizedBox(height: 10),
          TextField(
            controller: note,
            maxLines: 2,
            style: moveraText(),
            decoration: InputDecoration(
              hintText: 'Catatan kondisi kendaraan (opsional)',
              hintStyle: moveraText(size: 13, color: MoveraColors.textFaint),
              filled: true,
              fillColor: MoveraColors.card,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 16),
          PrimaryButton(label: 'Selesaikan Shift', onPressed: () => Navigator.pop(c, true)),
        ]),
      ),
    );
    if (ok != true || !context.mounted) return;
    final b = int.tryParse(battery.text);
    final o = int.tryParse(odo.text);
    if (b == null || o == null) {
      showMoveraSnack(context, 'Isi baterai dan odometer.', error: true);
      return;
    }
    await _run(context, () => cubit.endShift(batteryPercent: b, odometer: o, note: note.text.trim()));
  }
}

Future<int?> askBattery(BuildContext context, String title, int current) async {
  final c = TextEditingController(text: '$current');
  final v = await showDialog<String>(
    context: context,
    builder: (d) => AlertDialog(
      backgroundColor: MoveraColors.card,
      title: Text(title, style: moveraText(size: 17, weight: FontWeight.w700)),
      content: numberField(c, 'Baterai (%)', max: 3),
      actions: [
        TextButton(onPressed: () => Navigator.pop(d), child: const Text('Batal')),
        TextButton(onPressed: () => Navigator.pop(d, c.text), child: const Text('Simpan')),
      ],
    ),
  );
  return v == null ? null : int.tryParse(v);
}
