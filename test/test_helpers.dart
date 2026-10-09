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
/// JSON body, the way FastAPI answers; a path with no handler answers `null`.
ApiClient fakeApiClient(Map<String, dynamic Function(Uri uri)> routes) {
  return ApiClient(
    baseUrl: 'https://crm.test',
    client: MockClient((request) async {
      final handler = routes[request.url.path];
      final data = handler?.call(request.url);
      return http.Response(jsonEncode(data), 200);
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

/// `{ items, total, skip, limit }`, the envelope of every paged list.
Map<String, dynamic> pageOf(
  List<Map<String, dynamic>> items, {
  int? total,
  int skip = 0,
  int limit = 20,
}) => {
  'items': items,
  'total': total ?? items.length,
  'skip': skip,
  'limit': limit,
};

/// A `GET /contacts` row. `type` is the mobile kind: `lead` or `awareness`
/// (both are API consumers, told apart by `awareness_mode`).
Map<String, dynamic> contactJson({
  required int id,
  String? name,
  String phone = '9876543210',
  String type = 'lead',
  String? district,
  String? stage,
  int? createdBy,
  int assignedTo = 3,
  String createdAt = '2026-01-01T00:00:00',
}) => {
  'id': id,
  'contact_type': 'consumer',
  'name': name ?? 'Contact $id',
  'phone': phone,
  'district': district ?? 'Calicut',
  'awareness_mode': type == 'awareness' ? 1 : 0,
  'lead_stage': stage == null
      ? null
      : {'stage': stage, 'changed_at': createdAt},
  'assigned_to': {'id': assignedTo, 'name': 'Staff $assignedTo'},
  'created_by': createdBy == null
      ? null
      : {'id': createdBy, 'name': 'Staff $createdBy'},
  'created_at': createdAt,
  'is_verified': true,
  'missing_fields': <String>[],
};

/// A `GET /contacts/map` row.
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
  'contact_type': 'consumer',
  'awareness_mode': type == 'awareness' ? 1 : 0,
  'name': name ?? 'Contact $id',
};

/// A partner `GET /contacts` row. `type` accepts the display name.
Map<String, dynamic> professionalJson({
  required int id,
  String? name,
  String phone = '9876543211',
  String type = 'Plumber',
  double? latitude,
  double? longitude,
  String createdAt = '2026-01-01T00:00:00',
}) => {
  'id': id,
  'contact_type': 'partner',
  'name': name ?? 'Partner $id',
  'phone': phone,
  'profession_type': type.toLowerCase().replaceAll(' ', '_'),
  'work_area': null,
  'district': 'Calicut',
  'latitude': latitude,
  'longitude': longitude,
  'created_at': createdAt,
};

/// A consumer row on the follow-up board; same shape as [contactJson].
Map<String, dynamic> leadJson({
  required int id,
  String? name,
  String phone = '9876543212',
  String? stage,
  int assignedTo = 3,
  List<String> missingFields = const [],
  String createdAt = '2026-01-01T00:00:00',
}) => {
  ...contactJson(
    id: id,
    name: name,
    phone: phone,
    stage: stage,
    assignedTo: assignedTo,
    createdAt: createdAt,
  ),
  'is_verified': missingFields.isEmpty,
  'missing_fields': missingFields,
};

/// An open follow-up as `GET /tasks` returns it.
Map<String, dynamic> taskJson({
  required int id,
  required int contactId,
  required String scheduledDate,
  int assignedTo = 3,
}) => {
  'id': id,
  'contact_id': contactId,
  'contact_name': 'Contact $contactId',
  'contact_phone': '9876543212',
  'contact_type': 'consumer',
  'type': 'phone_call',
  'status': 'pending',
  'scheduled_date': scheduledDate,
  'assigned_to': assignedTo,
};

Map<String, dynamic> stageJson({
  required String id,
  required String label,
  required int orderIndex,
}) => {'id': id, 'label': label, 'order_index': orderIndex};

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
