import '../core/network/api_client.dart';
import '../core/utils/formatters.dart';
import '../models/staff_location.dart';

/// The five staff-location endpoints described in §5.3 of the mobile PRD.
class LocationApiService {
  const LocationApiService(this._api);

  final ApiClient _api;

  /// Uploads a batch. The server de-duplicates on `(userId, recordedAt)`, so a
  /// retry after a half-failed flush cannot create phantom detours.
  Future<void> upload(List<PendingPoint> points) {
    if (points.isEmpty) return Future.value();
    return _api.post(
      '/api/staff/locations',
      body: {
        'points': points.map((point) => point.toJson()).toList(growable: false),
      },
    );
  }

  /// Tells the server the device stopped or resumed sharing, so the head map
  /// can distinguish "location off" from "simply out of coverage".
  Future<void> reportState(String state) {
    return _api.post('/api/staff/locations/state', body: {'state': state});
  }

  Future<List<StaffLocation>> live() async {
    final data = await _api.get('/api/staff/locations/live');
    final rows = data is List ? asList(data) : asList(asMap(data)['staff']);
    return rows
        .map(StaffLocation.fromJson)
        .whereType<StaffLocation>()
        .toList(growable: false);
  }

  Future<StaffRoute> history({
    required int userId,
    required String date,
  }) async {
    final data = await _api.get(
      '/api/staff/locations/history',
      query: {'userId': userId, 'date': date},
    );
    return StaffRoute.fromJson(userId, date, _routeBody(data));
  }

  /// A staff member's own route, for "My Route Today".
  Future<StaffRoute> myRoute({required int userId, String? date}) async {
    final day = date ?? todayIso();
    final data = await _api.get(
      '/api/staff/locations/me',
      query: {'date': day},
    );
    return StaffRoute.fromJson(userId, day, _routeBody(data));
  }

  /// The endpoint may answer with a bare list of points or with the full
  /// summary object; both are accepted.
  Map<String, dynamic> _routeBody(dynamic data) =>
      data is List ? {'points': data} : asMap(data);
}
