import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';

/// Handles all Firebase Cloud Messaging setup for the mobile app.
///
/// WHAT IT DOES:
///   1. Requests notification permission from the OS.
///   2. Gets the FCM token (a unique ID for this device+app combination).
///   3. POSTs the token to the backend so the server can push to this device.
///   4. Sets up handlers for messages in all three app states:
///      - Foreground (app is open) → show a local notification.
///      - Background (app is open but minimised) → FCM shows a system tray notification automatically.
///      - Terminated (app is closed) → FCM shows a system tray notification automatically.
///
/// WHY CALL init() AFTER LOGIN (NOT APP START)?
///   We need the JWT token to register the FCM token with the backend.
///   The user must be authenticated first, so we call init() inside adopt()
///   in SessionViewModel right after login succeeds.
class FirebaseService {
  FirebaseService._();

  static final _messaging = FirebaseMessaging.instance;
  static final _localNotifs = FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  /// Set up FCM and register the device token with the backend.
  /// Safe to call multiple times — only runs once per app process.
  static Future<void> init({required String jwtToken}) async {
    if (_initialized) return;
    _initialized = true;

    try {
      await _requestPermission();
      await _setupLocalNotifications();
      await _registerToken(jwtToken: jwtToken);
      _listenForegroundMessages();
    } catch (e) {
      // Never crash the app because of a notification setup failure.
      debugPrint('[FCM] init error: $e');
    }
  }

  static Future<void> _requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    debugPrint('[FCM] permission: ${settings.authorizationStatus}');
  }

  // flutter_local_notifications is used to show heads-up notifications when
  // the app is in the foreground, since FCM does not show them automatically.
  static Future<void> _setupLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    await _localNotifs.initialize(initSettings);

    // Create a high-importance notification channel on Android 8+.
    const channel = AndroidNotificationChannel(
      'ogera_crm_channel',
      'Ogera CRM',
      description: 'Ogera CRM push notifications',
      importance: Importance.high,
    );
    await _localNotifs
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  static Future<void> _registerToken({required String jwtToken}) async {
    // firebase_messaging 17+ uses register() + onRegistered stream.
    await _messaging.register();
    _messaging.onRegistered.listen((token) async {
      debugPrint('[FCM] token obtained, registering with backend');
      try {
        final url = Uri.parse('${AppConfig.apiBaseUrl}/employees/me/fcm-token');
        final response = await http.post(
          url,
          headers: {
            'Authorization': 'Bearer $jwtToken',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'token': token}),
        );
        if (response.statusCode == 200) {
          debugPrint('[FCM] token registered successfully');
        } else {
          debugPrint('[FCM] token registration failed: ${response.statusCode}');
        }
      } catch (e) {
        debugPrint('[FCM] token registration error: $e');
      }
    });
  }

  static void _listenForegroundMessages() {
    // When the app is open and a push arrives, FCM does NOT show a notification
    // automatically on iOS and some Android configs. We show one ourselves.
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final notification = message.notification;
      if (notification == null) return;

      _localNotifs.show(
        notification.hashCode,
        notification.title,
        notification.body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'ogera_crm_channel',
            'Ogera CRM',
            channelDescription: 'Ogera CRM push notifications',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
      );
    });
  }
}
