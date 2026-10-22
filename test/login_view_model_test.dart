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
        'Enter your mobile number or email.',
      );
      expect(viewModel.validatePassword(''), 'Enter your password.');
    });

    test('accepts a phone number or an email address as the identifier', () {
      final viewModel = LoginViewModel(_FakeAuthService());
      expect(viewModel.validateEmail('9847012345'), isNull);
      expect(viewModel.validateEmail('test@email.com'), isNull);
      expect(viewModel.validateEmail('+91 98470 12345'), isNull);
      expect(viewModel.validateEmail('notvalid'), isNotNull);
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

    test('signs in with valid credentials and returns a session', () async {
      final service = _FakeAuthService();
      final viewModel = LoginViewModel(service);
      viewModel.updateEmail('sam@ogera.com');
      viewModel.updatePassword('password');

      final session = await viewModel.signIn();

      expect(service.wasCalled, isTrue);
      expect(session, isNotNull);
    });

    test('typing after an error clears the error message', () {
      final viewModel = LoginViewModel(_FakeAuthService());
      viewModel.showNotice('Your session ended. Please sign in again.');
      expect(viewModel.hasError, isTrue);

      viewModel.updateEmail('x');

      expect(viewModel.message, isNull);
      expect(viewModel.hasError, isFalse);
    });
  });
}

class _FakeAuthService implements AuthService {
  _FakeAuthService({this.error});

  final AuthException? error;
  bool wasCalled = false;

  @override
  Future<AuthSession> signIn({
    required String email,
    required String password,
  }) async {
    wasCalled = true;
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
