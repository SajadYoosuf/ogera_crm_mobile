// Login screen widget + integration tests
//
// WHAT IS A WIDGET TEST?
// A widget test builds real Flutter widgets inside a test environment. It can
// tap buttons, type text, scroll, and check what's on screen — without a real
// device. We still swap the network layer with fakes.
//
// WHAT IS AN INTEGRATION TEST (at this level)?
// Here "integration" means we wire together the real view model + real auth
// service (backed by a mock HTTP client) + the real screen. This catches bugs
// that unit tests miss because all the pieces talk to each other.
//
// SCOPE: only the login flow (submit → success / error).
//   - Forgot password and WhatsApp are present in the UI but NOT tested here;
//     they open dialogs / external apps that are out of scope for login testing.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ogera_crm_mobile/core/network/api_client.dart';
import 'package:ogera_crm_mobile/models/auth_session.dart';
import 'package:ogera_crm_mobile/services/auth_service.dart';
import 'package:ogera_crm_mobile/theme/app_theme.dart';
import 'package:ogera_crm_mobile/view_models/login_view_model.dart';
import 'package:ogera_crm_mobile/view_models/session_view_model.dart';
import 'package:ogera_crm_mobile/views/login_screen.dart';
import 'package:provider/provider.dart';

// ── Shared fixtures ───────────────────────────────────────────────────────────

/// The JSON body the backend sends back on a successful login.
Map<String, dynamic> _loginOkBody({String role = 'sales_executive'}) => {
  'access_token': 'crm-token',
  'token_type': 'bearer',
  'employee': {
    'id': 1,
    'name': 'Sam Ogera',
    'email': 'sam@ogera.com',
    'role': role,
    'phone': '+919876543210',
    'is_active': true,
  },
};

// ── Widget harness ────────────────────────────────────────────────────────────
//
// _harness() builds a minimal Flutter app containing just the LoginScreen.
// Every test calls this so we don't repeat the provider setup.
//
// Two variants:
//   - _harness()        → uses a fake AuthService (fully controlled)
//   - _harnessWithHttp  → uses the real AuthService backed by a mock HTTP client

Widget _harness({
  AuthService? auth,
  SessionViewModel? session,
}) {
  final service = auth ?? _FakeAuthService();
  final api = ApiClient();
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<SessionViewModel>(
        create: (_) =>
            session ?? SessionViewModel(auth: service, api: api),
      ),
      ChangeNotifierProvider<LoginViewModel>(
        create: (_) => LoginViewModel(service),
      ),
    ],
    child: MaterialApp(theme: AppTheme.build(), home: const LoginScreen()),
  );
}

/// Harness wired to the REAL AuthService + a controllable mock HTTP client.
/// Use this for integration-level tests that verify the full chain:
///   UI tap → view model → auth service → HTTP → parse response → UI update.
Widget _harnessWithHttp(http.Client mockClient) {
  final api = ApiClient(client: mockClient, baseUrl: 'https://crm.test');
  final store = _MemorySessionStore();
  final authService = AuthService(api, store);
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<SessionViewModel>(
        create: (_) => SessionViewModel(auth: authService, api: api),
      ),
      ChangeNotifierProvider<LoginViewModel>(
        create: (_) => LoginViewModel(authService),
      ),
    ],
    child: MaterialApp(theme: AppTheme.build(), home: const LoginScreen()),
  );
}

// ─────────────────────────────────────────────────────────────────────────────

