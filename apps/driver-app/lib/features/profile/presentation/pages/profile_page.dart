import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/presentation/widgets/movera_widgets.dart';
import '../../../../core/theme/movera_colors.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_event.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../auth/presentation/pages/auth_page.dart';
import '../../../work/data/work_models.dart';
import '../../../work/presentation/cubit/work_cubit.dart';
import '../../../work/presentation/pages/incident_report_page.dart';
import 'about_app_page.dart';
import 'support_and_help_page.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final shift = context.watch<WorkCubit>().state.shift;
    return BlocConsumer<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthUnauthenticated) {
          Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const AuthPage()), (_) => false);
        }
      },
      builder: (context, state) {
        final user = state.currentUser;
        final name = user?.fullName ?? '-';
        return Scaffold(
          backgroundColor: MoveraColors.bg,
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
              children: [
                Text('Profil', style: moveraText(size: 26, weight: FontWeight.w800)),
                const SizedBox(height: 20),
                MoveraCard(
                  child: Row(children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: MoveraColors.accent.withValues(alpha: 0.12),
                      child: Text(name.isEmpty ? '?' : name[0].toUpperCase(),
                          style: moveraText(size: 20, weight: FontWeight.w800, color: MoveraColors.accent)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(name, style: moveraText(size: 17, weight: FontWeight.w700)),
                        Text(user?.email ?? '', style: moveraText(size: 13, color: MoveraColors.textMuted)),
                        const SizedBox(height: 4),
                        Text('Driver karyawan', style: moveraText(size: 12, color: MoveraColors.textFaint)),
                      ]),
                    ),
                  ]),
                ),
                if (shift != null) ...[
                  const SizedBox(height: 12),
                  MoveraCard(
                    child: Row(children: [
                      const Icon(Icons.electric_car_rounded, color: MoveraColors.accent),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Kendaraan hari ini', style: moveraText(size: 12, color: MoveraColors.textMuted)),
                          Text('${shift.vehicle.plate} · ${shift.vehicle.model}', style: moveraText(weight: FontWeight.w600)),
                        ]),
                      ),
                    ]),
                  ),
                ],
                const SizedBox(height: 24),
                const SectionLabel('Menu'),
                _menu(context, Icons.report_problem_outlined, 'Laporan Insiden', 'Kerusakan, kecelakaan, masalah penumpang', const IncidentReportPage()),
                _menu(context, Icons.support_agent_rounded, 'Bantuan & SOP', 'Panduan kerja driver', const SupportAndHelpPage()),
                _menu(context, Icons.info_outline_rounded, 'Tentang Aplikasi', 'Versi dan lisensi', const AboutAppPage()),
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

  Widget _menu(BuildContext context, IconData icon, String title, String subtitle, Widget page) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: MoveraCard(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => page)),
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
    final shift = context.read<WorkCubit>().state.shift;
    final onDuty = shift?.status.isOnDuty ?? false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: MoveraColors.card,
        title: Text('Keluar dari akun?', style: moveraText(size: 17, weight: FontWeight.w700)),
        content: onDuty
            ? Text('Shift Anda masih berjalan. Selesaikan shift dulu sebelum keluar.',
                style: moveraText(size: 13, color: MoveraColors.warning))
            : null,
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Batal')),
          if (!onDuty) TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Keluar')),
        ],
      ),
    );
    if (ok == true) auth.add(LogoutEvent());
  }
}
