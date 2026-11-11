import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/presentation/widgets/movera_widgets.dart';
import '../../../../core/theme/movera_colors.dart';
import '../../data/work_models.dart';
import '../cubit/work_cubit.dart';
import 'incident_report_page.dart';

class StartShiftPage extends StatefulWidget {
  const StartShiftPage({super.key});

  @override
  State<StartShiftPage> createState() => _StartShiftPageState();
}

class _StartShiftPageState extends State<StartShiftPage> {
  final List<ChecklistItem> _items = [...defaultChecklist];
  final _battery = TextEditingController();
  final _odometer = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final shift = context.read<WorkCubit>().state.shift;
    if (shift != null) _battery.text = '${shift.batteryPercent}';
  }

  @override
  void dispose() {
    _battery.dispose();
    _odometer.dispose();
    super.dispose();
  }

  bool get _criticalOk => _items.where((c) => c.critical).every((c) => c.ok);

  @override
  Widget build(BuildContext context) {
    final shift = context.watch<WorkCubit>().state.shift;
    return Scaffold(
      backgroundColor: MoveraColors.bg,
      appBar: AppBar(
        backgroundColor: MoveraColors.bg,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text('Mulai Shift', style: moveraText(size: 18, weight: FontWeight.w700)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          if (shift != null)
            MoveraCard(
              child: Row(children: [
                const Icon(Icons.electric_car_rounded, color: MoveraColors.accent, size: 30),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(shift.vehicle.plate, style: moveraText(size: 17, weight: FontWeight.w800)),
                    Text('${shift.vehicle.model} · ${shift.vehicle.seats} kursi penumpang',
                        style: moveraText(size: 12, color: MoveraColors.textMuted)),
                  ]),
                ),
              ]),
            ),
          const SizedBox(height: 22),
          const SectionLabel('Checklist kendaraan'),
          MoveraCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(children: [
              for (var i = 0; i < _items.length; i++)
                CheckboxListTile(
                  value: _items[i].ok,
                  onChanged: (v) => setState(() => _items[i] = _items[i].withOk(v ?? false)),
                  activeColor: MoveraColors.accent,
                  checkColor: Colors.black,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(_items[i].label, style: moveraText(size: 14)),
                  subtitle: _items[i].critical
                      ? Text('Wajib', style: moveraText(size: 11, color: MoveraColors.textFaint))
                      : null,
                ),
            ]),
          ),
          if (!_criticalOk) ...[
            const SizedBox(height: 10),
            Text('Shift hanya bisa dimulai jika semua butir wajib lolos. Jika ada yang bermasalah, laporkan kendaraan.',
                style: moveraText(size: 12, color: MoveraColors.warning, height: 1.45)),
            const SizedBox(height: 8),
            SecondaryButton(
              label: 'Laporkan masalah kendaraan',
              icon: Icons.report_problem_outlined,
              color: MoveraColors.warning,
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const IncidentReportPage(initialType: IncidentType.vehicleDamage)),
              ),
            ),
          ],
          const SizedBox(height: 22),
          const SectionLabel('Kondisi awal'),
          Row(children: [
            Expanded(child: numberField(_battery, 'Baterai (%)', max: 3)),
            const SizedBox(width: 10),
            Expanded(child: numberField(_odometer, 'Odometer (km)', max: 7)),
          ]),
          const SizedBox(height: 24),
          PrimaryButton(
            label: 'Mulai Shift',
            busy: _busy,
            onPressed: _criticalOk ? () => _submit(context) : null,
          ),
        ],
      ),
    );
  }

  Future<void> _submit(BuildContext context) async {
    final battery = int.tryParse(_battery.text);
    final odo = int.tryParse(_odometer.text);
    if (battery == null || odo == null) {
      showMoveraSnack(context, 'Isi persentase baterai dan odometer.', error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      await context.read<WorkCubit>().startShift(checklist: _items, batteryPercent: battery, odometer: odo);
      if (context.mounted) {
        showMoveraSnack(context, 'Shift dimulai. Selamat bertugas.');
        Navigator.pop(context);
      }
    } on WorkException catch (e) {
      if (context.mounted) showMoveraSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

Widget numberField(TextEditingController c, String label, {int max = 6}) => TextField(
      controller: c,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(max)],
      style: moveraText(size: 16, weight: FontWeight.w700),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: moveraText(size: 13, color: MoveraColors.textMuted),
        filled: true,
        fillColor: MoveraColors.card,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      ),
    );
