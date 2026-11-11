import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/presentation/widgets/movera_widgets.dart';
import '../../../../core/theme/movera_colors.dart';
import '../../../profile/presentation/pages/profile_page.dart';
import '../cubit/work_cubit.dart';
import 'driver_home_page.dart';
import 'task_list_page.dart';

/// Kerangka utama aplikasi driver setelah login.
class DriverShell extends StatefulWidget {
  const DriverShell({super.key});

  @override
  State<DriverShell> createState() => _DriverShellState();
}

class _DriverShellState extends State<DriverShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    context.read<WorkCubit>().load();
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      DriverHomePage(onOpenTasks: () => setState(() => _index = 1)),
      const TaskListPage(),
      const HistoryPage(),
      const ProfilePage(),
    ];
    final openCount = context.watch<WorkCubit>().state.openTrips.length;
    return Scaffold(
      backgroundColor: MoveraColors.bg,
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          backgroundColor: MoveraColors.surface,
          indicatorColor: MoveraColors.accent.withValues(alpha: 0.18),
          labelTextStyle: WidgetStatePropertyAll(moveraText(size: 11, weight: FontWeight.w600, color: MoveraColors.textMuted)),
          iconTheme: WidgetStateProperty.resolveWith(
            (s) => IconThemeData(color: s.contains(WidgetState.selected) ? MoveraColors.accent : MoveraColors.textFaint),
          ),
        ),
        child: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          destinations: [
            const NavigationDestination(icon: Icon(Icons.home_rounded), label: 'Beranda'),
            NavigationDestination(
              icon: Badge(isLabelVisible: openCount > 0, label: Text('$openCount'), child: const Icon(Icons.assignment_rounded)),
              label: 'Tugas',
            ),
            const NavigationDestination(icon: Icon(Icons.history_rounded), label: 'Riwayat'),
            const NavigationDestination(icon: Icon(Icons.person_rounded), label: 'Profil'),
          ],
        ),
      ),
    );
  }
}
