import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ogera_crm_mobile/core/network/api_client.dart';
import 'package:ogera_crm_mobile/models/staff_location.dart';
import 'package:ogera_crm_mobile/services/location_api_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('staff upload is visible to head and admin using the shared location contract',
      (tester) async {
    var reported = false;
    final client = MockClient((request) async {
      if (request.method == 'POST') {
        reported = true;
        expect(request.url.path, '/api/staff/locations');
        return http.Response(jsonEncode({'success': true, 'data': {'accepted': 1}}), 200);
      }
      expect(reported, isTrue);
      expect(request.url.path, '/api/staff/locations/live');
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
          ],
        },
      }), 200);
    });
    final api = ApiClient(client: client, baseUrl: 'https://crm.example')
      ..setAccessToken('test-token');
    final locations = LocationApiService(api);

    await locations.upload([
      PendingPoint(
        latitude: 11.2588,
        longitude: 75.7804,
        recordedAt: DateTime.utc(2026, 9, 10, 9),
        isMoving: true,
      ),
    ]);
    final rows = await locations.live();

    expect(rows.single.address, 'West Hill, Kozhikode, Kerala');
    expect(rows.single.state, StaffState.moving);
  });
}
