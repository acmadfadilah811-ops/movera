import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'core/config/app_config.dart';
import 'core/mock/mock_work_backend.dart';
import 'core/services/api_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/socket_service.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/splash/presentation/bloc/splash_bloc.dart';
import 'features/work/data/work_models.dart';
import 'features/work/presentation/cubit/work_cubit.dart';

final sl = GetIt.instance;

Future<void> init() async {
  final sharedPreferences = await SharedPreferences.getInstance();
  sl.registerLazySingleton(() => sharedPreferences);
  sl.registerLazySingleton(() => http.Client());

  sl.registerLazySingleton(() => SocketService(baseUrl: AppConfig.serverUrl));
  sl.registerLazySingleton(() => ApiService(client: sl(), prefs: sl()));
  sl.registerLazySingleton(() => NotificationService(sl()));

  sl.registerLazySingleton(() => AuthBloc(apiService: sl(), prefs: sl(), socketService: sl(), notificationService: sl()));
  sl.registerFactory(() => SplashBloc());

  // TODO(backend): ganti MockWorkBackend dengan repository HTTP saat backend siap.
  sl.registerLazySingleton<WorkRepository>(() => MockWorkBackend(sl()));
  sl.registerLazySingleton(() => WorkCubit(sl()));
}
