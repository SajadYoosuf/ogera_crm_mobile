import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ogera_crm_mobile/core/network/api_client.dart';
import 'package:ogera_crm_mobile/models/auth_session.dart';
import 'package:ogera_crm_mobile/services/auth_service.dart';
import 'package:ogera_crm_mobile/theme/app_theme.dart';
import 'package:ogera_crm_mobile/view_models/login_view_model.dart';
import 'package:ogera_crm_mobile/view_models/session_view_model.dart';
import 'package:ogera_crm_mobile/views/login_screen.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('login screen shows identifier and password fields', (
    tester,
  ) async {
    await tester.pumpWidget(_harness());

    expect(find.text('Mobile number or email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Login'), findsOneWidget);
  });

  testWidgets('an empty form never reaches the service', (tester) async {
    final auth = _FakeAuthService();
    await tester.pumpWidget(_harness(auth: auth));

    final signIn = find.widgetWithText(FilledButton, 'Login');
    await tester.ensureVisible(signIn);
    await tester.pumpAndSettle();
    await tester.tap(signIn);
    await tester.pumpAndSettle();

    expect(auth.wasCalled, isFalse);
    expect(
      find.text('Enter your mobile number or email.'),
      findsOneWidget,
    );
  });
}

Widget _harness({_FakeAuthService? auth}) {
  final service = auth ?? _FakeAuthService();
  final api = ApiClient();
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<SessionViewModel>(
        create: (_) => SessionViewModel(auth: service, api: api),
      ),
      ChangeNotifierProvider<LoginViewModel>(
        create: (_) => LoginViewModel(service),
      ),
    ],
    child: MaterialApp(theme: AppTheme.build(), home: const LoginScreen()),
  );
}

class _FakeAuthService implements AuthService {
  bool wasCalled = false;

  @override
  Future<AuthSession> signIn({
    required String email,
    required String password,
  }) async {
    wasCalled = true;
    return const AuthSession(
      accessToken: 'token',
      user: AuthUser(
        id: 1,
        email: 'sam@ogera.com',
        name: 'Sam Ogera',
        phone: null,
        role: UserRole.salesStaff,
      ),
    );
  }

  @override
  Future<AuthSession> signInForTest({
    required String email,
    required String password,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<AuthSession?> restore() async => null;

  @override
  Future<void> signOut() async {}
}
