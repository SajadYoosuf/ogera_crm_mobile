import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:ogera_crm_mobile/models/auth_session.dart';
import 'package:ogera_crm_mobile/models/staff_location.dart';
import 'package:ogera_crm_mobile/theme/app_theme.dart';
import 'package:ogera_crm_mobile/view_models/session_view_model.dart';
import 'package:ogera_crm_mobile/views/more/profile_screen.dart';
import 'package:provider/provider.dart';

import 'fakes/fake_geolocator_platform.dart';
import 'fakes/fake_location_api_service.dart';
import 'fakes/fake_location_queue.dart';
import 'fakes/no_op_start_tracking_service.dart';
import 'test_helpers.dart';

/// The "Location sharing" card on the staff profile screen: the pending-sync
/// count, last-upload time, and the ten-second debug readout. These are the
/// only on-screen signals a field user or the person supporting them has for
/// telling a working tracker from a broken one (see
/// LOCATION_BACKGROUND_TRACKING_REPORT.md).
///
/// Uses [NoOpStartTrackingService] so `SessionViewModel.adopt()` never runs
/// the real `start()` (GPS stream + connectivity subscription) — that's
/// exhaustively covered by `location_tracking_service_test.dart`, and running
/// it inside a widget test hangs this Flutter build's test teardown the
/// moment anything cancels those subscriptions (see the fake's doc comment).
void main() {
  late FakeGeolocatorPlatform geolocator;
  late FakeLocationApiService api;
  late FakeLocationQueue queue;
  late NoOpStartTrackingService tracking;

  setUp(() {
    geolocator = FakeGeolocatorPlatform();
    GeolocatorPlatform.instance = geolocator;
    api = FakeLocationApiService();
    queue = FakeLocationQueue();
    tracking = NoOpStartTrackingService(api, queue);
  });

  Future<SessionViewModel> staffSession() async {
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
    return session;
  }

  Widget harness(SessionViewModel session) {
    return ChangeNotifierProvider<SessionViewModel>.value(
      value: session,
      child: MaterialApp(theme: AppTheme.build(), home: const ProfileScreen()),
    );
  }

  PendingPoint point([DateTime? at]) => PendingPoint(
    latitude: 11.2588,
    longitude: 75.7804,
    recordedAt: at ?? DateTime.utc(2026, 9, 10, 9),
    isMoving: true,
  );

  group('waiting to sync', () {
    testWidgets('shows "Nothing queued" when the queue starts empty', (
      tester,
    ) async {
      geolocator.permission = LocationPermission.whileInUse;
      final session = await staffSession();

      await tester.pumpWidget(harness(session));
      await tester.pumpAndSettle();

      expect(find.text('Nothing queued'), findsOneWidget);
    });

    testWidgets('shows the plural point count once points are queued', (
      tester,
    ) async {
      geolocator.permission = LocationPermission.whileInUse;
      await queue.add(point());
      await queue.add(point(DateTime.utc(2026, 9, 10, 9, 1)));
      api.uploadError = StateError('offline');
      await tracking.flush();
      final session = await staffSession();

      await tester.pumpWidget(harness(session));
      await tester.pumpAndSettle();

      expect(find.text('2 points'), findsOneWidget);
    });

    testWidgets('uses the singular for exactly one queued point', (
      tester,
    ) async {
      geolocator.permission = LocationPermission.whileInUse;
      await queue.add(point());
      api.uploadError = StateError('offline');
      await tracking.flush();
      final session = await staffSession();

      await tester.pumpWidget(harness(session));
      await tester.pumpAndSettle();

      expect(find.text('1 point'), findsOneWidget);
    });
  });

  group('last upload', () {
    testWidgets('shows "Not yet" before any upload has succeeded', (
      tester,
    ) async {
      geolocator.permission = LocationPermission.whileInUse;
      final session = await staffSession();

      await tester.pumpWidget(harness(session));
      await tester.pumpAndSettle();

      expect(find.text('Not yet'), findsOneWidget);
    });

    testWidgets('shows a relative time once an upload has succeeded', (
      tester,
    ) async {
      geolocator.permission = LocationPermission.whileInUse;
      await queue.add(point());
      await tracking.flush();
      final session = await staffSession();

      await tester.pumpWidget(harness(session));
      await tester.pumpAndSettle();

      expect(find.text('Not yet'), findsNothing);
      expect(find.text('just now'), findsOneWidget);
    });
  });

  group('debug readout', () {
    testWidgets('has no Error line when nothing has failed', (tester) async {
      geolocator.permission = LocationPermission.whileInUse;
      final session = await staffSession();

      await tester.pumpWidget(harness(session));
      await tester.pumpAndSettle();

      expect(find.text('Error'), findsNothing);
    });

    testWidgets('shows an Error line only after a failed flush', (
      tester,
    ) async {
      geolocator.permission = LocationPermission.whileInUse;
      await queue.add(point());
      api.uploadError = StateError('network down');
      await tracking.flush();
      final session = await staffSession();

      await tester.pumpWidget(harness(session));
      await tester.pumpAndSettle();

      expect(find.text('Error'), findsOneWidget);
      expect(find.textContaining('network down'), findsOneWidget);
    });
  });

  group('location sharing status copy', () {
    testWidgets('"While using the app" shows the foreground-only copy', (
      tester,
    ) async {
      geolocator.permission = LocationPermission.whileInUse;
      final session = await staffSession();

      await tester.pumpWidget(harness(session));
      await tester.pumpAndSettle();

      expect(find.text('On — sharing while the app is open'), findsOneWidget);
    });

    testWidgets('"Allow all the time" shows the background copy', (
      tester,
    ) async {
      geolocator.permission = LocationPermission.always;
      final session = await staffSession();

      await tester.pumpWidget(harness(session));
      await tester.pumpAndSettle();

      expect(find.text('On — sharing in the background'), findsOneWidget);
    });

    testWidgets('disabled device location services shows that specific copy', (
      tester,
    ) async {
      geolocator.serviceEnabled = false;
      final session = await staffSession();

      await tester.pumpWidget(harness(session));
      await tester.pumpAndSettle();

      expect(
        find.text('Device location services are switched off'),
        findsOneWidget,
      );
    });
  });
}
