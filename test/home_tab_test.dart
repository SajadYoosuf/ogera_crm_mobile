import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ogera_crm_mobile/core/utils/formatters.dart';
import 'package:ogera_crm_mobile/models/auth_session.dart';
import 'package:ogera_crm_mobile/services/crm_services.dart';
import 'package:ogera_crm_mobile/theme/app_theme.dart';
import 'package:ogera_crm_mobile/view_models/contacts_view_model.dart';
import 'package:ogera_crm_mobile/view_models/followups_view_model.dart';
import 'package:ogera_crm_mobile/view_models/session_view_model.dart';
import 'package:ogera_crm_mobile/views/home/home_tab.dart';
import 'package:provider/provider.dart';

import 'test_helpers.dart';

/// The Home module renders one of two dashboards depending on role: the Head
/// gets a team overview, Staff get their own day's queue.
void main() {
  testWidgets('Head sees the team overview with pipeline and recent contacts', (
    tester,
  ) async {
    final api = fakeApiClient({
      '/contacts': (uri) {
        final mode = uri.queryParameters['awareness_mode'];
        final all = [
          contactJson(id: 1, name: 'Amina Lead'),
          contactJson(id: 2, name: 'Bala Awareness', type: 'awareness'),
        ];
        // The tab badges ask for one kind at a time; the totals are the
        // server's, not the length of the rows shown.
        final totals = {'0': 3, '1': 2};
        final rows = all
            .where((c) => mode == null || '${c['awareness_mode']}' == mode)
            .toList();
        return pageOf(rows, total: totals[mode] ?? rows.length);
      },
      '/tasks': (_) => {
        'items': <Map<String, dynamic>>[],
        'total': 0,
        'summary': {'overdue': 0, 'today': 0, 'upcoming': 0, 'done': 0},
      },
      '/contacts/stage-types': (_) => [
        stageJson(id: 'new', label: 'New', orderIndex: 0),
        stageJson(id: 'won', label: 'Won', orderIndex: 1),
      ],
      '/employees/directory': (_) => <Map<String, dynamic>>[],
    });

    final headUser = const AuthUser(
      id: 1,
      email: 'head@ogera.com',
      name: 'Head User',
      phone: null,
      role: UserRole.salesHead,
    );

    final contacts = ContactsViewModel(ContactsService(api));
    final followups = FollowupsViewModel(
      FollowupsService(api),
      StaffDirectoryService(api),
      headUser,
    );
    await Future.wait([contacts.load(), followups.load()]);

    final session = SessionViewModel(
      auth: FakeAuthService(),
      api: api,
    );
    await session.adopt(AuthSession(accessToken: 'token', user: headUser));

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SessionViewModel>.value(value: session),
          ChangeNotifierProvider<ContactsViewModel>.value(value: contacts),
          ChangeNotifierProvider<FollowupsViewModel>.value(value: followups),
        ],
        child: MaterialApp(
          theme: AppTheme.build(),
          home: const Scaffold(body: HomeTab()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Overview'), findsOneWidget);
    expect(find.text('Manager'), findsOneWidget);

    expect(find.text('Leads'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('Awareness'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);

    // Everything below the metric grid sits below the fold at the default
    // test viewport, so each section is scrolled into view in turn.
    // SectionHeader renders its title upper-cased.
    await _scrollUntilVisible(tester, find.text('PIPELINE'));
    expect(find.text('PIPELINE'), findsOneWidget);
    expect(find.text('New'), findsOneWidget);

    await _scrollUntilVisible(tester, find.text('Amina Lead'));
    // The recent list shows the Leads tab; the awareness contact only counts
    // towards the Awareness metric.
    expect(find.text('Amina Lead'), findsOneWidget);
  });

  testWidgets('Staff see their own overdue, due-today, and upcoming queue', (
    tester,
  ) async {
    final now = DateTime.now();
    final yesterday = isoDate(now.subtract(const Duration(days: 1)));
    final today = isoDate(now);
    final nextWeek = isoDate(now.add(const Duration(days: 7)));

    final api = fakeApiClient({
      '/contacts': (_) => pageOf([
        leadJson(id: 1, name: 'Overdue Lead', stage: 'new', assignedTo: 2),
        leadJson(id: 2, name: 'Due Today Lead', stage: 'new', assignedTo: 2),
        leadJson(id: 3, name: 'Upcoming Lead', stage: 'new', assignedTo: 2),
      ]),
      // A lead's due date is the earliest open follow-up booked on it.
      '/tasks': (_) => {
        'items': [
          taskJson(
            id: 10,
            contactId: 1,
            scheduledDate: yesterday,
            assignedTo: 2,
          ),
          taskJson(id: 11, contactId: 2, scheduledDate: today, assignedTo: 2),
          taskJson(
            id: 12,
            contactId: 3,
            scheduledDate: nextWeek,
            assignedTo: 2,
          ),
        ],
        'total': 3,
        'summary': {'overdue': 1, 'today': 1, 'upcoming': 1, 'done': 0},
      },
      '/contacts/stage-types': (_) => [
        stageJson(id: 'new', label: 'New', orderIndex: 0),
      ],
      '/employees/directory': (_) => <Map<String, dynamic>>[],
    });

    final staffUser = const AuthUser(
      id: 2,
      email: 'staff@ogera.com',
      name: 'Staff User',
      phone: null,
      role: UserRole.salesStaff,
    );

    final followups = FollowupsViewModel(
      FollowupsService(api),
      StaffDirectoryService(api),
      staffUser,
    );
    await followups.load();

    final session = SessionViewModel(
      auth: FakeAuthService(),
      api: api,
    );
    await session.adopt(AuthSession(accessToken: 'token', user: staffUser));

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SessionViewModel>.value(value: session),
          ChangeNotifierProvider<FollowupsViewModel>.value(value: followups),
        ],
        child: MaterialApp(
          theme: AppTheme.build(),
          home: const Scaffold(body: HomeTab()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('My day'), findsOneWidget);
    expect(find.text('Sales Staff'), findsOneWidget);

    expect(find.text('Overdue'), findsOneWidget);
    expect(find.text('Due today'), findsOneWidget);
    expect(find.text('Upcoming'), findsOneWidget);
    expect(find.text('Assigned'), findsOneWidget);
    expect(find.text('3'), findsOneWidget); // Assigned metric == all 3 leads.

    // "Needs attention" sits below the fold at the default test viewport.
    await _scrollUntilVisible(tester, find.text('Overdue Lead'));
    expect(find.text('Overdue Lead'), findsOneWidget);

    await _scrollUntilVisible(tester, find.text('Due Today Lead'));
    expect(find.text('Due Today Lead'), findsOneWidget);
  });
}

/// `dragUntilVisible` throws if the target never appears within its own
/// iteration budget, which is pickier than this dashboard's plain, single
/// `ListView` needs — a few manual drags are enough to bring any section
/// into view.
Future<void> _scrollUntilVisible(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 10 && finder.evaluate().isEmpty; i++) {
    await tester.drag(find.byType(ListView).first, const Offset(0, -300));
    await tester.pump(const Duration(milliseconds: 100));
  }
}
