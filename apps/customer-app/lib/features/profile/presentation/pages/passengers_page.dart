import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/presentation/widgets/movera_widgets.dart';
import '../../../../core/theme/movera_colors.dart';
import '../../../booking/data/booking_models.dart';
import '../../../booking/presentation/cubit/booking_cubit.dart';

class PassengersPage extends StatelessWidget {
  const PassengersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MoveraColors.bg,
      appBar: AppBar(
        backgroundColor: MoveraColors.bg,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text('Data Penumpang', style: moveraText(size: 18, weight: FontWeight.w700)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: MoveraColors.accent,
        foregroundColor: Colors.black,
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PassengerFormPage())),
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: Text('Tambah', style: moveraText(weight: FontWeight.w700, color: Colors.black)),
      ),
      body: BlocBuilder<BookingCubit, BookingState>(
        builder: (context, state) {
          if (state.passengers.isEmpty) {
            return const EmptyState(
              icon: Icons.family_restroom_rounded,
              title: 'Belum ada penumpang',
              message: 'Daftarkan anak atau anggota keluarga yang sering ikut, supaya namanya tercatat di manifest driver.',
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
            children: [
              for (final p in state.passengers)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: MoveraCard(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PassengerFormPage(existing: p))),
                    child: Row(children: [
                      Icon(p.isChild ? Icons.child_care_rounded : Icons.person_rounded, color: MoveraColors.accent),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(p.name, style: moveraText(weight: FontWeight.w700)),
                          const SizedBox(height: 2),
                          Text(
                            [p.relation, if (p.school.isNotEmpty) p.school].join(' · '),
                            style: moveraText(size: 12, color: MoveraColors.textMuted),
                          ),
                        ]),
                      ),
                      if (p.isChild) const StatusChip('Anak', color: MoveraColors.textMuted),
                      const Icon(Icons.chevron_right_rounded, color: MoveraColors.textFaint),
                    ]),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class PassengerFormPage extends StatefulWidget {
  final Passenger? existing;
  const PassengerFormPage({super.key, this.existing});

  @override
  State<PassengerFormPage> createState() => _PassengerFormPageState();
}

class _PassengerFormPageState extends State<PassengerFormPage> {
  static const _relations = ['Anak', 'Pasangan', 'Orang tua', 'Saudara', 'Lainnya'];

  late final TextEditingController _name;
  late final TextEditingController _school;
  late final TextEditingController _notes;
  late final TextEditingController _emergencyName;
  late final TextEditingController _emergencyPhone;
  late String _relation;
  late bool _isChild;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _school = TextEditingController(text: e?.school ?? '');
    _notes = TextEditingController(text: e?.notes ?? '');
    _emergencyName = TextEditingController(text: e?.emergencyName ?? '');
    _emergencyPhone = TextEditingController(text: e?.emergencyPhone ?? '');
    _relation = e?.relation.isNotEmpty == true ? e!.relation : 'Anak';
    _isChild = e?.isChild ?? true;
  }

  @override
  void dispose() {
    for (final c in [_name, _school, _notes, _emergencyName, _emergencyPhone]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.existing != null;
    return Scaffold(
      backgroundColor: MoveraColors.bg,
      appBar: AppBar(
        backgroundColor: MoveraColors.bg,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(editing ? 'Ubah Penumpang' : 'Tambah Penumpang', style: moveraText(size: 18, weight: FontWeight.w700)),
        actions: [
          if (editing)
            IconButton(
              tooltip: 'Hapus',
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: () => _delete(context),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          _field(_name, 'Nama lengkap', capitalization: TextCapitalization.words),
          const SizedBox(height: 18),
          const SectionLabel('Hubungan'),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final r in _relations)
              ChoiceChip(
                label: Text(r),
                selected: _relation == r,
                showCheckmark: false,
                selectedColor: MoveraColors.accent,
                backgroundColor: MoveraColors.card,
                side: BorderSide(color: MoveraColors.border),
                labelStyle: moveraText(size: 13, weight: FontWeight.w600, color: _relation == r ? Colors.black : MoveraColors.textMuted),
                onSelected: (_) => setState(() {
                  _relation = r;
                  if (r == 'Anak') _isChild = true;
                }),
              ),
          ]),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _isChild,
            activeThumbColor: MoveraColors.accent,
            onChanged: (v) => setState(() => _isChild = v),
            title: Text('Penumpang anak / di bawah umur', style: moveraText(size: 14)),
            subtitle: Text('Wajib ada kontak darurat. Driver hanya mengantar dan menjemput, tidak melakukan serah terima.',
                style: moveraText(size: 12, color: MoveraColors.textMuted, height: 1.4)),
          ),
          if (_isChild) ...[
            const SizedBox(height: 8),
            _field(_school, 'Sekolah (opsional)', capitalization: TextCapitalization.words),
          ],
          const SizedBox(height: 18),
          const SectionLabel('Kontak darurat'),
          _field(_emergencyName, 'Nama kontak darurat', capitalization: TextCapitalization.words),
          const SizedBox(height: 10),
          _field(_emergencyPhone, 'Nomor HP kontak darurat', keyboard: TextInputType.phone),
          const SizedBox(height: 18),
          const SectionLabel('Catatan untuk driver'),
          _field(_notes, 'Contoh: butuh kursi anak, alergi parfum', maxLines: 3),
          const SizedBox(height: 24),
          PrimaryButton(label: 'Simpan', busy: _busy, onPressed: () => _save(context)),
        ],
      ),
    );
  }

  Widget _field(TextEditingController c, String hint,
      {TextInputType? keyboard, int maxLines = 1, TextCapitalization capitalization = TextCapitalization.sentences}) {
    return TextField(
      controller: c,
      keyboardType: keyboard,
      maxLines: maxLines,
      textCapitalization: capitalization,
      style: moveraText(),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: moveraText(size: 13, color: MoveraColors.textFaint),
        filled: true,
        fillColor: MoveraColors.card,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      ),
    );
  }

  Future<void> _save(BuildContext context) async {
    setState(() => _busy = true);
    try {
      await context.read<BookingCubit>().savePassenger(Passenger(
            id: widget.existing?.id ?? '',
            name: _name.text,
            relation: _relation,
            isChild: _isChild,
            school: _isChild ? _school.text : '',
            notes: _notes.text,
            emergencyName: _emergencyName.text,
            emergencyPhone: _emergencyPhone.text,
          ));
      if (context.mounted) Navigator.pop(context);
    } on BookingException catch (e) {
      if (context.mounted) showMoveraSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(BuildContext context) async {
    final cubit = context.read<BookingCubit>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: MoveraColors.card,
        title: Text('Hapus ${widget.existing!.name}?', style: moveraText(size: 17, weight: FontWeight.w700)),
        content: Text('Booking yang sudah dibuat tetap mencantumkan nama ini.',
            style: moveraText(size: 13, color: MoveraColors.textMuted)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Hapus')),
        ],
      ),
    );
    if (ok != true) return;
    await cubit.deletePassenger(widget.existing!.id);
    if (context.mounted) Navigator.pop(context);
  }
}
