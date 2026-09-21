import 'dart:async';

import 'package:geolocator/geolocator.dart';

/// A hand-rolled double for [GeolocatorPlatform], swapped in via
/// `GeolocatorPlatform.instance = ...` so [LocationTrackingService] can be
/// exercised without a real device or platform channel.
///
/// Only the members [LocationTrackingService] actually calls are overridden;
/// anything else falls back to the base class's `UnimplementedError`, which
/// makes an untested code path fail loudly instead of silently.
class FakeGeolocatorPlatform extends GeolocatorPlatform {
  bool serviceEnabled = true;
  LocationPermission permission = LocationPermission.denied;

  /// Position returned by a one-shot [getCurrentPosition] call (what
  /// `LocationTrackingService._tick()` uses). Set this before calling
  /// `start()`/awaiting a tick.
  Position? currentPosition;
  Object? currentPositionError;

  final StreamController<Position> _positions =
      StreamController<Position>.broadcast();

  /// The settings the service most recently asked for a position stream
  /// with — this is what the foreground-service regression test inspects.
  LocationSettings? lastStreamSettings;

  int openAppSettingsCalls = 0;
  int openLocationSettingsCalls = 0;

  void emitPosition(Position position) => _positions.add(position);

  @override
  Future<bool> isLocationServiceEnabled() async => serviceEnabled;

  @override
  Future<LocationPermission> checkPermission() async => permission;

  @override
  Future<LocationPermission> requestPermission() async => permission;

  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async {
    final error = currentPositionError;
    if (error != null) throw error;
    final position = currentPosition;
    if (position == null) {
      throw StateError(
        'FakeGeolocatorPlatform.currentPosition was not set before this call',
      );
    }
    return position;
  }

  @override
  Stream<Position> getPositionStream({LocationSettings? locationSettings}) {
    lastStreamSettings = locationSettings;
    return _positions.stream;
  }

  @override
  Future<bool> openAppSettings() async {
    openAppSettingsCalls++;
    return true;
  }

  @override
  Future<bool> openLocationSettings() async {
    openLocationSettingsCalls++;
    return true;
  }

  Future<void> dispose() => _positions.close();
}

/// A [Position] with sensible defaults so tests only spell out what they
/// actually vary.
Position fakePosition({
  double latitude = 11.2588,
  double longitude = 75.7804,
  DateTime? timestamp,
  double speed = 0,
  double accuracy = 5,
}) {
  return Position(
    latitude: latitude,
    longitude: longitude,
    timestamp: timestamp ?? DateTime.utc(2026, 9, 10, 9),
    accuracy: accuracy,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: 0,
    headingAccuracy: 0,
    speed: speed,
    speedAccuracy: 0,
  );
}
