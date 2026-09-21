import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:ogera_crm_mobile/models/staff_location.dart';
import 'package:ogera_crm_mobile/services/location_tracking_service.dart';

import 'fakes/fake_geolocator_platform.dart';
import 'fakes/fake_location_api_service.dart';
import 'fakes/fake_location_queue.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeGeolocatorPlatform geolocator;
  late FakeLocationApiService api;
  late FakeLocationQueue queue;
  late LocationTrackingService service;

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    geolocator = FakeGeolocatorPlatform();
    GeolocatorPlatform.instance = geolocator;
    api = FakeLocationApiService();
    queue = FakeLocationQueue();
    service = LocationTrackingService(api, queue);
  });

  tearDown(() async {
    await service.stop(clearQueue: false);
    service.dispose();
    await geolocator.dispose();
    debugDefaultTargetPlatformOverride = null;
  });

  group('LocationPermissionStateX', () {
    test('canTrack is true only for granted and grantedForeground', () {
      expect(LocationPermissionState.granted.canTrack, isTrue);
      expect(LocationPermissionState.grantedForeground.canTrack, isTrue);
      expect(LocationPermissionState.denied.canTrack, isFalse);
      expect(LocationPermissionState.deniedForever.canTrack, isFalse);
      expect(LocationPermissionState.serviceDisabled.canTrack, isFalse);
      expect(LocationPermissionState.unknown.canTrack, isFalse);
    });

    test('needsSettings is true only for deniedForever and serviceDisabled', () {
      expect(LocationPermissionState.deniedForever.needsSettings, isTrue);
      expect(LocationPermissionState.serviceDisabled.needsSettings, isTrue);
      expect(LocationPermissionState.granted.needsSettings, isFalse);
      // Documents the known gap from LOCATION_BACKGROUND_TRACKING_REPORT.md
      // section 3.3: "While using the app" is never routed to Settings, even
      // though that's the only way to reach "Always" on Android 11+. If this
      // is fixed, flip the expectation below rather than deleting it.
      expect(LocationPermissionState.grantedForeground.needsSettings, isFalse);
    });
  });

  group('checkPermission', () {
    test('reports serviceDisabled before looking at the permission grant', () async {
      geolocator.serviceEnabled = false;
      geolocator.permission = LocationPermission.always;

      expect(await service.checkPermission(), LocationPermissionState.serviceDisabled);
    });

    test('maps every geolocator permission to the matching state', () async {
      final cases = <LocationPermission, LocationPermissionState>{
        LocationPermission.always: LocationPermissionState.granted,
        LocationPermission.whileInUse: LocationPermissionState.grantedForeground,
        LocationPermission.denied: LocationPermissionState.denied,
        LocationPermission.deniedForever: LocationPermissionState.deniedForever,
        LocationPermission.unableToDetermine: LocationPermissionState.unknown,
      };

      for (final MapEntry(key: permission, value: expected) in cases.entries) {
        geolocator.permission = permission;
        expect(await service.checkPermission(), expected, reason: '$permission');
      }
    });
  });

  group('start()', () {
    test('does not start tracking when permission does not allow it', () async {
      geolocator.permission = LocationPermission.denied;

      await service.start();

      expect(service.isTracking, isFalse);
    });

    test(
      'regression: starts the Android foreground service on "While using the '
      'app" alone, not just "Always"',
      () async {
        geolocator.permission = LocationPermission.whileInUse;
        geolocator.currentPosition = fakePosition();

        await service.start();
        await pumpEventQueue();

        expect(service.isTracking, isTrue);
        final settings = geolocator.lastStreamSettings;
        expect(settings, isA<AndroidSettings>());
        expect(
          (settings as AndroidSettings).foregroundNotificationConfig,
          isNotNull,
          reason:
              'Without this, Android freezes the process once the app is '
              'minimized: the 60s cadence timer stops firing and nothing '
              'reaches the server until the app is reopened. See '
              'LOCATION_BACKGROUND_TRACKING_REPORT.md section 3.2.',
        );
      },
    );

    test('also starts the foreground service with full "Always" permission', () async {
      geolocator.permission = LocationPermission.always;
      geolocator.currentPosition = fakePosition();

      await service.start();
      await pumpEventQueue();

      final settings = geolocator.lastStreamSettings as AndroidSettings;
      expect(settings.foregroundNotificationConfig, isNotNull);
    });

    test('is a no-op when already tracking', () async {
      geolocator.permission = LocationPermission.whileInUse;
      geolocator.currentPosition = fakePosition();

      await service.start();
      await pumpEventQueue();
      final firstCallSettings = geolocator.lastStreamSettings;

      geolocator.lastStreamSettings = null;
      await service.start();

      expect(geolocator.lastStreamSettings, isNull);
      expect(firstCallSettings, isNotNull);
    });

    test('records and uploads the very first fix without waiting a full heartbeat', () async {
      geolocator.permission = LocationPermission.whileInUse;
      geolocator.currentPosition = fakePosition();

      await service.start();
      await pumpEventQueue();

      expect(queue.rows, hasLength(0));
      expect(api.uploadedBatches, hasLength(1));
      expect(api.uploadedBatches.single.single.latitude, fakePosition().latitude);
    });
  });

  group('flush()', () {
    Future<void> seedQueue(int count) async {
      for (var i = 0; i < count; i++) {
        await queue.add(
          PendingPoint(
            latitude: 11.2588,
            longitude: 75.7804 + i * 0.0001,
            recordedAt: DateTime.utc(2026, 9, 10, 9, i),
            isMoving: true,
          ),
        );
      }
    }

    test('uploads in batches no larger than 10 and drains the queue', () async {
      await seedQueue(15);

      await service.flush();

      expect(api.uploadedBatches, hasLength(2));
      expect(api.uploadedBatches[0], hasLength(10));
      expect(api.uploadedBatches[1], hasLength(5));
      expect(await queue.count(), 0);
    });

    test('a failed upload leaves the batch queued and clears on the next success', () async {
      await seedQueue(3);
      api.uploadError = StateError('network down');

      await service.flush();

      expect(await queue.count(), 3, reason: 'nothing is dropped on failure');
      expect(api.uploadedBatches, isEmpty);

      await service.flush(force: true);

      expect(await queue.count(), 0);
      expect(api.uploadedBatches.single, hasLength(3));
    });

    test('a non-forced flush is skipped during the retry backoff window', () async {
      await seedQueue(1);
      api.uploadError = StateError('network down');
      await service.flush();
      expect(await queue.count(), 1);

      // Immediately retrying without `force` should be a no-op: still inside
      // the 2-minute backoff started by the failure above.
      await service.flush();

      expect(api.uploadedBatches, isEmpty, reason: 'backoff should still be active');
      expect(await queue.count(), 1);
    });
  });

  group('stop()', () {
    test('clears the queue by default and reports the given state', () async {
      geolocator.permission = LocationPermission.whileInUse;
      geolocator.currentPosition = fakePosition();
      await service.start();
      await pumpEventQueue();

      await service.stop(reportState: 'signed_out');

      expect(service.isTracking, isFalse);
      expect(await queue.count(), 0);
      expect(api.reportedStates, ['signed_out']);
    });

    test('keeps the queue when clearQueue is false', () async {
      await queue.add(
        PendingPoint(
          latitude: 11.2588,
          longitude: 75.7804,
          recordedAt: DateTime.utc(2026, 9, 10, 9),
          isMoving: false,
        ),
      );

      await service.stop(clearQueue: false);

      expect(await queue.count(), 1);
    });
  });
}
