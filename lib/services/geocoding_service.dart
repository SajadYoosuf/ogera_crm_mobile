import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../core/config/app_config.dart';

/// Reverse geocoding through OpenStreetMap Nominatim, the same provider the web
/// app uses in `src/lib/location.ts`.
///
/// Nominatim's usage policy requires an identifying User-Agent and at most one
/// request per second, so every lookup passes through a serial queue with a
/// one-second spacing. Results are cached against a 5-decimal coordinate key —
/// roughly a one-metre cell — so a route with hundreds of points only ever
/// geocodes each distinct place once.
class GeocodingService {
  GeocodingService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  final Map<String, String> _cache = {};
  final Map<String, Future<String?>> _inFlight = {};

  Future<void> _gate = Future.value();
  DateTime _lastRequest = DateTime.fromMillisecondsSinceEpoch(0);

  static const _minimumSpacing = Duration(seconds: 1);

  String _keyOf(double latitude, double longitude) =>
      '${latitude.toStringAsFixed(5)},${longitude.toStringAsFixed(5)}';

  /// The cached address, if this coordinate has already been resolved. Callers
  /// use it to paint a row immediately and fall back to [resolve] for the rest.
  String? cached(LatLng position) =>
      _cache[_keyOf(position.latitude, position.longitude)];

  Future<String?> resolve(LatLng position) {
    final key = _keyOf(position.latitude, position.longitude);
    final hit = _cache[key];
    if (hit != null) return Future.value(hit);
    return _inFlight[key] ??= _enqueue(key, position).whenComplete(() {
      _inFlight.remove(key);
    });
  }

  Future<String?> _enqueue(String key, LatLng position) {
    final completer = Completer<String?>();
    _gate = _gate.then((_) async {
      final sinceLast = DateTime.now().difference(_lastRequest);
      if (sinceLast < _minimumSpacing) {
        await Future<void>.delayed(_minimumSpacing - sinceLast);
      }
      _lastRequest = DateTime.now();
      final address = await _lookup(position);
      if (address != null) _cache[key] = address;
      completer.complete(address);
    });
    return completer.future;
  }

  Future<String?> _lookup(LatLng position) async {
    final uri = Uri.parse('${AppConfig.geocodingBaseUrl}/reverse').replace(
      queryParameters: {
        'format': 'jsonv2',
        'lat': position.latitude.toString(),
        'lon': position.longitude.toString(),
        'zoom': '18',
        'addressdetails': '1',
      },
    );
    try {
      final response = await _client
          .get(uri, headers: {'User-Agent': AppConfig.geocodingUserAgent})
          .timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) return null;
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return null;
      return _shorten(decoded);
    } catch (_) {
      // Offline or rate-limited: the caller shows coordinates instead.
      return null;
    }
  }

  /// Nominatim's `display_name` is long enough to wrap four lines on a phone.
  /// This keeps the parts a field team actually reads.
  String? _shorten(Map<String, dynamic> json) {
    final address = json['address'];
    if (address is! Map) return json['display_name']?.toString();
    String? pick(List<String> keys) {
      for (final key in keys) {
        final value = address[key];
        if (value is String && value.trim().isNotEmpty) return value.trim();
      }
      return null;
    }

    final parts = <String>[
      ?pick(['road', 'neighbourhood', 'suburb', 'hamlet']),
      ?pick(['village', 'town', 'city', 'municipality']),
      ?pick(['county', 'state_district']),
    ];
    if (parts.isEmpty) return json['display_name']?.toString();
    return parts.join(', ');
  }

  /// Formatted coordinates, used wherever geocoding failed so a row is never
  /// left blank.
  static String coordinateLabel(LatLng position) =>
      '${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}';
}
