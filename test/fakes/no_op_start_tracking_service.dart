import 'package:ogera_crm_mobile/services/location_tracking_service.dart';

/// A [LocationTrackingService] whose [start] does nothing.
///
/// The real [start] subscribes to a live GPS position stream and a
/// `connectivity_plus` broadcast stream — both exhaustively covered by
/// `location_tracking_service_test.dart` via [FakeGeolocatorPlatform]. Widget
/// tests (`profile_screen_test.dart`, `location_gate_screen_test.dart`) only
/// need `SessionViewModel.permission`/`.status` to transition correctly when
/// tracking "starts"; they don't exercise `start()`'s own logic.
///
/// Letting the real subscriptions get created inside a `testWidgets` test
/// currently hangs `flutter_test`'s own test-completion machinery the moment
/// something calls `.cancel()` on them (reproduced with a bare
/// `StreamController.broadcast()` + explicit `.cancel()`, no plugin involved
/// — an environment/SDK issue in this Flutter build, not a production bug).
/// Skipping the real `start()` here sidesteps that entirely.
class NoOpStartTrackingService extends LocationTrackingService {
  NoOpStartTrackingService(super.api, super.queue);

  @override
  Future<void> start() async {}
}
