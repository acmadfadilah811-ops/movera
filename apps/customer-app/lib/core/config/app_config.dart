/// Konfigurasi aplikasi. Alamat server diisi saat build/run, contoh:
/// flutter run --dart-define=API_BASE_URL=https://api.movera.id
class AppConfig {
  AppConfig._();

  static const String appName = 'Movera';
  static const String tagline = 'Antar-jemput mobil listrik dengan langganan bulanan.';
  static const String version = '1.0.0';

  /// Alamat server tanpa garis miring di akhir. Bawaan 10.0.2.2 = komputer host dari emulator Android.
  static const String serverUrl =
      String.fromEnvironment('API_BASE_URL', defaultValue: 'http://10.0.2.2:3000');

  /// Mode data contoh (tanpa backend). Matikan saat backend siap: --dart-define=USE_MOCK=false
  static const bool useMock = bool.fromEnvironment('USE_MOCK', defaultValue: true);

  static const String apiBaseUrl = '$serverUrl/api';

  /// Email bantuan sementara, ganti sebelum rilis.
  static const String supportEmail =
      String.fromEnvironment('SUPPORT_EMAIL', defaultValue: 'support@movera.id');

  /// Proyek asal kode aplikasi ini (lihat NOTICE.md).
  static const String upstreamProject = 'GoRide oleh samimalikdev (github.com/samimalikdev/GoRide)';
}
