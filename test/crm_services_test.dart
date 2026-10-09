import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ogera_crm_mobile/core/network/api_client.dart';
import 'package:ogera_crm_mobile/models/contact.dart';
import 'package:ogera_crm_mobile/models/followup.dart';
import 'package:ogera_crm_mobile/models/professional.dart';
import 'package:ogera_crm_mobile/models/sale.dart';
import 'package:ogera_crm_mobile/services/crm_services.dart';

import 'test_helpers.dart';

/// A fake API that records every request and answers by `"METHOD /path"`.
/// A route returns the JSON body (status 200) or an [http.Response] for
/// anything else; a path nobody registered is a 404.
class FakeServer {
  FakeServer(this.routes);

  final Map<String, Object? Function(http.Request request)> routes;
  final calls = <http.Request>[];

  ApiClient get api => ApiClient(
    baseUrl: 'https://crm.test',
    client: MockClient((request) async {
      calls.add(request);
      final route = routes['${request.method} ${request.url.path}'];
      if (route == null) {
        return http.Response(jsonEncode({'detail': 'No route'}), 404);
      }
      final result = route(request);
      if (result is http.Response) return result;
      return http.Response(jsonEncode(result), 200);
    }),
  )..currentUserId = 5;

  Iterable<http.Request> to(String method, String path) =>
      calls.where((c) => c.method == method && c.url.path == path);

  Map<String, dynamic> bodyOf(String method, String path) =>
      jsonDecode(to(method, path).last.body) as Map<String, dynamic>;
}

const _sources = [
  {'id': 1, 'name': 'Meta', 'slug': 'meta'},
  {'id': 3, 'name': 'Offline', 'slug': 'offline'},
  {'id': 5, 'name': 'Website', 'slug': 'website'},
];

http.Response _json(int status, Object body) =>
    http.Response(jsonEncode(body), status);

