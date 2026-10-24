import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ogera_crm_mobile/core/network/api_client.dart';
import 'package:ogera_crm_mobile/core/utils/formatters.dart';
import 'package:ogera_crm_mobile/models/auth_session.dart';
import 'package:ogera_crm_mobile/services/crm_services.dart';
import 'package:ogera_crm_mobile/services/home_service.dart';
import 'package:ogera_crm_mobile/theme/app_theme.dart';
import 'package:ogera_crm_mobile/services/notification_service.dart';
import 'package:ogera_crm_mobile/view_models/followups_view_model.dart';
import 'package:ogera_crm_mobile/view_models/home_view_model.dart';
import 'package:ogera_crm_mobile/view_models/notification_view_model.dart';
import 'package:ogera_crm_mobile/view_models/session_view_model.dart';
import 'package:ogera_crm_mobile/views/home/home_tab.dart';
import 'package:provider/provider.dart';

import 'test_helpers.dart';

/// The Home tab shows the same layout to every role: a greeting, the check-in
/// card, the KPI tiles for the chosen range, and the follow-ups that need
/// attention today.
void main() {
  testWidgets('Head sees the greeting, check-in card and KPI tiles', (
    tester,
  ) async {
    final api = _api(contacts: [contactJson(id: 1, name: 'Amina Lead')]);
    final headUser = const AuthUser(
      id: 1,
      email: 'head@ogera.com',
      name: 'Head User',
      phone: null,
      role: UserRole.salesHead,
    );

    await _pumpHome(tester, api: api, user: headUser);

    expect(find.text('Manager'), findsOneWidget);
    expect(find.text('Not checked in'), findsOneWidget);
    expect(find.text('Check in'), findsOneWidget);
    expect(find.text('New leads'), findsOneWidget);
    expect(find.text('Open follow-ups'), findsOneWidget);
    expect(find.text('Won'), findsOneWidget);
  });

  testWidgets('Staff see their own overdue and due-today queue', (
    tester,
  ) async {
    final now = DateTime.now();
    final yesterday = isoDate(now.subtract(const Duration(days: 1)));
    final today = isoDate(now);
    final nextWeek = isoDate(now.add(const Duration(days: 7)));

    final api = _api(
      contacts: [
        leadJson(id: 1, name: 'Overdue Lead', stage: 'new', assignedTo: 2),
        leadJson(id: 2, name: 'Due Today Lead', stage: 'new', assignedTo: 2),
        leadJson(id: 3, name: 'Upcoming Lead', stage: 'new', assignedTo: 2),
      ],
      // A lead's due date is the earliest open follow-up booked on it.
      tasks: [
        taskJson(id: 10, contactId: 1, scheduledDate: yesterday, assignedTo: 2),
        taskJson(id: 11, contactId: 2, scheduledDate: today, assignedTo: 2),
        taskJson(id: 12, contactId: 3, scheduledDate: nextWeek, assignedTo: 2),
      ],
    );
    final staffUser = const AuthUser(
      id: 2,
      email: 'staff@ogera.com',
      name: 'Staff User',
      phone: null,
      role: UserRole.salesStaff,
    );

    await _pumpHome(tester, api: api, user: staffUser);

    expect(find.text('Sales Staff'), findsOneWidget);
    await _scrollUntilVisible(tester, find.text('Overdue Lead'));
    expect(find.text('Overdue Lead'), findsOneWidget);

    await _scrollUntilVisible(tester, find.text('Due Today Lead'));
    expect(find.text('Due Today Lead'), findsOneWidget);
  });
}

/// Stubs every endpoint the Home tab calls.
ApiClient _api({
  required List<Map<String, dynamic>> contacts,
  List<Map<String, dynamic>> tasks = const [],
}) {
  return fakeApiClient({
    '/contacts': (_) => pageOf(contacts, total: contacts.length),
    '/tasks': (_) => {
      'items': tasks,
      'total': tasks.length,
      'summary': {'overdue': 0, 'today': 0, 'upcoming': 0, 'done': 0},
    },
    '/pipeline/stages': (_) => [
      stageJson(id: 'new', label: 'New', orderIndex: 0),
      stageJson(id: 'won', label: 'Won', orderIndex: 1),
    ],
    '/employees/directory': (_) => <Map<String, dynamic>>[],
    '/dashboard/summary': (_) => {
      'kpis': {
        'total_contacts': contacts.length,
        'new_leads': {'value': 1},
        'open_followups': {'value': 2, 'overdue': 1},
        'won': {'value': 0},
      },
    },
    '/attendance/today': (_) => null,
    '/notifications': (_) => {'items': <Map<String, dynamic>>[], 'unread_count': 0},
  });
}

/// Loads the view models the shell would provide, then pumps the tab.
Future<void> _pumpHome(
  WidgetTester tester, {
  required ApiClient api,
  required AuthUser user,
}) async {
  final followups = FollowupsViewModel(
    FollowupsService(api),
    StaffDirectoryService(api),
    user,
  );
  final home = HomeViewModel(HomeService(api));
  await Future.wait([followups.load(), home.load()]);

  final session = SessionViewModel(auth: FakeAuthService(), api: api);
  await session.adopt(AuthSession(accessToken: 'token', user: user));

  final notifications = NotificationViewModel(NotificationService(api));

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<SessionViewModel>.value(value: session),
        ChangeNotifierProvider<FollowupsViewModel>.value(value: followups),
        ChangeNotifierProvider<HomeViewModel>.value(value: home),
        ChangeNotifierProvider<NotificationViewModel>.value(value: notifications),
      ],
      child: MaterialApp(theme: AppTheme.build(), home: const HomeTab()),
    ),
  );
  await tester.pumpAndSettle();
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
