import 'package:flutter_test/flutter_test.dart';
import 'package:ogera_crm_mobile/core/utils/country_codes.dart';

/// Looks up a country by ISO code, so each test reads clearly.
DialCountry _country(String iso) =>
    dialCountries.firstWhere((c) => c.iso == iso);

void main() {
  group('validateNationalNumber', () {
    test('an Indian 10-digit mobile starting with 9 is valid', () {
      expect(validateNationalNumber(_country('IN'), '9876543210'), isNull);
    });

    test(
      'an Indian number with 9 digits is rejected with the exact length',
      () {
        expect(
          validateNationalNumber(_country('IN'), '987654321'),
          'Enter 10 digits for India',
        );
      },
    );

    test('an Indian number starting with 1 is rejected as not mobile', () {
      expect(
        validateNationalNumber(_country('IN'), '1234567890'),
        'Enter a valid India mobile number',
      );
    });

    test('a UAE mobile is 9 digits starting with 5', () {
      expect(validateNationalNumber(_country('AE'), '501234567'), isNull);
      expect(
        validateNationalNumber(_country('AE'), '401234567'),
        'Enter a valid United Arab Emirates mobile number',
      );
    });

    test('no digits gives the required message', () {
      expect(
        validateNationalNumber(_country('IN'), ''),
        'Mobile number is required',
      );
    });

    test('a missing country asks the user to pick a code', () {
      expect(
        validateNationalNumber(null, '9876543210'),
        'Select a country code',
      );
    });

    test('a country with a length range accepts both ends', () {
      final malaysia = _country('MY');
      expect(validateNationalNumber(malaysia, '123456789'), isNull);
      expect(validateNationalNumber(malaysia, '1234567890'), isNull);
      expect(
        validateNationalNumber(malaysia, '12345678'),
        'Enter 9 to 10 digits for Malaysia',
      );
    });

    test('every country allows at most 10 national digits', () {
      for (final country in dialCountries) {
        expect(
          country.maxDigits,
          lessThanOrEqualTo(kMaxNationalDigits),
          reason: country.name,
        );
        expect(
          country.minDigits,
          lessThanOrEqualTo(country.maxDigits),
          reason: country.name,
        );
      }
    });
  });

  group('toE164', () {
    test('joins the plus sign, dial code and national digits', () {
      expect(toE164(_country('IN'), '9876543210'), '+919876543210');
      expect(toE164(_country('AE'), '501234567'), '+971501234567');
    });
  });

  group('cleanNationalInput', () {
    test('plain digits are kept', () {
      expect(cleanNationalInput('9876543210', _country('IN')), '9876543210');
    });

    test('spaces and dashes are removed', () {
      expect(cleanNationalInput('98765 432-10', _country('IN')), '9876543210');
    });

    test('a pasted +91 prefix is removed so the last digit is not lost', () {
      expect(
        cleanNationalInput('+91 98765 43210', _country('IN')),
        '9876543210',
      );
    });

    test('a 00 prefix is removed the same way', () {
      expect(
        cleanNationalInput('0091 9876543210', _country('IN')),
        '9876543210',
      );
    });

    test('a number typed with the code and no plus is trimmed back', () {
      expect(cleanNationalInput('919876543210', _country('IN')), '9876543210');
    });

    test('extra digits beyond the country limit are cut off', () {
      expect(cleanNationalInput('98765432101', _country('AE')), '987654321');
    });

    test('with no country chosen, only digits are kept', () {
      expect(cleanNationalInput('+91 9876', null), '919876');
    });
  });

  group('splitStoredPhone', () {
    test('a saved UAE number fills the UAE code and national digits', () {
      final split = splitStoredPhone('+971501234567');
      expect(split.country?.iso, 'AE');
      expect(split.national, '501234567');
    });

    test('a saved Indian number without a plus is read as India', () {
      final split = splitStoredPhone('9876543210');
      expect(split.country?.iso, 'IN');
      expect(split.national, '9876543210');
    });

    test('a number from an unlisted country keeps its digits and no code', () {
      final split = splitStoredPhone('+4915123456789');
      expect(split.country, isNull);
      expect(split.national, '4915123456789');
    });
  });
}
