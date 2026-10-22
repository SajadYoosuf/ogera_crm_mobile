// LoginViewModel unit tests
//
// WHAT IS A UNIT TEST?
// A unit test tests one class in complete isolation — no real network, no
// Flutter widgets. We swap the real AuthService with a _FakeAuthService that
// we fully control. This lets us test every path (success, error, loading)
// without a running backend.
//
// WHY TEST THE VIEW MODEL SEPARATELY FROM THE SCREEN?
// The screen shows what the view model tells it. If the view model is correct,
// the screen will be correct. Testing at this layer is fast (no widget build,
// no image loading, no theme) and the failures point straight to the logic.

import 'package:flutter_test/flutter_test.dart';
import 'package:ogera_crm_mobile/models/auth_session.dart';
import 'package:ogera_crm_mobile/services/auth_service.dart';
import 'package:ogera_crm_mobile/view_models/login_view_model.dart';

// ── Fixture ───────────────────────────────────────────────────────────────────

/// A successful staff session returned by the fake service.
const _staffSession = AuthSession(
  accessToken: 'tok',
  user: AuthUser(
    id: 1,
    email: 'sam@ogera.com',
    name: 'Sam',
    phone: null,
    role: UserRole.salesStaff,
  ),
);

// ─────────────────────────────────────────────────────────────────────────────

