import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:ogera_crm_mobile/models/staff_location.dart';
import 'package:ogera_crm_mobile/theme/app_theme.dart';
import 'package:ogera_crm_mobile/views/map/staff_sheet.dart';

void main() {
  testWidgets('manager staff row shows address and status without coordinates',
      (tester) async {
    const address = 'West Hill, Kozhikode, Kerala';
    final staff = StaffLocation(
      userId: 7,
      name: 'Nila Staff',
      position: LatLng(11.2588, 75.7804),
      state: StaffState.moving,
      address: address,
      recordedAt: DateTime(2026, 9, 10, 14, 30),
      colorIndex: 7,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.build(),
        home: Scaffold(
          body: StaffRow(
            staff: staff,
            isSelected: false,
            onTrace: () {},
            onFocus: () {},
          ),
        ),
      ),
    );

    expect(find.text('Nila Staff'), findsOneWidget);
    expect(find.text('Moving'), findsOneWidget);
    expect(find.text(address), findsOneWidget);
    expect(find.textContaining('11.2588'), findsNothing);
    expect(find.textContaining('75.7804'), findsNothing);
  });

  testWidgets(
    'address falls back to "Address unavailable" when the server has none',
    (tester) async {
      final staff = StaffLocation(
        userId: 7,
        name: 'Nila Staff',
        position: LatLng(11.2588, 75.7804),
        state: StaffState.moving,
        address: null,
        recordedAt: DateTime(2026, 9, 10, 14, 30),
        colorIndex: 7,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.build(),
          home: Scaffold(
            body: StaffRow(
              staff: staff,
              isSelected: false,
              onTrace: () {},
              onFocus: () {},
            ),
          ),
        ),
      );

      expect(find.text('Address unavailable'), findsOneWidget);
    },
  );

  for (final testCase in [
    (StaffState.stuck, 'Stuck'),
    (StaffState.connectionLost, 'Connection lost'),
    (StaffState.locationDisabled, 'Location off'),
  ]) {
    final (state, label) = testCase;
    testWidgets('shows the $label badge for StaffState.$state', (
      tester,
    ) async {
      final staff = StaffLocation(
        userId: 7,
        name: 'Nila Staff',
        position: LatLng(11.2588, 75.7804),
        state: state,
        address: 'West Hill, Kozhikode, Kerala',
        recordedAt: DateTime(2026, 9, 10, 14, 30),
        colorIndex: 7,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.build(),
          home: Scaffold(
            body: StaffRow(
              staff: staff,
              isSelected: false,
              onTrace: () {},
              onFocus: () {},
            ),
          ),
        ),
      );

      expect(find.text(label), findsOneWidget);
    });
  }

  testWidgets('shows a low-battery icon and the percentage below 20%', (
    tester,
  ) async {
    final staff = StaffLocation(
      userId: 7,
      name: 'Nila Staff',
      position: LatLng(11.2588, 75.7804),
      state: StaffState.moving,
      address: 'West Hill, Kozhikode, Kerala',
      recordedAt: DateTime(2026, 9, 10, 14, 30),
      colorIndex: 7,
      batteryLevel: 15,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.build(),
        home: Scaffold(
          body: StaffRow(
            staff: staff,
            isSelected: false,
            onTrace: () {},
            onFocus: () {},
          ),
        ),
      ),
    );

    expect(find.text('15%'), findsOneWidget);
    expect(find.byIcon(Icons.battery_alert_rounded), findsOneWidget);
  });

  testWidgets('tapping the row calls onFocus, tapping Trace calls onTrace', (
    tester,
  ) async {
    var focused = false;
    var traced = false;
    final staff = StaffLocation(
      userId: 7,
      name: 'Nila Staff',
      position: LatLng(11.2588, 75.7804),
      state: StaffState.moving,
      address: 'West Hill, Kozhikode, Kerala',
      recordedAt: DateTime(2026, 9, 10, 14, 30),
      colorIndex: 7,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.build(),
        home: Scaffold(
          body: StaffRow(
            staff: staff,
            isSelected: false,
            onTrace: () => traced = true,
            onFocus: () => focused = true,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Trace'));
    expect(traced, isTrue);
    expect(focused, isFalse);

    await tester.tap(find.text('Nila Staff'));
    expect(focused, isTrue);
  });
}
