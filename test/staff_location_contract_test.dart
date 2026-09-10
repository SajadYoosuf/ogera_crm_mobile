import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ogera_crm_mobile/core/network/api_client.dart';
import 'package:ogera_crm_mobile/models/staff_location.dart';
import 'package:ogera_crm_mobile/services/location_api_service.dart';

void main() {
  group('staff location API contract', () {
    test('sales staff uploads only a timestamped location and movement state',
        () async {
      final client = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/staff/locations');
        expect(request.headers['authorization'], 'Bearer staff-token');
        expect(jsonDecode(request.body), {
          'points': [
            {
              'latitude': 11.2588,
              'longitude': 75.7804,
              'recordedAt': '2026-09-10T09:00:00.000Z',
              'isMoving': false,
            },
          ],
        });
        return http.Response(jsonEncode({'success': true, 'data': {'accepted': 1}}), 200);
      });
      final api = ApiClient(client: client, baseUrl: 'https://crm.example')
        ..setAccessToken('staff-token');

      await LocationApiService(api).upload([
        PendingPoint(
          latitude: 11.2588,
          longitude: 75.7804,
          recordedAt: DateTime.utc(2026, 9, 10, 9),
          isMoving: false,
        ),
      ]);
    });

    test('head and admin clients receive readable addresses and server states',
        () async {
      final client = MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/staff/locations/live');
        expect(request.headers['authorization'], anyOf('Bearer head-token', 'Bearer admin-token'));
        return http.Response(jsonEncode({
          'success': true,
          'data': {
            'staff': [
              {
                'userId': 7,
                'name': 'Nila Staff',
                'latitude': 11.2588,
                'longitude': 75.7804,
                'address': 'West Hill, Kozhikode, Kerala',
                'recordedAt': '2026-09-10T09:00:00Z',
                'state': 'moving',
                'colorIndex': 7,
              },
              {
                'userId': 8,
                'name': 'Ravi Staff',
                'latitude': 11.2590,
                'longitude': 75.7810,
                'address': 'Medical College Road, Kozhikode, Kerala',
                'recordedAt': '2026-09-10T08:56:00Z',
                'state': 'connection_lost',
                'colorIndex': 8,
              },
            ],
          },
        }), 200);
      });

      for (final token in ['head-token', 'admin-token']) {
        final api = ApiClient(client: client, baseUrl: 'https://crm.example')
          ..setAccessToken(token);
        final rows = await LocationApiService(api).live();
        expect(rows.first.address, 'West Hill, Kozhikode, Kerala');
        expect(rows.first.state, StaffState.moving);
        expect(rows.last.state, StaffState.connectionLost);
      }
    });

    test('a staff session is denied the manager live-location endpoint', () async {
      final api = ApiClient(
        baseUrl: 'https://crm.example',
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'success': false,
              'error': {'code': 'FORBIDDEN', 'message': 'You do not have access to this system'},
            }),
            403,
          ),
        ),
      )..setAccessToken('staff-token');

      await expectLater(
        LocationApiService(api).live(),
        throwsA(isA<ApiException>().having((error) => error.statusCode, 'statusCode', 403)),
      );
    });

    test('manager route history preserves address and movement status', () async {
      final api = ApiClient(
        baseUrl: 'https://crm.example',
        client: MockClient(
          (request) async {
            expect(request.url.path, '/api/staff/locations/history');
            expect(request.url.queryParameters, {'userId': '7', 'date': '2026-09-10'});
            return http.Response(jsonEncode({
              'success': true,
              'data': {
                'points': [
                  {
                    'latitude': 11.2588,
                    'longitude': 75.7804,
                    'address': 'West Hill, Kozhikode, Kerala',
                    'recordedAt': '2026-09-10T09:00:00Z',
                    'state': 'stuck',
                  },
                ],
                'distanceMeters': 0,
              },
            }), 200);
          },
        ),
      )..setAccessToken('head-token');

      final route = await LocationApiService(api).history(userId: 7, date: '2026-09-10');
      expect(route.points.single.address, 'West Hill, Kozhikode, Kerala');
      expect(route.points.single.state, StaffState.stuck);
    });
  });
}
