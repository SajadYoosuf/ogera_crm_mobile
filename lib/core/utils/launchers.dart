import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'formatters.dart';

/// Call / WhatsApp / directions are offered from every contact and professional
/// row, so the failure handling lives here once.
class Launchers {
  const Launchers._();

  static Future<void> call(
    BuildContext context,
    String phone, {
    String? countryCode,
  }) async {
    final number = normalisePhone(phone, countryCode: countryCode);
    await _open(
      context,
      Uri(scheme: 'tel', path: number),
      failure: 'No dialler is available on this device.',
    );
  }

  static Future<void> whatsapp(
    BuildContext context,
    String phone, {
    String? countryCode,
    String? message,
  }) async {
    final number = normaliseWhatsAppPhone(phone, countryCode: countryCode);
    if (number == null) {
      _toast(context, 'Save a valid phone number with its country code first.');
      return;
    }
    final uri = Uri.https('wa.me', '/$number', {
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
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) _show(messenger, failure);
    } catch (_) {
      _show(messenger, failure);
    }
  }

  static void _toast(BuildContext context, String message) {
    _show(ScaffoldMessenger.maybeOf(context), message);
  }

  static void _show(ScaffoldMessengerState? messenger, String message) {
    messenger?.showSnackBar(SnackBar(content: Text(message)));
  }
}
