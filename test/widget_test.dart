import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ogera_crm_mobile/core/network/api_client.dart';
import 'package:ogera_crm_mobile/models/auth_session.dart';
import 'package:ogera_crm_mobile/services/auth_service.dart';
import 'package:ogera_crm_mobile/services/location_api_service.dart';
import 'package:ogera_crm_mobile/services/location_queue.dart';
import 'package:ogera_crm_mobile/services/location_tracking_service.dart';
import 'package:ogera_crm_mobile/theme/app_theme.dart';
import 'package:ogera_crm_mobile/view_models/login_view_model.dart';
import 'package:ogera_crm_mobile/view_models/session_view_model.dart';
import 'package:ogera_crm_mobile/views/login_screen.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('login offers a Head tab and a Staff tab', (tester) async {
    await tester.pumpWidget(_harness());

    expect(find.text('Head'), findsOneWidget);
    expect(find.text('Staff'), findsOneWidget);
    expect(find.text('Work email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    // Head is selected first, so the action names that experience.
    expect(find.text('Sign in as Head'), findsWidgets);
  });

  testWidgets('choosing the Staff tab re-labels the sign-in action', (
    tester,
  ) async {
    await tester.pumpWidget(_harness());

    await tester.tap(find.text('Staff'));
    await tester.pumpAndSettle();

    expect(find.text('Sign in as Staff'), findsWidgets);
    expect(find.text('Field workspace'), findsOneWidget);
  });

  testWidgets('an empty form never reaches the service', (tester) async {
    final auth = _FakeAuthService();
    await tester.pumpWidget(_harness(auth: auth));

    // The default 800x600 test viewport puts the button below the fold.
    final signIn = find.widgetWithText(FilledButton, 'Sign in as Head');
    await tester.ensureVisible(signIn);
    await tester.pumpAndSettle();
    await tester.tap(signIn);
    await tester.pumpAndSettle();

    expect(auth.wasCalled, isFalse);
    expect(find.text('Enter the email for your workspace.'), findsOneWidget);
  });
}

Widget _harness({_FakeAuthService? auth}) {
  final service = auth ?? _FakeAuthService();
  final api = ApiClient();
  final tracking = LocationTrackingService(
    LocationApiService(api),
    LocationQueue(),
  );
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<SessionViewModel>(
        create: (_) =>
            SessionViewModel(auth: service, api: api, tracking: tracking),
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
    required LoginScope scope,
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
  Future<AuthSession?> restore() async => null;

  @override
  Future<void> signOut() async {}
}
