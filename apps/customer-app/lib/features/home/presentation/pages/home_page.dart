import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/presentation/widgets/custom_bottom_nav.dart';
import '../../../../core/theme/movera_colors.dart';
import '../../../booking/presentation/cubit/booking_cubit.dart';
import '../../../booking/presentation/pages/booking_list_page.dart';
import '../../../booking/presentation/pages/create_booking_page.dart';
import '../../../profile/presentation/pages/profile_page.dart';
import '../../../subscription/presentation/cubit/subscription_cubit.dart';
import '../../../subscription/presentation/pages/subscription_page.dart';
import 'beranda_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const _tabBeranda = 0;
  static const _tabBooking = 1;
  static const _tabLangganan = 2;

  int _selectedIndex = _tabBeranda;

  @override
  void initState() {
    super.initState();
    context.read<SubscriptionCubit>().load();
    context.read<BookingCubit>().load();
  }

  void _go(int index) => setState(() => _selectedIndex = index);

  void _createBooking() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CreateBookingPage(onOpenSubscription: () => _go(_tabLangganan))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      BerandaPage(
        onCreateBooking: _createBooking,
        onOpenSubscription: () => _go(_tabLangganan),
        onOpenBookings: () => _go(_tabBooking),
      ),
      const BookingListPage(),
      const SubscriptionPage(),
      const ProfilePage(),
    ];
    return Scaffold(
      backgroundColor: MoveraColors.bg,
      body: IndexedStack(index: _selectedIndex, children: pages),
      bottomNavigationBar: CustomBottomNav(selectedIndex: _selectedIndex, onItemSelected: _go),
      floatingActionButton: _buildCenterFab(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  Widget _buildCenterFab() {
    return Tooltip(
      message: 'Buat booking',
      child: GestureDetector(
        onTap: _createBooking,
        child: Container(
          height: 62,
          width: 62,
          decoration: BoxDecoration(
            color: MoveraColors.accent,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: MoveraColors.accent.withValues(alpha: 0.3), blurRadius: 15, spreadRadius: 2, offset: const Offset(0, 5)),
            ],
          ),
          child: const Icon(Icons.add_rounded, color: Colors.black, size: 32),
        ),
      ),
    );
  }
}
