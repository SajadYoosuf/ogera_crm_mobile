import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../core/network/api_client.dart';
import '../models/auth_session.dart';

/// Kept for the screens that still catch it; it wraps the same message the API
/// returned so the login form can print it verbatim.
class AuthException implements Exception {
  const AuthException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => message;
}

/// Where a signed-in session is kept between launches.
abstract class SessionStore {
  Future<void> save(AuthSession session);
  Future<AuthSession?> read();
  Future<void> clear();
}

/// Tokens live in the platform keystore, never in shared preferences. The
/// cached user profile sits alongside it so a cold start can restore the shell
/// without a network round-trip.
class SecureSessionStore implements SessionStore {
  SecureSessionStore({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(encryptedSharedPreferences: true),
          );

  static const _sessionKey = 'ogera_session';
  static const _legacyTokenKey = 'ogera_access_token';

  final FlutterSecureStorage _storage;

  @override
  Future<void> save(AuthSession session) async {
    await _storage.write(key: _sessionKey, value: jsonEncode(session.toJson()));
  }

  @override
  Future<AuthSession?> read() async {
    final raw = await _storage.read(key: _sessionKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      final session = AuthSession.fromJson(decoded);
      return session.accessToken.isEmpty ? null : session;
    } on FormatException {
      return null;
    }
  }

  @override
  Future<void> clear() async {
    await _storage.delete(key: _sessionKey);
    await _storage.delete(key: _legacyTokenKey);
  }
}

class AuthService {
  AuthService(this._api, this._store);

  final ApiClient _api;
  final SessionStore _store;

  /// Signs in and verifies that the authenticated role matches the tab the user
  /// picked. The API has no scope guard of its own, so this check is the only
  /// one, and it runs before the token is stored.
  Future<AuthSession> signIn({
    required String email,
    required String password,
    required LoginScope scope,
  }) async {
    dynamic body;
    try {
      body = await _api.post(
        '/auth/login',
        body: {'email': email.trim(), 'password': password},
      );
    } on ApiException catch (error) {
      throw AuthException(error.message, code: error.code);
    }

    final session = AuthSession.fromLogin(body);
    if (session == null) {
      throw const AuthException(
        'The server returned an invalid sign-in response.',
      );
    }
    if (!scope.accepts(session.user.role)) {
      throw AuthException(scope.mismatchMessage, code: 'SCOPE_MISMATCH');
    }

    await _store.save(session);
    _api.setAccessToken(session.accessToken);
    _api.currentUserId = session.user.id;
    return session;
  }

  Future<AuthSession?> restore() async {
    final session = await _store.read();
    if (session != null) {
      _api.setAccessToken(session.accessToken);
      _api.currentUserId = session.user.id;
    }
    return session;
  }

  Future<void> signOut() async {
    await _store.clear();
    _api.setAccessToken(null);
    _api.currentUserId = null;
  }
}
