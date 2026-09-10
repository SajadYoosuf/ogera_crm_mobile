/// Build-time configuration.
///
/// The base URL must be supplied with `--dart-define=API_BASE_URL=...` for any
/// build that is not running against a local development server on an Android
/// emulator, where `10.0.2.2` is the host machine.
class AppConfig {
  const AppConfig._();

  // Configure your backend server:
  // - For Android Emulator: http://10.0.2.2:3000
  // - For Local Machine: http://192.168.29.206:3000
  // - For Hostinger Remote: http://187.127.150.170:3000
  // Override with: flutter run --dart-define=API_BASE_URL=http://your-ip:3000
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://192.168.29.206:3000',
  );

  /// Nominatim asks every client to identify itself and to stay under one
  /// request per second. Both rules are honoured by [GeocodingService].
  static const geocodingUserAgent = 'OgeraCRM/1.0 (mobile)';
  static const geocodingBaseUrl = 'https://nominatim.openstreetmap.org';

  static const osmTileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const osmTilePackage = 'com.ogera.crm';

  /// How often the head map refreshes live staff positions while foregrounded.
  static const liveRefreshInterval = Duration(seconds: 20);
}
