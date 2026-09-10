import 'package:flutter_test/flutter_test.dart';
import 'package:ogera_crm_mobile/models/auth_session.dart';
import 'package:ogera_crm_mobile/services/auth_service.dart';
import 'package:ogera_crm_mobile/view_models/login_view_model.dart';

void main() {
  group('LoginViewModel', () {
    test('does not call the service with incomplete credentials', () async {
      final service = _FakeAuthService();
      final viewModel = LoginViewModel(service);

      await viewModel.signIn();

      expect(viewModel.hasAttemptedSubmit, isTrue);
      expect(service.wasCalled, isFalse);
      expect(
        viewModel.validateEmail(''),
        'Enter the email for your workspace.',
      );
      expect(viewModel.validatePassword(''), 'Enter your password.');
    });

    test('shows a recoverable message when authentication fails', () async {
      final viewModel = LoginViewModel(
        _FakeAuthService(
          error: const AuthException('Incorrect email or password.'),
        ),
      );
      viewModel.updateEmail('sam@ogera.com');
      viewModel.updatePassword('password');

      final session = await viewModel.signIn();

      expect(session, isNull);
      expect(viewModel.hasError, isTrue);
      expect(viewModel.message, 'Incorrect email or password.');
    });

    test('sends the selected tab as the login scope', () async {
      final service = _FakeAuthService();
      final viewModel = LoginViewModel(service);
      viewModel.selectScope(LoginScope.staff);
      viewModel.updateEmail('sam@ogera.com');
      viewModel.updatePassword('password');

      final session = await viewModel.signIn();

      expect(service.receivedScope, LoginScope.staff);
      expect(session, isNotNull);
    });

    test('switching tabs clears a stale error message', () {
      final viewModel = LoginViewModel(_FakeAuthService());
      viewModel.showNotice('Your session ended. Please sign in again.');
      expect(viewModel.hasError, isTrue);

      viewModel.selectScope(LoginScope.staff);

      expect(viewModel.message, isNull);
      expect(viewModel.hasError, isFalse);
    });
  });
}

class _FakeAuthService implements AuthService {
  _FakeAuthService({this.error});

  final AuthException? error;
  bool wasCalled = false;
  LoginScope? receivedScope;

  @override
  Future<AuthSession> signIn({
    required String email,
    required String password,
    required LoginScope scope,
  }) async {
    wasCalled = true;
    receivedScope = scope;
    final failure = error;
    if (failure != null) throw failure;
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
