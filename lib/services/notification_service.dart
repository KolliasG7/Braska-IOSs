// lib/services/notification_service.dart
import 'package:flutter/foundation.dart' show debugPrint, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart' show Color;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationService {
  NotificationService._();
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  static Future<void> init() async {
    try {
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const ios     = DarwinInitializationSettings();
      const linux   = LinuxInitializationSettings(defaultActionName: 'Open');
      await _plugin.initialize(
        const InitializationSettings(
          android: android,
          iOS: ios,
          linux: linux,
        ),
      );
      _ready = true;
    } catch (e) {
      // Notification service failed to initialize - app can still function
      // but notifications will be disabled
      _ready = false;
      debugPrint('[NotificationService] Failed to initialize: $e');
    }
  }

  static Future<void> showStatus({
    required String title,
    required String body,
  }) async {
    if (!_ready) return;
    if (defaultTargetPlatform == TargetPlatform.windows) return;
    final channel = AndroidNotificationDetails(
      'ps4_status', 'PS4 Status',
      channelDescription: 'Live PS4 system status',
      importance: Importance.low,
      priority:   Priority.low,
      ongoing:    true,
      showWhen:   false,
      styleInformation: BigTextStyleInformation(body),
    );
    await _plugin.show(1, title, body,
      NotificationDetails(android: channel));
  }

  static Future<void> showAlert({
    required String title,
    required String body,
  }) async {
    if (!_ready) return;
    if (defaultTargetPlatform == TargetPlatform.windows) return;
    const channel = AndroidNotificationDetails(
      'ps4_alert', 'PS4 Alerts',
      channelDescription: 'Temperature and fault alerts',
      importance: Importance.high,
      priority:   Priority.high,
      color:      Color(0xFFFFFFFF),
    );
    await _plugin.show(2, title, body,
      const NotificationDetails(android: channel));
  }

  static Future<void> cancelStatus() => _plugin.cancel(1);

  static Future<void> storeLastTemp(double tempC) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('last_apu_temp', tempC);
  }

  static Future<double?> getLastTemp() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble('last_apu_temp');
  }
}
