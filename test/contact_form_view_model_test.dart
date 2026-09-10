import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ogera_crm_mobile/core/network/api_client.dart';
import 'package:ogera_crm_mobile/models/contact.dart';
import 'package:ogera_crm_mobile/services/crm_services.dart';
import 'package:ogera_crm_mobile/view_models/contacts_view_model.dart';

void main() {
  group('ContactFormViewModel', () {
    test('requires campaign staff before saving a campaign target', () async {
      var wasCalled = false;
      final viewModel = ContactFormViewModel(
        ContactsService(
          ApiClient(
            baseUrl: 'https://crm.test',
            client: MockClient((request) async {
              wasCalled = true;
              return http.Response('{}', 500);
            }),
          ),
        ),
      );

      viewModel.setCampaign(isTarget: true);

      final saved = await viewModel.save();

      expect(saved, isNull);
      expect(wasCalled, isFalse);
      expect(
        viewModel.error,
        'Select which staff this campaign-target contact belongs to.',
      );
    });

    test('creates a contact with selected dropdown values', () async {
      Map<String, dynamic>? payload;
      final api = ApiClient(
        baseUrl: 'https://crm.test',
        client: MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.path, '/api/contacts');
          payload = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'id': 31,
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
        }),
      );
      final viewModel = ContactFormViewModel(ContactsService(api));
      viewModel.draft
        ..name = 'Amina'
        ..phone = '9876543210'
        ..source = 'showroom'
        ..district = 'Malappuram'
        ..houseStage = 'Ready';

      final saved = await viewModel.save();

      expect(saved, isNotNull);
      expect(saved!.id, 31);
      expect(payload, containsPair('name', 'Amina'));
      expect(payload, containsPair('phone', '9876543210'));
      expect(payload, containsPair('source', 'showroom'));
      expect(payload, containsPair('district', 'Malappuram'));
      expect(payload, containsPair('houseStage', 'Ready'));
      expect(payload, containsPair('contactType', ContactType.lead.id));
    });
  });
}
