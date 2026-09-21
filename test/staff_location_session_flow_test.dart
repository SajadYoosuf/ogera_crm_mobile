import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:ogera_crm_mobile/models/auth_session.dart';
import 'package:ogera_crm_mobile/services/location_tracking_service.dart';
import 'package:ogera_crm_mobile/view_models/session_view_model.dart';

import 'fakes/fake_geolocator_platform.dart';
import 'fakes/fake_location_api_service.dart';
import 'fakes/fake_location_queue.dart';
import 'test_helpers.dart';

/// Multi-component flows across `SessionViewModel` + `LocationTrackingService`
/// + `LocationQueue` + `LocationApiService` — the parts of
/// `docs/location-tracking-test-checklist.md`'s integration section that
/// don't need a device. Plain `test()`, not `testWidgets()`: nothing here
/// renders a widget, and `LocationTrackingService.start()` needs to run for
/// real (real timers, real `Connectivity`/`Geolocator` subscriptions via the
/// fakes below) — see `test/fakes/no_op_start_tracking_service.dart` for why
/// that combination is avoided inside an actual `testWidgets` test.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeGeolocatorPlatform geolocator;
  late FakeLocationApiService api;
  late FakeLocationQueue queue;
  late LocationTrackingService tracking;

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    geolocator = FakeGeolocatorPlatform();
    GeolocatorPlatform.instance = geolocator;
    api = FakeLocationApiService();
    queue = FakeLocationQueue();
    tracking = LocationTrackingService(api, queue);
  });

  tearDown(() async {
    await tracking.stop(clearQueue: false);
    tracking.dispose();
    await geolocator.dispose();
    debugDefaultTargetPlatformOverride = null;
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

  test(
    'offline then reconnect: a point recorded while offline reaches the '
    'server once a forced retry succeeds, without ever being dropped',
    () async {
      geolocator.permission = LocationPermission.whileInUse;
      geolocator.currentPosition = fakePosition();
      api.uploadError = StateError('offline');

      final session = await staffSession();
      await pumpEventQueue();

      expect(session.status, SessionStatus.ready);
      expect(await queue.count(), 1, reason: 'the first fix stays queued');
      expect(api.uploadedBatches, isEmpty);

      // Connectivity returns; a "Sync now" tap is the app's forced retry.
      await tracking.flush(force: true);

      expect(await queue.count(), 0);
      expect(api.uploadedBatches.single, hasLength(1));
    },
  );

  test(
    'permission revoked mid-session: tracking stops, the server is told '
    'location_disabled, and the app falls back to the location gate',
    () async {
      geolocator.permission = LocationPermission.whileInUse;
      geolocator.currentPosition = fakePosition();
      final session = await staffSession();
      await pumpEventQueue();
      expect(session.status, SessionStatus.ready);
      expect(tracking.isTracking, isTrue);

      geolocator.permission = LocationPermission.denied;
      await session.refreshLocationPermission();

      expect(tracking.isTracking, isFalse);
      expect(session.status, SessionStatus.needsLocation);
      expect(api.reportedStates, contains('location_disabled'));
    },
  );

  test(
    'sign out: tracking stops, the server is told signed_out, and nothing '
    'is left queued to leak after the session ends',
    () async {
      geolocator.permission = LocationPermission.whileInUse;
      geolocator.currentPosition = fakePosition();
      api.uploadError = StateError('offline'); // leave a point queued
      final session = await staffSession();
      await pumpEventQueue();
      expect(await queue.count(), greaterThan(0));

      await session.signOut();

      expect(tracking.isTracking, isFalse);
      expect(await queue.count(), 0, reason: 'sign-out clears the queue');
      expect(api.reportedStates, contains('signed_out'));
      expect(session.status, SessionStatus.signedOut);
    },
  );

  test(
    'a session that starts blocked and is later granted begins tracking '
    'and the first fix reaches the server',
    () async {
      geolocator.serviceEnabled = false;
      final session = await staffSession();
      expect(session.status, SessionStatus.needsLocation);
      expect(api.reportedStates, contains('location_disabled'));

      geolocator.serviceEnabled = true;
      geolocator.permission = LocationPermission.whileInUse;
      geolocator.currentPosition = fakePosition();
      final granted = await session.requestLocationPermission();
      await pumpEventQueue();

      expect(granted, LocationPermissionState.grantedForeground);
      expect(session.status, SessionStatus.ready);
      expect(api.uploadedBatches, isNotEmpty);
    },
  );
}
