import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';
import 'package:ogera_crm_mobile/models/auth_session.dart';
import 'package:ogera_crm_mobile/views/performance/staff_contacts_screen.dart';

import 'performance_test_support.dart';
import 'test_helpers.dart';

/// The per-staff contact list opened from Performance: the request it sends, the
/// Lead/Awareness filter, paging, and the empty / error / load-more-failure states.
void main() {
  setUpAll(() {
    GeolocatorPlatform.instance = NoLocationServicePlatform();
  });

  final range = DateTimeRange(
    start: DateTime(2026, 8, 1),
    end: DateTime(2026, 8, 31),
  );

  Future<void> pumpScreen(
    WidgetTester tester,
    ServerHandler handler, {
    String staffId = '7',
    String name = 'Shiju',
  }) async {
    final session = await sessionFor(UserRole.salesHead);
    addTearDown(() => session.tracking.dispose());
    await tester.pumpWidget(
      performanceHarness(
        api: apiFor(handler),
        session: session,
        home: StaffContactsScreen(staffId: staffId, name: name, range: range),
      ),
    );
  }

  List<Map<String, dynamic>> contacts(
    int count, {
    int from = 1,
    String type = 'lead',
  }) => [
    for (var i = from; i < from + count; i++)
      contactJson(
        id: i,
        name: 'Contact ${i.toString().padLeft(2, '0')}',
        type: type,
      ),
  ];

  Finder listScrollable() => find.descendant(
    of: find.byType(RefreshIndicator),
    matching: find.byType(Scrollable),
  );

  testWidgets('shows a centred spinner with text while the first page loads', (
    tester,
  ) async {
    final gate = Completer<void>();
    await pumpScreen(tester, (_) async {
      await gate.future;
      return jsonOk(contactPageJson(contacts(2)));
    });
    await tester.pump();

    expect(find.text('Loading contacts…'), findsOneWidget);
    expect(find.text('Loading…'), findsOneWidget); // the count line

    gate.complete();
    await tester.pumpAndSettle();
    expect(find.text('Loading contacts…'), findsNothing);
  });

  testWidgets('asks for this staff member, in this range, page 1', (
    tester,
  ) async {
    final requests = <Uri>[];
    await pumpScreen(tester, (request) {
      requests.add(request.url);
      return jsonOk(contactPageJson(contacts(3)));
    });
    await tester.pumpAndSettle();

    expect(requests, hasLength(1));
    final query = requests.single.queryParameters;
    expect(requests.single.path, '/contacts');
    expect(query['created_by'], '7');
    expect(query['created_from'], '2026-08-01');
    expect(query['created_to'], '2026-08-31');
    expect(query['skip'], '0');
    expect(query.containsKey('awareness_mode'), isFalse);
  });

  testWidgets('shows the name, the count and the contacts', (tester) async {
    await pumpScreen(tester, (_) => jsonOk(contactPageJson(contacts(3))));
    await tester.pumpAndSettle();

    expect(find.text('Shiju'), findsOneWidget); // app bar
    expect(find.text('3 contacts added'), findsOneWidget);
    expect(find.text('Contact 01'), findsOneWidget);
    expect(find.text('Contact 03'), findsOneWidget);
  });

  testWidgets('uses the singular for a single contact', (tester) async {
    await pumpScreen(tester, (_) => jsonOk(contactPageJson(contacts(1))));
    await tester.pumpAndSettle();

    expect(find.text('1 contact added'), findsOneWidget);
  });

  testWidgets('the count is the server total, not just the loaded page', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      (_) => jsonOk(contactPageJson(contacts(2), total: 91)),
    );
    await tester.pumpAndSettle();

    expect(find.text('91 contacts added'), findsOneWidget);
  });

  testWidgets('the unattributed bucket is requested as unattributed=true', (
    tester,
  ) async {
    late Uri url;
    await pumpScreen(
      tester,
      (request) {
        url = request.url;
        return jsonOk(contactPageJson(contacts(1, type: 'awareness')));
      },
      staffId: 'unattributed',
      name: 'Unattributed',
    );
    await tester.pumpAndSettle();

    expect(url.queryParameters['unattributed'], 'true');
    expect(find.text('Unattributed'), findsOneWidget);
  });

  group('filter chips', () {
    testWidgets('Lead and Awareness re-fetch with the type', (tester) async {
      final requests = <Uri>[];
      await pumpScreen(tester, (request) {
        requests.add(request.url);
        final mode = request.url.queryParameters['awareness_mode'];
        return jsonOk(
          contactPageJson(
            mode == '1'
                ? contacts(2, from: 50, type: 'awareness')
                : contacts(3),
          ),
        );
      });
      await tester.pumpAndSettle();

      await tester.tap(find.text('Awareness'));
      await tester.pumpAndSettle();

      expect(requests.last.queryParameters['awareness_mode'], '1');
      expect(requests.last.queryParameters['skip'], '0');
      expect(find.text('Contact 50'), findsOneWidget);
      expect(find.text('Contact 01'), findsNothing);
      expect(find.text('2 contacts added'), findsOneWidget);

      await tester.tap(find.text('Lead'));
      await tester.pumpAndSettle();
      expect(requests.last.queryParameters['awareness_mode'], '0');
      expect(find.text('Contact 01'), findsOneWidget);

      await tester.tap(find.text('All'));
      await tester.pumpAndSettle();
      expect(
        requests.last.queryParameters.containsKey('awareness_mode'),
        isFalse,
      );
    });

    testWidgets('tapping the selected chip does not re-fetch', (tester) async {
      var calls = 0;
      await pumpScreen(tester, (_) {
        calls++;
        return jsonOk(contactPageJson(contacts(2)));
      });
      await tester.pumpAndSettle();

      await tester.tap(find.text('All'));
      await tester.pumpAndSettle();

      expect(calls, 1);
    });
  });

  group('empty and failures', () {
    testWidgets('an empty result shows the empty state', (tester) async {
      await pumpScreen(tester, (_) => jsonOk(contactPageJson(const [])));
      await tester.pumpAndSettle();

      expect(find.text('No contacts'), findsOneWidget);
      expect(find.text('0 contacts added'), findsOneWidget);
    });

    testWidgets('offline shows No connection and Try again recovers', (
      tester,
    ) async {
      var online = false;
      await pumpScreen(tester, (_) {
        if (!online) throw const SocketException('unreachable');
        return jsonOk(contactPageJson(contacts(2)));
      });
      await tester.pumpAndSettle();

      expect(find.text('No connection'), findsOneWidget);

      online = true;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(find.text('Contact 01'), findsOneWidget);
    });

    testWidgets('a server error shows the message', (tester) async {
      await pumpScreen(
        tester,
        (_) => jsonError(500, 'SERVER_ERROR', 'Unable to load contacts'),
      );
      await tester.pumpAndSettle();

      expect(find.text('Something went wrong'), findsOneWidget);
      expect(find.text('Unable to load contacts'), findsOneWidget);
    });
  });

  group('paging', () {
    testWidgets('scrolling near the end loads the next page and appends it', (
      tester,
    ) async {
      final requests = <Uri>[];
      await pumpScreen(tester, (request) {
        requests.add(request.url);
        final page = int.parse(request.url.queryParameters['skip']!) ~/ 20 + 1;
        return jsonOk(
          contactPageJson(
            contacts(12, from: page == 1 ? 1 : 13),
            total: 24,
            page: page,
          ),
        );
      });
      await tester.pumpAndSettle();
      expect(requests, hasLength(1));

      await tester.drag(listScrollable(), const Offset(0, -1500));
      await tester.pumpAndSettle();

      expect(requests.map((r) => r.queryParameters['skip']), ['0', '20']);
      await tester.scrollUntilVisible(
        find.text('Contact 24'),
        400,
        scrollable: listScrollable(),
      );
      expect(find.text('Contact 24'), findsOneWidget);
    });

    testWidgets('does not ask for a page beyond the last', (tester) async {
      var calls = 0;
      await pumpScreen(tester, (_) {
        calls++;
        return jsonOk(contactPageJson(contacts(12), total: 12));
      });
      await tester.pumpAndSettle();

      await tester.drag(listScrollable(), const Offset(0, -1500));
      await tester.pumpAndSettle();

      expect(calls, 1);
    });

    testWidgets('a failed next page keeps the list and offers Retry', (
      tester,
    ) async {
      var page2Online = false;
      await pumpScreen(tester, (request) {
        final page = int.parse(request.url.queryParameters['skip']!) ~/ 20 + 1;
        if (page == 2 && !page2Online) throw const SocketException('dropped');
        return jsonOk(
          contactPageJson(
            contacts(12, from: page == 1 ? 1 : 13),
            total: 24,
            page: page,
          ),
        );
      });
      await tester.pumpAndSettle();

      await tester.drag(listScrollable(), const Offset(0, -1500));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text("You're offline. Showing the last loaded data."),
        400,
        scrollable: listScrollable(),
      );

      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('Contact 12'), findsOneWidget); // earlier rows kept

      page2Online = true;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Contact 24'),
        400,
        scrollable: listScrollable(),
      );

      expect(find.text('Contact 24'), findsOneWidget);
      expect(find.text('Retry'), findsNothing);
    });
  });
}
