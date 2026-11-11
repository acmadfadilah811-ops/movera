import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/presentation/widgets/movera_widgets.dart';
import '../../../../core/theme/movera_colors.dart';

class SupportAndHelpPage extends StatelessWidget {
  const SupportAndHelpPage({super.key});

  static const _faq = [
    (
      'Apa itu satu booking?',
      'Satu booking adalah satu perjalanan dari titik jemput ke tujuan. Rumah ke kantor dihitung 1 booking, '
          'kantor ke rumah dihitung 1 booking lagi.'
    ),
    (
      'Kuota harian bisa dipakai hari lain?',
      'Tidak. Kuota berlaku per tanggal dan tidak bisa dipindah atau dikumpulkan. Sisa kuota hari ini hangus saat hari berganti.'
    ),
    (
      'Bagaimana kalau saya membatalkan booking?',
      'Pembatalan paling lambat 60 menit sebelum jemput mengembalikan kuota. Kalau lebih mepet, kuota tanggal itu hangus.'
    ),
    (
      'Apa bedanya Sendiri dan Bersedia berbagi?',
      'Sendiri berarti mobil hanya untuk Anda dan penumpang dalam booking yang sama. Bersedia berbagi berarti mobil boleh '
          'menjemput penumpang lain yang searah, dengan batas tambahan waktu yang Anda pilih.'
    ),
    (
      'Apa itu booking rutin?',
      'Jadwal mingguan, misalnya Senin sampai Jumat jam 06.30 ke sekolah. Aplikasi membuat booking otomatis untuk 7 hari ke depan '
          'dan mencadangkan kuota per tanggal.'
    ),
    (
      'Untuk apa PIN jemput?',
      'Sebutkan PIN di detail booking kepada driver saat dijemput. Driver hanya memulai perjalanan setelah PIN cocok, '
          'supaya yang naik benar-benar penumpang Anda.'
    ),
    (
      'Apakah driver menyerahkan anak langsung ke guru atau wali?',
      'Tidak. Layanan pelajar hanya antar dan jemput. Pastikan kontak darurat anak terisi di Data Penumpang dan ada '
          'pihak yang menerima anak di tujuan.'
    ),
    (
      'Bagaimana cara membayar langganan?',
      'Pilih paket di tab Langganan, lalu bayar lewat payment gateway (transfer bank, e-wallet, atau QRIS). '
          'Langganan aktif setelah pembayaran terverifikasi.'
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
        title: Text('Bantuan', style: moveraText(size: 18, weight: FontWeight.w700)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          const SectionLabel('Hubungi kami'),
          MoveraCard(
            onTap: () {
              Clipboard.setData(const ClipboardData(text: AppConfig.supportEmail));
              showMoveraSnack(context, 'Alamat email disalin.');
            },
            child: Row(children: [
              const Icon(Icons.email_rounded, color: MoveraColors.accent),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Email', style: moveraText(weight: FontWeight.w600)),
                  Text(AppConfig.supportEmail, style: moveraText(size: 12, color: MoveraColors.textMuted)),
                ]),
              ),
              const Icon(Icons.copy_rounded, color: MoveraColors.textFaint, size: 18),
            ]),
          ),
          const SizedBox(height: 8),
          MoveraCard(
            child: Row(children: [
              const Icon(Icons.emergency_rounded, color: MoveraColors.danger),
              const SizedBox(width: 14),
              Expanded(
                child: Text('Dalam keadaan darurat saat perjalanan, hubungi 112 terlebih dahulu.',
                    style: moveraText(size: 13, color: MoveraColors.textMuted, height: 1.45)),
              ),
            ]),
          ),
          const SizedBox(height: 24),
          const SectionLabel('Pertanyaan umum'),
          for (final (q, a) in _faq)
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
                    title: Text(q, style: moveraText(size: 14, weight: FontWeight.w600)),
                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    children: [Text(a, style: moveraText(size: 13, color: MoveraColors.textMuted, height: 1.5))],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
