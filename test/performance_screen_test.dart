import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';
import 'package:ogera_crm_mobile/core/utils/formatters.dart';
import 'package:ogera_crm_mobile/models/auth_session.dart';
import 'package:ogera_crm_mobile/views/performance/performance_screen.dart';

import 'performance_test_support.dart';
import 'test_helpers.dart';

/// The Performance screen: every state it can be in (loading, data, empty,
/// offline, server error, no access, refresh failure) and the role difference
/// between a Head (team) and a Staff member (own numbers only).
void main() {
  setUpAll(() {
    GeolocatorPlatform.instance = NoLocationServicePlatform();
  });

  final teamReport = perfJson(
    staff: [
      staffPerfJson(7, 'Shiju', leads: 91, awareness: 4),
      staffPerfJson(1, 'Admin', leads: 58, awareness: 3),
    ],
    unattributedLeads: 42,
    unattributedAwareness: 127,
  );

  Future<void> pumpScreen(
    WidgetTester tester,
    ServerHandler handler, {
    UserRole role = UserRole.salesHead,
  }) async {
    final session = await sessionFor(role);
    addTearDown(() => session.tracking.dispose());
    await tester.pumpWidget(
      performanceHarness(
        api: apiFor(handler),
        session: session,
        home: const PerformanceScreen(),
      ),
    );
  }

  group('loading', () {
    testWidgets('shows a centred spinner with text until the data arrives', (
      tester,
    ) async {
      final gate = Completer<void>();
      await pumpScreen(tester, (_) async {
        await gate.future;
        return jsonOk(teamReport);
      });
      await tester.pump();

      expect(find.text('Loading performance…'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Shiju'), findsNothing);

      gate.complete();
      await tester.pumpAndSettle();

      expect(find.text('Loading performance…'), findsNothing);
      expect(find.text('Shiju'), findsOneWidget);
    });
  });

  group('Head (team view)', () {
    testWidgets('shows totals, the team ranked in server order, and the note', (
      tester,
    ) async {
      await pumpScreen(tester, (_) => jsonOk(teamReport));
      await tester.pumpAndSettle();

      expect(find.text('Performance'), findsOneWidget);

      // Stat cards: 91 + 58 leads, 4 + 3 awareness.
      expect(find.text('Leads added'), findsOneWidget);
      expect(find.text('149'), findsOneWidget);
      expect(find.text('Awareness added'), findsOneWidget);
      expect(find.text('7'), findsOneWidget);

      expect(find.text('TEAM'), findsOneWidget);
      expect(find.text('91 leads'), findsOneWidget);
      expect(find.text('4 awareness'), findsOneWidget);
      expect(find.text('95'), findsOneWidget);
      expect(find.text('61'), findsOneWidget);

      // Ranking is the server's order.
      expect(
        tester.getTopLeft(find.text('Shiju')).dy,
        lessThan(tester.getTopLeft(find.text('Admin')).dy),
      );

      expect(
        find.textContaining('42 leads and 127 awareness records'),
        findsOneWidget,
      );
    });

    testWidgets('defaults to All time, starting from 2000-01-01', (
      tester,
    ) async {
      final requests = <Uri>[];
      await pumpScreen(tester, (request) {
        requests.add(request.url);
        return jsonOk(teamReport);
      });
      await tester.pumpAndSettle();

      expect(find.text('All time'), findsOneWidget);
      expect(find.text('All records to date'), findsOneWidget);
      expect(requests.single.path, '/performance');
      expect(requests.single.queryParameters['start_date'], '2000-01-01');
      expect(requests.single.queryParameters['end_date'], todayIso());
    });

    testWidgets('choosing Today re-fetches for a single day', (tester) async {
      final requests = <Uri>[];
      await pumpScreen(tester, (request) {
        requests.add(request.url);
        return jsonOk(teamReport);
      });
      await tester.pumpAndSettle();

      await tester.tap(find.text('Today'));
      await tester.pumpAndSettle();

      expect(requests, hasLength(2));
      expect(requests.last.queryParameters['start_date'], todayIso());
      expect(requests.last.queryParameters['end_date'], todayIso());
    });

    testWidgets('This month starts on the first of the month', (tester) async {
      final requests = <Uri>[];
      await pumpScreen(tester, (request) {
        requests.add(request.url);
        return jsonOk(teamReport);
      });
      await tester.pumpAndSettle();

      await tester.tap(find.text('This month'));
      await tester.pumpAndSettle();

      final now = DateTime.now();
      expect(
        requests.last.queryParameters['start_date'],
        isoDate(DateTime(now.year, now.month, 1)),
      );
    });

    testWidgets('an empty team shows the empty state', (tester) async {
      await pumpScreen(tester, (_) => jsonOk(perfJson(staff: const [])));
      await tester.pumpAndSettle();

      expect(find.text('No activity'), findsOneWidget);
      expect(
        find.text('Nothing was added in this date range.'),
        findsOneWidget,
      );
    });

    testWidgets('no unattributed note when every record has an owner', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        (_) => jsonOk(
          perfJson(staff: [staffPerfJson(7, 'Shiju', leads: 1, awareness: 0)]),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('no creator'), findsNothing);
    });
  });

  group('Staff (own numbers only)', () {
    testWidgets('sees My performance and no team section', (tester) async {
      await pumpScreen(
        tester,
        (_) => jsonOk(
          perfJson(
            scope: 'self',
            staff: [staffPerfJson(2, 'Staff User', leads: 12, awareness: 5)],
            unattributedLeads: 42, // the server never sends this to staff
          ),
        ),
        role: UserRole.salesStaff,
      );
      await tester.pumpAndSettle();

      expect(find.text('My performance'), findsOneWidget);
      expect(find.text('Staff User'), findsOneWidget);
      expect(find.text('12 leads'), findsOneWidget);
      expect(find.text('TEAM'), findsNothing);
      expect(find.textContaining('no creator'), findsNothing);
    });
  });

  group('failures', () {
    testWidgets('offline shows No connection and Try again recovers', (
      tester,
    ) async {
      var online = false;
      await pumpScreen(tester, (_) {
        if (!online) throw const SocketException('unreachable');
        return jsonOk(teamReport);
      });
      await tester.pumpAndSettle();

      expect(find.text('No connection'), findsOneWidget);
      expect(find.byIcon(Icons.wifi_off_rounded), findsOneWidget);
      expect(find.text('Shiju'), findsNothing);

      online = true;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(find.text('No connection'), findsNothing);
      expect(find.text('Shiju'), findsOneWidget);
    });

    testWidgets('a server error shows the server message', (tester) async {
      await pumpScreen(
        tester,
        (_) => jsonError(500, 'SERVER_ERROR', 'Unable to load performance'),
      );
      await tester.pumpAndSettle();

      expect(find.text('Something went wrong'), findsOneWidget);
      expect(find.text('Unable to load performance'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    });

    testWidgets('a route missing on the server reads as Not found', (
      tester,
    ) async {
      await pumpScreen(tester, (_) => htmlNotFound());
      await tester.pumpAndSettle();

      expect(find.text('Not found'), findsOneWidget);
    });

    testWidgets('no access offers no retry', (tester) async {
      await pumpScreen(
        tester,
        (_) => jsonError(403, 'FORBIDDEN', 'You do not have access'),
      );
      await tester.pumpAndSettle();

      expect(find.text('No access'), findsOneWidget);
      expect(find.text('Try again'), findsNothing);
    });

    testWidgets('a failed refresh keeps the data and shows a retry banner', (
      tester,
    ) async {
      var calls = 0;
      await pumpScreen(tester, (_) {
        calls++;
        if (calls > 1) throw const SocketException('dropped');
        return jsonOk(teamReport);
      });
      await tester.pumpAndSettle();
      expect(find.text('Shiju'), findsOneWidget);

      await tester.tap(find.text('Today'));
      await tester.pumpAndSettle();

      // Old numbers stay; a banner explains and offers Retry.
      expect(find.text('Shiju'), findsOneWidget);
      expect(find.text('149'), findsOneWidget);
      expect(
        find.text("You're offline. Showing the last loaded data."),
        findsOneWidget,
      );
      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('No connection'), findsNothing);
    });

    testWidgets('Retry on the banner reloads and clears it', (tester) async {
      var online = true;
      await pumpScreen(tester, (_) {
        if (!online) throw const SocketException('dropped');
        return jsonOk(teamReport);
      });
      await tester.pumpAndSettle();

      online = false;
      await tester.tap(find.text('Today'));
      await tester.pumpAndSettle();
      expect(find.text('Retry'), findsOneWidget);

      online = true;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.text('Retry'), findsNothing);
      expect(find.text('Shiju'), findsOneWidget);
    });

    testWidgets('a refresh shows a thin progress bar over the old data', (
      tester,
    ) async {
      var calls = 0;
      final gate = Completer<void>();
      await pumpScreen(tester, (_) async {
        calls++;
        if (calls > 1) await gate.future;
        return jsonOk(teamReport);
      });
      await tester.pumpAndSettle();

      await tester.tap(find.text('Today'));
      await tester.pump();

      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.text('Shiju'), findsOneWidget); // not blanked

      gate.complete();
      await tester.pumpAndSettle();
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });
  });
}
