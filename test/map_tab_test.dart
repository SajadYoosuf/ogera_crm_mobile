import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ogera_crm_mobile/services/crm_services.dart';
import 'package:ogera_crm_mobile/services/location_api_service.dart';
import 'package:ogera_crm_mobile/theme/app_theme.dart';
import 'package:ogera_crm_mobile/view_models/map_view_model.dart';
import 'package:ogera_crm_mobile/views/map/map_tab.dart';
import 'package:provider/provider.dart';

import 'test_helpers.dart';

/// The Map module: layer switcher, per-layer filter pills, and the pin-count
/// legend. `flutter_map`'s tile layer would otherwise reach for the real
/// internet, so network is disabled for this whole file.
void main() {
  setUpAll(() {
    HttpOverrides.global = NoNetworkHttpOverrides();
  });

  tearDownAll(() {
    HttpOverrides.global = null;
  });

  testWidgets('Contacts layer shows the pin count and Lead/Awareness pills', (
    tester,
  ) async {
    final viewModel = await _loadedViewModel(canViewStaff: true);
    await tester.pumpWidget(_harness(viewModel));
    await tester.pumpAndSettle();

    expect(find.text('1 pin on the map'), findsOneWidget);
    expect(find.text('All contacts'), findsOneWidget);
    expect(find.text('Lead'), findsWidgets);
    expect(find.text('Awareness'), findsWidgets);
  });

  testWidgets('switching to Professionals updates the legend and pills', (
    tester,
  ) async {
    final viewModel = await _loadedViewModel(canViewStaff: true);
    await tester.pumpWidget(_harness(viewModel));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Professionals'));
    await tester.pumpAndSettle();

    expect(find.text('1 pin on the map'), findsOneWidget);
    expect(find.text('All trades'), findsOneWidget);
    expect(find.text('Plumber'), findsWidgets);
  });

  testWidgets('the Staff layer is only offered to a Head session', (
    tester,
  ) async {
    final headViewModel = await _loadedViewModel(canViewStaff: true);
    await tester.pumpWidget(_harness(headViewModel));
    await tester.pumpAndSettle();
    expect(find.text('Staff'), findsOneWidget);

    final staffViewModel = await _loadedViewModel(canViewStaff: false);
    await tester.pumpWidget(_harness(staffViewModel));
    await tester.pumpAndSettle();
    expect(find.text('Staff'), findsNothing);
  });
}

Future<MapViewModel> _loadedViewModel({required bool canViewStaff}) async {
  final api = fakeApiClient({
    '/contacts/map': (_) => {
      'items': [contactPinJson(id: 1, name: 'Amina Lead')],
      'total': 1,
    },
    // Professionals are the API's partner contacts.
    '/contacts': (_) => pageOf([
      professionalJson(
        id: 1,
        name: 'Arun Plumber',
        latitude: 11.25,
        longitude: 75.78,
      ),
    ]),
    '/staff/locations/live': (_) => {
      'staff': [staffLocationJson(userId: 9, name: 'Rahul Staff')],
    },
  });
  final viewModel = MapViewModel(
    contacts: ContactsService(api),
    professionals: ProfessionalsService(api),
    locations: LocationApiService(api),
    canViewStaff: canViewStaff,
  );
  await viewModel.load();
  return viewModel;
}

Widget _harness(MapViewModel viewModel) {
  return ChangeNotifierProvider<MapViewModel>.value(
    value: viewModel,
    child: MaterialApp(theme: AppTheme.build(), home: const MapTab()),
  );
}
