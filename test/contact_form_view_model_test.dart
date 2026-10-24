import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ogera_crm_mobile/core/network/api_client.dart';
import 'package:ogera_crm_mobile/models/contact.dart';
import 'package:ogera_crm_mobile/services/crm_services.dart';
import 'package:ogera_crm_mobile/view_models/contacts_view_model.dart';

const _sources = [
  {'id': 1, 'name': 'Meta', 'slug': 'meta'},
  {'id': 3, 'name': 'Offline', 'slug': 'offline'},
  {'id': 4, 'name': 'Showroom', 'slug': 'showroom'},
];

/// An API that records every call and answers `/lead-sources` and `POST /contacts`.
class _Recorder {
  final calls = <http.Request>[];
  Map<String, dynamic>? posted;

  ApiClient get api => ApiClient(
    baseUrl: 'https://crm.test',
    client: MockClient((request) async {
      calls.add(request);
      if (request.url.path == '/lead-sources') {
        return http.Response(jsonEncode(_sources), 200);
      }
      posted = jsonDecode(request.body) as Map<String, dynamic>;
      return http.Response(
        jsonEncode({
          ...posted!,
          'id': 31,
          'created_at': '2026-09-10T00:00:00',
          'lead_source': _sources.firstWhere(
            (s) => s['id'] == posted!['lead_source_id'],
            orElse: () => const {},
          ),
        }),
        201,
      );
    }),
  );
}

void main() {
  group('ContactFormViewModel', () {
    test('requires campaign staff before saving a campaign target', () async {
      final recorder = _Recorder();
      final viewModel = ContactFormViewModel(ContactsService(recorder.api));

      viewModel.setCampaign(isTarget: true);
      final saved = await viewModel.save();

      expect(saved, isNull);
      expect(recorder.calls, isEmpty);
      expect(
        viewModel.error,
        'Select which staff this campaign-target contact belongs to.',
      );
    });

    test(
      'asks for a district and an address before calling the server',
      () async {
        final recorder = _Recorder();
        final viewModel = ContactFormViewModel(ContactsService(recorder.api));
        viewModel.draft
          ..phone = '9876543210'
          ..source = 'showroom';

        expect(await viewModel.save(), isNull);
        expect(viewModel.error, 'Select the district.');

        viewModel.draft.district = 'Malappuram';
        expect(await viewModel.save(), isNull);
        expect(viewModel.error, 'Enter the address.');
        expect(recorder.calls, isEmpty);
      },
    );

    test('an Offline contact must come with a captured location', () async {
      final recorder = _Recorder();
      final viewModel = ContactFormViewModel(ContactsService(recorder.api));
      viewModel.draft
        ..phone = '9876543210'
        ..source = 'offline'
        ..district = 'Malappuram'
        ..address = 'Near the bus stand';

      expect(await viewModel.save(), isNull);
      expect(viewModel.error, 'Capture the location for an Offline contact.');
      expect(recorder.calls, isEmpty);
    });

    test(
      'creates a contact as a consumer with the source resolved to its id',
      () async {
        final recorder = _Recorder();
        final viewModel = ContactFormViewModel(ContactsService(recorder.api));
        viewModel.draft
          ..name = 'Amina'
          ..phone = '9876543210'
          ..source = 'showroom'
          ..district = 'Malappuram'
          ..address = 'Near the bus stand'
          ..houseStage = 'ready';

        final saved = await viewModel.save();

        expect(saved, isNotNull);
        expect(saved!.id, 31);
        expect(recorder.calls.last.method, 'POST');
        expect(recorder.calls.last.url.path, '/contacts');
        expect(recorder.posted, containsPair('contact_type', 'consumer'));
        expect(recorder.posted, containsPair('name', 'Amina'));
        expect(recorder.posted, containsPair('phone', '9876543210'));
        expect(recorder.posted, containsPair('district', 'Malappuram'));
        expect(recorder.posted, containsPair('address', 'Near the bus stand'));
        expect(recorder.posted, containsPair('lead_source_id', 4));
        expect(recorder.posted!['consumer_profile'], {
          'awareness_mode': 0,
          'house_stage': 'ready',
        });
        // Coordinates are only allowed with the Offline source.
        expect(recorder.posted!.containsKey('latitude'), isFalse);
      },
    );

    test('a new contact defaults to the Offline source', () {
      final viewModel = ContactFormViewModel(ContactsService(_Recorder().api));
      expect(viewModel.draft.source, 'offline');
    });

    test('a partner contact is sent with contact_type partner', () async {
      final recorder = _Recorder();
      final viewModel = ContactFormViewModel(ContactsService(recorder.api));
      viewModel.setType(ContactKind.partner);
      viewModel.draft
        ..phone = '9876543210'
        ..source = 'meta'
        ..district = 'Kannur'
        ..address = 'Main road';

      await viewModel.save();

      expect(recorder.posted, containsPair('contact_type', 'partner'));
      // No name typed: the phone number stands in so the API accepts it.
      expect(recorder.posted, containsPair('name', '9876543210'));
    });

    test('an Offline contact sends its coordinates', () async {
      final recorder = _Recorder();
      final viewModel = ContactFormViewModel(ContactsService(recorder.api));
      viewModel.draft
        ..phone = '9876543210'
        ..source = 'offline'
        ..district = 'Kannur'
        ..address = 'Main road'
        ..latitude = '11.250000'
        ..longitude = '75.780000';

      await viewModel.save();

      expect(recorder.posted, containsPair('lead_source_id', 3));
      expect(recorder.posted, containsPair('latitude', 11.25));
      expect(recorder.posted, containsPair('longitude', 75.78));
    });

    test('a referral by another contact is sent as referred_by_id', () async {
      final recorder = _Recorder();
      final viewModel = ContactFormViewModel(ContactsService(recorder.api));
      viewModel.setContactReferral(77);
      viewModel.draft
        ..phone = '9876543210'
        ..source = 'meta'
        ..district = 'Kannur'
        ..address = 'Main road';

      await viewModel.save();

      expect(recorder.posted, containsPair('referred_by_id', 77));
    });

    test('surfaces the server message when the save is rejected', () async {
      final api = ApiClient(
        baseUrl: 'https://crm.test',
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({'detail': 'Lead source not found'}),
            400,
          ),
        ),
      );
      final viewModel = ContactFormViewModel(ContactsService(api));
      viewModel.draft
        ..phone = '9876543210'
        ..source = null
        ..district = 'Kannur'
        ..address = 'Main road';

      expect(await viewModel.save(), isNull);
      expect(viewModel.error, 'Lead source not found');
    });
  });
}
