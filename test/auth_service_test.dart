import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ogera_crm_mobile/core/network/api_client.dart';
import 'package:ogera_crm_mobile/models/auth_session.dart';
import 'package:ogera_crm_mobile/services/auth_service.dart';

Map<String, dynamic> _loginReply({
  required int id,
  required String role,
  String name = 'Sam Ogera',
  String email = 'sam@ogera.com',
}) => {
  'access_token': 'crm-token',
  'token_type': 'bearer',
  'employee': {
    'id': id,
    'name': name,
    'email': email,
    'role': role,
    'phone': '+919876543210',
    'is_active': true,
  },
};

// Builds an AuthService backed by a mock HTTP client.
AuthService _serviceReplying(
  http.Response Function(http.Request request) reply, {
  _MemorySessionStore? store,
  ApiClient? api,
}) {
  final client = MockClient((request) async => reply(request));
  return AuthService(
    api ?? ApiClient(client: client, baseUrl: 'https://crm.example'),
    store ?? _MemorySessionStore(),
  );
}

void main() {
  test('posts credentials to /auth/login and stores the session', () async {
    final store = _MemorySessionStore();
    final client = MockClient((request) async {
      expect(request.method, 'POST');
      expect(request.url, Uri.parse('https://crm.example/auth/login'));
      expect(request.headers['x-client-type'], 'mobile');
      expect(jsonDecode(request.body), {
        'email': 'sam@ogera.com',
        'password': 'password',
      });
      return http.Response(
        jsonEncode(_loginReply(id: 12, role: 'sales_executive')),
        200,
      );
    });
    final api = ApiClient(client: client, baseUrl: 'https://crm.example');
    final service = AuthService(api, store);

    final session = await service.signIn(
      email: 'sam@ogera.com',
      password: 'password',
    );

    expect(session.user.name, 'Sam Ogera');
    expect(session.user.id, 12);
    expect(session.user.role, UserRole.salesStaff);
    expect(store.saved?.accessToken, 'crm-token');
    // Subsequent calls must carry the token and know who is signed in.
    expect(api.hasToken, isTrue);
    expect(api.currentUserId, 12);
  });

  test('every non-head employee role signs in as staff', () async {
    for (final role in [
      'sales_executive',
      'team_lead',
      'tele_caller',
      'field_executive',
      'accounts_executive', // a custom role created in the web app
    ]) {
      final service = _serviceReplying(
        (_) => http.Response(jsonEncode(_loginReply(id: 1, role: role)), 200),
      );
      final session = await service.signIn(email: 'a@b.com', password: 'x');
      expect(session.user.role, UserRole.salesStaff, reason: role);
      expect(session.user.isStaff, isTrue);
    }
  });

  test('support signs in as staff but cannot move leads through the pipeline', () async {
    final service = _serviceReplying(
      (_) => http.Response(jsonEncode(_loginReply(id: 1, role: 'support')), 200),
    );
    final session = await service.signIn(email: 'a@b.com', password: 'x');
    expect(session.user.role, UserRole.support);
    expect(session.user.isStaff, isTrue);
    expect(session.user.role.canMoveStage, isFalse);
    expect(UserRole.salesStaff.canMoveStage, isTrue);
  });

  // The mobile app is staff-only. Admin and manager accounts belong in the
  // Ogera web portal. Attempting to sign in on mobile must fail with STAFF_ONLY.
  test('admin and manager are rejected with STAFF_ONLY', () async {
    for (final entry in {
      'admin': UserRole.admin,
      'manager': UserRole.salesHead,
    }.entries) {
      final service = _serviceReplying(
        (_) =>
            http.Response(jsonEncode(_loginReply(id: 2, role: entry.key)), 200),
      );
      await expectLater(
        service.signIn(email: 'a@b.com', password: 'x'),
        throwsA(
          isA<AuthException>().having(
            (error) => error.code,
            'code',
            'STAFF_ONLY',
          ),
        ),
        reason: entry.key,
      );
    }
  });

  test('a rejected head account must not leave a usable session behind', () async {
    final store = _MemorySessionStore();
    final service = _serviceReplying(
      (_) => http.Response(
        jsonEncode(_loginReply(id: 3, role: 'manager', name: 'Mani')),
        200,
      ),
      store: store,
    );

    await expectLater(
      service.signIn(email: 'lead@ogera.com', password: 'password'),
      throwsA(isA<AuthException>()),
    );
    // A rejected sign-in must not leave a usable session behind.
    expect(store.saved, isNull);
  });

  test('shows the server message when the credentials are wrong', () async {
    final service = _serviceReplying(
      (_) => http.Response(
        jsonEncode({'detail': 'Invalid email or password'}),
        401,
      ),
    );

    await expectLater(
      service.signIn(email: 'sam@ogera.com', password: 'wrong'),
      throwsA(
        isA<AuthException>().having(
          (error) => error.message,
          'message',
          'Invalid email or password',
        ),
      ),
    );
  });

  test('shows the server message for a deactivated account', () async {
    final service = _serviceReplying(
      (_) => http.Response(
        jsonEncode({'detail': 'Employee account is inactive'}),
        403,
      ),
    );
    await expectLater(
      service.signIn(email: 'a@b.com', password: 'x'),
      throwsA(
        isA<AuthException>().having(
          (error) => error.message,
          'message',
          'Employee account is inactive',
        ),
      ),
    );
  });

  test('rejects a reply that carries no token', () async {
    final service = _serviceReplying(
      (_) => http.Response(
        jsonEncode({
          'employee': {'id': 1},
        }),
        200,
      ),
    );
    await expectLater(
      service.signIn(email: 'a@b.com', password: 'x'),
      throwsA(isA<AuthException>()),
    );
  });

  test('restore rehydrates the stored session and re-arms the token', () async {
    final store = _MemorySessionStore()
      ..saved = const AuthSession(
        accessToken: 'stored-token',
        user: AuthUser(
          id: 7,
          email: 'staff@ogera.com',
          name: 'Staff User',
          phone: null,
          role: UserRole.salesStaff,
        ),
      );
    final api = ApiClient(baseUrl: 'https://crm.example');
    final service = AuthService(api, store);

    final restored = await service.restore();

    expect(restored?.user.id, 7);
    expect(api.hasToken, isTrue);
    expect(api.currentUserId, 7);

    await service.signOut();
    expect(store.saved, isNull);
    expect(api.hasToken, isFalse);
    expect(api.currentUserId, isNull);
  });

  test('a stored session survives the round trip through JSON', () {
    final session = AuthSession.fromLogin(
      _loginReply(id: 9, role: 'sales_executive', name: 'Sam'),
    )!;
    final copy = AuthSession.fromJson(session.toJson());
    expect(copy.accessToken, 'crm-token');
    expect(copy.user.id, 9);
    expect(copy.user.role, UserRole.salesStaff);
  });
}

class _MemorySessionStore implements SessionStore {
  AuthSession? saved;

  @override
  Future<void> save(AuthSession session) async => saved = session;

  @override
  Future<AuthSession?> read() async => saved;

  @override
  Future<void> clear() async => saved = null;
}
