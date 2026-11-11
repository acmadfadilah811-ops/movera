import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/config/app_config.dart';
import 'core/services/notification_service.dart';
import 'core/theme/movera_colors.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/auth/presentation/bloc/auth_event.dart';
import 'features/auth/presentation/bloc/auth_state.dart';
import 'features/auth/presentation/pages/mfa_page.dart';
import 'features/auth/presentation/pages/mfa_setup_page.dart';
import 'features/booking/presentation/cubit/booking_cubit.dart';
import 'features/home/presentation/pages/home_page.dart';
import 'features/splash/presentation/pages/splash_page.dart';
import 'features/subscription/presentation/cubit/subscription_cubit.dart';
import 'injection_container.dart' as di;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('Firebase belum dikonfigurasi: $e');
  }
  await di.init();
  try {
    di.sl<NotificationService>().init().catchError((e) => debugPrint('Notifikasi tidak aktif: $e'));
  } catch (e) {
    debugPrint('Notifikasi tidak aktif: $e');
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => di.sl<AuthBloc>()..add(CheckAuthSession())),
        BlocProvider.value(value: di.sl<SubscriptionCubit>()),
        BlocProvider.value(value: di.sl<BookingCubit>()),
      ],
      child: MaterialApp(
        title: AppConfig.appName,
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          scaffoldBackgroundColor: MoveraColors.bg,
          colorScheme: ColorScheme.fromSeed(
            seedColor: MoveraColors.accent,
            brightness: Brightness.dark,
            primary: MoveraColors.accent,
            onPrimary: MoveraColors.onAccent,
            surface: MoveraColors.surface,
          ),
          dialogTheme: const DialogThemeData(backgroundColor: MoveraColors.card),
        ),
        home: BlocBuilder<AuthBloc, AuthState>(
          builder: (context, state) {
            if (state is AuthAuthenticated ||
                state is AuthMfaStatus ||
                (state is AuthLoading && state.user != null) ||
                (state is AuthError && state.user != null)) {
              return const HomePage();
            } else if (state is AuthMfaRequired) {
              return MfaPage(factorId: state.factorId, challengeId: state.challengeId);
            } else if (state is AuthMfaSetupRequired) {
              return MfaSetupPage(
                qrCode: state.qrCode,
                secret: state.secret,
                factorId: state.factorId,
                challengeId: state.challengeId,
              );
            }
            return const SplashPage();
          },
        ),
      ),
    );
  }
}
