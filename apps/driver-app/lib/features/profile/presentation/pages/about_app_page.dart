import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:movera_driver/core/config/app_config.dart';

const _bg = Color(0xff0a0a0a);
const _card = Color(0xff1a1a1a);
const _accent = Color(0xff76eb07);

class AboutAppPage extends StatelessWidget {
  const AboutAppPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Tentang Aplikasi',
          style: GoogleFonts.poppins(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            Center(
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                child: Image.asset('assets/brand/logo_portrait.png', width: 150),
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: Text(
                AppConfig.appName,
                style: GoogleFonts.poppins(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(height: 4),
            Center(
              child: Text(
                'Versi ${AppConfig.version}',
                style: GoogleFonts.poppins(color: _accent, fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 15),
            Center(
              child: Text(
                AppConfig.tagline,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(color: Colors.white54, fontSize: 13, height: 1.5),
              ),
            ),
            const SizedBox(height: 35),
            Text(
              'LEGAL & LISENSI',
              style: GoogleFonts.poppins(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1),
            ),
            const SizedBox(height: 12),
            _buildAboutCard(
              icon: Icons.description_rounded,
              title: 'Syarat & Ketentuan',
              subtitle: 'Aturan penggunaan layanan',
              onTap: () => _showSimpleDialog(context, 'Syarat & Ketentuan',
                  'Syarat & ketentuan layanan Movera sedang disusun dan akan tersedia sebelum layanan resmi berjalan.'),
            ),
            _buildAboutCard(
              icon: Icons.privacy_tip_rounded,
              title: 'Kebijakan Privasi',
              subtitle: 'Cara kami menjaga data dan lokasi Anda',
              onTap: () => _showSimpleDialog(context, 'Kebijakan Privasi',
                  'Kebijakan privasi Movera sedang disusun dan akan tersedia sebelum layanan resmi berjalan.'),
            ),
            _buildAboutCard(
              icon: Icons.code_rounded,
              title: 'Lisensi Open Source',
              subtitle: 'Pustaka pihak ketiga dan proyek asal',
              onTap: () => showLicensePage(
                context: context,
                applicationName: AppConfig.appName,
                applicationVersion: AppConfig.version,
                applicationLegalese: 'Sebagian kode aplikasi ini berasal dari ${AppConfig.upstreamProject}.',
                applicationIcon: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Image.asset('assets/brand/symbol.png', width: 72),
                ),
              ),
            ),
            const SizedBox(height: 30),
            Center(
              child: Text(
                '© 2026 ${AppConfig.appName}',
                style: GoogleFonts.poppins(color: Colors.white38, fontSize: 11),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildAboutCard({required IconData icon, required String title, required String subtitle, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _accent.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: _accent, size: 22),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.poppins(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: GoogleFonts.poppins(color: Colors.white38, fontSize: 11)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white24, size: 14),
          ],
        ),
      ),
    );
  }

  void _showSimpleDialog(BuildContext context, String title, String content) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title, style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18)),
        content: SingleChildScrollView(
          child: Text(content, style: GoogleFonts.poppins(color: Colors.white70, fontSize: 13, height: 1.5)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Tutup', style: GoogleFonts.poppins(color: _accent, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
