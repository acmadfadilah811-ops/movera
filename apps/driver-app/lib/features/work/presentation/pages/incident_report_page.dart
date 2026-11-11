import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/presentation/widgets/movera_widgets.dart';
import '../../../../core/theme/movera_colors.dart';
import '../../data/work_models.dart';
import '../cubit/work_cubit.dart';

class IncidentReportPage extends StatefulWidget {
  final IncidentType initialType;
  final String? tripId;
  const IncidentReportPage({super.key, this.initialType = IncidentType.other, this.tripId});

  @override
  State<IncidentReportPage> createState() => _IncidentReportPageState();
}

class _IncidentReportPageState extends State<IncidentReportPage> {
  late IncidentType _type = widget.initialType;
  bool _emergency = false;
  final _description = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MoveraColors.bg,
      appBar: AppBar(
        backgroundColor: MoveraColors.bg,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text('Laporan Insiden', style: moveraText(size: 18, weight: FontWeight.w700)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          MoveraCard(
            child: Row(children: [
              const Icon(Icons.emergency_rounded, color: MoveraColors.danger),
              const SizedBox(width: 12),
              Expanded(
                child: Text('Keselamatan dulu. Jika ada korban atau bahaya, hubungi 112 sebelum mengisi laporan.',
                    style: moveraText(size: 13, color: MoveraColors.textMuted, height: 1.45)),
              ),
            ]),
          ),
          const SizedBox(height: 22),
          const SectionLabel('Jenis kejadian'),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final t in IncidentType.values)
              ChoiceChip(
                label: Text(t.label),
                selected: _type == t,
                showCheckmark: false,
                selectedColor: MoveraColors.accent,
                backgroundColor: MoveraColors.card,
                side: BorderSide(color: MoveraColors.border),
                labelStyle: moveraText(size: 13, weight: FontWeight.w600, color: _type == t ? Colors.black : MoveraColors.textMuted),
                onSelected: (_) => setState(() => _type = t),
              ),
          ]),
          if (_type == IncidentType.childNoReceiver) ...[
            const SizedBox(height: 12),
            Text(
              'Jangan tinggalkan anak sendirian. Hubungi kontak darurat anak dan operasional, tetap tunggu bersama anak '
              'di tempat aman sampai ada arahan.',
              style: moveraText(size: 12, color: MoveraColors.warning, height: 1.45),
            ),
          ],
          const SizedBox(height: 22),
          const SectionLabel('Ceritakan kejadiannya'),
          TextField(
            controller: _description,
            maxLines: 5,
            maxLength: 1000,
            style: moveraText(),
            decoration: InputDecoration(
              hintText: 'Apa yang terjadi, di mana, dan kondisi saat ini',
              hintStyle: moveraText(size: 13, color: MoveraColors.textFaint),
              filled: true,
              fillColor: MoveraColors.card,
              counterStyle: moveraText(size: 11, color: MoveraColors.textFaint),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _emergency,
            activeThumbColor: MoveraColors.danger,
            onChanged: (v) => setState(() => _emergency = v),
            title: Text('Darurat, butuh bantuan segera', style: moveraText(size: 14)),
            subtitle: Text('Operasional akan langsung menghubungi Anda.', style: moveraText(size: 12, color: MoveraColors.textMuted)),
          ),
          const SizedBox(height: 16),
          PrimaryButton(label: 'Kirim Laporan', busy: _busy, onPressed: () => _submit(context)),
        ],
      ),
    );
  }

  Future<void> _submit(BuildContext context) async {
    setState(() => _busy = true);
    try {
      await context.read<WorkCubit>().reportIncident(
            type: _type,
            description: _description.text,
            tripId: widget.tripId,
            emergency: _emergency,
          );
      if (context.mounted) {
        showMoveraSnack(context, 'Laporan terkirim ke operasional.');
        Navigator.pop(context);
      }
    } on WorkException catch (e) {
      if (context.mounted) showMoveraSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
