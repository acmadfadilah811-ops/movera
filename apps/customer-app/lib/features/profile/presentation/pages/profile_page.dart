import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/presentation/widgets/movera_widgets.dart';
import '../../../../core/theme/movera_colors.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_event.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../auth/presentation/pages/auth_page.dart';
import 'about_app_page.dart';
import 'manage_profile_page.dart';
import 'mfa_settings_page.dart';
import 'passengers_page.dart';
import 'saved_places_page.dart';
import 'support_and_help_page.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthUnauthenticated) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const AuthPage()),
            (_) => false,
          );
        }
      },
      builder: (context, state) {
        final user = state.currentUser;
        return Scaffold(
          backgroundColor: MoveraColors.bg,
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
              children: [
                Text('Profil', style: moveraText(size: 26, weight: FontWeight.w800)),
                const SizedBox(height: 20),
                MoveraCard(
                  onTap: () => _push(context, const ManageProfilePage()),
                  child: Row(children: [
                    _avatar(user?.profilePic, user?.fullName ?? ''),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(user?.fullName ?? '-', style: moveraText(size: 17, weight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text(user?.email ?? '', style: moveraText(size: 13, color: MoveraColors.textMuted)),
                      ]),
                    ),
                    const Icon(Icons.edit_rounded, color: MoveraColors.textFaint, size: 18),
                  ]),
                ),
                const SizedBox(height: 24),
                const SectionLabel('Perjalanan'),
                _menu(context, Icons.bookmark_rounded, 'Alamat Tersimpan', 'Rumah, kantor, sekolah', const SavedPlacesPage()),
                _menu(context, Icons.family_restroom_rounded, 'Data Penumpang', 'Anak dan anggota keluarga', const PassengersPage()),
                const SizedBox(height: 16),
                const SectionLabel('Akun'),
                if (!AppConfig.useMock)
                  _menu(context, Icons.security_rounded, 'Keamanan Akun', 'Verifikasi dua langkah', const MfaSettingsPage()),
                _menu(context, Icons.support_agent_rounded, 'Bantuan', 'Pertanyaan umum dan kontak', const SupportAndHelpPage()),
                _menu(context, Icons.info_outline_rounded, 'Tentang Aplikasi', 'Versi, syarat, dan lisensi', const AboutAppPage()),
                const SizedBox(height: 24),
                SecondaryButton(
                  label: 'Keluar',
                  icon: Icons.logout_rounded,
                  color: MoveraColors.danger,
                  onPressed: () => _logout(context),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _push(BuildContext context, Widget page) => Navigator.push(context, MaterialPageRoute(builder: (_) => page));

  Widget _avatar(String? pic, String name) {
    ImageProvider? image;
    if (pic != null && pic.isNotEmpty) {
      if (pic.startsWith('data:image')) {
        try {
          image = MemoryImage(base64Decode(pic.split(',').last));
        } catch (_) {}
      } else if (pic.startsWith('http')) {
        image = NetworkImage(pic);
      }
    }
    return CircleAvatar(
      radius: 28,
      backgroundColor: MoveraColors.accent.withValues(alpha: 0.12),
      backgroundImage: image,
      child: image == null
          ? Text(name.isEmpty ? '?' : name[0].toUpperCase(),
              style: moveraText(size: 20, weight: FontWeight.w800, color: MoveraColors.accent))
          : null,
    );
  }

  Widget _menu(BuildContext context, IconData icon, String title, String subtitle, Widget page) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: MoveraCard(
          onTap: () => _push(context, page),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(children: [
            Icon(icon, color: MoveraColors.accent, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: moveraText(weight: FontWeight.w600)),
                Text(subtitle, style: moveraText(size: 12, color: MoveraColors.textMuted)),
              ]),
            ),
            const Icon(Icons.chevron_right_rounded, color: MoveraColors.textFaint),
          ]),
        ),
      );

  Future<void> _logout(BuildContext context) async {
    final auth = context.read<AuthBloc>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: MoveraColors.card,
        title: Text('Keluar dari akun?', style: moveraText(size: 17, weight: FontWeight.w700)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Keluar')),
        ],
      ),
    );
    if (ok == true) auth.add(LogoutEvent());
  }
}
