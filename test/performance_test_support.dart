import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ogera_crm_mobile/core/network/api_client.dart';
import 'package:ogera_crm_mobile/models/auth_session.dart';
import 'package:ogera_crm_mobile/services/crm_services.dart';
import 'package:ogera_crm_mobile/services/location_api_service.dart';
import 'package:ogera_crm_mobile/services/location_tracking_service.dart';
import 'package:ogera_crm_mobile/theme/app_theme.dart';
import 'package:ogera_crm_mobile/view_models/session_view_model.dart';
import 'package:provider/provider.dart';

import 'test_helpers.dart';

/// Shared plumbing for the Performance tests (unit, widget and flow): a fake
/// server, response builders, a signed-in session and the app-level providers.

typedef ServerHandler = FutureOr<http.Response> Function(http.Request request);

http.Response jsonOk(dynamic data) => http.Response(jsonEncode(data), 200);

/// FastAPI's error body: `{ "detail": message }`. [code] is only a label for
/// the test's own readability.
http.Response jsonError(int status, String code, String message) =>
    http.Response(jsonEncode({'detail': message}), status);

/// What a proxy answers for a route that is not deployed: an HTML page, not JSON.
http.Response htmlNotFound() =>
    http.Response('<!DOCTYPE html><html><body>404</body></html>', 404);

/// An [ApiClient] whose fake server is [handler]. Throw a `SocketException` from
/// the handler to simulate a dead connection.
ApiClient apiFor(ServerHandler handler) {
  return ApiClient(
    baseUrl: 'https://crm.test',
    client: MockClient((request) async => handler(request)),
  )..setAccessToken('test-token');
}

Map<String, dynamic> staffPerfJson(
  int id,
  String name, {
  required int leads,
  required int awareness,
}) => {
  'id': id,
  'name': name,
  'leads': leads,
  'awareness': awareness,
  'total': leads + awareness,
};

/// The body of `GET /performance`.
Map<String, dynamic> perfJson({
  required List<Map<String, dynamic>> staff,
  int unattributedLeads = 0,
  int unattributedAwareness = 0,
  String scope = 'team',
}) {
  final leads = staff.fold<int>(0, (sum, s) => sum + (s['leads'] as int));
  final awareness = staff.fold<int>(
    0,
    (sum, s) => sum + (s['awareness'] as int),
  );
  return {
    'range': {'startDate': '2000-01-01', 'endDate': '2026-09-19'},
    'scope': scope,
    'totals': {'leads': leads, 'awareness': awareness},
    'unattributed': {
      'leads': unattributedLeads,
      'awareness': unattributedAwareness,
    },
    'staff': staff,
  };
}

/// The body of `GET /contacts` for a page of [contacts].
Map<String, dynamic> contactPageJson(
  List<Map<String, dynamic>> contacts, {
  int? total,
  int page = 1,
  int limit = 20,
}) => {
  'items': contacts,
  'total': total ?? contacts.length,
  'skip': (page - 1) * limit,
  'limit': limit,
};

Future<SessionViewModel> sessionFor(UserRole role) async {
  final api = fakeApiClient({});
  final session = SessionViewModel(
    auth: FakeAuthService(),
    api: api,
    tracking: LocationTrackingService(
      LocationApiService(api),
      NoopLocationQueue(),
    ),
  );
  await session.adopt(
    AuthSession(
      accessToken: 'token',
      user: AuthUser(
        id: role.isHead ? 1 : 2,
        email: role.isHead ? 'head@ogera.com' : 'staff@ogera.com',
        name: role.isHead ? 'Head User' : 'Staff User',
        phone: null,
        role: role,
      ),
    ),
  );
  return session;
}

/// The providers sit above [MaterialApp], exactly as in `main.dart`, so a pushed
/// route (Performance -> a staff member's contacts) can still reach them.
Widget performanceHarness({
  required ApiClient api,
  required SessionViewModel session,
  required Widget home,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<SessionViewModel>.value(value: session),
      Provider<PerformanceService>.value(value: PerformanceService(api)),
      Provider<ContactsService>.value(value: ContactsService(api)),
    ],
    child: MaterialApp(theme: AppTheme.build(), home: home),
  );
}
