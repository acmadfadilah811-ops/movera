import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:movera_pelanggan/core/services/api_service.dart';
import 'package:movera_pelanggan/core/services/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Regresi: APK demo macet di layar awal karena FirebaseMessaging.instance dipanggil
/// saat Firebase belum dikonfigurasi (belum ada google-services.json).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('NotificationService bisa dibuat dan init tanpa Firebase', () async {
    SharedPreferences.setMockInitialValues({});
    final api = ApiService(client: http.Client(), prefs: await SharedPreferences.getInstance());
    final service = NotificationService(api);
    await service.init();
    expect(await service.getToken(), isNull);
  });
}
