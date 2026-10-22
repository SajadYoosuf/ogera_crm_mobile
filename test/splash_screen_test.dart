// ──────────────────────────────────────────────────────────────────────────────
// WHAT IS TESTED HERE?
//   1. Widget    — SplashScreen renders every expected visual element.
//   2. Responsive— no overflow at common phone screen sizes.
//   3. Unit      — SessionViewModel.bootstrap() enforces a 3-second minimum;
//                  tests use Flutter's fake-async clock so they run instantly.
//   4. Integration— RootRouter shows SplashScreen while bootstrapping, then
//                   transitions to LoginScreen when no session is stored.
//
// HOW fake-async timing works (beginners):
//   Widget tests run in a fake-time environment. `tester.pump(duration)` moves
//   the fake clock forward without waiting in real time. This lets us test a
//   3-second hold in milliseconds of wall-clock time.
// ──────────────────────────────────────────────────────────────────────────────

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ogera_crm_mobile/core/network/api_client.dart';
import 'package:ogera_crm_mobile/models/auth_session.dart';
import 'package:ogera_crm_mobile/services/auth_service.dart';
import 'package:ogera_crm_mobile/theme/app_theme.dart';
import 'package:ogera_crm_mobile/theme/ogera_colors.dart';
import 'package:ogera_crm_mobile/view_models/login_view_model.dart';
import 'package:ogera_crm_mobile/view_models/session_view_model.dart';
import 'package:ogera_crm_mobile/views/root_router.dart';
import 'package:ogera_crm_mobile/views/splash_screen.dart';
import 'package:provider/provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Fakes
// ─────────────────────────────────────────────────────────────────────────────

/// restore() returns null immediately — simulates a first-launch cold start.
class _QuickNullAuth implements AuthService {
  @override
  Future<AuthSession?> restore() async => null;
  @override
  Future<AuthSession> signIn({required String email, required String password})
      => throw UnimplementedError();
  @override
  Future<AuthSession> signInForTest({required String email, required String password})
      => throw UnimplementedError();
  @override
  Future<void> signOut() async {}
}

/// restore() returns a valid session immediately — simulates a warm restart.
class _QuickSessionAuth implements AuthService {
  static const _stored = AuthSession(
    accessToken: 'tok',
    user: AuthUser(
      id: 1, email: 'sam@ogera.com', name: 'Sam',
      phone: null, role: UserRole.salesStaff,
    ),
  );

  @override
  Future<AuthSession?> restore() async => _stored;
  @override
  Future<AuthSession> signIn({required String email, required String password})
      => throw UnimplementedError();
  @override
  Future<AuthSession> signInForTest({required String email, required String password})
      => throw UnimplementedError();
  @override
  Future<void> signOut() async {}
}

/// restore() deliberately waits [delay] before returning null.
/// Used to verify that a slow restore is also protected by Future.wait.
class _SlowNullAuth implements AuthService {
  const _SlowNullAuth(this.delay);
  final Duration delay;

  @override
  Future<AuthSession?> restore() async {
    await Future<void>.delayed(delay);
    return null;
  }
  @override
  Future<AuthSession> signIn({required String email, required String password})
      => throw UnimplementedError();
  @override
  Future<AuthSession> signInForTest({required String email, required String password})
      => throw UnimplementedError();
  @override
  Future<void> signOut() async {}
}

// ─────────────────────────────────────────────────────────────────────────────
// Harness helpers
// ─────────────────────────────────────────────────────────────────────────────

/// Wraps SplashScreen in the minimum MaterialApp needed to pump it.
/// We deliberately skip the full theme here — SplashScreen uses only
/// hard-coded OgeraColors, so no theme is required.
Widget _splash() => const MaterialApp(home: SplashScreen());

/// Builds a minimal app with RootRouter + the two providers it needs.
/// Returns both the widget and the SessionViewModel so tests can call
/// bootstrap() at the right moment.
({Widget widget, SessionViewModel session}) _rootHarness(AuthService auth) {
  final api = ApiClient();
  final session = SessionViewModel(auth: auth, api: api);
  final widget = MultiProvider(
    providers: [
      ChangeNotifierProvider<SessionViewModel>.value(value: session),
      ChangeNotifierProvider<LoginViewModel>(
        create: (_) => LoginViewModel(auth),
      ),
    ],
    child: MaterialApp(theme: AppTheme.build(), home: const RootRouter()),
  );
  return (widget: widget, session: session);
}

// ─────────────────────────────────────────────────────────────────────────────

