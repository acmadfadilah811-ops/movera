import 'package:flutter/material.dart';

import '../../../../core/presentation/widgets/movera_widgets.dart';
import '../../../../core/theme/movera_colors.dart';

/// Ringkasan SOP driver dari blueprint bagian 13.3 dan 13.4.
class SupportAndHelpPage extends StatelessWidget {
  const SupportAndHelpPage({super.key});

  static const _sop = [
    (
      'Sebelum shift',
      'Check-in lewat tombol Mulai Shift. Periksa ban, rem, lampu, sabuk pengaman, kebersihan, dan dokumen. '
          'Isi persentase baterai dan odometer. Periksa daftar tugas hari ini.'
    ),
    (
      'Saat menjemput',
      'Kerjakan titik sesuai urutan manifest. Tandai tiba di lokasi, lalu minta penumpang menyebutkan PIN. '
          'Perjalanan hanya dimulai setelah PIN cocok.'
    ),
    (
      'Penumpang tidak hadir',
      'Tunggu minimal 5 menit sejak tiba dan coba telepon pemesan. Setelah itu tombol "Penumpang tidak hadir" bisa dipakai.'
    ),
    (
      'Saat perjalanan',
      'Ikuti rute dan urutan titik. Jangan mengangkut penumpang di luar manifest. Laporkan keterlambatan, kerusakan, '
          'atau insiden lewat menu Laporan Insiden.'
    ),
    (
      'Penumpang anak',
      'Layanan hanya antar dan jemput, tanpa serah terima. Pastikan anak turun di area tujuan dengan aman. '
          'Jika tidak ada penerima dan anak tidak boleh ditinggal, jangan tinggalkan anak: hubungi kontak darurat '
          'yang tertera di manifest dan operasional.'
    ),
    (
      'Baterai dan pengecasan',
      'Jaga baterai di atas 25%. Sebelum mengecas, tekan Mulai Cas supaya dispatcher tidak memberi tugas. '
          'Setelah selesai, isi persentase baterai terbaru.'
    ),
    (
      'Akhir shift',
      'Pastikan tidak ada perjalanan berjalan. Periksa kendaraan, colokkan ke pengecas di pool, lalu tekan Selesai Shift '
          'dan isi baterai serta odometer akhir.'
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MoveraColors.bg,
      appBar: AppBar(
        backgroundColor: MoveraColors.bg,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text('Bantuan & SOP', style: moveraText(size: 18, weight: FontWeight.w700)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          MoveraCard(
            child: Row(children: [
              const Icon(Icons.emergency_rounded, color: MoveraColors.danger),
              const SizedBox(width: 14),
              Expanded(
                child: Text('Keadaan darurat: hubungi 112, lalu laporkan ke operasional lewat Laporan Insiden.',
                    style: moveraText(size: 13, color: MoveraColors.textMuted, height: 1.45)),
              ),
            ]),
          ),
          const SizedBox(height: 22),
          const SectionLabel('SOP driver'),
          for (final (title, body) in _sop)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                decoration: BoxDecoration(
                  color: MoveraColors.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: MoveraColors.border),
                ),
                child: Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    iconColor: MoveraColors.accent,
                    collapsedIconColor: MoveraColors.textFaint,
                    title: Text(title, style: moveraText(size: 14, weight: FontWeight.w600)),
                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    children: [Text(body, style: moveraText(size: 13, color: MoveraColors.textMuted, height: 1.5))],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
