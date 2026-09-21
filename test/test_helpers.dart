import 'dart:convert';
import 'dart:io';

import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ogera_crm_mobile/core/network/api_client.dart';
import 'package:ogera_crm_mobile/models/auth_session.dart';
import 'package:ogera_crm_mobile/models/staff_location.dart';
import 'package:ogera_crm_mobile/services/auth_service.dart';
import 'package:ogera_crm_mobile/services/location_queue.dart';

/// Shared fakes for the module widget tests. Kept in one place so each test
/// file only has to describe the data it cares about, not the plumbing.

/// An [ApiClient] whose [MockClient] answers by request path, ignoring the
/// bearer token and headers. [routes] maps a path to a function of the full
/// request URI (so a handler can branch on query parameters) returning the
/// envelope's `data` payload; a path with no handler answers with `null`.
ApiClient fakeApiClient(Map<String, dynamic Function(Uri uri)> routes) {
  return ApiClient(
    baseUrl: 'https://crm.test',
    client: MockClient((request) async {
      final handler = routes[request.url.path];
      final data = handler?.call(request.url);
      return http.Response(jsonEncode({'success': true, 'data': data}), 200);
    }),
  );
}

/// Never restores a session and never signs one in unless a test overrides it
/// — most harnesses only need [SessionViewModel.adopt] to work. [signOutCalled]
/// lets a test confirm sign-out actually reached the auth layer.
class FakeAuthService implements AuthService {
  bool signOutCalled = false;

  @override
  Future<AuthSession> signIn({
    required String email,
    required String password,
    required LoginScope scope,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<AuthSession?> restore() async => null;

  @override
  Future<void> signOut() async {
    signOutCalled = true;
  }
}

/// Lets `SessionViewModel.adopt` resolve instantly for a Staff session without
/// touching a real location plugin: reporting the service as unavailable is
/// the first check `LocationTrackingService.checkPermission` makes, and it
/// short-circuits before anything platform-specific runs.
class NoLocationServicePlatform extends GeolocatorPlatform {
  @override
  Future<bool> isLocationServiceEnabled() async => false;
}

/// A [LocationQueue] that never opens a real database. `sqflite` has no
/// platform implementation inside a widget test, so a `SessionViewModel`
/// harness always passes this instead of a real queue.
class NoopLocationQueue implements LocationQueue {
  @override
  Future<void> add(PendingPoint point) async {}

  @override
  Future<List<PendingPoint>> take(int limit) async => const [];

  @override
  Future<void> remove(List<PendingPoint> points) async {}

  @override
  Future<int> count() async => 0;

  @override
  Future<void> clear() async {}

  @override
  Future<void> close() async {}
}

/// Fails any real network request immediately instead of letting it hang —
/// used so `flutter_map`'s tile layer cannot reach out to the real internet
/// while the Map tab is mounted (it stays in the widget tree even when it is
/// not the visible shell tab, because `IndexedStack` builds every child).
class NoNetworkHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) => _FailingHttpClient();
}

class _FailingHttpClient implements HttpClient {
  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    throw const SocketException('Network disabled in tests');
  }

  @override
  void close({bool force = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ------------------------------------------------------------------ builders

Map<String, dynamic> contactJson({
  required int id,
  String? name,
  String phone = '9876543210',
  String type = 'lead',
  String? panchayath,
  String? district,
  String createdAt = '2026-01-01T00:00:00.000Z',
}) => {
  'id': id,
  'phone': phone,
  'name': name,
  'contactType': type,
  'panchayath': panchayath,
  'district': district,
  'createdAt': createdAt,
};

Map<String, dynamic> contactPinJson({
  required int id,
  double latitude = 11.25,
  double longitude = 75.78,
  String type = 'lead',
  String? name,
}) => {
  'id': id,
  'phone': '9876543210',
  'latitude': latitude,
  'longitude': longitude,
  'contactType': type,
  'name': name,
};

Map<String, dynamic> professionalJson({
  required int id,
  String? name,
  String phone = '9876543211',
  String type = 'Plumber',
  double? latitude,
  double? longitude,
  String createdAt = '2026-01-01T00:00:00.000Z',
}) => {
  'id': id,
  'phone': phone,
  'name': name,
  'type': type,
  'latitude': latitude?.toString(),
  'longitude': longitude?.toString(),
  'createdAt': createdAt,
};

Map<String, dynamic> leadJson({
  required int id,
  String? name,
  String phone = '9876543212',
  String? stage,
  String? followupDueDate,
  String? panchayath,
  String createdAt = '2026-01-01T00:00:00.000Z',
}) => {
  'id': id,
  'phone': phone,
  'name': name,
  'stage': stage,
  'followupDueDate': followupDueDate,
  'panchayath': panchayath,
  'createdAt': createdAt,
};

Map<String, dynamic> stageJson({
  required String id,
  required String label,
  required int orderIndex,
}) => {'id': id, 'label': label, 'orderIndex': orderIndex};

Map<String, dynamic> staffLocationJson({
  required int userId,
  required String name,
  double latitude = 11.25,
  double longitude = 75.78,
  String state = 'moving',
}) => {
  'userId': userId,
  'name': name,
  'latitude': latitude,
  'longitude': longitude,
  'state': state,
  'recordedAt': '2026-01-01T00:00:00.000Z',
};
