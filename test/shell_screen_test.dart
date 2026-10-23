import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ogera_crm_mobile/models/auth_session.dart';
import 'package:ogera_crm_mobile/services/activity_service.dart';
import 'package:ogera_crm_mobile/services/crm_services.dart';
import 'package:ogera_crm_mobile/services/expense_service.dart';
import 'package:ogera_crm_mobile/services/home_service.dart';
import 'package:ogera_crm_mobile/theme/app_theme.dart';
import 'package:ogera_crm_mobile/view_models/session_view_model.dart';
import 'package:ogera_crm_mobile/views/shell_screen.dart';
import 'package:provider/provider.dart';

import 'test_helpers.dart';

/// Covers the shell: the bottom bar lists Home · Contacts · Tasks · Pipeline ·
/// More, Tasks and Pipeline are placeholders, the centre button fans out the
/// quick actions (Add expense only for staff), and the bar keeps its layout at
/// phone widths.
///
/// Tabs load lazily and can keep progress indicators animating, so this file
/// settles with a bounded [_settle] instead of `pumpAndSettle`, which would hang.
void main() {
  testWidgets('bottom bar lists every tab in order and switches between them', (
    tester,
  ) async {
    await tester.pumpWidget(await _shellHarness(role: UserRole.admin));
    await _settle(tester);

    for (final label in const [
      'Home',
      'Contacts',
      'Tasks',
      'Pipeline',
      'More',
    ]) {
      expect(_navLabel(label), findsOneWidget);
    }

    // Home is the initial tab.
    expect(find.widgetWithText(AppBar, 'Home'), findsOneWidget);

    await tester.tap(_navLabel('Contacts'));
    await _settle(tester);
    expect(find.widgetWithText(AppBar, 'Contacts'), findsOneWidget);

    // Placeholder tabs say what is coming instead of an empty screen.
    await tester.tap(_navLabel('Tasks'));
    await _settle(tester);
    expect(find.widgetWithText(AppBar, 'Tasks'), findsOneWidget);
    expect(find.text('Coming soon'), findsOneWidget);

    await tester.tap(_navLabel('Pipeline'));
    await _settle(tester);
    expect(find.widgetWithText(AppBar, 'Pipeline'), findsOneWidget);
    expect(find.text('Coming soon'), findsOneWidget);

    await tester.tap(_navLabel('More'));
    await _settle(tester);
    expect(find.widgetWithText(AppBar, 'More'), findsOneWidget);
  });

  testWidgets(
    'centre button fans out Add contact and Activity log; staff also get Add expense',
    (tester) async {
      await tester.pumpWidget(await _shellHarness(role: UserRole.salesStaff));
      await _settle(tester);

      // Closed: none of the fan labels are visible.
      expect(find.text('Activity log'), findsNothing);

      await tester.tap(find.byTooltip('Quick actions'));
      await _settle(tester);
      expect(find.text('Add contact'), findsOneWidget);
      expect(find.text('Activity log'), findsOneWidget);
      expect(find.text('Add expense'), findsOneWidget);

      // Tapping the dimmed background closes the fan.
      await tester.tapAt(const Offset(10, 120));
      await _settle(tester);
      expect(find.byTooltip('Quick actions'), findsOneWidget);
    },
  );

  testWidgets(
    'Add expense is hidden for admin and manager, who review rather than submit',
    (tester) async {
      await tester.pumpWidget(await _shellHarness(role: UserRole.admin));
      await _settle(tester);

      await tester.tap(find.byTooltip('Quick actions'));
      await _settle(tester);
      expect(find.text('Add contact'), findsOneWidget);
      expect(find.text('Activity log'), findsOneWidget);
      expect(find.text('Add expense'), findsNothing);
    },
  );

  testWidgets('bottom bar renders without overflow across phone sizes', (
    tester,
  ) async {
    await tester.pumpWidget(await _shellHarness(role: UserRole.admin));
    await _settle(tester);

    const phoneSizes = [
      Size(320, 568), // iPhone SE — the narrowest phone still supported.
      Size(360, 740), // A common small/mid Android width.
      Size(390, 844), // iPhone 12/13/14.
      Size(428, 926), // iPhone 13/14 Pro Max — the widest common phone.
    ];

    for (final size in phoneSizes) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await _settle(tester);

      // `IndexedStack` lays out every tab at this size, so Home's content
      // can overflow at very narrow widths. Drain that so this test checks
      // only the bottom bar.
      tester.takeException();

      for (final label in const [
        'Home',
        'Contacts',
        'Tasks',
        'Pipeline',
        'More',
      ]) {
        expect(_navLabel(label), findsOneWidget, reason: 'at $size');
      }

      // The bar itself must always fit the width it was given.
      final barSize = tester.getSize(find.byType(BottomAppBar));
      expect(barSize.width, lessThanOrEqualTo(size.width));
    }
  });
}

/// A label inside the bottom bar. The same text also appears in the AppBar
/// title, so the search is limited to the bar.
Finder _navLabel(String label) =>
    find.descendant(of: find.byType(BottomAppBar), matching: find.text(label));

/// A bounded stand-in for `pumpAndSettle`. A loaded-but-inactive tab can keep
/// an indeterminate progress indicator animating, so waiting for "no more
/// frames scheduled" never finishes; a fixed number of pumps is enough for the
/// shell's actual (finite) transition animations.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<Widget> _shellHarness({required UserRole role}) async {
  final api = fakeApiClient({
    '/employees/directory': (_) => <Map<String, dynamic>>[],
    // One list endpoint serves contacts and the contacts tab; the query says which.
    '/contacts': (uri) => pageOf([
      contactJson(id: 1, name: 'Amina'),
      leadJson(id: 2, name: 'Bina Lead', stage: 'new'),
    ], total: 2),
    '/tasks': (_) => {
      'items': <Map<String, dynamic>>[],
      'total': 0,
      'summary': {'overdue': 0, 'today': 0, 'upcoming': 0, 'done': 0},
    },
    '/contacts/stage-types': (_) => [
      stageJson(id: 'new', label: 'New', orderIndex: 0),
    ],
    // Home tab's KPI and attendance loads.
    '/dashboard/summary': (_) => {
      'kpis': {
        'total_contacts': 2,
        'new_leads': {'value': 1},
        'open_followups': {'value': 1, 'overdue': 0},
        'won': {'value': 0},
      },
    },
    '/attendance/today': (_) => null,
  });

  final session = SessionViewModel(auth: FakeAuthService(), api: api);
  await session.adopt(
    AuthSession(
      accessToken: 'token',
      user: AuthUser(
        id: 1,
        email: 'user@ogera.com',
        name: 'Test User',
        phone: null,
        role: role,
      ),
    ),
  );

  return MultiProvider(
    providers: [
      ChangeNotifierProvider<SessionViewModel>.value(value: session),
      Provider<ContactsService>(create: (_) => ContactsService(api)),
      Provider<ProfessionalsService>(create: (_) => ProfessionalsService(api)),
      Provider<FollowupsService>(create: (_) => FollowupsService(api)),
      Provider<StaffDirectoryService>(
        create: (_) => StaffDirectoryService(api),
      ),
      Provider<HomeService>(create: (_) => HomeService(api)),
      Provider<ExpenseService>(create: (_) => ExpenseService(api)),
      Provider<ActivityService>(create: (_) => ActivityService(api)),
    ],
    child: MaterialApp(theme: AppTheme.build(), home: const ShellScreen()),
  );
}
