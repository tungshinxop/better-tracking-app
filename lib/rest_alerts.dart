import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Tells the user when a rest period is over, even if the app is in the background.
class RestAlerts {
  const RestAlerts();

  /// Arms an alert for [endsAt]. Replaces any alert armed before.
  Future<void> schedule(DateTime endsAt, String nextUp) async {}

  /// Fires the alert immediately (the in-app countdown reached zero).
  Future<void> fireNow(String nextUp) async {}

  Future<void> cancel() async {}
}

class NotificationRestAlerts extends RestAlerts {
  NotificationRestAlerts();

  static const _id = 1001;
  static const _title = 'Rest is over';

  final _plugin = FlutterLocalNotificationsPlugin();
  Future<bool>? _ready;
  bool _askedPermission = false;

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'rest_timer',
      'Rest timer',
      channelDescription: 'Alerts when the rest between sets is over',
      importance: Importance.max,
      priority: Priority.high,
      category: AndroidNotificationCategory.alarm,
      visibility: NotificationVisibility.public,
      timeoutAfter: 60000,
    ),
    iOS: DarwinNotificationDetails(
      presentAlert: true,
      presentBanner: true,
      presentList: true,
      presentSound: true,
    ),
  );

  bool get _supported => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  Future<bool> _init() => _ready ??= () async {
        if (!_supported) return false;
        try {
          tz_data.initializeTimeZones();
          await _plugin.initialize(
            settings: const InitializationSettings(
              android: AndroidInitializationSettings('@mipmap/ic_launcher'),
              iOS: DarwinInitializationSettings(
                requestAlertPermission: false,
                requestSoundPermission: false,
                requestBadgePermission: false,
              ),
            ),
          );
          return true;
        } catch (error) {
          debugPrint('Notifications unavailable: $error');
          return false;
        }
      }();

  /// Asks once, the first time a rest timer starts (a user action).
  Future<void> _ensurePermission() async {
    if (_askedPermission) return;
    _askedPermission = true;
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, sound: true);
  }

  String _body(String nextUp) => nextUp.isEmpty ? 'Time for your next set.' : 'Next up: $nextUp';

  @override
  Future<void> schedule(DateTime endsAt, String nextUp) async {
    if (!await _init()) return;
    try {
      await _ensurePermission();
      await _plugin.cancel(id: _id);
      await _plugin.zonedSchedule(
        id: _id,
        title: _title,
        body: _body(nextUp),
        scheduledDate: tz.TZDateTime.from(endsAt.toUtc(), tz.UTC),
        notificationDetails: _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    } catch (error) {
      debugPrint('Could not schedule rest alert: $error');
    }
  }

  @override
  Future<void> fireNow(String nextUp) async {
    if (!await _init()) return;
    try {
      await _plugin.cancel(id: _id);
      await _plugin.show(
          id: _id, title: _title, body: _body(nextUp), notificationDetails: _details);
    } catch (error) {
      debugPrint('Could not show rest alert: $error');
    }
  }

  @override
  Future<void> cancel() async {
    if (!await _init()) return;
    try {
      await _plugin.cancel(id: _id);
    } catch (error) {
      debugPrint('Could not cancel rest alert: $error');
    }
  }
}
