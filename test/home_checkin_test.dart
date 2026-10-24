// Field check-in behaviour on the Home tab: the view model's state changes
// against a fake server, plus the address helper the card uses.
//
// The fake server answers by path and can be told to fail a given route, so a
// test can show exactly what the app does when the server disagrees with it
// (for example a 409 "Already checked in today").

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ogera_crm_mobile/core/network/api_client.dart';
import 'package:ogera_crm_mobile/core/utils/formatters.dart';
import 'package:ogera_crm_mobile/services/geocoding_service.dart';
import 'package:ogera_crm_mobile/services/home_service.dart';
import 'package:ogera_crm_mobile/services/location_streaming_service.dart';
import 'package:ogera_crm_mobile/view_models/home_view_model.dart';

/// Records start/stop calls and returns a fixed GPS fix, so no real GPS
/// timers or platform channels are involved.
class _FakeLocation extends LocationStreamingService {
  _FakeLocation(super.service, {this.fix});

  final Position? fix;
  int startCalls = 0;
  int stopCalls = 0;

  @override
  Future<void> start() async {
    startCalls++;
  }

  @override
  Future<void> stop() async {
    stopCalls++;
  }

  @override
  Future<Position?> currentPosition() async => fix;
}

/// A server with a switchable attendance record. [checkinStatus] and
/// [kpiStatus] let a test make a route fail.
class _FakeServer {
  _FakeServer({
    this.todayRecord,
    this.checkinStatus = 201,
    this.kpiStatus = 200,
  });

  /// Today's record as the server holds it; null when not checked in.
  Map<String, dynamic>? todayRecord;
  int checkinStatus;
  int kpiStatus;
  Map<String, dynamic>? lastLocation;
  Map<String, dynamic>? lastCheckinBody;

  late final ApiClient api = ApiClient(
    baseUrl: 'https://crm.test',
    client: MockClient(_handle),
  );

  Future<http.Response> _handle(http.Request request) async {
    final path = request.url.path;
    if (path == '/dashboard/summary') {
      if (kpiStatus != 200) {
        return http.Response('{"detail":"boom"}', kpiStatus);
      }
      return _json({
        'kpis': {
          'total_contacts': 0,
          'new_leads': {'value': 0},
          'open_followups': {'value': 0, 'overdue': 0},
          'won': {'value': 0},
        },
      });
    }
    if (path == '/attendance/today') return _json(todayRecord);
    if (path == '/attendance/checkin') {
      if (checkinStatus == 409) {
        return _json({'detail': 'Already checked in today'}, status: 409);
      }
      lastCheckinBody = jsonDecode(request.body) as Map<String, dynamic>;
      todayRecord = _openRecord();
      return _json(todayRecord, status: 201);
    }
    if (path == '/attendance/checkout') {
      todayRecord = {
        ...?todayRecord,
        'checkout_at': '2026-10-24T17:40:00',
        'is_open': false,
      };
      return _json(todayRecord);
    }
    if (path == '/staff/location/me') return _json(lastLocation);
    if (path == '/contacts') return _json({'items': [], 'total': 0});
    if (path == '/tasks') return _json({'items': [], 'total': 0});
    return _json(null);
  }

  http.Response _json(Object? body, {int status = 200}) =>
      http.Response(jsonEncode(body), status);
}

Map<String, dynamic> _openRecord() => {
  'id': 1,
  'date': '2026-10-24',
  'checkin_at': '2026-10-24T09:12:00',
  'checkout_at': null,
  'checkin_lat': null,
  'checkin_lng': null,
  'is_open': true,
};

Position _fix() => Position(
  longitude: 75.7804,
  latitude: 11.2588,
  timestamp: DateTime(2026, 10, 24, 9, 12),
  accuracy: 5,
  altitude: 0,
  altitudeAccuracy: 0,
  heading: 0,
  headingAccuracy: 0,
  speed: 0,
  speedAccuracy: 0,
);

/// Nominatim-style reply: the road comes first, so the short label is the road.
GeocodingService _geocoder() {
  final client = MockClient((request) async {
    return http.Response(
      jsonEncode({
        'display_name': 'Mavoor Road, Kozhikode, Kerala, India',
        'address': {
          'road': 'Mavoor Road',
          'town': 'Kozhikode',
          'state': 'Kerala',
        },
      }),
      200,
    );
  });
  return GeocodingService(client: client);
}