void main() {
  // ── 1. Identifier validation ───────────────────────────────────────────────
  //
  // The field accepts a phone number OR an email. Some staff remember their
  // phone but not the email they registered with, so both must work.
  // validateEmail returns null (= valid) or an error string.

  group('identifier validation', () {
    late LoginViewModel vm;
    setUp(() => vm = LoginViewModel(_FakeAuthService()));

    test('empty string → required error', () {
      expect(vm.validateEmail(''), 'Enter your mobile number or email.');
    });

    test('null → required error', () {
      expect(vm.validateEmail(null), 'Enter your mobile number or email.');
    });

    test('whitespace-only → required error', () {
      expect(vm.validateEmail('   '), 'Enter your mobile number or email.');
    });

    test('10-digit phone is valid', () {
      expect(vm.validateEmail('9847012345'), isNull);
    });

    test('phone with +91 and spaces is valid', () {
      expect(vm.validateEmail('+91 98470 12345'), isNull);
    });

    test('phone with dashes is valid', () {
      expect(vm.validateEmail('984-701-2345'), isNull);
    });

    test('phone shorter than 7 digits is invalid', () {
      // 6 digits — too short to be a real number.
      expect(vm.validateEmail('123456'), isNotNull);
    });

    test('standard email is valid', () {
      expect(vm.validateEmail('test@email.com'), isNull);
      expect(vm.validateEmail('staff.member@ogera.in'), isNull);
    });

    test('letters with no @ sign are invalid', () {
      expect(vm.validateEmail('notvalid'), isNotNull);
    });
  });

  // ── 2. Password validation ─────────────────────────────────────────────────

  group('password validation', () {
    late LoginViewModel vm;
    setUp(() => vm = LoginViewModel(_FakeAuthService()));

    test('empty → required error', () {
      expect(vm.validatePassword(''), 'Enter your password.');
      expect(vm.validatePassword(null), 'Enter your password.');
    });

    test('any non-empty string passes', () {
      expect(vm.validatePassword('x'), isNull);
      expect(vm.validatePassword(r'my$3cretP@ss'), isNull);
    });
  });

  // ── 3. Submit guard ────────────────────────────────────────────────────────
  //
  // signIn() must NOT reach the network if the form is invalid.
  // It sets hasAttemptedSubmit = true so the UI starts showing inline errors.

  group('submit guard — service is never called with incomplete form', () {
    test('both fields empty', () async {
      final service = _FakeAuthService();
      final vm = LoginViewModel(service);

      await vm.signIn();

      expect(service.wasCalled, isFalse);
      expect(vm.hasAttemptedSubmit, isTrue);
    });

    test('only identifier filled', () async {
      final service = _FakeAuthService();
      final vm = LoginViewModel(service)..updateEmail('sam@ogera.com');

      await vm.signIn();

      expect(service.wasCalled, isFalse);
    });

    test('only password filled', () async {
      final service = _FakeAuthService();
      final vm = LoginViewModel(service)..updatePassword('secret');

      await vm.signIn();

      expect(service.wasCalled, isFalse);
    });
  });

  // ── 4. State machine: idle → submitting → idle / error ────────────────────
  //
  // The view model tracks three states so the UI knows what to render:
  //   - idle    → normal form, button enabled
  //   - submitting → spinner shown, button disabled
  //   - error   → error message shown
  //
  // After signIn() completes (success or failure), isSubmitting is always false.

  group('state machine', () {
    test('starts as idle with no message', () {
      final vm = LoginViewModel(_FakeAuthService());
      expect(vm.isSubmitting, isFalse);
      expect(vm.hasError, isFalse);
      expect(vm.message, isNull);
    });

    test('successful sign-in returns a session and stays idle', () async {
      final service = _FakeAuthService();
      final vm = LoginViewModel(service)
        ..updateEmail('sam@ogera.com')
        ..updatePassword('secret');

      final session = await vm.signIn();

      expect(service.wasCalled, isTrue);
      expect(session, isNotNull);
      expect(vm.session, isNotNull);
      expect(vm.isSubmitting, isFalse);
      expect(vm.hasError, isFalse);
    });

    test('AuthException → error state, correct message, session null', () async {
      final vm = LoginViewModel(
        _FakeAuthService(
          error: const AuthException('Incorrect email or password.'),
        ),
      )
        ..updateEmail('sam@ogera.com')
        ..updatePassword('wrong');

      final session = await vm.signIn();

      expect(session, isNull);
      expect(vm.hasError, isTrue);
      expect(vm.message, 'Incorrect email or password.');
      expect(vm.isSubmitting, isFalse);
    });

    test('admin STAFF_ONLY error → shows web-portal message', () async {
      // Admin accounts sign in successfully on the backend, but our service
      // rejects them because this app is for staff only.
      const msg =
          'This app is for sales staff only. '
          'Please use the Ogera web portal for admin and manager access.';
      final vm = LoginViewModel(
        _FakeAuthService(error: const AuthException(msg, code: 'STAFF_ONLY')),
      )
        ..updateEmail('admin@ogera.com')
        ..updatePassword('pass');

      await vm.signIn();

      expect(vm.hasError, isTrue);
      expect(vm.message, msg);
    });

    test('unexpected exception → safe fallback message (no stack trace leaked)', () async {
      // A network drop or unexpected crash should show a friendly message,
      // never a raw Dart error that would confuse a non-developer user.
      final vm = LoginViewModel(_FakeAuthService(throwGeneric: true))
        ..updateEmail('sam@ogera.com')
        ..updatePassword('secret');

      await vm.signIn();

      expect(vm.hasError, isTrue);
      expect(vm.message, 'We could not sign you in. Please try again.');
    });
  });

  // ── 5. Error clearing ──────────────────────────────────────────────────────
  //
  // When the user starts typing again after an error, the error disappears.
  // This prevents the old message from still showing while they re-type.

  group('typing after an error clears the message', () {
    test('updateEmail clears the error', () {
      final vm = LoginViewModel(_FakeAuthService())
        ..showNotice('Session expired. Sign in again.');

      vm.updateEmail('new@email.com');

      expect(vm.hasError, isFalse);
      expect(vm.message, isNull);
    });

    test('updatePassword clears the error', () {
      final vm = LoginViewModel(_FakeAuthService())
        ..showNotice('Session expired.');

      vm.updatePassword('newpassword');

      expect(vm.hasError, isFalse);
    });

    test('showNotice sets the error state directly', () {
      final vm = LoginViewModel(_FakeAuthService());

      vm.showNotice('Your session ended. Please sign in again.');

      expect(vm.hasError, isTrue);
      expect(vm.message, 'Your session ended. Please sign in again.');
    });
  });

  // ── 6. Password visibility toggle ─────────────────────────────────────────
  //
  // The eye-icon on the password field toggles between hidden and visible.
  // The view model tracks this with obscurePassword.

  group('password visibility toggle', () {
    test('hidden by default', () {
      expect(LoginViewModel(_FakeAuthService()).obscurePassword, isTrue);
    });

    test('one toggle → visible', () {
      final vm = LoginViewModel(_FakeAuthService())
        ..togglePasswordVisibility();
      expect(vm.obscurePassword, isFalse);
    });

    test('two toggles → hidden again', () {
      final vm = LoginViewModel(_FakeAuthService())
        ..togglePasswordVisibility()
        ..togglePasswordVisibility();
      expect(vm.obscurePassword, isTrue);
    });
  });

  // ── 7. Identifier trimming ─────────────────────────────────────────────────
  //
  // Leading/trailing spaces are stripped before sending to the API.
  // This prevents "invalid credentials" errors from accidental keyboard spaces.

  group('identifier is trimmed before the API call', () {
    test('spaces around email are removed', () async {
      final service = _FakeAuthService();
      final vm = LoginViewModel(service)
        ..updateEmail('  sam@ogera.com  ')
        ..updatePassword('secret');

      await vm.signIn();

      expect(service.lastEmail, 'sam@ogera.com');
    });
  });
}

// ── Fake AuthService ──────────────────────────────────────────────────────────
//
// Never hits the network. Configure it per test:
//   - Default: returns _staffSession (success)
//   - error: throws the given AuthException
//   - throwGeneric: throws a plain Exception (simulates a network crash)

class _FakeAuthService implements AuthService {
  _FakeAuthService({this.error, this.throwGeneric = false});

  final AuthException? error;
  final bool throwGeneric;

  bool wasCalled = false;
  String? lastEmail; // captures the email actually sent to the service

  @override
  Future<AuthSession> signIn({
    required String email,
    required String password,
  }) async {
    wasCalled = true;
    lastEmail = email;
    if (throwGeneric) throw Exception('network timeout');
    final failure = error;
    if (failure != null) throw failure;
    return _staffSession;
  }

  @override
  Future<AuthSession> signInForTest({
    required String email,
    required String password,
  }) async =>
      throw UnimplementedError();

  @override
  Future<AuthSession?> restore() async => null;

  @override
  Future<void> signOut() async {}
}
