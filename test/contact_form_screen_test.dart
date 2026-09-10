import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ogera_crm_mobile/core/network/api_client.dart';
import 'package:ogera_crm_mobile/models/auth_session.dart';
import 'package:ogera_crm_mobile/services/auth_service.dart';
import 'package:ogera_crm_mobile/services/crm_services.dart';
import 'package:ogera_crm_mobile/services/geocoding_service.dart';
import 'package:ogera_crm_mobile/services/location_api_service.dart';
import 'package:ogera_crm_mobile/services/location_queue.dart';
import 'package:ogera_crm_mobile/services/location_tracking_service.dart';
import 'package:ogera_crm_mobile/theme/app_theme.dart';
import 'package:ogera_crm_mobile/view_models/session_view_model.dart';
import 'package:ogera_crm_mobile/core/widgets/form_fields.dart';
import 'package:ogera_crm_mobile/views/contacts/contact_form_screen.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('contact form selects dropdown values and submits the payload', (
    tester,
  ) async {
    Map<String, dynamic>? payload;
    final api = ApiClient(
      baseUrl: 'https://crm.test',
      client: MockClient((request) async {
        if (request.method == 'GET' && request.url.path == '/api/staff') {
          return http.Response(jsonEncode({'success': true, 'data': []}), 200);
        }
        if (request.method == 'POST' && request.url.path == '/api/contacts') {
          payload = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'id': 42,
                'phone': payload!['phone'],
                'name': payload!['name'],
                'contactType': payload!['contactType'],
                'source': payload!['source'],
                'district': payload!['district'],
                'houseStage': payload!['houseStage'],
                'createdAt': '2026-09-10T00:00:00.000Z',
              },
            }),
            200,
          );
        }
        return http.Response('Not found', 404);
      }),
    );
    final session = SessionViewModel(
      auth: _FakeAuthService(),
      api: api,
      tracking: LocationTrackingService(
        LocationApiService(api),
        LocationQueue(),
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
          Provider<StaffDirectoryService>(
            create: (_) => StaffDirectoryService(api),
          ),
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

    await tester.enterText(_textField('Name'), 'Amina');
    await tester.enterText(_textField('Phone *'), '9876543210');

    await _pick(tester, label: 'Source', option: 'Showroom');
    await _pick(tester, label: 'District', option: 'Malappuram');
    await _pick(tester, label: 'House stage', option: 'Under Construction');
    await _pick(tester, label: 'Construction phase', option: 'Plastering');

    await tester.tap(find.widgetWithText(FilledButton, 'Add contact'));
    await tester.pumpAndSettle();

    expect(payload, isNotNull);
    expect(payload, containsPair('name', 'Amina'));
    expect(payload, containsPair('phone', '9876543210'));
    expect(payload, containsPair('source', 'showroom'));
    expect(payload, containsPair('district', 'Malappuram'));
    expect(
      payload,
      containsPair('houseStage', 'Under Construction - Plastering'),
    );
  });
}

Finder _textField(String label) {
  return find.byWidgetPredicate(
    (widget) => widget is TextFormField && widget.decoration?.labelText == label,
  );
}

Future<void> _pick(
  WidgetTester tester, {
  required String label,
  required String option,
}) async {
  final field = find.byWidgetPredicate(
    (widget) => widget is OgeraPickerField && widget.label == label,
  );
  await tester.ensureVisible(field);
  await tester.pumpAndSettle();
  await tester.tap(field);
  await tester.pumpAndSettle();
  await tester.tap(find.text(option).last);
  await tester.pumpAndSettle();
}

class _FakeAuthService implements AuthService {
  @override
  Future<AuthSession> signIn({
    required String email,
    required String password,
    required LoginScope scope,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<AuthSession?> restore() async => null;

  @override
  Future<void> signOut() async {}
}
