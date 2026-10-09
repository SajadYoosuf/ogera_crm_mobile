import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';
import 'package:ogera_crm_mobile/models/auth_session.dart';
import 'package:ogera_crm_mobile/services/location_api_service.dart';
import 'package:ogera_crm_mobile/services/location_tracking_service.dart';
import 'package:ogera_crm_mobile/theme/app_theme.dart';
import 'package:ogera_crm_mobile/view_models/session_view_model.dart';
import 'package:ogera_crm_mobile/views/more/more_tab.dart';
import 'package:provider/provider.dart';

import 'test_helpers.dart';

/// The More module: the profile header, role-gated menu sections, and the
/// sign-out confirmation flow.
void main() {
  setUpAll(() {
    // Only the Staff scenario needs this, but it is harmless for Head too.
    GeolocatorPlatform.instance = NoLocationServicePlatform();
  });

  testWidgets('Head sees the Team section and not My activity', (tester) async {
    final auth = FakeAuthService();
    final session = await _sessionFor(UserRole.salesHead, auth);

    await tester.pumpWidget(_harness(session));
    await tester.pumpAndSettle();

    expect(find.text('Head User'), findsOneWidget);
    expect(find.text('head@ogera.com'), findsOneWidget);
    expect(find.text('Manager'), findsOneWidget);

    // SectionHeader renders its title upper-cased.
    expect(find.text('TEAM'), findsOneWidget);
    expect(find.text('Sales Ledger'), findsOneWidget);
    expect(find.text('Staff directory'), findsOneWidget);
    expect(find.text('Performance'), findsOneWidget);
    expect(find.text('My performance'), findsNothing);

    expect(find.text('MY ACTIVITY'), findsNothing);
    expect(find.text('My route today'), findsNothing);

    expect(find.text('ACCOUNT'), findsOneWidget);
    expect(find.text('Profile and settings'), findsOneWidget);
    expect(find.text('Sign out'), findsOneWidget);
  });

  testWidgets('Staff sees My activity and not the Team section', (
    tester,
  ) async {
    final auth = FakeAuthService();
    final session = await _sessionFor(UserRole.salesStaff, auth);
    addTearDown(() => session.tracking.dispose());

    await tester.pumpWidget(_harness(session));
    await tester.pumpAndSettle();

    expect(find.text('Staff User'), findsOneWidget);
    expect(find.text('Sales Staff'), findsOneWidget);

    expect(find.text('MY ACTIVITY'), findsOneWidget);
    expect(find.text('My route today'), findsOneWidget);
    expect(find.text('My performance'), findsOneWidget);

    expect(find.text('TEAM'), findsNothing);
    expect(find.text('Performance'), findsNothing);
    expect(find.text('Sales Ledger'), findsNothing);
  });

  testWidgets('cancelling the sign-out confirmation keeps the session', (
    tester,
  ) async {
    final auth = FakeAuthService();
    final session = await _sessionFor(UserRole.salesHead, auth);

    await tester.pumpWidget(_harness(session));
    await tester.pumpAndSettle();

    // The menu is taller now (Performance), so bring Sign out into view first.
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

  testWidgets('confirming sign-out as Staff warns about location sharing', (
    tester,
  ) async {
    final auth = FakeAuthService();
    final session = await _sessionFor(UserRole.salesStaff, auth);

    await tester.pumpWidget(_harness(session));
    await tester.pumpAndSettle();

    // The menu is taller now (Performance), so bring Sign out into view first.
    await tester.ensureVisible(find.text('Sign out'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Location sharing stops as soon as you sign out'),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Sign out'));
    await tester.pumpAndSettle();

    expect(auth.signOutCalled, isTrue);
    expect(session.status, SessionStatus.signedOut);
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
    tracking: LocationTrackingService(
      LocationApiService(api),
      NoopLocationQueue(),
    ),
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
