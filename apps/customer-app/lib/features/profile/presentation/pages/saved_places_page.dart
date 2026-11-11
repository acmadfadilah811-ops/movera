import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/presentation/widgets/movera_widgets.dart';
import '../../../../core/theme/movera_colors.dart';
import '../../../booking/data/booking_models.dart';
import '../../../booking/presentation/cubit/booking_cubit.dart';
import '../../../../core/presentation/pages/location_picker_page.dart';

class SavedPlacesPage extends StatelessWidget {
  const SavedPlacesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MoveraColors.bg,
      appBar: AppBar(
        backgroundColor: MoveraColors.bg,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text('Alamat Tersimpan', style: moveraText(size: 18, weight: FontWeight.w700)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: MoveraColors.accent,
        foregroundColor: Colors.black,
        onPressed: () => _add(context),
        icon: const Icon(Icons.add_location_alt_rounded),
        label: Text('Tambah', style: moveraText(weight: FontWeight.w700, color: Colors.black)),
      ),
      body: BlocBuilder<BookingCubit, BookingState>(
        builder: (context, state) {
          if (state.savedPlaces.isEmpty) {
            return const EmptyState(
              icon: Icons.bookmark_border_rounded,
              title: 'Belum ada alamat',
              message: 'Simpan alamat rumah, kantor, atau sekolah supaya membuat booking lebih cepat.',
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
            children: [
              for (final p in state.savedPlaces)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: MoveraCard(
                    child: Row(children: [
                      Icon(_iconFor(p.label), color: MoveraColors.accent),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(p.label, style: moveraText(weight: FontWeight.w700)),
                          const SizedBox(height: 2),
                          Text(p.address, style: moveraText(size: 12, color: MoveraColors.textMuted, height: 1.4)),
                        ]),
                      ),
                      IconButton(
                        tooltip: 'Hapus',
                        icon: const Icon(Icons.delete_outline_rounded, color: MoveraColors.textFaint),
                        onPressed: () => _delete(context, p),
                      ),
                    ]),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  static IconData _iconFor(String label) => switch (label.toLowerCase()) {
        'rumah' => Icons.home_rounded,
        'kantor' => Icons.work_rounded,
        'sekolah' => Icons.school_rounded,
        _ => Icons.bookmark_rounded,
      };

  Future<void> _add(BuildContext context) async {
    final cubit = context.read<BookingCubit>();
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => const LocationPickerPage(title: 'Tambah Alamat')),
    );
    if (result == null || !context.mounted) return;
    final label = await askPlaceLabel(context, required: true);
    if (label == null || label.isEmpty) return;
    final ll = result['location'] as LatLng;
    await cubit.savePlace(Place(label: label, address: result['address'] as String, latitude: ll.latitude, longitude: ll.longitude));
    if (context.mounted) showMoveraSnack(context, 'Alamat "$label" disimpan.');
  }

  Future<void> _delete(BuildContext context, Place p) async {
    final cubit = context.read<BookingCubit>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: MoveraColors.card,
        title: Text('Hapus "${p.label}"?', style: moveraText(size: 17, weight: FontWeight.w700)),
        content: Text('Booking yang sudah dibuat dengan alamat ini tidak terpengaruh.',
            style: moveraText(size: 13, color: MoveraColors.textMuted)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Hapus')),
        ],
      ),
    );
    if (ok == true) await cubit.deletePlace(p.label);
  }
}

/// Dialog memberi nama alamat. [required] false menampilkan tombol "Tidak usah".
Future<String?> askPlaceLabel(BuildContext context, {bool required = false}) {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (c) => AlertDialog(
      backgroundColor: MoveraColors.card,
      title: Text(required ? 'Nama alamat' : 'Simpan alamat?', style: moveraText(size: 17, weight: FontWeight.w700)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Wrap(spacing: 8, children: [
          for (final l in ['Rumah', 'Kantor', 'Sekolah'])
            ActionChip(label: Text(l), onPressed: () => Navigator.pop(c, l)),
        ]),
        const SizedBox(height: 10),
        TextField(
          controller: controller,
          style: moveraText(),
          decoration: InputDecoration(hintText: 'Nama lain, misalnya Rumah Nenek', hintStyle: moveraText(color: MoveraColors.textFaint)),
        ),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: Text(required ? 'Batal' : 'Tidak usah')),
        TextButton(onPressed: () => Navigator.pop(c, controller.text.trim()), child: const Text('Simpan')),
      ],
    ),
  );
}
