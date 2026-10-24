import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'phone_numbers.dart';

/// Call / WhatsApp / directions are offered from every contact and professional
/// row, so the failure handling lives here once.
///
/// Both call and WhatsApp use [parseContactPhone], so they always dial the same
/// international number. If a stored number cannot be parsed, nothing is opened
/// and the user sees a message, instead of dialling a wrong number.
class Launchers {
  const Launchers._();

  static const invalidPhoneMessage =
      'This number is incomplete or invalid. Edit the contact to fix it.';

  static Future<void> call(BuildContext context, String phone) async {
    final parsed = parseContactPhone(phone);
    _log('call', phone, parsed);
    if (parsed == null) {
      _toast(context, invalidPhoneMessage);
      return;
    }
    await _open(
      context,
      Uri(scheme: 'tel', path: parsed.e164),
      failure: 'No dialler is available on this device.',
    );
  }

  static Future<void> whatsapp(
    BuildContext context,
    String phone, {
    String? message,
  }) async {
    final parsed = parseContactPhone(phone);
    _log('whatsapp', phone, parsed);
    if (parsed == null) {
      _toast(context, invalidPhoneMessage);
      return;
    }
    final uri = Uri.https('wa.me', '/${parsed.whatsAppDigits}', {
      if (message != null && message.isNotEmpty) 'text': message,
    });
    await _open(
      context,
      uri,
      failure: 'WhatsApp is not installed on this device.',
    );
  }

  static Future<void> directions(
    BuildContext context, {
    double? latitude,
    double? longitude,
    String? address,
  }) async {
    Uri uri;
    if (latitude != null && longitude != null) {
      uri = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=$latitude,$longitude',
      );
    } else if (address != null && address.trim().isNotEmpty) {
      uri = Uri.https('www.google.com', '/maps/search/', {
        'api': '1',
        'query': address,
      });
    } else {
      _toast(context, 'This record has no location saved yet.');
      return;
    }
    await _open(
      context,
      uri,
      failure: 'No maps app is available on this device.',
    );
  }

  static Future<void> openSettingsUrl(BuildContext context, String url) async {
    await _open(context, Uri.parse(url), failure: 'Could not open that link.');
  }

  static Future<void> _open(
    BuildContext context,
    Uri uri, {
    required String failure,
  }) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (kDebugMode) debugPrint('[Ogera Launch] opening $uri');
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (kDebugMode) debugPrint('[Ogera Launch] launched=$launched');
      if (!launched) _show(messenger, failure);
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[Ogera Launch] failed | ${error.runtimeType}: $error');
      }
      _show(messenger, failure);
    }
  }

  /// Debug-only: shows the stored number and the number that will be dialled,
  /// so a wrong country code is visible in the console at a glance.
  static void _log(String action, String stored, ContactPhone? parsed) {
    if (!kDebugMode) return;
    debugPrint(
      '[Ogera Launch] $action | stored="$stored" '
      '-> ${parsed?.e164 ?? 'REJECTED'} (${parsed?.countryName ?? 'n/a'})',
    );
  }

  static void _toast(BuildContext context, String message) {
    _show(ScaffoldMessenger.maybeOf(context), message);
  }

  static void _show(ScaffoldMessengerState? messenger, String message) {
    messenger?.showSnackBar(SnackBar(content: Text(message)));
  }
}