void main() {
  // ── 1. Render ─────────────────────────────────────────────────────────────
  //
  // Verify that the screen shows all expected elements when first opened.
  // A beginner check: "does the screen look right at all?"

  group('render — screen shows expected elements', () {
    testWidgets('hero section shows brand text', (tester) async {
      await tester.pumpWidget(_harness());

      expect(find.text('Namaskaram!\nWelcome to Ogera.'), findsOneWidget);
      // English tagline
      expect(
        find.text('Every lead, every follow-up, in one place.'),
        findsOneWidget,
      );
    });

    testWidgets('form section shows "Welcome back!" headline', (tester) async {
      await tester.pumpWidget(_harness());
      expect(find.text('Welcome back!'), findsOneWidget);
    });

    testWidgets('identifier and password field labels are shown', (
      tester,
    ) async {
      await tester.pumpWidget(_harness());
      expect(find.text('Mobile number or email'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
    });

    testWidgets('Login button is present and enabled', (tester) async {
      await tester.pumpWidget(_harness());
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Login'),
      );
      // A FilledButton is disabled when onPressed is null.
      expect(button.onPressed, isNotNull);
    });

    testWidgets('password field is obscured by default', (tester) async {
      await tester.pumpWidget(_harness());

      // Find the TextFormField for password via its hint text.
      final passField = tester.widget<EditableText>(
        find.descendant(
          of: find.byType(Form),
          matching: find.byType(EditableText).last,
        ),
      );
      expect(passField.obscureText, isTrue);
    });
  });

  // ── 2. Validation — inline errors appear after the first submit attempt ────
  //
  // The form only shows inline errors AFTER the user has tapped Login at least
  // once (autovalidateMode switches on). Before that, no nagging red text.

  group('validation — errors shown after submit attempt', () {
    testWidgets('tapping Login with both fields empty shows both errors', (
      tester,
    ) async {
      await tester.pumpWidget(_harness(auth: _FakeAuthService()));

      await _tapLogin(tester);

      expect(find.text('Enter your mobile number or email.'), findsOneWidget);
      expect(find.text('Enter your password.'), findsOneWidget);
    });

    testWidgets('only identifier empty → identifier error only', (
      tester,
    ) async {
      await tester.pumpWidget(_harness(auth: _FakeAuthService()));

      await tester.enterText(
        find.byType(TextFormField).last, // password field
        'secret',
      );
      await _tapLogin(tester);

      expect(find.text('Enter your mobile number or email.'), findsOneWidget);
      expect(find.text('Enter your password.'), findsNothing);
    });

    testWidgets('only password empty → password error only', (tester) async {
      await tester.pumpWidget(_harness(auth: _FakeAuthService()));

      await tester.enterText(
        find.byType(TextFormField).first, // identifier field
        'sam@ogera.com',
      );
      await _tapLogin(tester);

      expect(find.text('Enter your password.'), findsOneWidget);
      expect(find.text('Enter your mobile number or email.'), findsNothing);
    });

    testWidgets(
      'after submit attempt with wrong credentials, clearing a field shows inline error',
      (tester) async {
        // This test covers the auto-validate path that activates AFTER the
        // first successful form submission attempt reaches the service.
        //
        // HOW autovalidate works in this screen:
        //   1. First tap with empty form → form.validate() shows errors, but
        //      viewModel.signIn() is never called (form blocks it) so
        //      hasAttemptedSubmit stays false → no auto-validate yet.
        //   2. Fill valid-format credentials + tap → form is valid → signIn()
        //      is called → hasAttemptedSubmit = true → autovalidate switches
        //      to onUserInteraction.
        //   3. Now clearing a field instantly re-shows the inline error.
        final service = _FakeAuthService(
          error: const AuthException('Incorrect email or password.'),
        );
        await tester.pumpWidget(_harness(auth: service));

        // Fill valid-format credentials and submit (service will reject them).
        await _fillAndSubmit(tester);
        // Dismiss the error dialog.
        await tester.tap(find.text('Try again'));
        await tester.pumpAndSettle();

        // hasAttemptedSubmit is now true → autovalidate is on.
        // Clear the identifier field by typing an empty string.
        await tester.enterText(find.byType(TextFormField).first, '');
        await tester.pumpAndSettle();

        // The inline identifier error must now appear immediately.
        expect(find.text('Enter your mobile number or email.'), findsOneWidget);
      },
    );
  });

  // ── 3. Password visibility toggle ────────────────────────────────────────
  //
  // Tapping the eye icon reveals the password; tapping again hides it.

  group('password visibility toggle', () {
    testWidgets('tapping the eye icon reveals the password', (tester) async {
      await tester.pumpWidget(_harness());

      // The tooltip says "Show password" when the password is hidden.
      final eyeIcon = find.byTooltip('Show password');
      expect(eyeIcon, findsOneWidget);

      await tester.tap(eyeIcon);
      await tester.pump();

      // After tap, tooltip should switch to "Hide password".
      expect(find.byTooltip('Hide password'), findsOneWidget);
      expect(find.byTooltip('Show password'), findsNothing);
    });

    testWidgets('tapping the eye icon twice re-hides the password', (
      tester,
    ) async {
      await tester.pumpWidget(_harness());

      await tester.tap(find.byTooltip('Show password'));
      await tester.pump();
      await tester.tap(find.byTooltip('Hide password'));
      await tester.pump();

      expect(find.byTooltip('Show password'), findsOneWidget);
    });
  });

  // ── 4. Loading state — spinner shown while API call is in progress ─────────
  //
  // When the user taps Login and the app is waiting for the server, the button
  // must show a spinner and must NOT be tappable (prevents double submission).
  //
  // HOW THIS WORKS:
  // We use a Completer — a "promise" we control. The fake service awaits the
  // Completer's future and does not continue until we call completer.complete().
  // This lets us inspect the mid-flight state between tap and response.

  group('loading state', () {
    // Set a portrait viewport so the Login button fits on screen.
    Future<void> setPortrait(WidgetTester t) async {
      await t.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => t.binding.setSurfaceSize(null));
    }

    testWidgets('Login button shows a spinner while submitting', (
      tester,
    ) async {
      await setPortrait(tester);
      final completer = Completer<AuthSession>();
      final service = _CompleterAuthService(completer);
      await tester.pumpWidget(_harness(auth: service));

      // Fill the form and scroll the button into view BEFORE tapping.
      await _fillForm(tester);
      final loginBtn = find.widgetWithText(FilledButton, 'Login');
      await tester.ensureVisible(loginBtn);
      await tester.pumpAndSettle();

      // Tap — the service is now waiting on the completer.
      await tester.tap(loginBtn);
      await tester.pump(); // process the first frame of the state change

      // The spinner should be visible; "Login" text should be gone.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Login'), findsNothing);

      // Finish the request so the test can tear down cleanly.
      completer.complete(const AuthSession(
        accessToken: 'tok',
        user: AuthUser(
          id: 1, email: 'sam@ogera.com', name: 'Sam',
          phone: null, role: UserRole.salesStaff,
        ),
      ));
      await tester.pumpAndSettle();
    });

    testWidgets('Login button is disabled while submitting', (tester) async {
      await setPortrait(tester);
      final completer = Completer<AuthSession>();
      final service = _CompleterAuthService(completer);
      await tester.pumpWidget(_harness(auth: service));

      await _fillForm(tester);
      final loginBtn = find.widgetWithText(FilledButton, 'Login');
      await tester.ensureVisible(loginBtn);
      await tester.pumpAndSettle();

      await tester.tap(loginBtn);
      await tester.pump();

      final button = tester.widget<FilledButton>(
        find.byType(FilledButton).first,
      );
      // onPressed is null when the button is disabled.
      expect(button.onPressed, isNull);

      completer.complete(const AuthSession(
        accessToken: 'tok',
        user: AuthUser(
          id: 1, email: 'sam@ogera.com', name: 'Sam',
          phone: null, role: UserRole.salesStaff,
        ),
      ));
      await tester.pumpAndSettle();
    });
  });

  // ── 5. Error dialog — backend errors appear as a popup ───────────────────
  //
  // When the server rejects the credentials, an AlertDialog appears.
  // This makes the error impossible to miss on any screen size.

  group('error dialog', () {
    testWidgets('wrong credentials → "Sign in failed" dialog', (tester) async {
      final service = _FakeAuthService(
        error: const AuthException('Incorrect email or password.'),
      );
      await tester.pumpWidget(_harness(auth: service));

      await _fillAndSubmit(tester);

      expect(find.text('Sign in failed'), findsOneWidget);
      expect(find.text('Incorrect email or password.'), findsOneWidget);
    });

    testWidgets('deactivated account → dialog shows server message', (
      tester,
    ) async {
      final service = _FakeAuthService(
        error: const AuthException('Employee account is inactive'),
      );
      await tester.pumpWidget(_harness(auth: service));

      await _fillAndSubmit(tester);

      expect(find.text('Employee account is inactive'), findsOneWidget);
    });

    testWidgets('admin/manager STAFF_ONLY → web-portal message in dialog', (
      tester,
    ) async {
      const msg =
          'This app is for sales staff only. Please use the Ogera web '
          'portal for admin and manager access.';
      final service = _FakeAuthService(
        error: const AuthException(msg, code: 'STAFF_ONLY'),
      );
      await tester.pumpWidget(_harness(auth: service));

      await _fillAndSubmit(tester);

      expect(find.text('Sign in failed'), findsOneWidget);
      expect(find.textContaining('web portal'), findsOneWidget);
    });

    testWidgets('dismissing the dialog brings back the enabled Login button', (
      tester,
    ) async {
      final service = _FakeAuthService(
        error: const AuthException('Wrong password.'),
      );
      await tester.pumpWidget(_harness(auth: service));

      await _fillAndSubmit(tester);
      // Dismiss the dialog by tapping the "Try again" button inside it.
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Login'),
      );
      expect(button.onPressed, isNotNull);
    });
  });

  // ── 6. Session expired notice ─────────────────────────────────────────────
  //
  // If the app navigates to the login screen because a session timed out,
  // SessionViewModel.expiryNotice is set. The screen shows it as a dialog
  // on first render so the user knows why they were signed out.

  group('session expired notice', () {
    testWidgets('expiryNotice shows a "Session expired" dialog on init', (
      tester,
    ) async {
      final api = ApiClient();
      final fakeAuth = _FakeAuthService();
      final session = SessionViewModel(auth: fakeAuth, api: api);
      session.setExpiryNotice('Your session expired. Please sign in again.');

      await tester.pumpWidget(_harness(auth: fakeAuth, session: session));
      await tester.pumpAndSettle();

      expect(find.text('Session expired'), findsOneWidget);
      expect(
        find.text('Your session expired. Please sign in again.'),
        findsOneWidget,
      );
    });
  });

  // ── 7. Integration — real view model + real service + mock HTTP ───────────
  //
  // These tests wire EVERY real layer together. Only the HTTP transport is
  // replaced with a fake that returns controlled JSON responses.
  //
  // This catches bugs that happen when the layers DON'T talk to each other
  // correctly — for example, if the service parses the JSON wrong, or the
  // view model passes the wrong field name to the service.

  group('integration — full chain (UI → view model → service → HTTP)', () {
    testWidgets('valid staff credentials → navigates away (session adopted)', (
      tester,
    ) async {
      final client = MockClient((_) async => http.Response(
        jsonEncode(_loginOkBody(role: 'sales_executive')),
        200,
      ));
      await tester.pumpWidget(_harnessWithHttp(client));

      await _fillAndSubmit(tester);

      // After a successful sign-in, SessionViewModel.adopt() is called.
      // The test does not navigate (no shell route set up), but we verify
      // no error dialog appeared, meaning the sign-in was accepted.
      expect(find.text('Sign in failed'), findsNothing);
    });

    testWidgets('wrong password (HTTP 401) → shows error dialog', (
      tester,
    ) async {
      final client = MockClient((_) async => http.Response(
        jsonEncode({'detail': 'Invalid email or password'}),
        401,
      ));
      await tester.pumpWidget(_harnessWithHttp(client));

      await _fillAndSubmit(tester);

      expect(find.text('Sign in failed'), findsOneWidget);
      expect(find.text('Invalid email or password'), findsOneWidget);
    });

    testWidgets('deactivated account (HTTP 403) → shows error dialog', (
      tester,
    ) async {
      final client = MockClient((_) async => http.Response(
        jsonEncode({'detail': 'Employee account is inactive'}),
        403,
      ));
      await tester.pumpWidget(_harnessWithHttp(client));

      await _fillAndSubmit(tester);

      expect(find.text('Employee account is inactive'), findsOneWidget);
    });

    testWidgets('admin role (HTTP 200 but role=admin) → STAFF_ONLY dialog', (
      tester,
    ) async {
      // The backend accepts the admin credentials (200), but our service
      // rejects the role and throws STAFF_ONLY.
      final client = MockClient((_) async => http.Response(
        jsonEncode(_loginOkBody(role: 'admin')),
        200,
      ));
      await tester.pumpWidget(_harnessWithHttp(client));

      await _fillAndSubmit(tester);

      expect(find.text('Sign in failed'), findsOneWidget);
      expect(find.textContaining('web portal'), findsOneWidget);
    });

    testWidgets('correct email and password are sent to /auth/login', (
      tester,
    ) async {
      String? sentEmail;
      String? sentPassword;

      final client = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        sentEmail = body['email'] as String?;
        sentPassword = body['password'] as String?;
        return http.Response(
          jsonEncode(_loginOkBody()),
          200,
        );
      });
      await tester.pumpWidget(_harnessWithHttp(client));

      // Type specific values and submit.
      await tester.enterText(
        find.byType(TextFormField).first,
        '  sam@ogera.com  ', // has leading/trailing spaces → should be trimmed
      );
      await tester.enterText(find.byType(TextFormField).last, 'mypassword');
      await _tapLogin(tester);

      expect(sentEmail, 'sam@ogera.com'); // spaces trimmed
      expect(sentPassword, 'mypassword');
    });
  });

  // ── 8. Responsiveness ─────────────────────────────────────────────────────
  //
  // The login screen must render without any overflow (yellow-striped boxes)
  // on both small phones (360px wide) and tablets (768px wide).
  //
  // HOW THIS WORKS:
  // tester.binding.setSurfaceSize() simulates a specific screen size.
  // find.byType(OverflowBox) would catch overflow, but the most reliable
  // Flutter approach is to check for RenderObject exceptions and the absence
  // of any yellow overflow stripe widget.

  group('responsiveness — no overflow at different screen sizes', () {
    Future<void> expectNoOverflow(
      WidgetTester tester,
      Size size,
      String label,
    ) async {
      // Set the simulated screen size.
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_harness());
      await tester.pump();

      // If a flex layout overflows, Flutter adds a yellow/red diagonal stripe
      // widget (a RenderFlex overflow error). We check no error was thrown.
      // The tester.takeException() call returns any pending exception.
      expect(
        tester.takeException(),
        isNull,
        reason: 'No overflow expected at $label ($size)',
      );
    }

    testWidgets('renders without overflow on a small phone (360×800)', (
      tester,
    ) async {
      await expectNoOverflow(tester, const Size(360, 800), 'small phone');
    });

    testWidgets('renders without overflow on a standard phone (390×844)', (
      tester,
    ) async {
      await expectNoOverflow(
        tester,
        const Size(390, 844),
        'standard phone',
      );
    });

    testWidgets('renders without overflow on a large phone (430×932)', (
      tester,
    ) async {
      await expectNoOverflow(tester, const Size(430, 932), 'large phone');
    });

    testWidgets('renders without overflow on a tablet (768×1024)', (
      tester,
    ) async {
      await expectNoOverflow(tester, const Size(768, 1024), 'tablet');
    });

    testWidgets('form is capped at 480px wide on a tablet', (tester) async {
      // On a wide screen the form should not stretch to full width — it should
      // be capped at 480px by the ConstrainedBox in the screen.
      await tester.binding.setSurfaceSize(const Size(768, 1024));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_harness());

      // Find the ConstrainedBox that wraps the form column.
      final constrained = tester.widgetList<ConstrainedBox>(
        find.byType(ConstrainedBox),
      );
      final cappedBox = constrained.where(
        (b) => b.constraints.maxWidth == 480,
      );
      expect(cappedBox, isNotEmpty,
          reason: 'A ConstrainedBox with maxWidth 480 must exist');
    });
  });
}

