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
}
