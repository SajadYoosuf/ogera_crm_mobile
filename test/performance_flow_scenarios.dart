import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ogera_crm_mobile/core/network/api_client.dart';
import 'package:ogera_crm_mobile/core/utils/formatters.dart';
import 'package:ogera_crm_mobile/models/auth_session.dart';
import 'package:ogera_crm_mobile/services/crm_services.dart';
import 'package:ogera_crm_mobile/services/location_api_service.dart';
import 'package:ogera_crm_mobile/services/location_tracking_service.dart';
import 'package:ogera_crm_mobile/theme/app_theme.dart';
import 'package:ogera_crm_mobile/view_models/session_view_model.dart';
import 'package:ogera_crm_mobile/views/performance/performance_screen.dart';
import 'package:provider/provider.dart';

import 'test_helpers.dart';

/// End to end through the real layers: screens -> view state -> services ->
/// [ApiClient] -> HTTP. Only the server is faked, and it is a small stateful one
/// that answers `/performance` and `/contacts` from ONE dataset, so the
/// two endpoints can only agree if the app asks each of them the right question.
///
/// Shared by `test/performance_flow_test.dart` (runs on the VM with the normal
/// test runner) and `integration_test/performance_flow_test.dart` (runs on a
/// device or emulator).
///
/// Flow: Head opens Performance -> sees the ranked team -> taps a person -> sees
/// exactly the contacts the report counted for them -> filters -> goes back and
/// changes the date range.
void definePerformanceFlowTests() {
  setUpAll(() {
    GeolocatorPlatform.instance = NoLocationServicePlatform();
  });

  final today = DateTime.now();
  String daysAgo(int days) =>
      today.subtract(Duration(days: days)).toUtc().toIso8601String();

  // (id, name, type, addedBy, createdAt). Owners: 7 = Shiju, 1 = Admin, null = none.
  final dataset = <_Row>[
    _Row(1, 'Lead A1', 'lead', '7', daysAgo(0)),
    _Row(2, 'Lead A2', 'lead', '7', daysAgo(0)),
    _Row(3, 'Lead A3', 'lead', '7', daysAgo(40)),
    _Row(4, 'Aware A4', 'awareness', '7', daysAgo(40)),
    _Row(5, 'Lead B1', 'lead', '1', daysAgo(0)),
    _Row(6, 'Old Lead', 'lead', null, daysAgo(60)),
    _Row(7, 'Old Aware', 'awareness', null, daysAgo(60)),
  ];
  const staffNames = {7: 'Shiju', 1: 'Admin'};

  late List<Uri> requests;

  http.Response handle(http.Request request) {
    requests.add(request.url);
    final query = request.url.queryParameters;
    final startText = query['start_date'] ?? query['created_from'];
    final endText = query['end_date'] ?? query['created_to'];
    final start = startText == null
        ? null
        : DateTime.parse('${startText}T00:00:00');
    final end = endText == null ? null : DateTime.parse('${endText}T23:59:59');
    bool inRange(_Row r) {
      final created = DateTime.parse(r.createdAt).toLocal();
      return (start == null || !created.isBefore(start)) &&
          (end == null || !created.isAfter(end));
    }

    if (request.url.path == '/performance') {
      final rows = dataset.where(inRange).toList();
      final staff = [
        for (final entry in staffNames.entries)
          () {
            final mine = rows.where((r) => r.addedBy == '${entry.key}');
            final leads = mine.where((r) => r.type == 'lead').length;
            final aware = mine.where((r) => r.type == 'awareness').length;
            return {
              'id': entry.key,
              'name': entry.value,
              'leads': leads,
              'awareness': aware,
              'total': leads + aware,
            };
          }(),
      ]..sort((a, b) => (b['total'] as int).compareTo(a['total'] as int));
      final orphans = rows.where((r) => r.addedBy == null);
      return http.Response(
        jsonEncode({
          'scope': 'team',
          'totals': {
            'leads': staff.fold<int>(0, (s, m) => s + (m['leads'] as int)),
            'awareness': staff.fold<int>(
              0,
              (s, m) => s + (m['awareness'] as int),
            ),
          },
          'unattributed': {
            'leads': orphans.where((r) => r.type == 'lead').length,
            'awareness': orphans.where((r) => r.type == 'awareness').length,
          },
          'staff': staff,
        }),
        200,
      );
    }

    if (request.url.path == '/contacts') {
      final createdBy = query['created_by'];
      final unattributed = query['unattributed'] == 'true';
      final mode = query['awareness_mode'];
      final rows = dataset.where(inRange).where((r) {
        final owner = unattributed ? r.addedBy == null : r.addedBy == createdBy;
        final kind = mode == null || (mode == '1') == (r.type == 'awareness');
        return owner && kind;
      }).toList();
      return http.Response(
        jsonEncode(
          pageOf([
            for (final r in rows)
              contactJson(
                id: r.id,
                name: r.name,
                type: r.type,
                createdAt: r.createdAt,
              ),
          ]),
        ),
        200,
      );
    }
    return http.Response('not found', 404);
  }

  testWidgets(
    'Head: team leaderboard -> a person\'s contacts -> filter -> back -> new range',
    (tester) async {
      requests = [];
      final api = ApiClient(
        baseUrl: 'https://crm.test',
        client: MockClient((request) async => handle(request)),
      )..setAccessToken('test-token');
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
            id: 1,
            email: 'head@ogera.com',
            name: 'Head User',
            phone: null,
            role: UserRole.salesHead,
          ),
        ),
      );
      addTearDown(() => session.tracking.dispose());

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<SessionViewModel>.value(value: session),
            Provider<PerformanceService>.value(value: PerformanceService(api)),
            Provider<ContactsService>.value(value: ContactsService(api)),
          ],
          child: MaterialApp(
            theme: AppTheme.build(),
            home: const PerformanceScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. The leaderboard, ranked by total: Shiju (4) above Admin (1).
      expect(find.text('Performance'), findsOneWidget);
      expect(find.text('3 leads'), findsOneWidget); // Shiju
      expect(find.text('1 awareness'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Shiju')).dy,
        lessThan(tester.getTopLeft(find.text('Admin')).dy),
      );
      expect(
        find.textContaining('1 leads and 1 awareness records'),
        findsOneWidget,
      );

      // 2. Tapping Shiju opens exactly the contacts the report counted.
      await tester.tap(find.text('Shiju'));
      await tester.pumpAndSettle();

      final contactsRequest = requests.lastWhere((u) => u.path == '/contacts');
      expect(contactsRequest.queryParameters['created_by'], '7');
      expect(contactsRequest.queryParameters['created_from'], '2000-01-01');
      expect(
        find.text('4 contacts added'),
        findsOneWidget,
      ); // 3 leads + 1 awareness
      expect(find.text('Lead A1'), findsOneWidget);
      expect(find.text('Aware A4'), findsOneWidget);
      expect(find.text('Lead B1'), findsNothing); // Admin's, not Shiju's
      expect(find.text('Old Lead'), findsNothing); // unattributed

      // 3. Filtering to Awareness narrows the same list.
      // The chip bar is above the list, so the chip is the first match (each
      // awareness contact card also carries an "Awareness" badge).
      await tester.tap(find.text('Awareness').first);
      await tester.pumpAndSettle();
      expect(find.text('1 contact added'), findsOneWidget);
      expect(find.text('Aware A4'), findsOneWidget);
      expect(find.text('Lead A1'), findsNothing);

      // 4. Back to the report; Today changes the numbers (2 of Shiju's 4).
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Today'));
      await tester.pumpAndSettle();

      final last = requests.lastWhere((u) => u.path == '/performance');
      expect(last.queryParameters['start_date'], todayIso());
      expect(last.queryParameters['end_date'], todayIso());
      expect(find.text('2 leads'), findsOneWidget); // Shiju today
      expect(find.text('0 awareness'), findsWidgets);
      expect(
        find.textContaining('no creator'),
        findsNothing,
      ); // orphans are 60d old

      // 5. The unattributed bucket is reachable from the All time note.
      await tester.tap(find.text('All time'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('no creator'));
      await tester.pumpAndSettle();
      expect(
        requests
            .lastWhere((u) => u.path == '/contacts')
            .queryParameters['unattributed'],
        'true',
      );
      expect(find.text('2 contacts added'), findsOneWidget);
      expect(find.text('Old Lead'), findsOneWidget);
      expect(find.text('Old Aware'), findsOneWidget);
    },
  );
}

class _Row {
  const _Row(this.id, this.name, this.type, this.addedBy, this.createdAt);

  final int id;
  final String name;
  final String type;
  final String? addedBy;
  final String createdAt;
}