// ── Helpers ───────────────────────────────────────────────────────────────────
//
// Small functions used in multiple tests to avoid repetition.

/// Types valid credentials into both fields.
Future<void> _fillForm(WidgetTester tester) async {
  await tester.enterText(
    find.byType(TextFormField).first, // identifier
    'sam@ogera.com',
  );
  await tester.enterText(
    find.byType(TextFormField).last, // password
    'password123',
  );
}

/// Scrolls the Login button into view and taps it.
Future<void> _tapLogin(WidgetTester tester) async {
  final button = find.widgetWithText(FilledButton, 'Login');
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  await tester.tap(button);
  await tester.pumpAndSettle();
}

/// Fills the form and taps the Login button — the most common test sequence.
Future<void> _fillAndSubmit(WidgetTester tester) async {
  await _fillForm(tester);
  await _tapLogin(tester);
}

// ── Fakes ─────────────────────────────────────────────────────────────────────

/// Returns a staff session on signIn(), or throws a given error.
class _FakeAuthService implements AuthService {
  _FakeAuthService({this.error});

  final AuthException? error;

  @override
  Future<AuthSession> signIn({
    required String email,
    required String password,
  }) async {
    final failure = error;
    if (failure != null) throw failure;
    return const AuthSession(
      accessToken: 'token',
      user: AuthUser(
        id: 1,
        email: 'sam@ogera.com',
        name: 'Sam',
        phone: null,
        role: UserRole.salesStaff,
      ),
    );
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

/// A fake whose signIn() waits for the given [completer] to be resolved.
/// Used to test the loading/spinner state: tap → pump → check spinner → resolve.
class _CompleterAuthService implements AuthService {
  _CompleterAuthService(this._completer);

  final Completer<AuthSession> _completer;

  @override
  Future<AuthSession> signIn({
    required String email,
    required String password,
  }) => _completer.future;

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

/// In-memory session store used with the real AuthService in integration tests.
class _MemorySessionStore implements SessionStore {
  AuthSession? saved;

  @override
  Future<void> save(AuthSession session) async => saved = session;

  @override
  Future<AuthSession?> read() async => saved;

  @override
  Future<void> clear() async => saved = null;
}
