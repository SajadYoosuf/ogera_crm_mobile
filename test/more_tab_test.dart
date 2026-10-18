import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ogera_crm_mobile/models/auth_session.dart';
import 'package:ogera_crm_mobile/theme/app_theme.dart';
import 'package:ogera_crm_mobile/view_models/session_view_model.dart';
import 'package:ogera_crm_mobile/views/more/more_tab.dart';
import 'package:provider/provider.dart';

import 'test_helpers.dart';

/// The More module: the profile header, role-gated menu sections, and the
/// sign-out confirmation flow.
void main() {
  testWidgets('Head sees the Team section with the staff directory', (tester) async {
    final auth = FakeAuthService();
    final session = await _sessionFor(UserRole.salesHead, auth);

    await tester.pumpWidget(_harness(session));
    await tester.pumpAndSettle();

    expect(find.text('Head User'), findsOneWidget);
    expect(find.text('head@ogera.com'), findsOneWidget);
    expect(find.text('Manager'), findsOneWidget);

    // SectionHeader renders its title upper-cased.
    expect(find.text('TEAM'), findsOneWidget);
    expect(find.text('Staff directory'), findsOneWidget);
    expect(find.text('Performance'), findsNothing);

    expect(find.text('ACCOUNT'), findsOneWidget);
    expect(find.text('Profile and settings'), findsOneWidget);
    expect(find.text('Sign out'), findsOneWidget);
  });

  testWidgets('Staff sees neither the Team section nor the staff directory', (
    tester,
  ) async {
    final auth = FakeAuthService();
    final session = await _sessionFor(UserRole.salesStaff, auth);

    await tester.pumpWidget(_harness(session));
    await tester.pumpAndSettle();

    expect(find.text('Staff User'), findsOneWidget);
    expect(find.text('Sales Staff'), findsOneWidget);

    expect(find.text('TEAM'), findsNothing);
    expect(find.text('Staff directory'), findsNothing);
    expect(find.text('Sales Ledger'), findsNothing);
    expect(find.text('Profile and settings'), findsOneWidget);
  });

  testWidgets('cancelling the sign-out confirmation keeps the session', (
    tester,
  ) async {
    final auth = FakeAuthService();
    final session = await _sessionFor(UserRole.salesHead, auth);

    await tester.pumpWidget(_harness(session));
    await tester.pumpAndSettle();

    // Bring Sign out into view first; the menu is taller than the test screen.
    await tester.ensureVisible(find.text('Sign out'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();

    expect(
      find.text('You will need to sign in again on this device.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(auth.signOutCalled, isFalse);
    expect(session.status, isNot(SessionStatus.signedOut));
  });
}

Future<SessionViewModel> _sessionFor(
  UserRole role,
  FakeAuthService auth,
) async {
  final api = fakeApiClient({});
  final session = SessionViewModel(
    auth: auth,
    api: api,
  );
  await session.adopt(
    AuthSession(
      accessToken: 'token',
      user: AuthUser(
        id: role.isHead ? 1 : 2,
        email: role.isHead ? 'head@ogera.com' : 'staff@ogera.com',
        name: role.isHead ? 'Head User' : 'Staff User',
        phone: null,
        role: role,
      ),
    ),
  );
  return session;
}

Widget _harness(SessionViewModel session) {
  return ChangeNotifierProvider<SessionViewModel>.value(
    value: session,
    child: MaterialApp(theme: AppTheme.build(), home: const MoreTab()),
  );
}
