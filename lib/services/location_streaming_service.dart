/// Location streaming service — keeps the backend updated while on field duty.
///
/// What it does:
///   When a staff member checks in, call [start]. The service shows a persistent
///   Android foreground-service notification (so Android does not kill the app)
///   and starts a periodic timer. Every 30 seconds it checks the current GPS
///   position. If the device has moved at least 50 metres from the last position
///   that was sent, it posts the new coordinates via POST /staff/location.
///   Call [stop] on checkout to cancel the timer and dismiss the notification.
///
/// Why this approach:
///   `flutter_foreground_task` keeps Android from sleeping the app. All the
///   location logic runs on the main isolate using a plain Dart Timer, so it
///   can share the app's ApiClient (via HomeService) without isolate plumbing.
library;

import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';

import '../core/network/api_client.dart';
import 'home_service.dart';
import 'location_queue.dart';

/// Distance in metres the device must travel before a new ping is posted.
const double _kThresholdMetres = 50;

/// How often to check for position change.
const Duration _kInterval = Duration(seconds: 30);

/// Notification channel / service identifiers.
const int _kServiceId = 300;
const String _kChannelId = 'ogera_location';
const String _kChannelName = 'Field location';

/// Top-level callback required by flutter_foreground_task; runs in the main
/// isolate. The task just keeps the notification alive — the real work is done
/// by the Timer in [LocationStreamingService].
@pragma('vm:entry-point')
void _startCallback() {
  FlutterForegroundTask.setTaskHandler(_KeepAliveHandler());
}

/// Minimal handler that satisfies the foreground-task contract.
/// All it does is keep the service alive; the Timer drives the actual work.
class _KeepAliveHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp) async {}
}

// ─────────────────────────────────────────────────────────────────────────────

/// Manages the foreground notification + periodic location ping.
///
/// Lifecycle:
///   [start] → called on successful check-in
///   [stop]  → called on checkout or sign-out
class LocationStreamingService with WidgetsBindingObserver {
  /// Pass the same [HomeService] instance the rest of the app uses.
  LocationStreamingService(this._homeService, {LocationQueue? queue})
    : _queue = queue ?? LocationQueue();

  final HomeService _homeService;
  final LocationQueue _queue;

  Timer? _timer;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  Future<void>? _activeTick;
  Future<void>? _activeFlush;
  Position? _lastPosted;
  bool _running = false;
  bool _isFlushing = false;
  int _pendingCount = 0;
  bool _isSyncing = false;

  VoidCallback? onStatusChanged;

  bool get isRunning => _running;
  int get pendingCount => _pendingCount;
  bool get isSyncing => _isSyncing;

  /// Initialises the foreground-task configuration (Android notification
  /// channel + interval). Call once at app startup, before [start].
  static void init() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: _kChannelId,
        channelName: _kChannelName,
        channelDescription:
            'Sends your GPS position while you are on field duty.',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(30000),
        autoRunOnBoot: false,
        allowWifiLock: false,
      ),
    );
  }

  /// Starts the foreground service and location timer.
  /// Safe to call multiple times — does nothing when already running.
  Future<void> start() async {
    if (_running) return;
    _running = true;
    _lastPosted = null;
    WidgetsBinding.instance.addObserver(this);
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
      (_) => flush(),
    );
    await _refreshQueueState();

    // Start the Android foreground service so the OS doesn't suspend the app.
    // If the OS refuses it, tracking still runs while the app is open, so a
    // failure here must not leave `_running` stuck at true.
    try {
      await FlutterForegroundTask.startService(
        serviceId: _kServiceId,
        notificationTitle: 'On field duty',
        notificationText: 'Location tracking is active',
        callback: _startCallback,
      );
    } catch (_) {
      // Keep going without the notification.
    }

    // Fire immediately, then every 30 s.
    await _runTick();
    _timer = Timer.periodic(_kInterval, (_) => _runTick());
  }

  /// Reads the phone's GPS position once, for the check-in record.
  ///
  /// Returns null when permission is off or no fix arrives in time. Check-in
  /// still goes through without coordinates, so this never throws.
  Future<Position?> currentPosition() async {
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
    } catch (_) {
      return null;
    }
  }

  /// Stops the timer and dismisses the foreground notification.
  Future<void> stop() async {
    if (!_running) return;
    _running = false;
    _timer?.cancel();
    _timer = null;
    await _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
    WidgetsBinding.instance.removeObserver(this);
    await _activeTick;
    await _activeFlush;
    _lastPosted = null;
    await FlutterForegroundTask.stopService();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _running) flush();
  }

  /// Checks the current GPS position and posts if moved far enough.
  /// Errors are swallowed — a missed ping is acceptable; a crash is not.
  Future<void> _tick() async {
    try {
      await flush();
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
      if (!_running) return;

      final last = _lastPosted;
      final moved =
          last == null ||
          Geolocator.distanceBetween(
                last.latitude,
                last.longitude,
                pos.latitude,
                pos.longitude,
              ) >=
              _kThresholdMetres;

      if (moved) {
        final ownerId = _homeService.currentUserId;
        if (ownerId == null) return;
        try {
          final accepted = await _homeService.sendLocationPing(
            pos.latitude,
            pos.longitude,
          );
          if (accepted) {
            _lastPosted = pos;
            await _queue.remove(ownerId: ownerId);
          } else {
            await _queue.save(
              ownerId: ownerId,
              latitude: pos.latitude,
              longitude: pos.longitude,
              capturedAt: pos.timestamp,
            );
          }
        } catch (error) {
          if (error is ApiException && error.isNetwork) {
            await _queue.save(
              ownerId: ownerId,
              latitude: pos.latitude,
              longitude: pos.longitude,
              capturedAt: pos.timestamp,
            );
          } else {
            rethrow;
          }
        }
        await _refreshQueueState();
      }
    } catch (_) {
      // GPS unavailable or network error — skip this tick silently.
    }
  }

  Future<void> flush() async {
    if (_activeFlush != null) return _activeFlush!;
    if (!_running || _isFlushing) return;
    final operation = _flushInternal();
    _activeFlush = operation;
    try {
      await operation;
    } finally {
      if (identical(_activeFlush, operation)) _activeFlush = null;
    }
  }

  Future<void> _flushInternal() async {
    final ownerId = _homeService.currentUserId;
    if (ownerId == null) return;
    _isFlushing = true;
    _isSyncing = true;
    onStatusChanged?.call();
    try {
      final pending = await _queue.peek(ownerId: ownerId);
      if (pending == null) return;
      final accepted = await _homeService.sendLocationPing(
        (pending['latitude'] as num).toDouble(),
        (pending['longitude'] as num).toDouble(),
      );
      if (accepted) await _queue.remove(ownerId: ownerId);
    } catch (_) {
      // Keep the row for the next connectivity event or timer tick.
    } finally {
      _isFlushing = false;
      _isSyncing = false;
      await _refreshQueueState();
    }
  }

  Future<void> _runTick() async {
    if (_activeTick != null) return _activeTick!;
    final operation = _tick();
    _activeTick = operation;
    try {
      await operation;
    } finally {
      if (identical(_activeTick, operation)) _activeTick = null;
    }
  }

  Future<void> _refreshQueueState() async {
    final ownerId = _homeService.currentUserId;
    _pendingCount = ownerId == null
        ? 0
        : await _queue.count(ownerId: ownerId);
    onStatusChanged?.call();
  }
}
