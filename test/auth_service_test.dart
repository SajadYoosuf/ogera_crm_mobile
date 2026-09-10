import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ogera_crm_mobile/core/network/api_client.dart';
import 'package:ogera_crm_mobile/models/auth_session.dart';
import 'package:ogera_crm_mobile/services/auth_service.dart';

void main() {
  test(
    'posts credentials with the mobile client scope and stores the session',
    () async {
      final store = _MemorySessionStore();
      final client = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url, Uri.parse('https://crm.example/api/auth/login'));
        expect(request.headers['x-client-type'], 'mobile');
        expect(request.headers['x-client-scope'], 'staff');
        expect(jsonDecode(request.body), {
          'email': 'sam@ogera.com',
          'password': 'password',
        });
        return http.Response(
          jsonEncode({
            'success': true,
            'accessToken': 'crm-token',
            'user': {
              'id': 12,
              'email': 'sam@ogera.com',
              'name': 'Sam Ogera',
              'phone': '+919876543210',
              'role': 'sales_staff',
            },
          }),
          200,
        );
      });
      final api = ApiClient(client: client, baseUrl: 'https://crm.example');
      final service = AuthService(api, store);

      final session = await service.signIn(
        email: 'sam@ogera.com',
        password: 'password',
        scope: LoginScope.staff,
      );

      expect(session.user.name, 'Sam Ogera');
      expect(session.user.role, UserRole.salesStaff);
      expect(store.saved?.accessToken, 'crm-token');
      // Subsequent calls must carry the token without the caller passing it.
      expect(api.hasToken, isTrue);
    },
  );

  test('refuses a head account signing in on the staff tab', () async {
    final store = _MemorySessionStore();
    final client = MockClient(
      (_) async => http.Response(
        jsonEncode({
          'success': true,
          'accessToken': 'crm-token',
          'user': {
            'id': 3,
            'email': 'lead@ogera.com',
            'name': 'Sales Head',
            'phone': null,
            'role': 'sales_head',
          },
        }),
        200,
      ),
    );
    final service = AuthService(
      ApiClient(client: client, baseUrl: 'https://crm.example'),
      store,
    );

    await expectLater(
      service.signIn(
        email: 'lead@ogera.com',
        password: 'password',
        scope: LoginScope.staff,
      ),
      throwsA(
        isA<AuthException>().having(
          (error) => error.code,
          'code',
          'SCOPE_MISMATCH',
        ),
      ),
    );
    // A rejected sign-in must not leave a usable session behind.
    expect(store.saved, isNull);
  });

  test('maps CRM credential errors to an AuthException', () async {
    final service = AuthService(
      ApiClient(
        baseUrl: 'https://crm.example',
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'success': false,
              'error': {
                'code': 'INVALID_CREDENTIALS',
                'message': 'Invalid email, password, or access',
              },
            }),
            401,
          ),
        ),
      ),
      _MemorySessionStore(),
    );

    await expectLater(
      service.signIn(
        email: 'sam@ogera.com',
        password: 'wrong',
        scope: LoginScope.head,
      ),
      throwsA(
        isA<AuthException>().having(
          (error) => error.message,
          'message',
          'Invalid email, password, or access',
        ),
      ),
    );
  });

  test('restore rehydrates the stored session and re-arms the token', () async {
    final store = _MemorySessionStore()
      ..saved = const AuthSession(
        accessToken: 'stored-token',
        user: AuthUser(
          id: 7,
          email: 'head@ogera.com',
          name: 'Head',
          phone: null,
          role: UserRole.admin,
        ),
      );
    final api = ApiClient(baseUrl: 'https://crm.example');
    final service = AuthService(api, store);

    final restored = await service.restore();

    expect(restored?.user.id, 7);
    expect(api.hasToken, isTrue);

    await service.signOut();
    expect(store.saved, isNull);
    expect(api.hasToken, isFalse);
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
