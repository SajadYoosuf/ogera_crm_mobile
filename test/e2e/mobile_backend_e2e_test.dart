import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ogera_crm_mobile/core/network/api_client.dart';
import 'package:ogera_crm_mobile/core/utils/formatters.dart';
import 'package:ogera_crm_mobile/models/auth_session.dart';
import 'package:ogera_crm_mobile/models/contact.dart';
import 'package:ogera_crm_mobile/models/professional.dart';
import 'package:ogera_crm_mobile/models/sale.dart';
import 'package:ogera_crm_mobile/models/staff_location.dart';
import 'package:ogera_crm_mobile/services/auth_service.dart';
import 'package:ogera_crm_mobile/services/crm_services.dart';
import 'package:ogera_crm_mobile/services/location_api_service.dart';
import 'package:ogera_crm_mobile/view_models/contacts_view_model.dart';
import 'package:ogera_crm_mobile/view_models/followups_view_model.dart';

/// End to end: the app's real services and view models talk over real HTTP to
/// the real FastAPI backend, on a throwaway SQLite database.
///
/// Run it with `python tests/run_mobile_e2e.py` from `ogera_crm_backend`, which
/// starts the server and sets E2E_API_URL. Without that variable every test in
/// this file is skipped, so a plain `flutter test` stays offline.
///
/// The scenarios build on one another (a contact is created, verified, moved
/// through the pipeline, then removed), so they run in order.

const _password = 'Passw0rd!';

class _MemoryStore implements SessionStore {
  AuthSession? saved;

  @override
  Future<void> save(AuthSession session) async => saved = session;

  @override
  Future<AuthSession?> read() async => saved;

  @override
  Future<void> clear() async => saved = null;
}

/// One signed-in person: an [ApiClient] with their token, as the app builds it.
class _Phone {
  _Phone(this.api, this.session);

  final ApiClient api;
  final AuthSession session;

  AuthUser get user => session.user;
  ContactsService get contacts => ContactsService(api);
  ProfessionalsService get professionals => ProfessionalsService(api);
  FollowupsService get followups => FollowupsService(api);
  SalesService get sales => SalesService(api);
  PerformanceService get performance => PerformanceService(api);
  StaffDirectoryService get staff => StaffDirectoryService(api);
  LocationApiService get locations => LocationApiService(api);
}

