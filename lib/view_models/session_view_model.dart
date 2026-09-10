import 'dart:async';

import 'package:flutter/widgets.dart';

import '../core/network/api_client.dart';
import '../models/auth_session.dart';
import '../services/auth_service.dart';
import '../services/location_tracking_service.dart';

enum SessionStatus { restoring, signedOut, needsLocation, ready }

/// Owns the app's top-level state: who is signed in, whether the staff location
/// gate has been satisfied, and the tracking lifecycle that hangs off both.
///
/// Every screen reads the role from here, so authorization decisions are made
/// in exactly one place.
class SessionViewModel extends ChangeNotifier with WidgetsBindingObserver {
  SessionViewModel({
    required AuthService auth,
    required ApiClient api,
    required LocationTrackingService tracking,
  }) : _auth = auth,
       _api = api,
       _tracking = tracking {
    _api.onUnauthorized = _onUnauthorized;
    WidgetsBinding.instance.addObserver(this);
  }

  final AuthService _auth;
  final ApiClient _api;
  final LocationTrackingService _tracking;

  SessionStatus _status = SessionStatus.restoring;
  AuthSession? _session;
  LocationPermissionState _permission = LocationPermissionState.unknown;
  String? _expiryNotice;

  SessionStatus get status => _status;
  AuthSession? get session => _session;
  AuthUser? get user => _session?.user;
  LocationPermissionState get permission => _permission;
  LocationTrackingService get tracking => _tracking;

  /// Shown once on the login screen after a session ended unexpectedly.
  String? get expiryNotice => _expiryNotice;

  bool get isSignedIn => _session != null;
  bool get isHead => user?.isHead ?? false;
  bool get isStaff => user?.isStaff ?? false;
  bool get isPrivileged => user?.isPrivileged ?? false;
  int get userId => user?.id ?? 0;

  Future<void> bootstrap() async {
    final restored = await _auth.restore();
    if (restored == null) {
      _set(SessionStatus.signedOut);
      return;
    }
    await adopt(restored);
  }

  /// Called after a successful login and on a restored cold start.
  Future<void> adopt(AuthSession session) async {
    _session = session;
    _expiryNotice = null;

    if (session.user.isStaff) {
      _permission = await _tracking.checkPermission();
      if (!_permission.canTrack) {
        await _tracking.reportLocationDisabled();
        _set(SessionStatus.needsLocation);
        return;
      }
      await _tracking.start();
    }
    _set(SessionStatus.ready);
  }

  /// Runs from the location gate. Returns the resulting state so the gate can
  /// show the right recovery action without duplicating the decision.
  Future<LocationPermissionState> requestLocationPermission() async {
    _permission = await _tracking.requestPermission();
    notifyListeners();
    if (_permission.canTrack) {
      await _tracking.start();
      _set(SessionStatus.ready);
    }
    return _permission;
  }

  Future<void> refreshLocationPermission() async {
    if (!isStaff) return;
    final next = await _tracking.checkPermission();
    if (next == _permission) return;
    _permission = next;

    if (next.canTrack) {
      await _tracking.start();
      if (_status == SessionStatus.needsLocation) _set(SessionStatus.ready);
      return;
    }
    // Permission was revoked while the app was running: stop reporting, tell
    // the server why, and put the gate back in front of the user.
    await _tracking.stop(clearQueue: false, reportState: 'location_disabled');
    _set(SessionStatus.needsLocation);
  }

  Future<void> signOut() async {
    if (isStaff) {
      await _tracking.stop(reportState: 'signed_out');
    }
    await _auth.signOut();
    _session = null;
    _permission = LocationPermissionState.unknown;
    _set(SessionStatus.signedOut);
  }

  /// A 401 from any endpoint ends the session wherever the user happens to be.
  void _onUnauthorized() {
    if (_session == null) return;
    _expiryNotice = 'Your session ended. Please sign in again.';
    if (isStaff) unawaited(_tracking.stop(reportState: 'signed_out'));
    unawaited(_auth.signOut());
    _session = null;
    _set(SessionStatus.signedOut);
  }

  void consumeExpiryNotice() {
    if (_expiryNotice == null) return;
    _expiryNotice = null;
    notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Returning from the system settings screen is the common way permission
    // changes, and it produces no callback of its own.
    if (state == AppLifecycleState.resumed && isStaff) {
      unawaited(refreshLocationPermission());
    }
  }

  void _set(SessionStatus status) {
    _status = status;
    notifyListeners();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _api.onUnauthorized = null;
    super.dispose();
  }
}
