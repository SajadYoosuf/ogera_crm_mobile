import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ogera_crm_mobile/core/network/api_client.dart';

ApiClient _client(http.Response Function(http.Request request) reply) {
  return ApiClient(
    baseUrl: 'https://crm.test',
    client: MockClient((request) async => reply(request)),
  );
}

Future<ApiException> _failure(ApiClient api) async {
  try {
    await api.get('/anything');
  } on ApiException catch (error) {
    return error;
  }
  fail('expected an ApiException');
}

void main() {
  group('responses', () {
    test('a plain JSON object is returned as it is', () async {
      final api = _client((_) => http.Response(jsonEncode({'id': 3}), 200));
      expect(await api.get('/contacts/3'), {'id': 3});
    });

    test('a plain JSON list is returned as it is', () async {
      final api = _client((_) => http.Response(jsonEncode([1, 2]), 200));
      expect(await api.get('/lead-sources'), [1, 2]);
    });

    test('an empty 204 answers null', () async {
      final api = _client((_) => http.Response('', 204));
      expect(await api.delete('/contacts/3'), isNull);
    });

    test('the old { success, data } envelope is still unwrapped', () async {
      final api = _client(
        (_) => http.Response(
          jsonEncode({
            'success': true,
            'data': [9],
          }),
          200,
        ),
      );
      expect(await api.get('/anything'), [9]);
    });

    test(
      'a record that happens to have a data field is not unwrapped',
      () async {
        final api = _client(
          (_) => http.Response(jsonEncode({'id': 1, 'data': 'x'}), 200),
        );
        expect(await api.get('/anything'), {'id': 1, 'data': 'x'});
      },
    );
  });

  group('requests', () {
    test('sends the bearer token, the client marker and a JSON body', () async {
      late http.Request seen;
      final api = _client((request) {
        seen = request;
        return http.Response('{}', 200);
      })..setAccessToken('tok');

      await api.post('/contacts', body: {'name': 'A'});

      expect(seen.url.toString(), 'https://crm.test/contacts');
      expect(seen.headers['Authorization'], 'Bearer tok');
      expect(seen.headers['x-client-type'], 'mobile');
      expect(seen.headers['Content-Type'], contains('application/json'));
      expect(jsonDecode(seen.body), {'name': 'A'});
    });

    test('supports PATCH', () async {
      late http.Request seen;
      final api = _client((request) {
        seen = request;
        return http.Response('{}', 200);
      });
      await api.patch('/contacts/1/activities/2', body: {'status': 'done'});
      expect(seen.method, 'PATCH');
    });

    test('drops empty query values and keeps the rest', () async {
      late Uri seen;
      final api = _client((request) {
        seen = request.url;
        return http.Response('{}', 200);
      });
      await api.get(
        '/contacts',
        query: {'search': '', 'skip': 0, 'type': null, 'verified': true},
      );
      expect(seen.queryParameters, {'skip': '0', 'verified': 'true'});
    });
  });

  group('errors read FastAPI detail', () {
    test('a string detail becomes the message', () async {
      final error = await _failure(
        _client(
          (_) =>
              http.Response(jsonEncode({'detail': 'Contact not found'}), 404),
        ),
      );
      expect(error.message, 'Contact not found');
      expect(error.kind, FailureKind.notFound);
      expect(error.statusCode, 404);
    });

    test('validation errors list each field with its message', () async {
      final error = await _failure(
        _client(
          (_) => http.Response(
            jsonEncode({
              'detail': [
                {
                  'loc': ['body', 'district'],
                  'msg': 'Field required',
                  'type': 'missing',
                },
                {
                  'loc': ['body', 'scheduled_date'],
                  'msg': 'Value error, scheduled_date cannot be in the past',
                  'type': 'value_error',
                },
              ],
            }),
            422,
          ),
        ),
      );
      expect(
        error.message,
        'district: Field required\n'
        'scheduled_date: scheduled_date cannot be in the past',
      );
      expect(error.statusCode, 422);
    });

    test('an object detail keeps its message and its missing_fields', () async {
      final error = await _failure(
        _client(
          (_) => http.Response(
            jsonEncode({
              'detail': {
                'message': "Complete the lead's details first",
                'missing_fields': ['house_stage', 'district'],
              },
            }),
            409,
          ),
        ),
      );
      expect(error.message, "Complete the lead's details first");
      expect(error.missingFields, ['house_stage', 'district']);
    });

    test('a body with no detail falls back to a status message', () async {
      final error = await _failure(
        _client((_) => http.Response('<html>oops</html>', 502)),
      );
      expect(error.kind, FailureKind.server);
      expect(error.message, 'The server had a problem. Please try again.');
    });

    test('403 is forbidden with the server wording', () async {
      final error = await _failure(
        _client(
          (_) => http.Response(
            jsonEncode({
              'detail': 'You do not have permission to perform this action',
            }),
            403,
          ),
        ),
      );
      expect(error.kind, FailureKind.forbidden);
      expect(
        error.message,
        'You do not have permission to perform this action',
      );
    });

    test('401 calls onUnauthorized once and carries the message', () async {
      var signedOut = 0;
      final api = _client(
        (_) => http.Response(jsonEncode({'detail': 'Invalid token'}), 401),
      )..onUnauthorized = () => signedOut++;
      final error = await _failure(api);
      expect(signedOut, 1);
      expect(error.isUnauthorized, isTrue);
      expect(error.message, 'Invalid token');
    });

    test('a dead connection is reported as offline', () async {
      final api = ApiClient(
        baseUrl: 'https://crm.test',
        client: MockClient((_) async => throw http.ClientException('down')),
      );
      final error = await _failure(api);
      expect(error.kind, FailureKind.offline);
      expect(error.isNetwork, isTrue);
    });
  });
}
