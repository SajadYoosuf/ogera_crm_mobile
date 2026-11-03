/// Country dial codes and mobile-number rules for the contact phone field.
///
/// Beginner note: the user never types a `+` or a country code. They pick a
/// country from a list (the "dial code" button), then type only the national
/// number. Each country says how long its mobile number is and which digits it
/// may start with, so `98765 43210` is valid for India but not for the UAE.
///
/// The saved value is always `+<dial code><national number>`, for example
/// `+919876543210`. The backend accepts that format (see `phone_utils.py`).
///
/// This file is pure Dart with no Flutter imports, so the rules can be unit
/// tested without a widget tree.
library;

import 'phone_numbers.dart';

/// The most digits a national number may have, in any country.
const int kMaxNationalDigits = 10;

/// One country the phone field supports.
class DialCountry {
  const DialCountry({
    required this.iso,
    required this.name,
    required this.dialCode,
    required this.minDigits,
    required this.maxDigits,
    required this.leadingDigits,
  });

  /// Two-letter ISO code, e.g. `IN`. Used to draw the flag.
  final String iso;

  /// Display name, e.g. `India`.
  final String name;

  /// Dial code without the plus sign, e.g. `91`.
  final String dialCode;

  /// Shortest and longest national number this country accepts. Never above
  /// [kMaxNationalDigits].
  final int minDigits;
  final int maxDigits;

  /// Digits a mobile number may start with, e.g. `['6', '7', '8', '9']` for
  /// India. An empty list means any first digit is allowed.
  final List<String> leadingDigits;

  /// The flag emoji, built from the ISO letters. Each letter maps to a
  /// "regional indicator" symbol, and two of them together show as a flag.
  String get flag =>
      String.fromCharCodes(iso.codeUnits.map((unit) => 0x1F1E6 + unit - 0x41));

  /// Text shown for the dial code, e.g. `+91`.
  String get dialLabel => '+$dialCode';
}

/// The countries offered in the picker. India is first because Ogera is
/// India-first; the GCC countries follow because many leads are there.
const List<DialCountry> dialCountries = [
  DialCountry(
    iso: 'IN',
    name: 'India',
    dialCode: '91',
    minDigits: 10,
    maxDigits: 10,
    leadingDigits: ['6', '7', '8', '9'],
  ),
  DialCountry(
    iso: 'AE',
    name: 'United Arab Emirates',
    dialCode: '971',
    minDigits: 9,
    maxDigits: 9,
    leadingDigits: ['5'],
  ),
  DialCountry(
    iso: 'SA',
    name: 'Saudi Arabia',
    dialCode: '966',
    minDigits: 9,
    maxDigits: 9,
    leadingDigits: ['5'],
  ),
  DialCountry(
    iso: 'QA',
    name: 'Qatar',
    dialCode: '974',
    minDigits: 8,
    maxDigits: 8,
    leadingDigits: ['3', '5', '6', '7'],
  ),
  DialCountry(
    iso: 'BH',
    name: 'Bahrain',
    dialCode: '973',
    minDigits: 8,
    maxDigits: 8,
    leadingDigits: ['3', '6'],
  ),
  DialCountry(
    iso: 'OM',
    name: 'Oman',
    dialCode: '968',
    minDigits: 8,
    maxDigits: 8,
    leadingDigits: ['7', '9'],
  ),
  DialCountry(
    iso: 'KW',
    name: 'Kuwait',
    dialCode: '965',
    minDigits: 8,
    maxDigits: 8,
    leadingDigits: ['4', '5', '6', '9'],
  ),
  DialCountry(
    iso: 'US',
    name: 'United States',
    dialCode: '1',
    minDigits: 10,
    maxDigits: 10,
    leadingDigits: ['2', '3', '4', '5', '6', '7', '8', '9'],
  ),
  DialCountry(
    iso: 'GB',
    name: 'United Kingdom',
    dialCode: '44',
    minDigits: 10,
    maxDigits: 10,
    leadingDigits: ['7'],
  ),
  DialCountry(
    iso: 'SG',
    name: 'Singapore',
    dialCode: '65',
    minDigits: 8,
    maxDigits: 8,
    leadingDigits: ['8', '9'],
  ),
  DialCountry(
    iso: 'MY',
    name: 'Malaysia',
    dialCode: '60',
    minDigits: 9,
    maxDigits: 10,
    leadingDigits: ['1'],
  ),
  DialCountry(
    iso: 'PK',
    name: 'Pakistan',
    dialCode: '92',
    minDigits: 10,
    maxDigits: 10,
    leadingDigits: ['3'],
  ),
  DialCountry(
    iso: 'BD',
    name: 'Bangladesh',
    dialCode: '880',
    minDigits: 10,
    maxDigits: 10,
    leadingDigits: ['1'],
  ),
  DialCountry(
    iso: 'LK',
    name: 'Sri Lanka',
    dialCode: '94',
    minDigits: 9,
    maxDigits: 9,
    leadingDigits: ['7'],
  ),
  DialCountry(
    iso: 'NP',
    name: 'Nepal',
    dialCode: '977',
    minDigits: 10,
    maxDigits: 10,
    leadingDigits: ['9'],
  ),
];

