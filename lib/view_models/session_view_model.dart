import 'dart:async';

import 'package:flutter/widgets.dart';

import '../core/network/api_client.dart';
import '../models/auth_session.dart';
import '../services/auth_service.dart';

enum SessionStatus { restoring, signedOut, ready }

/// Owns the app's top-level state: who is signed in.
///
/// Every screen reads the role from here, so authorization decisions are made
/// in exactly one place.
class SessionViewModel extends ChangeNotifier {
  SessionViewModel({
    required AuthService auth,
    required ApiClient api,
  }) : _auth = auth,
       _api = api {
    _api.onUnauthorized = _onUnauthorized;
  }

  final AuthService _auth;
  final ApiClient _api;

  SessionStatus _status = SessionStatus.restoring;
  AuthSession? _session;
  String? _expiryNotice;

  SessionStatus get status => _status;
  AuthSession? get session => _session;
  AuthUser? get user => _session?.user;

  /// Shown once on the login screen after a session ended unexpectedly.
  String? get expiryNotice => _expiryNotice;

  bool get isSignedIn => _session != null;
  bool get isHead => user?.isHead ?? false;
  bool get isStaff => user?.isStaff ?? false;
  bool get isPrivileged => user?.isPrivileged ?? false;
  int get userId => user?.id ?? 0;

  Future<void> bootstrap() async {
    // Run session restore and the minimum splash hold in parallel.
    // The splash stays visible until both finish, so fast restores still
    // show the screen for at least 3 seconds.
    final results = await Future.wait([
      _auth.restore(),
      Future<void>.delayed(const Duration(seconds: 3)),
    ]);
    final restored = results[0] as AuthSession?;
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
    _set(SessionStatus.ready);
  }

  Future<void> signOut() async {
    await _auth.signOut();
    _session = null;
    _set(SessionStatus.signedOut);
  }

  /// A 401 from any endpoint ends the session wherever the user happens to be.
  void _onUnauthorized() {
    if (_session == null) return;
    _expiryNotice = 'Your session ended. Please sign in again.';
    unawaited(_auth.signOut());
    _session = null;
    _set(SessionStatus.signedOut);
  }

  /// Sets an expiry notice directly. Use in tests only.
  @visibleForTesting
  void setExpiryNotice(String notice) {
    _expiryNotice = notice;
  }

  void consumeExpiryNotice() {
    if (_expiryNotice == null) return;
    _expiryNotice = null;
    notifyListeners();
  }

  void _set(SessionStatus status) {
    _status = status;
    notifyListeners();
  }

  @override
  void dispose() {
    _api.onUnauthorized = null;
    super.dispose();
  }
}
