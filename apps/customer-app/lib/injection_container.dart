import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'core/config/app_config.dart';
import 'core/mock/mock_backend.dart';
import 'core/services/api_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/socket_service.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/booking/data/booking_models.dart';
import 'features/booking/presentation/cubit/booking_cubit.dart';
import 'features/splash/presentation/bloc/splash_bloc.dart';
import 'features/subscription/data/subscription_models.dart';
import 'features/subscription/presentation/cubit/subscription_cubit.dart';

final sl = GetIt.instance;

Future<void> init() async {
  final sharedPreferences = await SharedPreferences.getInstance();
  sl.registerLazySingleton(() => sharedPreferences);
  sl.registerLazySingleton(() => http.Client());

  sl.registerLazySingleton(() => ApiService(client: sl(), prefs: sl()));
  sl.registerLazySingleton(() => NotificationService(sl()));

  final socketService = SocketService();
  if (!AppConfig.useMock) socketService.connect(AppConfig.serverUrl);
  sl.registerLazySingleton(() => socketService);

  sl.registerFactory(() => SplashBloc());

  sl.registerLazySingleton(() => AuthBloc(
        apiService: sl(),
        prefs: sl(),
        socketService: sl(),
        notificationService: sl(),
      ));

  // TODO(backend): ganti MockBackend dengan repository HTTP saat backend siap.
  final mock = MockBackend(sl());
  sl.registerLazySingleton<SubscriptionRepository>(() => mock);
  sl.registerLazySingleton<BookingRepository>(() => mock);
  sl.registerLazySingleton(() => SubscriptionCubit(sl()));
  sl.registerLazySingleton(() => BookingCubit(sl()));
}
