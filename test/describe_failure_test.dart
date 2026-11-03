// Tests for describeFailure(): the one place that turns a thrown error into
// words a person can read. Users must never see raw exception text.

import 'package:flutter_test/flutter_test.dart';
import 'package:ogera_crm_mobile/core/network/api_client.dart';

void main() {
  group('describeFailure', () {
    test('keeps the friendly message and kind of an ApiException', () {
      const error = ApiException(
        'Network problem. Check your connection and try again.',
      );

      final failure = describeFailure(error);

      expect(failure.message, error.message);
      expect(failure.kind, FailureKind.offline);
    });

    test('maps a server error to the server kind with its message', () {
      const error = ApiException(
        'The server had a problem. Please try again.',
        statusCode: 500,
      );

      final failure = describeFailure(error);

      expect(failure.kind, FailureKind.server);
      expect(failure.message, error.message);
    });

    test('hides the raw text of an unexpected error', () {
      final failure = describeFailure(
        FormatException('Unexpected character at offset 4'),
      );

      expect(failure.kind, FailureKind.server);
      expect(failure.message, isNot(contains('FormatException')));
      expect(failure.message, isNot(contains('offset')));
      expect(failure.message, isNotEmpty);
    });

    test('never returns the ApiException toString format', () {
      final failure = describeFailure(const ApiException('Oops', statusCode: 400));

      expect(failure.message, 'Oops');
      expect(failure.message, isNot(startsWith('ApiException')));
    });
  });
}
