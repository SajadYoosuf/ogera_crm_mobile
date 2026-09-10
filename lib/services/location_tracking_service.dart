import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../core/network/api_client.dart';
import '../models/staff_location.dart';
import 'location_api_service.dart';
import 'location_queue.dart';

/// What the app knows about the device's willingness to share location.
enum LocationPermissionState {
  unknown,
  granted,
  grantedForeground,
  denied,
  deniedForever,
  serviceDisabled,
}

extension LocationPermissionStateX on LocationPermissionState {
  bool get canTrack =>
      this == LocationPermissionState.granted ||
      this == LocationPermissionState.grantedForeground;

  /// Only `deniedForever` needs the system settings screen; the rest can be
  /// retried in-app.
  bool get needsSettings =>
      this == LocationPermissionState.deniedForever ||
      this == LocationPermissionState.serviceDisabled;
}

/// A ten-second heartbeat of what the device holds and what is on its way to
/// the database.
///
/// The real upload cadence is deliberately slow — 60 s while moving, 5 minutes
/// while stationary — which makes a working tracker and a broken one look
/// identical while you watch. This ticks every ten seconds regardless, and it
/// never asks for a fix of its own: it reports the last one the stream
/// delivered, so switching it on costs no extra battery.
class LocationDebugTick {
  const LocationDebugTick({
    required this.at,
    required this.isTracking,
    required this.isMoving,
    required this.pending,
    this.latitude,
    this.longitude,
    this.accuracy,
    this.queuedLatitude,
    this.queuedLongitude,
    this.queuedAt,
    this.lastUploadAt,
    this.lastError,
  });

  final DateTime at;
  final bool isTracking;
  final bool isMoving;

  /// Points written to the local queue and still waiting for the server.
  final int pending;

  /// The device's newest fix, whether or not it was worth recording.
  final double? latitude;
  final double? longitude;
  final double? accuracy;

  /// The last coordinate actually handed to the queue — the one bound for the
  /// database. It lags the fix above by design.
  final double? queuedLatitude;
  final double? queuedLongitude;
  final DateTime? queuedAt;

  final DateTime? lastUploadAt;

  /// Why the last upload attempt failed, if it did. A 404 here means the
  /// server has no `/api/staff/locations` route yet.
  final String? lastError;

  bool get hasFix => latitude != null && longitude != null;

  String get fixLabel => hasFix
      ? '${latitude!.toStringAsFixed(6)}, ${longitude!.toStringAsFixed(6)}'
      : 'no fix yet';

  String get queuedLabel => queuedLatitude != null && queuedLongitude != null
      ? '${queuedLatitude!.toStringAsFixed(6)}, ${queuedLongitude!.toStringAsFixed(6)}'
      : 'nothing queued yet';

  static String _clock(DateTime value) =>
      '${value.hour.toString().padLeft(2, '0')}:'
      '${value.minute.toString().padLeft(2, '0')}:'
      '${value.second.toString().padLeft(2, '0')}';

  /// One line, shaped to be readable in `flutter logs`.
  @override
  String toString() {
    final buffer = StringBuffer('${_clock(at)} | ');
    if (!isTracking) return (buffer..write('tracking STOPPED')).toString();

    buffer.write('gps $fixLabel');
    if (accuracy != null) buffer.write(' ±${accuracy!.round()}m');
    buffer.write(isMoving ? ' moving' : ' stationary');
    buffer.write(' | -> db $queuedLabel');
    if (queuedAt != null) buffer.write(' @${_clock(queuedAt!)}');
    buffer.write(' | queued $pending');
    buffer.write(
      ' | uploaded ${lastUploadAt == null ? 'never' : _clock(lastUploadAt!)}',
    );
    if (lastError != null) buffer.write(' | ERROR $lastError');
    return buffer.toString();
  }
}

/// The staff device's location uploader.
///
/// Reporting cadence, fixed by §4.2.2 of the mobile PRD:
///   * moving — every 100 m of displacement, or every 60 s
///   * stationary — every 5 minutes
///
/// Points are written to [LocationQueue] first and only removed once the server
/// has accepted them, so losing connectivity mid-visit costs nothing.
class LocationTrackingService {
  LocationTrackingService(this._api, this._queue);

  final LocationApiService _api;
  final LocationQueue _queue;

  static const heartbeatInterval = Duration(seconds: 60);
  static const movingDistanceMeters = 20.0;
  static const movingSpeedMetersPerSecond = 0.8;
  // A small batch lets an offline route be enriched with addresses without
  // overwhelming the reverse-geocoding provider when connectivity returns.
  static const _uploadBatchSize = 10;

  /// How long to wait before retrying after a failed upload. Points are never
  /// lost while waiting — they stay queued — so backing off costs nothing but
  /// saves a radio wake-up every 30 seconds when the server is unreachable.
  static const _retryBackoff = Duration(minutes: 2);

  StreamSubscription<Position>? _positions;
  StreamSubscription<List<ConnectivityResult>>? _connectivity;
  Timer? _cadenceTimer;
  Timer? _debugTimer;

