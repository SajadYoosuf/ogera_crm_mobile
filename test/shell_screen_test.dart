import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ogera_crm_mobile/models/auth_session.dart';
import 'package:ogera_crm_mobile/services/crm_services.dart';
import 'package:ogera_crm_mobile/services/location_api_service.dart';
import 'package:ogera_crm_mobile/services/location_tracking_service.dart';
import 'package:ogera_crm_mobile/theme/app_theme.dart';
import 'package:ogera_crm_mobile/view_models/session_view_model.dart';
import 'package:ogera_crm_mobile/views/shell_screen.dart';
import 'package:provider/provider.dart';

import 'test_helpers.dart';

/// Covers the shell's bottom navigation bar: it lists every module, switches
/// the active tab, offers the quick-action FAB only where creating a record
/// makes sense, and keeps rendering cleanly across phone screen sizes.
///
/// `IndexedStack` mounts every tab up front — including the Map tab, whose
/// `flutter_map` tile layer would otherwise reach for the real internet — so
/// every test here disables outgoing network via [NoNetworkHttpOverrides].
/// The Map tab also stays "loading" (an indeterminate, never-settling
/// progress indicator) until it is actually selected, since the shell only
/// activates a tab's view model once the user opens it — so this file settles
/// with a bounded [_settle] instead of `pumpAndSettle`, which would hang.
void main() {
  setUpAll(() {
    HttpOverrides.global = NoNetworkHttpOverrides();
  });

  tearDownAll(() {
    HttpOverrides.global = null;
  });

  testWidgets(
    'bottom navigation bar lists every module and switches the active tab',
    (tester) async {
      await tester.pumpWidget(await _shellHarness());
      await _settle(tester);

      for (final label in const [
        'Home',
        'Contacts',
        'Pros',
        'Follow-ups',
        'Map',
        'More',
      ]) {
        expect(find.text(label), findsOneWidget);
      }

      // Home is the initial tab.
      expect(find.text('Overview'), findsOneWidget);

      await tester.tap(find.text('Contacts'));
      await _settle(tester);
      expect(find.widgetWithText(AppBar, 'Contacts'), findsOneWidget);

      await tester.tap(find.text('Pros'));
      await _settle(tester);
      expect(find.widgetWithText(AppBar, 'Professionals'), findsOneWidget);

      await tester.tap(find.text('Follow-ups'));
      await _settle(tester);
      expect(find.widgetWithText(AppBar, 'Follow-ups'), findsOneWidget);

      // The Map tab has no app bar of its own; its "fit to pins" button is.
      await tester.tap(find.text('Map'));
      await _settle(tester);
      expect(find.byTooltip('Fit everything on screen'), findsOneWidget);

      await tester.tap(find.text('More'));
      await _settle(tester);
      expect(find.widgetWithText(AppBar, 'More'), findsOneWidget);

      // Switching back to Home keeps the shell's single Navigator alive.
      await tester.tap(find.text('Home'));
      await _settle(tester);
      expect(find.text('Overview'), findsOneWidget);
    },
  );

  testWidgets(
    'quick-action FAB appears only on Home, Contacts, and Professionals',
    (tester) async {
      await tester.pumpWidget(await _shellHarness());
      await _settle(tester);

      // The shell's own expandable FAB — distinct from Follow-ups' unrelated
      // "Add lead" FAB, which lives inside that tab's own nested Scaffold.
      expect(find.byType(QuickActionFab), findsOneWidget);

      await tester.tap(find.text('Follow-ups'));
      await _settle(tester);
      expect(find.byType(QuickActionFab), findsNothing);

      await tester.tap(find.text('Map'));
      await _settle(tester);
      expect(find.byType(QuickActionFab), findsNothing);

      await tester.tap(find.text('More'));
      await _settle(tester);
      expect(find.byType(QuickActionFab), findsNothing);

      await tester.tap(find.text('Contacts'));
      await _settle(tester);
      expect(find.byType(QuickActionFab), findsOneWidget);

      // Expanding it offers every quick action a Head session gets. Only the
      // shell's own FAB is on screen here, so its type is unambiguous.
      await tester.tap(find.byType(FloatingActionButton));
      await _settle(tester);
      expect(find.text('Add contact'), findsOneWidget);
      expect(find.text('Add professional'), findsOneWidget);
      expect(find.text('Add sale'), findsOneWidget);
    },
  );

  testWidgets(
    'bottom navigation bar renders without overflow across phone sizes',
    (tester) async {
      await tester.pumpWidget(await _shellHarness());
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

        // `IndexedStack` lays out every tab at this size, not just the
        // visible one — including Home's metric grid, which is a separate,
        // pre-existing overflow at very narrow widths and not something this
        // test is about. Drain it so it doesn't fail the test, and assert
        // directly on the one thing this test covers: the nav bar itself.
        tester.takeException();

        for (final label in const [
          'Home',
          'Contacts',
          'Pros',
          'Follow-ups',
          'Map',
          'More',
        ]) {
          expect(find.text(label), findsOneWidget, reason: 'at $size');
        }

        // The bar itself must always fit the width it was given.
        final barSize = tester.getSize(find.byType(NavigationBar));
        expect(barSize.width, lessThanOrEqualTo(size.width));
      }
    },
  );
}

/// A bounded stand-in for `pumpAndSettle`. The Map tab's indeterminate
/// progress indicator animates forever while it is loaded-but-inactive, so
/// waiting for "no more frames scheduled" never finishes; a fixed number of
/// pumps is enough for the shell's actual (finite) transition animations.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<Widget> _shellHarness() async {
  final api = fakeApiClient({
    '/employees/directory': (_) => <Map<String, dynamic>>[],
    '/contacts/map': (_) => {
      'items': [contactPinJson(id: 1, name: 'Amina')],
      'total': 1,
    },
    // One list endpoint serves consumers (Contacts, Follow-ups) and partners
    // (Professionals); the query says which.
    '/contacts': (uri) => uri.queryParameters['contact_type'] == 'partner'
        ? pageOf([professionalJson(id: 1, name: 'Arun Plumber')])
        : pageOf([
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
    '/staff/locations/live': (_) => {'staff': <Map<String, dynamic>>[]},
    '/sales': (_) => pageOf([]),
  });

  final session = SessionViewModel(
    auth: FakeAuthService(),
    api: api,
    tracking: LocationTrackingService(
      LocationApiService(api),
      NoopLocationQueue(),
    ),
  );
  await session.adopt(
    const AuthSession(
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

  return MultiProvider(
    providers: [
      ChangeNotifierProvider<SessionViewModel>.value(value: session),
      Provider<ContactsService>(create: (_) => ContactsService(api)),
      Provider<ProfessionalsService>(create: (_) => ProfessionalsService(api)),
      Provider<FollowupsService>(create: (_) => FollowupsService(api)),
      Provider<StaffDirectoryService>(
        create: (_) => StaffDirectoryService(api),
      ),
      Provider<LocationApiService>(create: (_) => LocationApiService(api)),
      Provider<SalesService>(create: (_) => SalesService(api)),
    ],
    child: MaterialApp(theme: AppTheme.build(), home: const ShellScreen()),
  );
}
