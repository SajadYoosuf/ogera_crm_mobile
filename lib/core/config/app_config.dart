import 'package:flutter/foundation.dart';

/// Build-time configuration.
///
/// Release builds use the public Ogera CRM deployment. Debug builds (flutter
/// run) use the local dev server on the LAN, so unreleased API routes work
/// without any flags. Either can be overridden with
/// `--dart-define=API_BASE_URL=...`.
class AppConfig {
  const AppConfig._();

  static const _override = String.fromEnvironment('API_BASE_URL');
  static const _productionUrl = 'https://ogera-crm.vercel.app';

  // Local dev server (npm run dev). Change this to your PC's address:
  // - Android Emulator: http://10.0.2.2:3000
  // - Physical device on the same LAN: http://192.168.29.206:3000
  static const _debugUrl = 'http://192.168.29.206:3000';

  static String get apiBaseUrl {
    if (_override.isNotEmpty) return _override;
    return kDebugMode ? _debugUrl : _productionUrl;
  }

  /// Nominatim asks every client to identify itself and to stay under one
  /// request per second. Both rules are honoured by [GeocodingService].
  static const geocodingUserAgent = 'OgeraCRM/1.0 (mobile)';
  static const geocodingBaseUrl = 'https://nominatim.openstreetmap.org';

  static const osmTileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const osmTilePackage = 'com.ogera.crm';

  /// How often the head map refreshes live staff positions while foregrounded.
  static const liveRefreshInterval = Duration(seconds: 20);
}
