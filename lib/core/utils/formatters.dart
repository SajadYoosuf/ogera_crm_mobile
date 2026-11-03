import 'package:intl/intl.dart';

/// Dates travel as plain `YYYY-MM-DD` so they never drift across a timezone,
/// matching the web app's `toDateInput` / `todayIsoDate` helpers.
String isoDate(DateTime value) => DateFormat('yyyy-MM-dd').format(value);

String todayIso() => isoDate(DateTime.now());

DateTime? parseDate(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  return DateTime.tryParse(value.toString());
}

String? asText(dynamic value) {
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

double? asDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

int? asInt(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

/// `12 Mar` — used on due-date chips and day selectors.
String formatDayMonth(DateTime value) => DateFormat('dd MMM').format(value);

/// `12 Mar 2026` — used in detail headers.
String formatFullDate(DateTime value) =>
    DateFormat('dd MMM yyyy').format(value);

/// `12 Mar, 14:05` — used on history timelines.
String formatMoment(DateTime value) =>
    DateFormat('dd MMM, HH:mm').format(value);

String formatTime(DateTime value) => DateFormat('HH:mm').format(value);

/// Relative age, the way the staff list reads it: "now", "6m ago", "2h ago".
String formatRelative(DateTime value) {
  final difference = DateTime.now().difference(value);
  if (difference.isNegative) return 'just now';
  if (difference.inSeconds < 45) return 'just now';
  if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
  if (difference.inHours < 24) return '${difference.inHours}h ago';
  if (difference.inDays < 7) return '${difference.inDays}d ago';
  return formatDayMonth(value);
}

final _currency = NumberFormat.currency(
  locale: 'en_IN',
  symbol: '₹',
  decimalDigits: 0,
);
final _compact = NumberFormat.compactCurrency(
  locale: 'en_IN',
  symbol: '₹',
  decimalDigits: 1,
);

String formatCurrency(num value) => _currency.format(value);

String formatCompactCurrency(num value) =>
    value.abs() >= 100000 ? _compact.format(value) : _currency.format(value);

String formatDistance(double meters) {
  if (meters < 1000) return '${meters.round()} m';
  return '${(meters / 1000).toStringAsFixed(1)} km';
}

String formatDuration(Duration value) {
  if (value.inMinutes < 60) return '${value.inMinutes} min';
  final hours = value.inHours;
  final minutes = value.inMinutes.remainder(60);
  return minutes == 0 ? '${hours}h' : '${hours}h ${minutes}m';
}

/// Two-letter monogram for avatars; falls back to the phone's last digits when
/// a record has no name, which happens often with imported contacts.
String initialsOf(String? name, {String? fallback}) {
  final source = (name ?? '').trim();
  if (source.isEmpty) {
    final digits = (fallback ?? '').replaceAll(RegExp(r'\D'), '');
    if (digits.length >= 2) return digits.substring(digits.length - 2);
    return '?';
  }
  final parts = source
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.length == 1) {
    return parts.first
        .substring(0, parts.first.length >= 2 ? 2 : 1)
        .toUpperCase();
  }
  return '${parts.first[0]}${parts[1][0]}'.toUpperCase();
}

/// Turns a stage id such as `closed_won` into `Closed Won` for the rare case
/// where a lead carries a stage that is no longer in `pipeline_stages`.
String humanizeSlug(String value) {
  return value
      .split(RegExp(r'[_\-\s]+'))
      .where((word) => word.isNotEmpty)
      .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
      .join(' ');
}

/// Keeps only the first [count] words of an address, dropping the trailing
/// commas left behind by the join. "MG Road, Calicut, Kerala" → "MG Road".
String firstWords(String text, {int count = 2}) {
  final words = text
      .trim()
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .map((word) => word.replaceAll(RegExp(r'[,;]+$'), ''))
      .where((word) => word.isNotEmpty)
      .take(count);
  return words.join(' ');
}

/// `firstOrNull` lives in package:collection, which this app does not depend on.
T? firstOrNull<T>(Iterable<T> items) {
  final iterator = items.iterator;
  return iterator.moveNext() ? iterator.current : null;
}
