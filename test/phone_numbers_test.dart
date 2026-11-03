import 'package:flutter_test/flutter_test.dart';
import 'package:ogera_crm_mobile/core/utils/phone_numbers.dart';

/// Phone rules: India by default, GCC when the number says so, and nothing
/// guessed when a number is ambiguous. Dialling and WhatsApp must agree.
void main() {
  group('Indian numbers (India is the default)', () {
    test('a local 10-digit mobile becomes +91', () {
      final phone = parseContactPhone('98765 43210');
      expect(phone?.e164, '+919876543210');
      expect(phone?.countryName, 'India');
      expect(phone?.isGcc, isFalse);
      expect(phone?.display, '+91 98765 43210');
    });

    test('a leading trunk zero is removed before adding +91', () {
      expect(parseContactPhone('09876543210')?.e164, '+919876543210');
    });

    test(
      'a 10-digit number that starts with 91 is still local, not +91 twice',
      () {
        expect(parseContactPhone('9123456789')?.e164, '+919123456789');
      },
    );

    test('an Indian landline with an STD code is accepted', () {
      expect(parseContactPhone('0484 2345678')?.e164, '+914842345678');
    });

    test('a +91 number keeps its country code', () {
      expect(parseContactPhone('+91 98765 43210')?.e164, '+919876543210');
    });

    test('91 followed by 10 digits, without a plus, is India', () {
      expect(parseContactPhone('919876543210')?.e164, '+919876543210');
    });
  });

  group('GCC numbers (UAE and the rest of the GCC)', () {
    test('a UAE mobile written with 05 becomes +971', () {
      final phone = parseContactPhone('0501234567');
      expect(phone?.e164, '+971501234567');
      expect(phone?.countryName, 'UAE');
      expect(phone?.isGcc, isTrue);
      expect(phone?.display, '+971 501234567');
    });

    test('a 9-digit UAE mobile starting with 5 becomes +971', () {
      expect(parseContactPhone('501234567')?.e164, '+971501234567');
    });

    test('+971 with spaces keeps the UAE code', () {
      expect(parseContactPhone('+971 50 123 4567')?.e164, '+971501234567');
    });

    test('00971 is read as +971', () {
      expect(parseContactPhone('00971 50 123 4567')?.e164, '+971501234567');
    });

    test('971 without a plus is UAE when the length matches', () {
      expect(parseContactPhone('971501234567')?.e164, '+971501234567');
    });

    test('Saudi Arabia and Qatar are recognised as GCC', () {
      final saudi = parseContactPhone('+966 50 123 4567');
      expect(saudi?.countryName, 'Saudi Arabia');
      expect(saudi?.isGcc, isTrue);
      final qatar = parseContactPhone('+974 3312 3456');
      expect(qatar?.countryName, 'Qatar');
      expect(qatar?.isGcc, isTrue);
    });
  });

  group('other countries', () {
    test('a foreign number with a plus is kept as international', () {
      final phone = parseContactPhone('+49 (151) 23456789');
      expect(phone?.e164, '+4915123456789');
      expect(phone?.countryName, 'International');
      expect(phone?.isGcc, isFalse);
      expect(phone?.display, '+4915123456789');
    });
  });

  group('numbers that are rejected instead of guessed', () {
    test('empty and short values', () {
      expect(parseContactPhone(''), isNull);
      expect(parseContactPhone('123'), isNull);
      expect(parseContactPhone('12345'), isNull);
    });

    test('a UAE number with the wrong length', () {
      expect(parseContactPhone('+971 5012'), isNull);
    });

    test('a plus number longer than E.164 allows', () {
      expect(parseContactPhone('+1234567890123456'), isNull);
    });

    test('a 9-digit number that is not a UAE mobile', () {
      expect(parseContactPhone('912345678'), isNull);
    });
  });

  group('dialling and WhatsApp use the same number', () {
    test('the WhatsApp digits are the dialled number without the plus', () {
      const samples = [
        '98765 43210',
        '09876543210',
        '0501234567',
        '+971 50 123 4567',
        '00971 50 123 4567',
        '+49 (151) 23456789',
      ];
      for (final sample in samples) {
        final phone = parseContactPhone(sample);
        expect(phone, isNotNull, reason: sample);
        expect('+${phone!.whatsAppDigits}', phone.e164, reason: sample);
      }
    });
  });

  group('validateContactPhone', () {
    test('accepts a usable number', () {
      expect(validateContactPhone('98765 43210'), isNull);
    });

    test('asks for a number when empty', () {
      expect(validateContactPhone('  '), 'Enter a phone number.');
    });

    test('explains how to fix an unusable number', () {
      expect(validateContactPhone('123'), contains('country code'));
    });
  });
}
