/// Phone numbers for calling and WhatsApp.
///
/// Beginner note: the dialer (`tel:`) and WhatsApp (`wa.me/`) must both get the
/// same full international number. Before this file, each action had its own
/// rules, so one Indian number could dial `9876543210` (no country code) while
/// WhatsApp opened `919876543210`. That is the "dialer and WhatsApp numbers do
/// not match" bug.
///
/// The fix is one parser, [parseContactPhone]. It turns any stored number into
/// one E.164 value such as `+971501234567`, and every action reads that value.
///
/// Rules (Ogera is India-first, with GCC numbers):
///   - `+971…` or `00971…`: international, kept as typed.
///   - `971501234567` (no plus): accepted only when the length matches a known
///     country exactly. This avoids misreading a local number as a country code.
///   - 10 digits after an optional leading `0`: India, `+91`.
///   - 9 digits starting with `5` after an optional leading `0`: UAE mobile, `+971`.
///   - Anything else returns null. We do not guess. The UI asks the user to fix it.
library;

/// A phone number that passed [parseContactPhone].
class ContactPhone {
  const ContactPhone({
    required this.e164,
    required this.countryName,
    required this.isGcc,
    this.countryCode,
    this.nationalNumber,
  });

  /// Full international number with a plus, e.g. `+971501234567`.
  /// The dialer uses this value as-is.
  final String e164;

  /// The dial code, e.g. `971`. Null for a number from an unknown country,
  /// where the code length is not known, so [display] shows [e164] as-is.
  final String? countryCode;

  /// The number without the country code, e.g. `501234567`. Null when
  /// [countryCode] is null.
  final String? nationalNumber;

  /// Human label for the country, e.g. `India`, `UAE`, or `International`.
  final String countryName;

  /// True for the six GCC countries (UAE, Saudi Arabia, Qatar, Bahrain, Oman,
  /// Kuwait). The UI shows this so staff can tell GCC leads from India leads.
  final bool isGcc;

  /// Digits only, no plus. This is the format `wa.me` expects.
  String get whatsAppDigits => e164.substring(1);

  /// Readable form for screens, e.g. `+91 98765 43210` or `+971 501234567`.
  String get display {
    final code = countryCode;
    final national = nationalNumber;
    if (code == null || national == null) return e164;
    if (code == '91' && national.length == 10) {
      return '+91 ${national.substring(0, 5)} ${national.substring(5)}';
    }
    return '+$code $national';
  }
}

class _Country {
  const _Country(this.code, this.name, this.nationalLength, {this.gcc = false});

  final String code;
  final String name;

  /// How many digits follow the country code in a full number.
  final int nationalLength;
  final bool gcc;
}

/// Countries we recognise by code. Any other `+` number is kept as
/// "International" and still dialled, as long as its length is valid.
const _countries = <_Country>[
  _Country('971', 'UAE', 9, gcc: true),
  _Country('966', 'Saudi Arabia', 9, gcc: true),
  _Country('974', 'Qatar', 8, gcc: true),
  _Country('973', 'Bahrain', 8, gcc: true),
  _Country('968', 'Oman', 8, gcc: true),
  _Country('965', 'Kuwait', 8, gcc: true),
  _Country('91', 'India', 10),
];

/// Parses a stored or typed phone number. Returns null when the number cannot
/// be turned into a safe international number.
ContactPhone? parseContactPhone(String raw) {
  final text = raw.trim();
  final digits = text.replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) return null;

  if (text.startsWith('+')) return _international(digits);
  if (digits.startsWith('00')) return _international(digits.substring(2));

  // A full number that already has its country code but no plus sign.
  final withCode = _knownCodeWithoutPlus(digits);
  if (withCode != null) return withCode;

  // A local number. One leading trunk zero is allowed, e.g. `09876543210`.
  final local = digits.startsWith('0') ? digits.substring(1) : digits;
  if (local.length == 10) {
    return _build('91', local, 'India', gcc: false);
  }
  if (local.length == 9 && local.startsWith('5')) {
    // UAE mobile numbers start with 05. Indian mobiles are 10 digits, so a
    // 9-digit number starting with 5 is not an Indian number.
    return _build('971', local, 'UAE', gcc: true);
  }
  return null;
}

/// Validator text for a phone field. Null means the number is acceptable.
String? validateContactPhone(String? value) {
  final text = (value ?? '').trim();
  if (text.isEmpty) return 'Enter a phone number.';
  if (parseContactPhone(text) != null) return null;
  return 'Enter a valid number. Use 10 digits for India, or add the country '
      'code (for example +971 for UAE).';
}

/// A number that starts with a known country code and has the exact length
/// for that country, such as `971501234567`. Returns null otherwise.
ContactPhone? _knownCodeWithoutPlus(String digits) {
  for (final country in _countries) {
    if (!digits.startsWith(country.code)) continue;
    final national = digits.substring(country.code.length);
    if (national.length == country.nationalLength) {
      return _build(country.code, national, country.name, gcc: country.gcc);
    }
  }
  return null;
}

/// Parses digits that came with a plus sign or `00` prefix.
ContactPhone? _international(String digits) {
  // Longest code wins: check 3-digit codes before 2- and 1-digit codes.
  _Country? match;
  for (final country in _countries) {
    if (!digits.startsWith(country.code)) continue;
    if (match == null || country.code.length > match.code.length) {
      match = country;
    }
  }
  if (match != null) {
    final national = digits.substring(match.code.length);
    if (national.length != match.nationalLength) return null;
    return _build(match.code, national, match.name, gcc: match.gcc);
  }

  // Unknown country: accept any plausible length. E.164 allows at most 15 digits.
  if (!RegExp(r'^[1-9]\d{7,14}$').hasMatch(digits)) return null;
  return ContactPhone(
    e164: '+$digits',
    countryName: 'International',
    isGcc: false,
  );
}

ContactPhone _build(
  String code,
  String national,
  String countryName, {
  required bool gcc,
}) {
  return ContactPhone(
    e164: '+$code$national',
    countryCode: code,
    nationalNumber: national,
    countryName: countryName,
    isGcc: gcc,
  );
}