void main() {
  final baseUrl = Platform.environment['E2E_API_URL'];
  if (baseUrl == null || baseUrl.isEmpty) {
    test(
      'mobile <-> backend end to end',
      () {},
      skip: 'Set E2E_API_URL (see tests/run_mobile_e2e.py) to run these.',
    );
    return;
  }

  Future<_Phone> signIn(String who, LoginScope scope) async {
    final api = ApiClient(baseUrl: baseUrl);
    final session = await AuthService(
      api,
      _MemoryStore(),
    ).signIn(email: '$who@example.com', password: _password, scope: scope);
    return _Phone(api, session);
  }

  late _Phone admin;
  late _Phone manager;
  late _Phone anu;
  late _Phone raj;

  setUpAll(() async {
    admin = await signIn('admin', LoginScope.head);
    manager = await signIn('manager', LoginScope.head);
    anu = await signIn('anu', LoginScope.staff);
    raj = await signIn('raj', LoginScope.staff);
  });

  group('sign in', () {
    test('roles fold into the Head and Staff audiences', () {
      expect(admin.user.role, UserRole.admin);
      expect(manager.user.role, UserRole.salesHead);
      expect(admin.user.isHead && manager.user.isHead, isTrue);
      expect(anu.user.isStaff && raj.user.isStaff, isTrue);
      expect(anu.user.name, 'Anu Sales');
      expect(anu.api.currentUserId, anu.user.id);
    });

    test('a wrong password shows the server message', () async {
      await expectLater(
        AuthService(ApiClient(baseUrl: baseUrl), _MemoryStore()).signIn(
          email: 'anu@example.com',
          password: 'nope',
          scope: LoginScope.staff,
        ),
        throwsA(
          isA<AuthException>().having(
            (e) => e.message,
            'message',
            'Invalid email or password',
          ),
        ),
      );
    });

    test('the wrong login tab is refused', () async {
      await expectLater(
        signIn('anu', LoginScope.head),
        throwsA(
          isA<AuthException>().having((e) => e.code, 'code', 'SCOPE_MISMATCH'),
        ),
      );
    });

    test('a request with no token is refused', () async {
      await expectLater(
        ContactsService(ApiClient(baseUrl: baseUrl)).list(),
        throwsA(
          isA<ApiException>().having(
            (e) => e.statusCode,
            'status',
            anyOf(401, 403),
          ),
        ),
      );
    });
  });

  group('contacts', () {
    late Contact offline;
    late Contact aware;

    test(
      'an Offline contact needs its location and then lists as a lead',
      () async {
        final draft = ContactDraft(
          name: 'Arun Kumar',
          phone: '9876543210',
          source: 'offline',
          district: 'Kozhikode',
          address: 'House 4, MG Road',
          latitude: '11.258800',
          longitude: '75.780400',
          houseStage: 'Ready',
        );
        offline = await admin.contacts.create(draft);

        expect(offline.id, greaterThan(0));
        expect(offline.contactType, ContactType.lead);
        expect(offline.source, 'offline');
        expect(offline.stage, 'new_lead');
        expect(offline.houseStage, 'Ready');
        expect(offline.hasLocation, isTrue);
        expect(offline.lat, closeTo(11.2588, 1e-6));
        expect(offline.followupAssignedUserId, isNotNull);
        expect(offline.createdByUserId, admin.user.id);
      },
    );

    test(
      'an awareness contact from a non-offline source carries no coordinates',
      () async {
        aware = await admin.contacts.create(
          ContactDraft(
            name: 'Beena',
            phone: '9876500000',
            source: 'meta',
            district: 'Kannur',
            address: 'Main road',
            contactType: ContactType.awareness,
          ),
        );
        expect(aware.contactType, ContactType.awareness);
        expect(aware.source, 'meta');
        expect(aware.hasLocation, isFalse);
        // No house stage yet, so the API reports the gap.
        expect(aware.isVerified, isFalse);
      },
    );

    test('coordinates are not sent for a non-offline source', () async {
      final contact = await admin.contacts.create(
        ContactDraft(
          phone: '9876511111',
          source: 'meta',
          district: 'Kannur',
          address: 'x',
          latitude: '11.0',
          longitude: '75.0',
        ),
      );
      // The API would reject a pin on a Meta lead; the draft left it out.
      expect(contact.hasLocation, isFalse);
      // No name was typed, so the phone number stands in for it.
      expect(contact.name, '9876511111');
      await admin.contacts.delete(contact.id);
    });

    test('the server still guards the Offline rule', () async {
      await expectLater(
        admin.contacts.create(
          ContactDraft(
            phone: '9876522222',
            source: 'offline',
            district: 'a',
            address: 'b',
          ),
        ),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            contains('required for offline leads'),
          ),
        ),
      );
    });

    test('lists split leads from awareness and count both', () async {
      final leads = await admin.contacts.list(
        type: ContactType.lead,
        withCounts: true,
      );
      expect(leads.contacts.any((c) => c.id == offline.id), isTrue);
      expect(leads.contacts.any((c) => c.id == aware.id), isFalse);
      expect(leads.leadsCount, greaterThanOrEqualTo(1));
      expect(leads.awarenessCount, greaterThanOrEqualTo(1));

      final awareness = await admin.contacts.list(
        type: ContactType.awareness,
        query: 'Beena',
      );
      expect(awareness.contacts.map((c) => c.id), [aware.id]);
    });

    test('filters by source, creator and date', () async {
      final today = todayIso();
      final bySource = await admin.contacts.list(source: 'offline');
      expect(bySource.contacts.every((c) => c.source == 'offline'), isTrue);
      expect(bySource.contacts.any((c) => c.id == offline.id), isTrue);

      final byCreator = await admin.contacts.list(
        addedBy: '${admin.user.id}',
        startDate: today,
        endDate: today,
      );
      expect(byCreator.contacts.any((c) => c.id == offline.id), isTrue);

      final none = await admin.contacts.list(addedBy: '${anu.user.id}');
      expect(none.contacts.any((c) => c.id == offline.id), isFalse);

      final nothing = await admin.contacts.list(source: 'gmb');
      expect(nothing.total, 0);
    });

    test('the map shows only contacts that have a location', () async {
      final pins = await admin.contacts.mapPins();
      expect(pins.map((p) => p.id), contains(offline.id));
      expect(pins.map((p) => p.id), isNot(contains(aware.id)));
      final pin = pins.firstWhere((p) => p.id == offline.id);
      expect(pin.latitude, closeTo(11.2588, 1e-6));
      expect(pin.contactType, ContactType.lead);
    });

    test('detail, edit and the paging view model', () async {
      final detail = await admin.contacts.detail(offline.id);
      expect(detail.name, 'Arun Kumar');

      final draft = ContactDraft.fromContact(detail)..name = 'Arun K.';
      final updated = await admin.contacts.update(offline.id, draft);
      expect(updated.name, 'Arun K.');
      expect(updated.houseStage, 'Ready');
      expect(updated.hasLocation, isTrue);

      final viewModel = ContactsViewModel(admin.contacts);
      await viewModel.load();
      expect(viewModel.error, isNull);
      expect(viewModel.contacts.any((c) => c.id == offline.id), isTrue);
      expect(viewModel.leadsCount, greaterThanOrEqualTo(1));
      viewModel.selectType(ContactType.awareness);
      await Future<void>.delayed(const Duration(milliseconds: 500));
      expect(viewModel.contacts.any((c) => c.id == aware.id), isTrue);
      viewModel.dispose();
    });

    test('referral by another contact', () async {
      final referred = await admin.contacts.create(
        ContactDraft(
          name: 'Referred Rani',
          phone: '9876533333',
          source: 'website',
          district: 'Kannur',
          address: 'Beach road',
          referredByContactId: offline.id,
        ),
      );
      final detail = await admin.contacts.detail(referred.id);
      expect(detail.referredByContactId, offline.id);
      expect(detail.referralSummary, startsWith('Contact · Arun'));
      await admin.contacts.delete(referred.id);
    });

    test('deleting removes it from every list', () async {
      await admin.contacts.delete(aware.id);
      await expectLater(
        admin.contacts.detail(aware.id),
        throwsA(
          isA<ApiException>().having((e) => e.isNotFound, 'isNotFound', isTrue),
        ),
      );
      final awareness = await admin.contacts.list(
        type: ContactType.awareness,
        query: 'Beena',
      );
      expect(awareness.contacts, isEmpty);
    });
  });

  group('professionals', () {
    test('create, list by trade, edit, delete', () async {
      final created = await admin.professionals.create(
        ProfessionalDraft(
          name: 'Joy Plumber',
          phone: '9847000001',
          type: ProfessionalType.plumber,
          place: 'Feroke',
          address: 'Beach Road',
          district: 'Kozhikode',
          latitude: '11.18',
          longitude: '75.84',
        ),
      );
      expect(created.type, ProfessionalType.plumber);
      expect(created.place, 'Feroke');
      expect(created.hasLocation, isTrue);

      await admin.professionals.create(
        ProfessionalDraft(
          name: 'Ravi Engineer',
          phone: '9847000002',
          type: ProfessionalType.engineer,
          address: 'MG Road',
          district: 'Kannur',
        ),
      );

      final plumbers = await admin.professionals.list(
        type: ProfessionalType.plumber,
      );
      expect(plumbers.map((p) => p.name), contains('Joy Plumber'));
      expect(plumbers.map((p) => p.name), isNot(contains('Ravi Engineer')));

      final everyone = await admin.professionals.list(query: 'ravi');
      expect(everyone.map((p) => p.name), ['Ravi Engineer']);

      final edited = await admin.professionals.update(
        created.id,
        ProfessionalDraft.fromProfessional(created)..place = 'Calicut Beach',
      );
      expect(edited.place, 'Calicut Beach');
      expect(
        (await admin.professionals.detail(created.id)).place,
        'Calicut Beach',
      );

      await admin.professionals.delete(created.id);
      final remaining = await admin.professionals.list();
      expect(remaining.map((p) => p.id), isNot(contains(created.id)));
    });

    test('a professional can be the referrer of a contact', () async {
      final partner = await admin.professionals.create(
        ProfessionalDraft(
          name: 'Kumar Architect',
          phone: '9847000003',
          type: ProfessionalType.architect,
          address: 'Town',
          district: 'Kannur',
        ),
      );
      final contact = await admin.contacts.create(
        ContactDraft(
          name: 'Via Kumar',
          phone: '9876544444',
          source: 'meta',
          district: 'Kannur',
          address: 'Road',
          referredByContactId: partner.id,
        ),
      );
      expect(
        (await admin.contacts.detail(contact.id)).referredByContactName,
        'Kumar Architect',
      );
    });
  });

  group('follow-ups', () {
    late Contact lead;

    test('a new lead is on the board in the first stage', () async {
      lead = await admin.contacts.create(
        ContactDraft(
          name: 'Board Lead',
          phone: '9876555555',
          source: 'meta',
          district: 'Kannur',
          address: 'Station road',
        ),
      );
      // Give it to Anu so she can work it.
      await admin.followups.updateLead(lead.id, assignedTo: '${anu.user.id}');

      final stages = await anu.followups.stages();
      expect(stages.first.id, 'new_lead');
      expect(stages.map((s) => s.id), containsAll(['won', 'lost']));
      expect(stages.map((s) => s.id), isNot(contains('referral')));

      final leads = await anu.followups.leads();
      final onBoard = leads.firstWhere((l) => l.id == lead.id);
      expect(onBoard.stage, 'new_lead');
      expect(onBoard.followupAssignedUserId, anu.user.id);
      expect(onBoard.isQualified, isFalse);
      expect(onBoard.missingQualification, contains('House stage'));
    });

    test('an unverified lead cannot leave the first stage', () async {
      await expectLater(
        anu.followups.updateLead(lead.id, stage: 'first_call'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'status', 409)
              .having(
                (e) => e.missingFields,
                'missing',
                contains('house_stage'),
              ),
        ),
      );
    });

    test(
      'once the details are in, it moves and the history records it',
      () async {
        final detail = await admin.contacts.detail(lead.id);
        await admin.contacts.update(
          lead.id,
          ContactDraft.fromContact(detail)..houseStage = 'Ready',
        );
        await anu.followups.updateLead(lead.id, stage: 'first_call');

        final board = await anu.followups.leads();
        final moved = board.firstWhere((l) => l.id == lead.id);
        expect(moved.stage, 'first_call');
        expect(moved.isQualified, isTrue);

        final history = await anu.followups.remarks(lead.id);
        expect(history.first.remark, 'Stage changed to First Call');
        expect(history.first.isSystem, isTrue);
      },
    );

    test('a due date books a call, a second date reschedules it', () async {
      final first = isoDate(DateTime.now().add(const Duration(days: 3)));
      final second = isoDate(DateTime.now().add(const Duration(days: 5)));

      await anu.followups.updateLead(lead.id, dueDate: first);
      var lead1 = (await anu.followups.leads()).firstWhere(
        (l) => l.id == lead.id,
      );
      expect(lead1.followupDueDate, first);

      await anu.followups.updateLead(lead.id, dueDate: second);
      lead1 = (await anu.followups.leads()).firstWhere((l) => l.id == lead.id);
      expect(lead1.followupDueDate, second);

      // Still exactly one open follow-up for the lead.
      final tasks = await anu.api.get(
        '/tasks',
        query: {'date_from': first, 'date_to': second, 'status': 'open'},
      );
      final mine = (asMap(tasks)['items'] as List).where(
        (t) => (t as Map)['contact_id'] == lead.id,
      );
      expect(mine, hasLength(1));
    });

    test('a past date is refused by the server', () async {
      final yesterday = isoDate(
        DateTime.now().subtract(const Duration(days: 1)),
      );
      await expectLater(
        anu.followups.updateLead(lead.id, dueDate: yesterday),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            contains('cannot be in the past'),
          ),
        ),
      );
    });

    test('notes join the timeline, newest first', () async {
      await anu.followups.addRemark(lead.id, 'Customer asked for a quote');
      final history = await anu.followups.remarks(lead.id);
      expect(history.first.remark, 'Customer asked for a quote');
      expect(history.first.author, 'Anu Sales');
      expect(history.first.isSystem, isFalse);
      expect(
        history.map((r) => r.remark),
        containsAll(['Stage changed to First Call']),
      );
    });

    test('marking a lead lost works without choosing a reason', () async {
      await anu.followups.updateLead(lead.id, stage: 'lost');
      final lost = (await anu.followups.leads()).firstWhere(
        (l) => l.id == lead.id,
      );
      expect(lost.stage, 'lost');
    });

    test('the board view model loads everything for a head', () async {
      final viewModel = FollowupsViewModel(
        admin.followups,
        admin.staff,
        admin.user,
      );
      await viewModel.load();
      expect(viewModel.error, isNull);
      expect(viewModel.stages, isNotEmpty);
      expect(viewModel.staff.map((s) => s.name), contains('Anu Sales'));
      expect(viewModel.visibleLeads.any((l) => l.id == lead.id), isTrue);
      expect(viewModel.countInStage('lost'), greaterThanOrEqualTo(1));
      expect(
        viewModel.assigneeLabel(
          viewModel.visibleLeads.firstWhere((l) => l.id == lead.id),
        ),
        'Anu Sales',
      );
      viewModel.dispose();
    });

    test('stage management is not available', () async {
      await expectLater(
        admin.followups.createStage('Custom'),
        throwsA(isA<ApiException>()),
      );
    });

    test('a lead can be deleted from the board', () async {
      await admin.followups.deleteLead(lead.id);
      final leads = await admin.followups.leads();
      expect(leads.any((l) => l.id == lead.id), isFalse);
    });
  });

  group('sales register', () {
    late Sale created;

    test('a manager creates, lists, searches, edits and deletes', () async {
      created = await manager.sales.create(
        SaleDraft(
          saleDate: '2026-09-01',
          buyerName: 'Buyer One',
          buyerPhone: '9947270717',
          address: 'Feroke',
          tankSize: '500 LTR Vertical Tank',
        ),
      );
      expect(created.buyerName, 'Buyer One');
      expect(created.saleDate, '2026-09-01');
      expect(created.tankSize, '500 LTR Vertical Tank');

      final page = await manager.sales.list(query: 'Buyer');
      expect(page.sales.map((s) => s.id), contains(created.id));
      expect(page.total, greaterThanOrEqualTo(1));

      final found = await manager.sales.search('9947270717');
      expect(found.map((s) => s.id), contains(created.id));

      final products = await manager.sales.products();
      expect(products.map((p) => p.name), contains('500 LTR Vertical Tank'));

      final inRange = await manager.sales.list(
        startDate: '2026-09-01',
        endDate: '2026-09-30',
      );
      expect(inRange.sales.map((s) => s.id), contains(created.id));
      final outOfRange = await manager.sales.list(
        startDate: '2025-01-01',
        endDate: '2025-01-31',
      );
      expect(outOfRange.sales.map((s) => s.id), isNot(contains(created.id)));

      final edited = await manager.sales.update(
        created.id,
        SaleDraft.fromSale(created)..buyerName = 'Buyer Uno',
      );
      expect(edited.buyerName, 'Buyer Uno');

      await manager.sales.delete(created.id);
      final after = await manager.sales.list(query: 'Buyer Uno');
      expect(after.sales, isEmpty);
    });

    test('staff may read the register but not change it', () async {
      await expectLater(
        anu.sales.create(SaleDraft(buyerName: 'Nope')),
        throwsA(
          isA<ApiException>().having(
            (e) => e.kind,
            'kind',
            FailureKind.forbidden,
          ),
        ),
      );
      expect((await anu.sales.list()).total, greaterThanOrEqualTo(0));
    });

    test('an invalid phone number is explained', () async {
      await expectLater(
        manager.sales.create(
          SaleDraft(buyerName: 'Bad Phone', buyerPhone: '12'),
        ),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 422)),
      );
    });
  });

  group('team and performance', () {
    test('a head sees the team, staff see only themselves', () async {
      final today = todayIso();
      final team = await admin.performance.fetch(
        startDate: today,
        endDate: today,
      );
      expect(team.isTeam, isTrue);
      expect(team.staff.map((s) => s.name), contains('Ada Admin'));
      expect(team.leads + team.awareness, greaterThanOrEqualTo(1));

      final mine = await anu.performance.fetch(
        startDate: today,
        endDate: today,
      );
      expect(mine.isTeam, isFalse);
      expect(mine.staff.single.name, 'Anu Sales');
    });

    test('a range with nothing in it is empty, not an error', () async {
      final report = await admin.performance.fetch(
        startDate: '2001-01-01',
        endDate: '2001-01-02',
      );
      expect(report.leads, 0);
      expect(report.awareness, 0);
    });

    test('the staff directory is open to every signed-in employee', () async {
      final people = await anu.staff.list();
      expect(
        people.map((p) => p.name),
        containsAll(['Ada Admin', 'Anu Sales', 'Raj Field']),
      );
    });
  });

  group('staff locations', () {
    final now = DateTime.now().toUtc();

    PendingPoint point(int minutesAgo, double lat, {bool moving = true}) =>
        PendingPoint(
          latitude: lat,
          longitude: 75.78,
          recordedAt: now.subtract(Duration(minutes: minutesAgo)),
          isMoving: moving,
          accuracy: 8.5,
          speed: 1.2,
          batteryLevel: 80,
        );

    test('staff upload a batch, a retry adds nothing', () async {
      final batch = [point(6, 11.25), point(4, 11.26), point(2, 11.27)];
      await raj.locations.upload(batch);
      await raj.locations.upload(batch);

      final route = await raj.locations.myRoute(userId: raj.user.id);
      expect(route.points, hasLength(3));
      expect(route.distanceMeters, greaterThan(0));
      expect(route.firstSeen, isNotNull);
    });

    test('a head sees the live map with colour, state and position', () async {
      final live = await admin.locations.live();
      final rajOnMap = live.firstWhere((s) => s.userId == raj.user.id);
      expect(rajOnMap.name, 'Raj Field');
      expect(rajOnMap.state, StaffState.moving);
      expect(rajOnMap.position.latitude, closeTo(11.27, 1e-6));
      expect(rajOnMap.colorIndex, isNotNull);
    });

    test('route history for a day', () async {
      final route = await admin.locations.history(
        userId: raj.user.id,
        date: todayIso(),
      );
      expect(route.points.length, greaterThanOrEqualTo(1));
    });

    test('switching location off shows on the head map', () async {
      await raj.locations.reportState('location_disabled');
      final live = await admin.locations.live();
      expect(
        live.firstWhere((s) => s.userId == raj.user.id).state,
        StaffState.locationDisabled,
      );
    });

    test('staff cannot see the live map or someone else\'s route', () async {
      await expectLater(
        anu.locations.live(),
        throwsA(
          isA<ApiException>().having(
            (e) => e.kind,
            'kind',
            FailureKind.forbidden,
          ),
        ),
      );
      await expectLater(
        anu.locations.history(userId: raj.user.id, date: todayIso()),
        throwsA(
          isA<ApiException>().having(
            (e) => e.kind,
            'kind',
            FailureKind.forbidden,
          ),
        ),
      );
    });

    test('an unknown tracking state is refused', () async {
      await expectLater(
        raj.locations.reportState('on_the_moon'),
        throwsA(isA<ApiException>()),
      );
    });
  });
}
