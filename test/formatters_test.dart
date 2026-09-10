import 'package:flutter_test/flutter_test.dart';
import 'package:ogera_crm_mobile/core/utils/formatters.dart';

void main() {
  group('normaliseWhatsAppPhone', () {
    test('adds India country code to local mobile formats', () {
      expect(normaliseWhatsAppPhone('98765 43210'), '919876543210');
      expect(normaliseWhatsAppPhone('09876543210'), '919876543210');
    });

    test('uses a saved country code for local contact numbers', () {
      expect(
        normaliseWhatsAppPhone('50 123 4567', countryCode: '+971'),
        '971501234567',
      );
      expect(
        normaliseWhatsAppPhone('07 7009 1234', countryCode: '+44'),
        '44770091234',
      );
    });

    test('preserves complete international number formats', () {
      expect(normaliseWhatsAppPhone('+49 (151) 23456789'), '4915123456789');
      expect(normaliseWhatsAppPhone('00971 50 123 4567'), '971501234567');
      expect(normaliseWhatsAppPhone('971501234567'), '971501234567');
    });

    test('rejects empty, short, and overlong numbers', () {
      expect(normaliseWhatsAppPhone(''), isNull);
      expect(normaliseWhatsAppPhone('123'), isNull);
      expect(normaliseWhatsAppPhone('+1234567890123456'), isNull);
    });
  });
}
