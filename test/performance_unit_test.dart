import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ogera_crm_mobile/core/network/api_client.dart';
import 'package:ogera_crm_mobile/core/utils/formatters.dart';
import 'package:ogera_crm_mobile/models/contact.dart';
import 'package:ogera_crm_mobile/models/performance.dart';
import 'package:ogera_crm_mobile/services/crm_services.dart';

import 'performance_test_support.dart';
import 'test_helpers.dart';

/// Unit tests for the Performance feature's non-UI code: response parsing, the
/// service's request shape, failure classification, and the phone-number rules
/// behind the WhatsApp/dial buttons.
void main() {
  group('StaffPerformance.fromJson', () {
    test('reads the fields and derives total', () {
      final staff = StaffPerformance.fromJson(
        staffPerfJson(7, 'Shiju', leads: 91, awareness: 4),
      );

      expect(staff.id, 7);
      expect(staff.name, 'Shiju');
      expect(staff.leads, 91);
      expect(staff.awareness, 4);
      expect(staff.total, 95);
    });

    test('falls back safely on missing or blank values', () {
      final staff = StaffPerformance.fromJson({'id': 3, 'name': '  '});

      expect(staff.name, 'Ogera user');
      expect(staff.leads, 0);
      expect(staff.awareness, 0);
      expect(staff.total, 0);
    });

    test('accepts numbers sent as strings', () {
      final staff = StaffPerformance.fromJson({
        'id': '5',
        'name': 'Amaan',
        'leads': '10',
        'awareness': '2',
      });

      expect(staff.id, 5);
      expect(staff.total, 12);
    });
  });

  group('PerformanceReport.fromJson', () {
    test('parses totals, staff order and unattributed counts', () {
      final report = PerformanceReport.fromJson(
        perfJson(
          staff: [
            staffPerfJson(1, 'Admin', leads: 58, awareness: 3),
            staffPerfJson(7, 'Shiju', leads: 91, awareness: 4),
          ],
          unattributedLeads: 42,
          unattributedAwareness: 127,
        ),
      );

      expect(report.leads, 149);
      expect(report.awareness, 7);
      expect(report.staff.map((s) => s.name), ['Admin', 'Shiju']);
      expect(report.isTeam, isTrue);
      expect(report.unattributedLeads, 42);
      expect(report.unattributedAwareness, 127);
      expect(report.unattributed, 169);
    });

    test('a self-scoped report is not a team report', () {
      final report = PerformanceReport.fromJson(
        perfJson(
          scope: 'self',
          staff: [staffPerfJson(2, 'Staff User', leads: 5, awareness: 1)],
        ),
      );

      expect(report.isTeam, isFalse);
      expect(report.staff.single.total, 6);
    });

    test('tolerates an empty or malformed payload', () {
      for (final bad in <dynamic>[
        null,
        'oops',
        <dynamic>[],
        <String, dynamic>{},
      ]) {
        final report = PerformanceReport.fromJson(bad);
        expect(report.leads, 0);
        expect(report.awareness, 0);
        expect(report.staff, isEmpty);
        expect(report.unattributed, 0);
      }
    });
  });

  group('PerformanceService', () {
    test(
      'requests /performance with the date range and bearer token',
      () async {
        late Uri url;
        late Map<String, String> headers;
        final api = apiFor((request) {
          url = request.url;
          headers = request.headers;
          return jsonOk(
            perfJson(
              staff: [staffPerfJson(7, 'Shiju', leads: 2, awareness: 1)],
            ),
          );
        });

        final report = await PerformanceService(
          api,
        ).fetch(startDate: '2026-08-01', endDate: '2026-08-31');

        expect(url.path, '/performance');
        expect(url.queryParameters, {
          'start_date': '2026-08-01',
          'end_date': '2026-08-31',
        });
        expect(headers['Authorization'], 'Bearer test-token');
        expect(report.staff.single.name, 'Shiju');
      },
    );
  });

  group('ContactsService.list (per-staff drill-down)', () {
    test(
      'forwards created_by, kind, dates and page as the API names them',
      () async {
        final urls = <Uri>[];
        final api = apiFor((request) {
          urls.add(request.url);
          return jsonOk(
            contactPageJson([contactJson(id: 1, name: 'Amina')], page: 2),
          );
        });

        final page = await ContactsService(api).list(
          addedBy: '7',
          type: ContactType.lead,
          startDate: '2026-08-01',
          endDate: '2026-08-31',
          page: 2,
        );

        final url = urls.first;
        expect(url.path, '/contacts');
        expect(url.queryParameters['created_by'], '7');
        expect(url.queryParameters['contact_type'], 'consumer');
        expect(url.queryParameters['awareness_mode'], '0');
        expect(url.queryParameters['created_from'], '2026-08-01');
        expect(url.queryParameters['created_to'], '2026-08-31');
        // Page 2 of 20 starts after the first twenty rows.
        expect(url.queryParameters['skip'], '20');
        expect(url.queryParameters['limit'], '20');
        expect(page.contacts.single.name, 'Amina');
        expect(page.page, 2);
      },
    );

    test(
      'omits created_by and the awareness filter when they are not set',
      () async {
        final urls = <Uri>[];
        final api = apiFor((request) {
          urls.add(request.url);
          return jsonOk(contactPageJson(const []));
        });

        await ContactsService(api).list();

        expect(urls.first.queryParameters.containsKey('created_by'), isFalse);
        expect(
          urls.first.queryParameters.containsKey('awareness_mode'),
          isFalse,
        );
        expect(urls.first.queryParameters['contact_type'], 'consumer');
      },
    );

    test('supports the unattributed bucket', () async {
      final urls = <Uri>[];
      final api = apiFor((request) {
        urls.add(request.url);
        return jsonOk(contactPageJson(const []));
      });

      await ContactsService(api).list(addedBy: 'unattributed');

      expect(urls.first.queryParameters['unattributed'], 'true');
      expect(urls.first.queryParameters.containsKey('created_by'), isFalse);
    });

    test('works out both tab counts from one extra count request', () async {
      final api = apiFor((request) {
        final mode = request.url.queryParameters['awareness_mode'];
        return jsonOk(
          contactPageJson([
            contactJson(id: 1, name: 'Amina'),
          ], total: mode == '1' ? 4 : 9),
        );
      });

      final page = await ContactsService(
        api,
      ).list(type: ContactType.lead, withCounts: true);

      expect(page.leadsCount, 9);
      expect(page.awarenessCount, 4);
      expect(page.total, 9);
      expect(page.totalPages, 1);
    });
  });

  group('failure classification', () {
    Future<ApiException> failWith(ServerHandler handler) async {
      final api = apiFor(handler);
      try {
        await PerformanceService(
          api,
        ).fetch(startDate: '2026-01-01', endDate: '2026-01-02');
      } on ApiException catch (error) {
        return error;
      }
      fail('expected an ApiException');
    }

    test('a dead connection is offline and carries no status', () async {
      final error = await failWith((_) => throw const SocketException('down'));

      expect(error.kind, FailureKind.offline);
      expect(error.statusCode, isNull);
    });

    test('401 is unauthorized', () async {
      final error = await failWith((_) => jsonError(401, 'UNAUTHORIZED', 'No'));

      expect(error.kind, FailureKind.unauthorized);
    });

    test('403 is forbidden', () async {
      final error = await failWith((_) => jsonError(403, 'FORBIDDEN', 'No'));

      expect(error.kind, FailureKind.forbidden);
    });

    test('a 404 (route missing on the server) is not found', () async {
      final error = await failWith((_) => htmlNotFound());

      expect(error.kind, FailureKind.notFound);
    });

    test('a 500 carries the server message and is a server failure', () async {
      final error = await failWith(
        (_) => jsonError(500, 'SERVER_ERROR', 'Unable to load performance'),
      );

      expect(error.kind, FailureKind.server);
      expect(error.message, 'Unable to load performance');
    });
  });

  group('phone numbers for WhatsApp and dialling', () {
    test('a plain 10-digit Indian mobile gets the +91 code', () {
      expect(normalisePhone('8606478859', countryCode: '+91'), '+918606478859');
    });

    test('the +91 default no longer produces a +971 number', () {
      expect(
        normalisePhone('8606478859', countryCode: '+91'),
        isNot(startsWith('+971')),
      );
    });

    test(
      'a number stored with its own +91 prefix keeps it, whatever the code',
      () {
        expect(
          normalisePhone('+91 7025356838', countryCode: '+971'),
          '+917025356838',
        );
      },
    );

    test(
      'a number that already starts with the code is not prefixed twice',
      () {
        expect(
          normalisePhone('918606478859', countryCode: '+91'),
          '+918606478859',
        );
      },
    );

    test('spacing and dashes are stripped', () {
      expect(normalisePhone('86064-78859', countryCode: '91'), '+918606478859');
    });

    test('with no country code only the digits remain', () {
      expect(normalisePhone(' 8606 478 859 '), '8606478859');
    });
  });
}
