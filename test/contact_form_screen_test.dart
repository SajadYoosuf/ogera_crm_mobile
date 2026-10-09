import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ogera_crm_mobile/core/network/api_client.dart';
import 'package:ogera_crm_mobile/core/widgets/form_fields.dart';
import 'package:ogera_crm_mobile/models/auth_session.dart';
import 'package:ogera_crm_mobile/services/crm_services.dart';
import 'package:ogera_crm_mobile/services/geocoding_service.dart';
import 'package:ogera_crm_mobile/services/location_api_service.dart';
import 'package:ogera_crm_mobile/services/location_tracking_service.dart';
import 'package:ogera_crm_mobile/theme/app_theme.dart';
import 'package:ogera_crm_mobile/view_models/session_view_model.dart';
import 'package:ogera_crm_mobile/views/contacts/contact_form_screen.dart';
import 'package:provider/provider.dart';

import 'test_helpers.dart';

void main() {
  testWidgets('contact form picks values and posts a consumer to /contacts', (
    tester,
  ) async {
    Map<String, dynamic>? payload;
    final api = ApiClient(
      baseUrl: 'https://crm.test',
      client: MockClient((request) async {
        if (request.method == 'GET' && request.url.path == '/lead-sources') {
          return http.Response(
            jsonEncode([
              {'id': 4, 'name': 'Showroom', 'slug': 'showroom'},
              {'id': 3, 'name': 'Offline', 'slug': 'offline'},
            ]),
            200,
          );
        }
        if (request.method == 'POST' && request.url.path == '/contacts') {
          payload = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({
              ...payload!,
              'id': 42,
              'created_at': '2026-09-10T00:00:00',
            }),
            201,
          );
        }
        return http.Response('Not found', 404);
      }),
    );
    final session = SessionViewModel(
      auth: FakeAuthService(),
      api: api,
      tracking: LocationTrackingService(
        LocationApiService(api),
        NoopLocationQueue(),
      ),
    );
    await session.adopt(
      const AuthSession(
        accessToken: 'token',
        user: AuthUser(
          id: 1,
          email: 'head@ogera.com',
          name: 'Head',
          phone: null,
          role: UserRole.salesHead,
        ),
      ),
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<ContactsService>(create: (_) => ContactsService(api)),
          Provider<GeocodingService>(create: (_) => GeocodingService()),
          ChangeNotifierProvider<SessionViewModel>.value(value: session),
        ],
        child: MaterialApp(
          theme: AppTheme.build(),
          home: const ContactFormScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, 'Name'), 'Amina');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Phone *'),
      '9876543210',
    );
    await _pick(tester, label: 'Source', option: 'Showroom');
    await _pick(tester, label: 'District', option: 'Malappuram');
    final address = find.widgetWithText(TextFormField, 'Address *');
    await tester.dragUntilVisible(
      address,
      find.byType(Scrollable).first,
      const Offset(0, -200),
    );
    await tester.enterText(address, 'Near the bus stand');
    await _pick(tester, label: 'House stage', option: 'Ready');

    final save = find.widgetWithText(FilledButton, 'Add contact');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(payload, isNotNull);
    expect(payload, containsPair('contact_type', 'consumer'));
    expect(payload, containsPair('name', 'Amina'));
    expect(payload, containsPair('phone', '9876543210'));
    expect(payload, containsPair('lead_source_id', 4));
    expect(payload, containsPair('district', 'Malappuram'));
    expect(payload, containsPair('address', 'Near the bus stand'));
    expect(payload!['consumer_profile'], {
      'awareness_mode': 0,
      'house_stage': 'Ready',
    });
    // The campaign section is gone: the API has nowhere to store it.
    expect(find.text('Campaign target'), findsNothing);
  });

  testWidgets('saving without a district is stopped on the phone', (
    tester,
  ) async {
    var posted = false;
    final api = ApiClient(
      baseUrl: 'https://crm.test',
      client: MockClient((request) async {
        if (request.method == 'POST') posted = true;
        return http.Response(jsonEncode([]), 200);
      }),
    );
    final session = SessionViewModel(
      auth: FakeAuthService(),
      api: api,
      tracking: LocationTrackingService(
        LocationApiService(api),
        NoopLocationQueue(),
      ),
    );
    await session.adopt(
      const AuthSession(
        accessToken: 'token',
        user: AuthUser(
          id: 1,
          email: 'head@ogera.com',
          name: 'Head',
          phone: null,
          role: UserRole.salesHead,
        ),
      ),
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<ContactsService>(create: (_) => ContactsService(api)),
          Provider<GeocodingService>(create: (_) => GeocodingService()),
          ChangeNotifierProvider<SessionViewModel>.value(value: session),
        ],
        child: MaterialApp(
          theme: AppTheme.build(),
          home: const ContactFormScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Phone *'),
      '9876543210',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Address *'),
      'Near the bus stand',
    );
    final save = find.widgetWithText(FilledButton, 'Add contact');
    await tester.ensureVisible(save);
    await tester.tap(save);
    // The toast times out, so look before the animations settle.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // The district comes first, and the request is never sent.
    expect(find.text('Select the district.'), findsOneWidget);
    expect(posted, isFalse);
  });

  testWidgets('an empty address is flagged on the field itself', (
    tester,
  ) async {
    var posted = false;
    final api = ApiClient(
      baseUrl: 'https://crm.test',
      client: MockClient((request) async {
        if (request.method == 'POST') posted = true;
        return http.Response(jsonEncode([]), 200);
      }),
    );
    final session = SessionViewModel(
      auth: FakeAuthService(),
      api: api,
      tracking: LocationTrackingService(
        LocationApiService(api),
        NoopLocationQueue(),
      ),
    );
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<ContactsService>(create: (_) => ContactsService(api)),
          Provider<GeocodingService>(create: (_) => GeocodingService()),
          ChangeNotifierProvider<SessionViewModel>.value(value: session),
        ],
        child: MaterialApp(
          theme: AppTheme.build(),
          home: const ContactFormScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Phone *'),
      '9876543210',
    );
    final save = find.widgetWithText(FilledButton, 'Add contact');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(find.text('Enter the address.'), findsOneWidget);
    expect(posted, isFalse);
  });
}

Future<void> _pick(
  WidgetTester tester, {
  required String label,
  required String option,
}) async {
  final field = find.byWidgetPredicate(
    (widget) => widget is OgeraPickerField && widget.label == label,
  );
  // The form is a lazy ListView, so a field below the fold is not built yet.
  await tester.dragUntilVisible(
    field,
    find.byType(Scrollable).first,
    const Offset(0, -200),
  );
  await tester.pumpAndSettle();
  await tester.tap(field);
  await tester.pumpAndSettle();
  await tester.tap(find.text(option).last);
  await tester.pumpAndSettle();
}