void main() {
  group('LeadSourceCatalog', () {
    test('looks the sources up once and maps slugs to ids', () async {
      final server = FakeServer({'GET /lead-sources': (_) => _sources});
      final catalog = LeadSourceCatalog.of(server.api);

      expect(await catalog.idFor('meta'), 1);
      expect(await catalog.idFor('Offline'), 3);
      expect(await catalog.idFor('nope'), isNull);
      expect(await catalog.idFor(null), isNull);
      expect(await catalog.idFor('  '), isNull);
      expect(server.to('GET', '/lead-sources'), hasLength(1));
    });

    test('older labels are mapped onto current slugs', () async {
      final server = FakeServer({'GET /lead-sources': (_) => _sources});
      final catalog = LeadSourceCatalog.of(server.api);
      expect(await catalog.idFor('online'), 5);
      expect(LeadSourceCatalog.normalise('Meta'), 'meta');
    });
  });

  group('Contact.fromJson', () {
    test('reads a slim list row', () {
      final contact = Contact.fromJson({
        'id': 12,
        'contact_type': 'consumer',
        'name': 'Arun',
        'phone': '9876543210',
        'district': 'Calicut',
        'address': 'MG Road',
        'awareness_mode': 1,
        'latitude': 11.25,
        'longitude': 75.78,
        'lead_stage': {'stage': 'quoted', 'changed_at': '2026-09-20T14:30:00'},
        'lead_source': {'id': 3, 'name': 'Offline', 'slug': 'offline'},
        'assigned_to': {'id': 7, 'name': 'Anu'},
        'created_by': {'id': 2, 'name': 'Admin'},
        'created_at': '2026-09-01T10:00:00',
        'is_verified': false,
        'missing_fields': ['house_stage'],
      });

      expect(contact.id, 12);
      expect(contact.contactType, ContactType.awareness);
      expect(contact.stage, 'quoted');
      expect(contact.source, 'offline');
      expect(contact.leadSourceId, 3);
      expect(contact.followupAssignedTo, '7');
      expect(contact.followupAssignedUserId, 7);
      expect(contact.assignedToName, 'Anu');
      expect(contact.createdByUserId, 2);
      expect(contact.latitude, '11.25');
      expect(contact.hasLocation, isTrue);
      expect(contact.isVerified, isFalse);
      expect(contact.missingFields, ['house_stage']);
    });

    test('reads the full detail, with profile, referrer and numeric ids', () {
      final contact = Contact.fromJson({
        'id': 12,
        'name': 'Arun',
        'phone': '9876543210',
        'assigned_to': 7,
        'created_by': 2,
        'lead_source_id': 3,
        'referred_by_id': 4,
        'referred_by': {'id': 4, 'name': 'Beena', 'phone': '9000000000'},
        'assigned_employee': {'id': 7, 'name': 'Anu'},
        'lead_source': {'id': 3, 'name': 'Offline', 'slug': 'offline'},
        'current_stage': {'id': 5, 'stage': 'won'},
        'consumer_profile': {
          'awareness_mode': 0,
          'house_stage': 'Ready',
          'current_tank_type': 'plastic',
        },
        'created_at': '2026-09-01T10:00:00',
        'updated_at': '2026-09-20T14:30:00',
        'missing_fields': <String>[],
      });

      expect(contact.contactType, ContactType.lead);
      expect(contact.stage, 'won');
      expect(contact.houseStage, 'Ready');
      expect(contact.currentTank, 'plastic');
      expect(contact.referredByContactId, 4);
      expect(contact.referredByContactName, 'Beena');
      expect(contact.referralSummary, 'Contact · Beena');
      expect(contact.followupAssignedUserId, 7);
      expect(contact.assignedToName, 'Anu');
      expect(contact.isVerified, isTrue);
      expect(contact.updatedAt, isNotNull);
    });

    test('a contact without a profile is a lead', () {
      final contact = Contact.fromJson({'id': 1, 'phone': '1', 'name': 'x'});
      expect(contact.contactType, ContactType.lead);
      expect(contact.missingFields, isEmpty);
    });

    test('only a creator or a head may edit', () {
      final mine = Contact.fromJson({'id': 1, 'phone': '1', 'created_by': 4});
      final theirs = Contact.fromJson({'id': 2, 'phone': '1', 'created_by': 9});
      final orphan = Contact.fromJson({'id': 3, 'phone': '1'});
      expect(mine.isEditableBy(userId: 4, isPrivileged: false), isTrue);
      expect(theirs.isEditableBy(userId: 4, isPrivileged: false), isFalse);
      expect(orphan.isEditableBy(userId: 4, isPrivileged: false), isFalse);
      expect(orphan.isEditableBy(userId: 4, isPrivileged: true), isTrue);
    });
  });

  group('ContactsService', () {
    test(
      'list asks for consumers by awareness_mode and builds the page',
      () async {
        final server = FakeServer({
          'GET /contacts': (request) {
            final limit = int.parse(request.url.queryParameters['limit']!);
            return pageOf(
              limit == 1 ? [] : [contactJson(id: 1, name: 'A')],
              total: request.url.queryParameters['awareness_mode'] == '1'
                  ? 4
                  : 41,
              skip: int.parse(request.url.queryParameters['skip'] ?? '0'),
              limit: limit,
            );
          },
        });

        final page = await ContactsService(
          server.api,
        ).list(query: 'ar', type: ContactType.lead, page: 3, withCounts: true);

        final first = server.calls.first.url.queryParameters;
        expect(first['contact_type'], 'consumer');
        expect(first['awareness_mode'], '0');
        expect(first['search'], 'ar');
        expect(first['skip'], '40');
        expect(first['limit'], '20');
        expect(page.total, 41);
        expect(page.totalPages, 3);
        expect(page.page, 3);
        expect(page.leadsCount, 41);
        expect(page.awarenessCount, 4);
      },
    );

    test(
      'an unknown source filters to nothing instead of everything',
      () async {
        final server = FakeServer({
          'GET /lead-sources': (_) => _sources,
          'GET /contacts': (_) => pageOf([]),
        });

        await ContactsService(server.api).list(source: 'carrier-pigeon');

        expect(
          server
              .to('GET', '/contacts')
              .single
              .url
              .queryParameters['lead_source_id'],
          '-1',
        );
      },
    );

    test(
      'a known source filters by id; dates map to created_from/to',
      () async {
        final server = FakeServer({
          'GET /lead-sources': (_) => _sources,
          'GET /contacts': (_) => pageOf([]),
        });

        await ContactsService(server.api).list(
          source: 'offline',
          startDate: '2026-08-01',
          endDate: '2026-08-31',
        );

        final query = server.to('GET', '/contacts').single.url.queryParameters;
        expect(query['lead_source_id'], '3');
        expect(query['created_from'], '2026-08-01');
        expect(query['created_to'], '2026-08-31');
      },
    );

    test(
      'mapPins reads /contacts/map and skips rows without coordinates',
      () async {
        final server = FakeServer({
          'GET /contacts/map': (_) => {
            'items': [
              contactPinJson(id: 1, name: 'Pin', type: 'awareness'),
              {'id': 2, 'phone': '1', 'latitude': null, 'longitude': null},
            ],
            'total': 2,
          },
        });

        final pins = await ContactsService(
          server.api,
        ).mapPins(type: ContactType.awareness);

        expect(pins, hasLength(1));
        expect(pins.single.contactType, ContactType.awareness);
        final query = server.calls.single.url.queryParameters;
        expect(query['contact_type'], 'consumer');
        expect(query['awareness_mode'], '1');
      },
    );

    test('detail, update and delete use the contact id', () async {
      final server = FakeServer({
        'GET /contacts/9': (_) => {'id': 9, 'phone': '1', 'name': 'Nine'},
        'PUT /contacts/9': (_) => {'id': 9, 'phone': '1', 'name': 'Renamed'},
        'DELETE /contacts/9': (_) => http.Response('', 204),
        'GET /lead-sources': (_) => _sources,
      });
      final service = ContactsService(server.api);

      expect((await service.detail(9)).name, 'Nine');
      final updated = await service.update(
        9,
        ContactDraft(
          phone: '1',
          name: 'Renamed',
          district: 'Kannur',
          source: 'meta',
        ),
      );
      await service.delete(9);

      expect(updated.name, 'Renamed');
      expect(server.bodyOf('PUT', '/contacts/9')['lead_source_id'], 1);
      expect(server.to('DELETE', '/contacts/9'), hasLength(1));
    });

    test('a rejected create surfaces the server message', () async {
      final server = FakeServer({
        'POST /contacts': (_) => _json(400, {
          'detail': 'latitude and longitude are required for offline leads',
        }),
        'GET /lead-sources': (_) => _sources,
      });

      await expectLater(
        ContactsService(server.api).create(
          ContactDraft(
            phone: '9876543210',
            source: 'offline',
            district: 'x',
            address: 'y',
          ),
        ),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            'latitude and longitude are required for offline leads',
          ),
        ),
      );
    });
  });

  group('ProfessionalsService', () {
    test('list reads partner contacts, filtered by profession', () async {
      final server = FakeServer({
        'GET /contacts': (_) => pageOf([
          professionalJson(id: 1, name: 'Joy', type: 'Interior Designer'),
        ]),
      });

      final result = await ProfessionalsService(
        server.api,
      ).list(type: ProfessionalType.interiorDesigner, query: 'jo');

      final query = server.calls.single.url.queryParameters;
      expect(query['contact_type'], 'partner');
      expect(query['profession_type'], 'interior_designer');
      expect(query['search'], 'jo');
      expect(result.single.type, ProfessionalType.interiorDesigner);
      expect(result.single.name, 'Joy');
    });

    test('list pages through everything when it is long', () async {
      final server = FakeServer({
        'GET /contacts': (request) {
          final skip = int.parse(request.url.queryParameters['skip']!);
          return pageOf(
            [
              for (var i = 0; i < (skip == 0 ? 100 : 30); i++)
                professionalJson(id: skip + i + 1),
            ],
            total: 130,
            skip: skip,
            limit: 100,
          );
        },
      });

      final result = await ProfessionalsService(server.api).list();

      expect(result, hasLength(130));
      expect(server.calls, hasLength(2));
      expect(
        server.calls.first.url.queryParameters.containsKey('profession_type'),
        isFalse,
      );
    });

    test('Professional.fromJson reads detail and falls back to Other', () {
      final detail = Professional.fromJson({
        'id': 4,
        'phone': '9',
        'name': 'Kumar',
        'created_by': 3,
        'partner_profile': {
          'profession_type': 'architect',
          'work_area': 'Feroke',
        },
        'created_at': '2026-09-01T10:00:00',
      });
      expect(detail.type, ProfessionalType.architect);
      expect(detail.place, 'Feroke');
      expect(detail.createdByUserId, 3);
      expect(
        Professional.fromJson({
          'id': 1,
          'phone': '1',
          'profession_type': 'astronaut',
        }).type,
        ProfessionalType.other,
      );
    });

    test(
      'create sends a partner; coordinates ride with the Offline source',
      () async {
        final server = FakeServer({
          'GET /lead-sources': (_) => _sources,
          'POST /contacts': (request) => {
            ...jsonDecode(request.body) as Map<String, dynamic>,
            'id': 8,
            'created_at': '2026-09-01T10:00:00',
          },
        });

        final created = await ProfessionalsService(server.api).create(
          ProfessionalDraft(
            name: 'Maya',
            phone: '9876543210',
            type: ProfessionalType.plumber,
            place: 'Feroke',
            address: 'Beach Road',
            district: 'Kozhikode',
            latitude: '11.25',
            longitude: '75.78',
          ),
        );

        final body = server.bodyOf('POST', '/contacts');
        expect(body['contact_type'], 'partner');
        expect(body['partner_profile'], {
          'profession_type': 'plumber',
          'work_area': 'Feroke',
        });
        expect(body['lead_source_id'], 3);
        expect(body['latitude'], 11.25);
        expect(created.id, 8);
      },
    );

    test(
      'create without a location sends no source and no coordinates',
      () async {
        final server = FakeServer({
          'GET /lead-sources': (_) => _sources,
          'POST /contacts': (_) => {'id': 8, 'phone': '1'},
        });

        await ProfessionalsService(server.api).create(
          ProfessionalDraft(phone: '9876543210', district: 'x', address: 'y'),
        );

        final body = server.bodyOf('POST', '/contacts');
        expect(body.containsKey('lead_source_id'), isFalse);
        expect(body.containsKey('latitude'), isFalse);
      },
    );

    test('update and delete use the contact id', () async {
      final server = FakeServer({
        'GET /lead-sources': (_) => _sources,
        'PUT /contacts/8': (_) => {'id': 8, 'phone': '1', 'name': 'New'},
        'DELETE /contacts/8': (_) => http.Response('', 204),
      });
      final service = ProfessionalsService(server.api);

      final updated = await service.update(
        8,
        ProfessionalDraft(phone: '1', name: 'New', district: 'x', address: 'y'),
      );
      await service.delete(8);

      expect(updated.name, 'New');
      expect(server.to('DELETE', '/contacts/8'), hasLength(1));
    });
  });

  group('FollowupsService', () {
    Map<String, Object? Function(http.Request)> board({
      List<Map<String, dynamic>>? tasks,
    }) => {
      'GET /contacts': (_) => pageOf([
        leadJson(
          id: 1,
          name: 'One',
          stage: 'new_lead',
          missingFields: ['house_stage'],
        ),
        leadJson(id: 2, name: 'Two', stage: 'won'),
      ]),
      'GET /tasks': (_) => {
        'items': tasks ?? [],
        'total': (tasks ?? []).length,
        'summary': {'overdue': 0, 'today': 0, 'upcoming': 0, 'done': 0},
      },
    };

    test(
      'leads carry the earliest open follow-up date and missing details',
      () async {
        final server = FakeServer(
          board(
            tasks: [
              taskJson(id: 1, contactId: 1, scheduledDate: '2026-10-20'),
              taskJson(id: 2, contactId: 1, scheduledDate: '2026-10-12'),
              taskJson(id: 3, contactId: 2, scheduledDate: '2026-11-01'),
            ],
          ),
        );

        final leads = await FollowupsService(server.api).leads();

        expect(leads, hasLength(2));
        expect(leads[0].followupDueDate, '2026-10-12');
        expect(leads[1].followupDueDate, '2026-11-01');
        expect(leads[0].missingFields, ['house_stage']);
        expect(leads[0].missingQualification, ['House stage']);
        expect(leads[0].isQualified, isFalse);
        expect(leads[1].isQualified, isTrue);
        expect(leads[0].stage, 'new_lead');
        expect(leads[0].followupAssignedTo, '3');

        final tasks = server.to('GET', '/tasks').single.url.queryParameters;
        expect(tasks['status'], 'open');
        expect(tasks['include_overdue'], 'true');
      },
    );

    test('stages come back in board order', () async {
      final server = FakeServer({
        'GET /contacts/stage-types': (_) => [
          stageJson(id: 'won', label: 'Won', orderIndex: 2),
          stageJson(id: 'new_lead', label: 'New Lead', orderIndex: 0),
          stageJson(id: 'quoted', label: 'Quoted', orderIndex: 1),
        ],
      });

      final stages = await FollowupsService(server.api).stages();

      expect(stages.map((s) => s.id), ['new_lead', 'quoted', 'won']);
      expect(stages.first.label, 'New Lead');
    });

    test('moving a stage posts it with the signed-in employee', () async {
      final server = FakeServer({
        'POST /contacts/1/stages': (_) =>
            _json(201, {'id': 1, 'stage': 'first_call'}),
      });

      await FollowupsService(server.api).updateLead(1, stage: 'first_call');

      expect(server.bodyOf('POST', '/contacts/1/stages'), {
        'stage': 'first_call',
        'changed_by': 5,
      });
    });

    test('marking a lead lost gives the reason the API requires', () async {
      final server = FakeServer({
        'POST /contacts/1/stages': (_) =>
            _json(201, {'id': 1, 'stage': 'lost'}),
      });

      await FollowupsService(server.api).updateLead(1, stage: 'lost');

      expect(
        server.bodyOf('POST', '/contacts/1/stages')['loss_reason'],
        'other',
      );
    });

    test('a blocked stage change surfaces the missing details', () async {
      final server = FakeServer({
        'POST /contacts/1/stages': (_) => _json(409, {
          'detail': {
            'message': "Complete the lead's details before moving it",
            'missing_fields': ['house_stage'],
          },
        }),
      });

      await expectLater(
        FollowupsService(server.api).updateLead(1, stage: 'quoted'),
        throwsA(
          isA<ApiException>().having((e) => e.statusCode, 'status', 409).having(
            (e) => e.missingFields,
            'missing',
            ['house_stage'],
          ),
        ),
      );
    });

    test('reassigning updates the owner on the contact', () async {
      final server = FakeServer({
        'PUT /contacts/1': (_) => {'id': 1},
      });

      await FollowupsService(server.api).updateLead(1, assignedTo: '7');

      expect(server.bodyOf('PUT', '/contacts/1'), {'assigned_to': 7});
    });

    test('the API cannot unassign a lead or remove a date', () async {
      final service = FollowupsService(FakeServer({}).api);
      await expectLater(
        service.updateLead(1, clearAssignee: true),
        throwsA(isA<ApiException>()),
      );
      await expectLater(
        service.updateLead(1, clearDueDate: true),
        throwsA(isA<ApiException>()),
      );
    });

    test('a new due date books a call for the lead\'s owner', () async {
      final server = FakeServer({
        'GET /contacts/1/activities': (_) => [],
        'GET /contacts/1': (_) => {'id': 1, 'assigned_to': 7},
        'POST /contacts/1/activities': (_) => _json(201, {'id': 4}),
      });

      await FollowupsService(server.api).updateLead(1, dueDate: '2026-12-01');

      expect(server.bodyOf('POST', '/contacts/1/activities'), {
        'type': 'phone_call',
        'scheduled_date': '2026-12-01',
        'assigned_to': 7,
      });
    });

    test(
      'a new due date reschedules the open follow-up instead of adding one',
      () async {
        final server = FakeServer({
          'GET /contacts/1/activities': (_) => [
            {'id': 9, 'status': 'pending', 'scheduled_date': '2026-11-20'},
            {'id': 8, 'status': 'pending', 'scheduled_date': '2026-11-10'},
            {'id': 7, 'status': 'done', 'scheduled_date': '2026-10-01'},
            {'id': 6, 'status': 'done', 'scheduled_date': null},
          ],
          'PATCH /contacts/1/activities/8': (_) => {'id': 8},
        });

        await FollowupsService(server.api).updateLead(1, dueDate: '2026-12-01');

        expect(server.bodyOf('PATCH', '/contacts/1/activities/8'), {
          'scheduled_date': '2026-12-01',
        });
        expect(server.to('POST', '/contacts/1/activities'), isEmpty);
      },
    );

    test(
      'assigning and dating in one call books the task for the new owner',
      () async {
        final server = FakeServer({
          'PUT /contacts/1': (_) => {'id': 1},
          'GET /contacts/1/activities': (_) => [],
          'POST /contacts/1/activities': (_) => _json(201, {'id': 4}),
        });

        await FollowupsService(
          server.api,
        ).updateLead(1, assignedTo: '9', dueDate: '2026-12-01');

        expect(
          server.bodyOf('POST', '/contacts/1/activities')['assigned_to'],
          9,
        );
        expect(server.to('GET', '/contacts/1'), isEmpty);
      },
    );

    test(
      'remarks merge notes, follow-ups and stage moves, newest first',
      () async {
        final server = FakeServer({
          'GET /contacts/1/activities': (_) => [
            {
              'id': 1,
              'type': 'internal_note',
              'notes': 'Called twice',
              'status': 'done',
              'scheduled_date': null,
              'created_by': 3,
              'created_by_name': 'Anu',
              'created_at': '2026-09-02T10:00:00',
            },
            {
              'id': 2,
              'type': 'phone_call',
              'notes': 'Confirm quote',
              'status': 'pending',
              'scheduled_date': '2026-10-20',
              'created_by': 3,
              'created_by_name': 'Anu',
              'created_at': '2026-09-04T10:00:00',
            },
          ],
          'GET /contacts/1/stages': (_) => [
            {
              'id': 7,
              'stage': 'lost',
              'loss_reason': 'price',
              'changed_by': 3,
              'changed_at': '2026-09-03T09:00:00',
            },
          ],
        });

        final remarks = await FollowupsService(server.api).remarks(1);

        expect(remarks.map((r) => r.remark), [
          'Call follow-up due 2026-10-20 · Confirm quote',
          'Stage changed to Lost (Price)',
          'Called twice',
        ]);
        expect(remarks.map((r) => r.isSystem), [true, true, false]);
        expect(remarks.last.author, 'Anu');
        expect(remarks[1].author, 'System');
      },
    );

    test(
      'rows saved in the same second keep the server newest-first order',
      () async {
        const second = '2026-09-03T09:00:00';
        final server = FakeServer({
          'GET /contacts/1/activities': (_) => [],
          'GET /contacts/1/stages': (_) => [
            {
              'id': 30,
              'stage': 'connected',
              'changed_by': 3,
              'changed_at': second,
            },
            {
              'id': 20,
              'stage': 'first_call',
              'changed_by': 3,
              'changed_at': second,
            },
            {
              'id': 10,
              'stage': 'new_lead',
              'changed_by': 3,
              'changed_at': second,
            },
          ],
        });

        final remarks = await FollowupsService(server.api).remarks(1);

        expect(remarks.map((r) => r.remark), [
          'Stage changed to Connected',
          'Stage changed to First Call',
          'Stage changed to New Lead',
        ]);
      },
    );

    test('adding a remark posts an internal note', () async {
      final server = FakeServer({
        'POST /contacts/1/activities': (_) => _json(201, {'id': 1}),
      });

      await FollowupsService(server.api).addRemark(1, 'Will order Friday');

      expect(server.bodyOf('POST', '/contacts/1/activities'), {
        'type': 'internal_note',
        'notes': 'Will order Friday',
      });
    });

    test('deleting a lead soft-deletes the contact', () async {
      final server = FakeServer({
        'DELETE /contacts/1': (_) => http.Response('', 204),
      });
      await FollowupsService(server.api).deleteLead(1);
      expect(server.to('DELETE', '/contacts/1'), hasLength(1));
    });

    test('stages are fixed on the server', () async {
      final service = FollowupsService(FakeServer({}).api);
      await expectLater(
        service.createStage('New'),
        throwsA(isA<ApiException>()),
      );
      await expectLater(
        service.updateStage('won', label: 'Closed'),
        throwsA(isA<ApiException>()),
      );
    });
  });

  group('SalesService', () {
    test('list maps the register and its paging', () async {
      final server = FakeServer({
        'GET /sales': (_) => {
          'items': [
            {
              'id': 3,
              'purchase_date': '2026-09-01',
              'name': 'Buyer One',
              'phone': '9947270717',
              'address': 'Feroke',
              'purchased_product': '500 LTR Tank',
              'created_at': '2026-09-02T10:00:00',
            },
          ],
          'total': 45,
          'skip': 20,
          'limit': 20,
        },
      });

      final page = await SalesService(server.api).list(
        query: 'buyer',
        startDate: '2026-09-01',
        endDate: '2026-09-30',
        page: 2,
      );

      final query = server.calls.single.url.queryParameters;
      expect(query['search'], 'buyer');
      expect(query['purchased_from'], '2026-09-01');
      expect(query['purchased_to'], '2026-09-30');
      expect(query['skip'], '20');
      expect(page.total, 45);
      expect(page.page, 2);
      expect(page.totalPages, 3);
      final sale = page.sales.single;
      expect(sale.buyerName, 'Buyer One');
      expect(sale.buyerPhone, '9947270717');
      expect(sale.saleDate, '2026-09-01');
      expect(sale.tankSize, '500 LTR Tank');
      expect(sale.address, 'Feroke');
    });

    test('create and update send the register columns', () async {
      final server = FakeServer({
        'POST /sales': (_) =>
            _json(201, {'id': 1, 'name': 'Buyer', 'phone': '9'}),
        'PUT /sales/1': (_) => {'id': 1, 'name': 'Buyer 2', 'phone': '9'},
        'DELETE /sales/1': (_) => http.Response('', 204),
      });
      final service = SalesService(server.api);
      final draft = SaleDraft(
        saleDate: '2026-09-01',
        buyerName: ' Buyer ',
        buyerPhone: '9947270717',
        address: 'Feroke',
        tankSize: '500 LTR Tank',
      );

      await service.create(draft);
      final updated = await service.update(1, draft);
      await service.delete(1);

      expect(server.bodyOf('POST', '/sales'), {
        'purchase_date': '2026-09-01',
        'name': 'Buyer',
        'phone': '9947270717',
        'address': 'Feroke',
        'purchased_product': '500 LTR Tank',
      });
      expect(updated.buyerName, 'Buyer 2');
      expect(server.to('DELETE', '/sales/1'), hasLength(1));
    });

    test('products turn plain names into options', () async {
      final server = FakeServer({
        'GET /sales/products': (_) => ['200 LTR Tank', '500 LTR Tank'],
      });
      final products = await SalesService(server.api).products();
      expect(products.map((p) => p.name), ['200 LTR Tank', '500 LTR Tank']);
      expect(products.map((p) => p.id), [1, 2]);
    });

    test('search is a short list query; referrals make no request', () async {
      final server = FakeServer({
        'GET /sales': (_) => {
          'items': [
            {'id': 1, 'name': 'Found', 'phone': '9'},
          ],
          'total': 1,
          'skip': 0,
          'limit': 10,
        },
      });
      final service = SalesService(server.api);

      expect((await service.search('fou')).single.buyerName, 'Found');
      expect(server.calls.single.url.queryParameters['limit'], '10');

      expect(await service.referrals(1), isEmpty);
      expect(server.calls, hasLength(1));
    });

    test('a non-manager write is refused with the server message', () async {
      final server = FakeServer({
        'POST /sales': (_) => _json(403, {
          'detail': 'You do not have permission to perform this action',
        }),
      });
      await expectLater(
        SalesService(server.api).create(SaleDraft(buyerName: 'x')),
        throwsA(
          isA<ApiException>().having(
            (e) => e.kind,
            'kind',
            FailureKind.forbidden,
          ),
        ),
      );
    });
  });

  group('StaffDirectoryService', () {
    test('reads the open directory', () async {
      final server = FakeServer({
        'GET /employees/directory': (_) => [
          {'id': 3, 'name': 'Anu', 'role': 'sales_executive', 'phone': '9'},
          {'id': 4, 'name': 'Raj', 'role': 'field_executive', 'phone': null},
        ],
      });

      final staff = await StaffDirectoryService(server.api).list();

      expect(staff.map((s) => s.name), ['Anu', 'Raj']);
      expect(staff.first.id, '3');
      expect(staff.first.numericId, 3);
    });
  });
}
