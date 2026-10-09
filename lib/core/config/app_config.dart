import 'package:flutter/foundation.dart';

/// Build-time configuration.
///
/// Release builds use the deployed Ogera CRM API. Debug builds (flutter
/// run) use the local dev server on the LAN, so unreleased API routes work
/// without any flags. Either can be overridden with
/// `--dart-define=API_BASE_URL=...`.
class AppConfig {
  const AppConfig._();

  static const _override = String.fromEnvironment('API_BASE_URL');
  // Set the deployed FastAPI address at build time:
  //   flutter build apk --dart-define=API_BASE_URL=https://api.example.com
  static const _productionUrl = 'https://ogera-crm.onrender.com';

  // Local dev server (`uvicorn main:app --host 0.0.0.0 --port 8000`):
  // - Android Emulator: http://10.0.2.2:8000
  // - Physical device on the same LAN: http://<your PC's address>:8000
  static const _debugUrl = 'http://192.168.29.206:8000';

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