  /// Broadcast so the console printer and a UI readout can both listen.
  final _debugTicks = StreamController<LocationDebugTick>.broadcast();
  String? _lastError;
  DateTime? _retryAfter;

  Position? _latest;
  Position? _lastRecorded;
  DateTime? _lastRecordedAt;
  bool _isMoving = true;
  bool _flushing = false;

  final _pendingCount = ValueNotifier<int>(0);
  final _lastUpload = ValueNotifier<DateTime?>(null);

  /// Points still waiting to reach the server — surfaced on the staff profile
  /// so a field user can see that nothing has been lost.
  ValueListenable<int> get pendingCount => _pendingCount;
  ValueListenable<DateTime?> get lastUpload => _lastUpload;

  bool get isTracking => _positions != null;

  /// Emits every [debugInterval] while tracking is running, and prints each
  /// tick in debug builds. Listen to it to show the same thing on screen.
  Stream<LocationDebugTick> get debugTicks => _debugTicks.stream;

  static const debugInterval = Duration(seconds: 10);

  /// The tick as of right now, so a widget can paint before the first emit.
  LocationDebugTick get currentDebugTick => LocationDebugTick(
    at: DateTime.now(),
    isTracking: isTracking,
    isMoving: _isMoving,
    pending: _pendingCount.value,
    latitude: _latest?.latitude,
    longitude: _latest?.longitude,
    accuracy: _latest?.accuracy,
    queuedLatitude: _lastRecorded?.latitude,
    queuedLongitude: _lastRecorded?.longitude,
    queuedAt: _lastRecordedAt,
    lastUploadAt: _lastUpload.value,
    lastError: _lastError,
  );

  // ---------------------------------------------------------------- permission