HomeViewModel _viewModel(_FakeServer server, {_FakeLocation? location}) {
  final service = HomeService(server.api);
  return HomeViewModel(
    service,
    location: location ?? _FakeLocation(service),
    geocoder: _geocoder(),
  );
}

void main() {
  group('firstWords', () {
    test('keeps the first two words of a joined address', () {
      expect(firstWords('Mavoor Road, Kozhikode, Kerala'), 'Mavoor Road');
    });

    test('returns a single word unchanged', () {
      expect(firstWords('Calicut'), 'Calicut');
    });

    test('drops trailing commas and tolerates extra spaces', () {
      expect(firstWords('  MG  Road,   Calicut '), 'MG Road');
    });

    test('returns an empty string for blank input', () {
      expect(firstWords('   '), '');
    });
  });

  test('before the first load the card is in its loading state', () {
    final server = _FakeServer();
    final home = _viewModel(server);
    expect(home.fieldDayStatus, FieldDayStatus.loading);
  });

  test('no record today means not started', () async {
    final server = _FakeServer();
    final home = _viewModel(server);
    await home.load();
    expect(home.fieldDayStatus, FieldDayStatus.notStarted);
  });

  test('attendance still loads when a KPI call fails', () async {
    // Regression: attendance used to share one Future.wait with the KPI calls,
    // so a KPI failure left it unknown and the card offered "Check in" again.
    final server = _FakeServer(todayRecord: _openRecord(), kpiStatus: 500);
    final home = _viewModel(server);
    await home.load();
    expect(home.error, isNotNull);
    expect(home.fieldDayStatus, FieldDayStatus.onField);
  });

  test('check-in sends the GPS fix with the request', () async {
    final server = _FakeServer();
    final home = _viewModel(
      server,
      location: _FakeLocation(HomeService(server.api), fix: _fix()),
    );
    await home.load();
    await home.checkin();
    expect(server.lastCheckinBody, {'latitude': 11.2588, 'longitude': 75.7804});
    expect(home.fieldDayStatus, FieldDayStatus.onField);
  });

  test('check-in still works without a GPS fix', () async {
    final server = _FakeServer();
    final home = _viewModel(server);
    await home.load();
    await home.checkin();
    expect(server.lastCheckinBody, isEmpty);
    expect(home.fieldDayStatus, FieldDayStatus.onField);
  });

  test(
    'a 409 shows the server message and re-reads the open session',
    () async {
      // The server already has an open session that the app did not know about.
      final server = _FakeServer(checkinStatus: 409);
      final location = _FakeLocation(HomeService(server.api));
      final home = _viewModel(server, location: location);
      await home.load();
      expect(home.fieldDayStatus, FieldDayStatus.notStarted);

      server.todayRecord = _openRecord();
      await home.checkin();

      expect(home.actionError, 'Already checked in today');
      expect(home.fieldDayStatus, FieldDayStatus.onField);
      expect(
        location.startCalls,
        1,
        reason: 'tracking resumes for the open session',
      );
    },
  );

  test('checkout moves the card to completed and stops tracking', () async {
    final server = _FakeServer(todayRecord: _openRecord());
    final location = _FakeLocation(HomeService(server.api));
    final home = _viewModel(server, location: location);
    await home.load();
    expect(home.fieldDayStatus, FieldDayStatus.onField);

    await home.checkout();

    expect(home.fieldDayStatus, FieldDayStatus.completed);
    expect(location.stopCalls, 1);
  });

  test(
    'the location label is the first two words of the server point',
    () async {
      final server = _FakeServer(todayRecord: _openRecord());
      server.lastLocation = {
        'latitude': 11.2588,
        'longitude': 75.7804,
        'recorded_at': '2026-10-24T09:20:00',
      };
      final home = _viewModel(server);
      await home.load();
      await home.refreshLocation();
      expect(home.locationLabel, 'Mavoor Road');
      expect(home.locationFailed, isFalse);
    },
  );

  test('no stored point leaves the label empty rather than failing', () async {
    final server = _FakeServer(todayRecord: _openRecord());
    final home = _viewModel(server);
    await home.load();
    await home.refreshLocation();
    expect(home.locationLabel, isNull);
    expect(home.locationFailed, isFalse);
  });
}