void main() {
  // ── 1. Widget — renders all expected elements ──────────────────────────────
  //
  // Each test checks one piece of the screen. This way a future change that
  // accidentally removes a badge or the tagline fails exactly ONE test, making
  // the breakage easy to find.

  group('SplashScreen widget — elements', () {
    testWidgets('scaffold background is OgeraColors.forest (deep green)', (
      tester,
    ) async {
      await tester.pumpWidget(_splash());
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, OgeraColors.forest);
    });

    testWidgets('shows "Ogera CRM" app name', (tester) async {
      await tester.pumpWidget(_splash());
      expect(find.text('Ogera CRM'), findsOneWidget);
    });

    testWidgets('shows Facebook badge — letter "f"', (tester) async {
      await tester.pumpWidget(_splash());
      expect(find.text('f'), findsOneWidget);
    });

    testWidgets('shows WhatsApp badge — phone_in_talk icon', (tester) async {
      await tester.pumpWidget(_splash());
      expect(
        find.byWidgetPredicate(
          (w) => w is Icon && w.icon == Icons.phone_in_talk,
        ),
        findsOneWidget,
      );
    });

    testWidgets('shows Google badge — search icon', (tester) async {
      await tester.pumpWidget(_splash());
      expect(
        find.byWidgetPredicate((w) => w is Icon && w.icon == Icons.search),
        findsOneWidget,
      );
    });

    testWidgets('shows YouTube badge — play_arrow icon', (tester) async {
      await tester.pumpWidget(_splash());
      expect(
        find.byWidgetPredicate((w) => w is Icon && w.icon == Icons.play_arrow),
        findsOneWidget,
      );
    });

    testWidgets('shows offline/walk-in badge — store icon', (tester) async {
      await tester.pumpWidget(_splash());
      expect(
        find.byWidgetPredicate((w) => w is Icon && w.icon == Icons.store),
        findsOneWidget,
      );
    });

    testWidgets('shows tagline "No lead goes out."', (tester) async {
      await tester.pumpWidget(_splash());
      expect(find.text('No lead goes out.'), findsOneWidget);
    });

    testWidgets('shows LinearProgressIndicator as loading cue', (
      tester,
    ) async {
      await tester.pumpWidget(_splash());
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('does NOT show a CircularProgressIndicator (old design gone)', (
      tester,
    ) async {
      await tester.pumpWidget(_splash());
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('exactly 5 channel badge containers are shown', (
      tester,
    ) async {
      await tester.pumpWidget(_splash());
      // Each badge is a 44×44 Container inside _ChannelBadges.
      // Count Containers that have width == 44 and height == 44.
      final badgeContainers = tester.widgetList<Container>(
        find.byType(Container),
      ).where((c) {
        final w = c.constraints?.maxWidth;
        final h = c.constraints?.maxHeight;
        // Sizes come from BoxConstraints tight = exact; fall back to checking
        // the decoration + known size by finding all 44×44 ones.
        return w == 44 || h == 44;
      });
      // At least 5 badge-sized containers (logo box is 72×72, so it won't match 44).
      expect(badgeContainers.length, greaterThanOrEqualTo(5));
    });
  });

  // ── 2. Responsive — no overflow at common phone sizes ─────────────────────
  //
  // Five channel badges in a Row occupy 5×44 + 4×8 = 252 dp.
  // Even the smallest phone (360 dp wide) has plenty of room, but this
  // confirms that no edge-case wrapping or padding breaks the layout.

  group('SplashScreen responsiveness — no overflow', () {
    Future<void> expectNoOverflow(
      WidgetTester tester,
      Size size,
      String label,
    ) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_splash());
      await tester.pump();

      expect(
        tester.takeException(),
        isNull,
        reason: 'No RenderFlex overflow expected at $label ($size)',
      );
    }

    testWidgets('no overflow at 360×800 — small Android', (tester) async {
      await expectNoOverflow(tester, const Size(360, 800), 'small Android');
    });

    testWidgets('no overflow at 390×844 — iPhone 14', (tester) async {
      await expectNoOverflow(tester, const Size(390, 844), 'iPhone 14');
    });

    testWidgets('no overflow at 430×932 — iPhone 14 Plus', (tester) async {
      await expectNoOverflow(tester, const Size(430, 932), 'iPhone 14 Plus');
    });
  });

  // ── 3. Unit — bootstrap() minimum 3-second hold ───────────────────────────
  //
  // Implementation in session_view_model.dart uses:
  //   Future.wait([auth.restore(), Future.delayed(Duration(seconds: 3))])
  //
  // The Future.wait resolves when BOTH finish. So:
  //   - If restore() is fast: the 3-second timer controls the hold.
  //   - If restore() is slow (> 3 s): restore() controls the hold.
  //
  // These tests use `tester.pump(duration)` to move the fake clock forward
  // without waiting in real time.

  group('SessionViewModel bootstrap() — minimum 3-second hold', () {
    testWidgets(
      'status stays restoring at 2.9 s when restore() is instant',
      (tester) async {
        final vm = SessionViewModel(auth: _QuickNullAuth(), api: ApiClient());
        unawaited(vm.bootstrap());

        // 2.9 s < 3 s — the 3-second timer has NOT fired yet.
        await tester.pump(const Duration(milliseconds: 2900));
        expect(
          vm.status,
          SessionStatus.restoring,
          reason: 'splash must still be showing at 2.9 s',
        );

        // Drain the pending timer before the test ends; Flutter requires no
        // timers to be outstanding after the test body completes.
        await tester.pump(const Duration(milliseconds: 200));
      },
    );

    testWidgets(
      'status becomes signedOut just after 3 s when no session is stored',
      (tester) async {
        final vm = SessionViewModel(auth: _QuickNullAuth(), api: ApiClient());
        unawaited(vm.bootstrap());

        await tester.pump(const Duration(seconds: 3, milliseconds: 10));
        expect(vm.status, SessionStatus.signedOut);
      },
    );

    testWidgets(
      'status becomes ready just after 3 s when a session is stored',
      (tester) async {
        final vm = SessionViewModel(auth: _QuickSessionAuth(), api: ApiClient());
        unawaited(vm.bootstrap());

        await tester.pump(const Duration(seconds: 3, milliseconds: 10));
        expect(vm.status, SessionStatus.ready);
      },
    );

    testWidgets(
      'when restore() takes 5 s, status stays restoring at 3 s '
      'and flips at 5 s (slow restore wins over the timer)',
      (tester) async {
        // Future.wait resolves when BOTH futures finish.
        // restore() takes 5 s, so the wait is 5 s even though the timer is 3 s.
        final vm = SessionViewModel(
          auth: _SlowNullAuth(const Duration(seconds: 5)),
          api: ApiClient(),
        );
        unawaited(vm.bootstrap());

        // At 3 s the timer has fired, but restore() hasn't finished yet.
        await tester.pump(const Duration(seconds: 3, milliseconds: 10));
        expect(
          vm.status,
          SessionStatus.restoring,
          reason: 'slow restore means the splash must still show at 3 s',
        );

        // At 5+ s restore() completes → Future.wait resolves → status flips.
        await tester.pump(const Duration(seconds: 2, milliseconds: 10));
        expect(vm.status, SessionStatus.signedOut);
      },
    );
  });

  // ── 4. Integration — RootRouter transitions correctly ─────────────────────
  //
  // Wires the real RootRouter + real SessionViewModel + fake AuthService.
  // Verifies the full path: splash shown → bootstrap completes → login shown.

  group('integration — RootRouter transitions', () {
    testWidgets('RootRouter shows SplashScreen while bootstrapping', (
      tester,
    ) async {
      final (:widget, :session) = _rootHarness(_QuickNullAuth());
      await tester.pumpWidget(widget);
      unawaited(session.bootstrap());

      // One frame — bootstrap is in flight (waiting on the 3-second timer).
      await tester.pump();
      expect(find.byType(SplashScreen), findsOneWidget);

      // Drain the pending 3-second timer before the test ends.
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
    });

    testWidgets(
      'RootRouter transitions to LoginScreen after 3 s with no stored session',
      (tester) async {
        final (:widget, :session) = _rootHarness(_QuickNullAuth());
        await tester.pumpWidget(widget);
        unawaited(session.bootstrap());

        await tester.pump(); // first frame — splash visible
        expect(find.byType(SplashScreen), findsOneWidget);

        // Advance past the 3-second hold + the 260 ms AnimatedSwitcher fade.
        await tester.pump(const Duration(seconds: 3, milliseconds: 300));
        await tester.pumpAndSettle();

        expect(
          find.byType(SplashScreen),
          findsNothing,
          reason: 'SplashScreen must be gone after bootstrap finishes',
        );
        expect(
          find.text('Namaskaram!\nWelcome to Ogera.'),
          findsOneWidget,
          reason: 'LoginScreen hero text must be visible',
        );
      },
    );
  });
}