  Future<LocationPermissionState> checkPermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return LocationPermissionState.serviceDisabled;
    }
    return _mapPermission(await Geolocator.checkPermission());
  }

  /// Asks for foreground access first, then quietly upgrades to background so
  /// tracking survives the user switching apps. A refused upgrade is not fatal:
  /// foreground-only still satisfies the gate.
  Future<LocationPermissionState> requestPermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return LocationPermissionState.serviceDisabled;
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    final state = _mapPermission(permission);
    if (state == LocationPermissionState.grantedForeground) {
      // Android 10+ and iOS both hand out "always" only as a second prompt.
      final upgraded = await Geolocator.requestPermission();
      return _mapPermission(upgraded);
    }
    return state;
  }

  Future<void> openLocationSettings() => Geolocator.openLocationSettings();

  Future<void> openAppSettings() => Geolocator.openAppSettings();

  /// Records an explicit permission/service denial when the app has a session
  /// but cannot start the 60-second tracker.
  Future<void> reportLocationDisabled() =>
      _api.reportState('location_disabled').catchError((_) {});

  LocationPermissionState _mapPermission(LocationPermission permission) {
    return switch (permission) {
      LocationPermission.always => LocationPermissionState.granted,
      LocationPermission.whileInUse =>
        LocationPermissionState.grantedForeground,
      LocationPermission.deniedForever => LocationPermissionState.deniedForever,
      LocationPermission.denied => LocationPermissionState.denied,
      LocationPermission.unableToDetermine => LocationPermissionState.unknown,
    };
  }

  // ------------------------------------------------------------------ lifecycle

  Future<void> start() async {
    if (isTracking) return;
    final state = await checkPermission();
    if (!state.canTrack) return;

    _positions =
        Geolocator.getPositionStream(
          locationSettings: _settings(
            background: state == LocationPermissionState.granted,
          ),
        ).listen(
          _onPosition,
          onError: (Object error) => _log('position stream error: $error'),
        );

    // The timer asks for a current fix every minute. The stream keeps the
    // latest position warm, but does not decide what reaches the server.
    _cadenceTimer = Timer.periodic(heartbeatInterval, (_) => _tick());

    // Independent of the upload cadence: a ten-second readout of what the
    // device holds and what is bound for the database.
    _debugTimer = Timer.periodic(debugInterval, (_) => _emitDebugTick());
    _emitDebugTick();

    _connectivity = Connectivity().onConnectivityChanged.listen((results) {
      final online = results.any((result) => result != ConnectivityResult.none);
      if (online) unawaited(flush());
    });

    unawaited(_tick());
    await _refreshPendingCount();
    _log(
      'tracking started (background: ${state == LocationPermissionState.granted})',
    );
  }

  /// Stops immediately on logout, a revoked session, or an inactive account,
  /// and clears anything still queued — an ended session must not keep
  /// reporting where the person is.
  Future<void> stop({bool clearQueue = true, String? reportState}) async {
    await _positions?.cancel();
    await _connectivity?.cancel();
    _cadenceTimer?.cancel();
    _debugTimer?.cancel();
    _positions = null;
    _connectivity = null;
    _cadenceTimer = null;
    _debugTimer = null;
    _latest = null;
    _lastRecorded = null;
    _lastRecordedAt = null;

    if (reportState != null) {
      await _api.reportState(reportState).catchError((_) {});
    }
    if (clearQueue) {
      await _queue.clear();
      _pendingCount.value = 0;
    }
    _emitDebugTick();
    _log('tracking stopped');
  }

  void dispose() {
    unawaited(stop(clearQueue: false));
    unawaited(_debugTicks.close());
    _pendingCount.dispose();
    _lastUpload.dispose();
  }

  LocationSettings _settings({required bool background}) {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        // Half the recording threshold, so a 100 m move is never missed
        // between two stream events.
        distanceFilter: 50,
        forceLocationManager: false,
        intervalDuration: const Duration(seconds: 30),
        foregroundNotificationConfig: background
            ? const ForegroundNotificationConfig(
                notificationTitle: 'Ogera CRM',
                notificationText: 'Sharing your location with your Sales Head.',
                notificationIcon: AndroidResource(
                  name: 'ic_launcher',
                  defType: 'mipmap',
                ),
                enableWakeLock: true,
                setOngoing: true,
              )
            : null,
      );
    }
    if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 50,
        activityType: ActivityType.otherNavigation,
        pauseLocationUpdatesAutomatically: true,
        allowBackgroundLocationUpdates: background,
        showBackgroundLocationIndicator: background,
      );
    }
    return const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 50,
    );
  }

  // ------------------------------------------------------------------- cadence

  void _onPosition(Position position) {
    _latest = position;
    _updateMovement(position);
  }

  Future<void> _tick() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      _latest = position;
      _updateMovement(position);
      _maybeRecord(position);
      await flush();
    } catch (_) {
      // Only a permission/service failure is Location disabled. A temporary
      // GPS failure is allowed to recover at the next one-minute heartbeat.
      final permission = await checkPermission();
      if (!permission.canTrack) {
        await _api.reportState('location_disabled').catchError((_) {});
      }
    }
  }

  /// At each heartbeat a meaningful position change or GPS speed means Moving;
  /// otherwise the manager sees Stuck at the current address.
  void _updateMovement(Position position) {
    final previous = _lastRecorded;
    if (previous == null) {
      _isMoving = true;
      return;
    }
    final moved = Geolocator.distanceBetween(
      previous.latitude,
      previous.longitude,
      position.latitude,
      position.longitude,
    );
    _isMoving = moved >= movingDistanceMeters ||
        position.speed >= movingSpeedMetersPerSecond;
  }

  void _maybeRecord(Position position) {
    final previous = _lastRecorded;
    final previousAt = _lastRecordedAt;
    if (previous == null || previousAt == null) {
      unawaited(_record(position));
      return;
    }

    final elapsed = DateTime.now().difference(previousAt);
    if (elapsed >= heartbeatInterval) {
      unawaited(_record(position));
    }
  }

  Future<void> _record(Position position) async {
    _lastRecorded = position;
    _lastRecordedAt = DateTime.now();
    await _queue.add(
      PendingPoint(
        latitude: position.latitude,
        longitude: position.longitude,
        recordedAt: position.timestamp,
        accuracy: position.accuracy,
        speed: position.speed,
        heading: position.heading,
        isMoving: _isMoving,
      ),
    );
    await _refreshPendingCount();
    _emitDebugTick();
    await flush();
  }

  // -------------------------------------------------------------------- upload

  /// Drains the queue in batches. A failure leaves the rows in place, so the
  /// next flush retries them in order.
  ///
  /// [force] bypasses the backoff for a deliberate "Sync now" tap.
  Future<void> flush({bool force = false}) async {
    if (_flushing) return;
    final retryAfter = _retryAfter;
    if (!force && retryAfter != null && DateTime.now().isBefore(retryAfter)) {
      return;
    }
    _flushing = true;
    try {
      while (true) {
        final batch = await _queue.take(_uploadBatchSize);
        if (batch.isEmpty) break;
        await _api.upload(batch);
        await _queue.remove(batch);
        _lastUpload.value = DateTime.now();
        // A successful batch clears the previous failure, so the readout does
        // not keep showing a stale error after the server comes back.
        _lastError = null;
        _retryAfter = null;
        if (batch.length < _uploadBatchSize) break;
      }
    } catch (error) {
      _lastError = error is ApiException
          ? '${error.statusCode ?? 'network'} ${error.message}'
          : error.toString();
      _retryAfter = DateTime.now().add(_retryBackoff);
      _log('flush deferred, retrying after $_retryBackoff: $error');
    } finally {
      _flushing = false;
      await _refreshPendingCount();
    }
  }

  Future<void> _refreshPendingCount() async {
    try {
      _pendingCount.value = await _queue.count();
    } catch (_) {
      // A queue read failure is not worth surfacing; the count is advisory.
    }
  }

  /// Prints the tick and hands it to any listener. Called on the ten-second
  /// timer, and again immediately after each recorded point so the console
  /// shows a write the moment it happens rather than up to ten seconds later.
  void _emitDebugTick() {
    final tick = currentDebugTick;
    // Only format the line when something will actually read it — building the
    // string unconditionally would cost every ten seconds forever in release.
    if (kDebugMode) debugPrint('[Ogera Tracking] $tick');
    if (!_debugTicks.isClosed) _debugTicks.add(tick);
  }

  void _log(String message) {
    if (kDebugMode) debugPrint('[Ogera Tracking] $message');
  }
}
