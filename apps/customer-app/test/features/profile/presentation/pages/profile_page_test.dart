import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:movera_pelanggan/core/models/user_model.dart';
import 'package:movera_pelanggan/core/services/api_service.dart';
import 'package:movera_pelanggan/core/services/notification_service.dart';
import 'package:movera_pelanggan/core/services/socket_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:movera_pelanggan/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:movera_pelanggan/features/auth/presentation/bloc/auth_event.dart';
import 'package:movera_pelanggan/features/auth/presentation/bloc/auth_state.dart';
import 'package:movera_pelanggan/features/profile/presentation/pages/profile_page.dart';

class FakeAuthBloc extends Bloc<AuthEvent, AuthState> implements AuthBloc {
  FakeAuthBloc(super.initialState);

  @override
  ApiService get apiService => throw UnimplementedError();

  @override
  SharedPreferences get prefs => throw UnimplementedError();

  @override
  SocketService get socketService => throw UnimplementedError();

  @override
  NotificationService get notificationService => throw UnimplementedError();
}

Widget _wrap(AuthBloc bloc) => MaterialApp(
      home: BlocProvider<AuthBloc>.value(value: bloc, child: const ProfilePage()),
    );

AuthBloc _signedIn() => FakeAuthBloc(
      AuthAuthenticated(
        user: const UserModel(id: 'usr_1', email: 'rider@movera.id', fullName: 'Siti Aminah'),
      ),
    );

void main() {
  testWidgets('Profil menampilkan nama, email, dan menu perjalanan', (tester) async {
    await tester.pumpWidget(_wrap(_signedIn()));
    expect(find.text('Siti Aminah'), findsOneWidget);
    expect(find.text('rider@movera.id'), findsOneWidget);
    expect(find.text('Alamat Tersimpan'), findsOneWidget);
    expect(find.text('Data Penumpang'), findsOneWidget);
    expect(find.text('Bantuan'), findsOneWidget);
    expect(find.text('Keluar'), findsOneWidget);
  });

  testWidgets('Menu Bantuan membuka halaman pertanyaan umum', (tester) async {
    await tester.pumpWidget(_wrap(_signedIn()));
    await tester.tap(find.text('Bantuan'));
    await tester.pumpAndSettle();
    expect(find.text('Apa itu satu booking?'), findsOneWidget);
  });

  testWidgets('Keluar meminta konfirmasi dulu', (tester) async {
    await tester.pumpWidget(_wrap(_signedIn()));
    await tester.ensureVisible(find.text('Keluar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Keluar'));
    await tester.pumpAndSettle();
    expect(find.text('Keluar dari akun?'), findsOneWidget);
  });
}