/// The country selected when a new contact form opens.
DialCountry get defaultDialCountry => dialCountries.first;

/// Returns the first problem with [digits] for [country], or null when the
/// number is acceptable. [digits] must contain digits only.
///
/// A null [country] means the user has not picked a code yet (this happens
/// when editing a stored number from a country we do not list).
String? validateNationalNumber(DialCountry? country, String digits) {
  if (country == null) return 'Select a country code';
  if (digits.isEmpty) return 'Mobile number is required';
  if (digits.length < country.minDigits || digits.length > country.maxDigits) {
    final range = country.minDigits == country.maxDigits
        ? '${country.maxDigits}'
        : '${country.minDigits} to ${country.maxDigits}';
    return 'Enter $range digits for ${country.name}';
  }
  final leading = country.leadingDigits;
  if (leading.isNotEmpty && !leading.any(digits.startsWith)) {
    return 'Enter a valid ${country.name} mobile number';
  }
  return null;
}

/// Builds the full number sent to the API, e.g. `+971501234567`.
/// Call this only after [validateNationalNumber] has passed.
String toE164(DialCountry country, String digits) {
  return '+${country.dialCode}$digits';
}

/// The result of reading a stored phone number back into the form.
class SplitPhone {
  const SplitPhone({required this.country, required this.national});

  /// The matching country, or null when the stored number is from a country
  /// we do not list. The user must then pick the code.
  final DialCountry? country;

  /// The digits to show in the number field.
  final String national;
}

/// Splits a stored number such as `+971501234567` or `9876543210` into a
/// country and a national number. It uses the shared parser, so editing and
/// calling read every number the same way.
SplitPhone splitStoredPhone(String raw) {
  final parsed = parseContactPhone(raw);
  if (parsed != null && parsed.countryCode != null) {
    for (final country in dialCountries) {
      if (country.dialCode == parsed.countryCode) {
        return SplitPhone(
          country: country,
          national: parsed.nationalNumber ?? '',
        );
      }
    }
  }
  // Unknown country: keep the digits so the user can see and fix them.
  return SplitPhone(country: null, national: raw.replaceAll(RegExp(r'\D'), ''));
}

/// Cleans text typed or pasted into the number field.
///
/// Pasting `+91 98765 43210` into the India field would otherwise keep the
/// `91` and cut the last digit off at the length limit, saving a wrong number.
/// So if the text starts with `+` or `00`, or has more digits than the country
/// allows, a leading dial code is removed first. Then the result is cut to the
/// country's maximum length.
String cleanNationalInput(String text, DialCountry? country) {
  var digits = text.replaceAll(RegExp(r'\D'), '');
  if (country == null) return digits;
  final trimmed = text.trimLeft();
  final hasInternationalPrefix =
      trimmed.startsWith('+') || trimmed.startsWith('00');
  // `00` is the older way to write `+`, so drop it before looking for the code.
  if (trimmed.startsWith('00') && digits.startsWith('00')) {
    digits = digits.substring(2);
  }
  final dial = country.dialCode;
  final tooLong = digits.length > country.maxDigits;
  if ((hasInternationalPrefix || tooLong) && digits.startsWith(dial)) {
    digits = digits.substring(dial.length);
  }
  if (digits.length > country.maxDigits) {
    digits = digits.substring(0, country.maxDigits);
  }
  return digits;
}
