import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:ogera_crm_mobile/models/auth_session.dart';
import 'package:ogera_crm_mobile/services/location_tracking_service.dart';
import 'package:ogera_crm_mobile/theme/app_theme.dart';
import 'package:ogera_crm_mobile/view_models/session_view_model.dart';
import 'package:ogera_crm_mobile/views/location_gate_screen.dart';
import 'package:provider/provider.dart';

import 'fakes/fake_geolocator_platform.dart';
import 'fakes/fake_location_api_service.dart';
import 'fakes/fake_location_queue.dart';
import 'fakes/no_op_start_tracking_service.dart';
import 'test_helpers.dart';

/// The screen a staff device is stuck behind until it can track location. It
/// is the app's only place that tells a "While using the app" grant apart
/// from a truly blocked one, so its copy and its "Open settings" affordance
/// matter for the background-tracking gap described in
/// LOCATION_BACKGROUND_TRACKING_REPORT.md.
///
/// Uses [NoOpStartTrackingService] — see its doc comment for why the real
/// `start()` must not run inside a widget test in this Flutter build.
void main() {
  late FakeGeolocatorPlatform geolocator;
  late NoOpStartTrackingService tracking;

  setUp(() {
    geolocator = FakeGeolocatorPlatform();
    GeolocatorPlatform.instance = geolocator;
    tracking = NoOpStartTrackingService(
      FakeLocationApiService(),
      FakeLocationQueue(),
    );
  });

  Future<SessionViewModel> staffSession() async {
    final session = SessionViewModel(
      auth: FakeAuthService(),
      api: fakeApiClient({}),
      tracking: tracking,
    );
    await session.adopt(
      AuthSession(
        accessToken: 'token',
        user: AuthUser(
          id: 2,
          email: 'staff@ogera.com',
          name: 'Staff User',
          phone: null,
          role: UserRole.salesStaff,
        ),
      ),
    );
    return session;
  }

  Widget harness(SessionViewModel session) {
    return ChangeNotifierProvider<SessionViewModel>.value(
      value: session,
      child: MaterialApp(
        theme: AppTheme.build(),
        home: const LocationGateScreen(),
      ),
    );
  }

  group('not yet requested', () {
    // `permission` starts at `unknown` until something calls checkPermission
    // (normally `SessionViewModel.adopt`). Skipping `adopt()` reproduces that
    // first-launch instant, before the gate has asked the OS anything —
    // `LocationGateScreen` reads only `session.permission`, not `session.user`.
    testWidgets(
      'shows the plain "sharing is required" copy and Enable button',
      (tester) async {
        final session = SessionViewModel(
          auth: FakeAuthService(),
          api: fakeApiClient({}),
          tracking: tracking,
        );

        await tester.pumpWidget(harness(session));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(find.text('Location sharing is required'), findsOneWidget);
        expect(find.text('Enable location'), findsOneWidget);
        expect(find.text('Open settings'), findsNothing);
      },
    );
  });

  group('blocked states', () {
    testWidgets('service disabled shows the turn-on-services copy', (
      tester,
    ) async {
      geolocator.serviceEnabled = false;
      final session = await staffSession();

      await tester.pumpWidget(harness(session));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('Location access is blocked'), findsOneWidget);
      expect(
        find.textContaining('Location services are switched off'),
        findsOneWidget,
      );
    });

    testWidgets(
      'deniedForever shows the permanently-denied copy and Open settings',
      (tester) async {
        geolocator.permission = LocationPermission.deniedForever;
        final session = await staffSession();

        await tester.pumpWidget(harness(session));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(find.text('Location access is blocked'), findsOneWidget);
        expect(
          find.textContaining('permanently denied for Ogera CRM'),
          findsOneWidget,
        );
        expect(find.text('Open settings'), findsOneWidget);
        expect(find.text('Try again'), findsOneWidget);
      },
    );

    testWidgets(
      'opening settings calls openLocationSettings for serviceDisabled',
      (tester) async {
        geolocator.serviceEnabled = false;
        final session = await staffSession();
        await tester.pumpWidget(harness(session));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        // serviceDisabled needs settings too, so the button is present here.
        await tester.tap(find.text('Open settings'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(geolocator.openLocationSettingsCalls, 1);
        expect(geolocator.openAppSettingsCalls, 0);
      },
    );

    testWidgets('opening settings calls openAppSettings for deniedForever', (
      tester,
    ) async {
      geolocator.permission = LocationPermission.deniedForever;
      final session = await staffSession();
      await tester.pumpWidget(harness(session));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      await tester.tap(find.text('Open settings'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(geolocator.openAppSettingsCalls, 1);
      expect(geolocator.openLocationSettingsCalls, 0);
    });
  });

  group('actions', () {
    testWidgets('tapping Enable requests permission through the session', (
      tester,
    ) async {
      // Starts from `unknown` (no adopt()), same as the "not yet requested"
      // case, so the button reads "Enable location" rather than "Try again".
      final session = SessionViewModel(
        auth: FakeAuthService(),
        api: fakeApiClient({}),
        tracking: tracking,
      );
      geolocator.serviceEnabled = true;
      geolocator.permission = LocationPermission.whileInUse;
      await tester.pumpWidget(harness(session));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      await tester.tap(find.text('Enable location'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(session.permission, LocationPermissionState.grantedForeground);
      expect(session.status, SessionStatus.ready);
    });

    testWidgets('sign out calls through to the auth service', (tester) async {
      geolocator.serviceEnabled = false;
      final auth = FakeAuthService();
      final session = SessionViewModel(
        auth: auth,
        api: fakeApiClient({}),
        tracking: tracking,
      );
      await session.adopt(
        AuthSession(
          accessToken: 'token',
          user: AuthUser(
            id: 2,
            email: 'staff@ogera.com',
            name: 'Staff User',
            phone: null,
            role: UserRole.salesStaff,
          ),
        ),
      );
      await tester.pumpWidget(harness(session));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      await tester.tap(find.text('Sign out'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(auth.signOutCalled, isTrue);
      expect(session.status, SessionStatus.signedOut);
    });
  });
}
