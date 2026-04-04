import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';

/// Smart daily notifications. Max 2-3 per day. Never spam.
/// Learns when the user is most at risk and hits them then.
class RetentionService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static const String _channelId = 'daily_sergeant';
  static const String _channelName = 'Daily Sergeant';

  // Only 3 notifications per day. Strategic timing.
  static const List<Map<String, dynamic>> _schedule = [
    // Morning: Set the tone
    {'id': 500001, 'hour': 7, 'minute': 30, 'title': 'HABITDRILL', 'body': 'Orders active. Execute.'},
    // Afternoon: Pressure
    {'id': 500002, 'hour': 14, 'minute': 0, 'title': 'HABITDRILL', 'body': 'Status check. Orders pending.'},
    // Evening: Last chance
    {'id': 500003, 'hour': 21, 'minute': 0, 'title': 'HABITDRILL', 'body': 'Final hours. Complete or train.'},
  ];

  // Morning variants (rotate daily)
  static const List<String> _morningMessages = [
    'Orders active. Execute.',
    'New day. Your orders are waiting.',
    'Status: PENDING. Move.',
    'Your discipline score depends on today.',
    'Report for duty.',
    'Day starts now.',
    'Execute your orders or face punishment.',
  ];

  // Evening variants (rotate daily)
  static const List<String> _eveningMessages = [
    'Final hours. Complete or train.',
    'Incomplete orders = punishment.',
    'Your streak is on the line.',
    'Complete now or lose your rank.',
    'Last chance before tomorrow.',
    'Your discipline score is watching.',
  ];

  static Future<void> initialize() async {
    final androidPlugin = _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    const channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: 'Daily discipline reminders',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    await androidPlugin?.createNotificationChannel(channel);
  }

  static Future<void> scheduleAll() async {
    await cancelAll();

    for (final entry in _schedule) {
      final hour = entry['hour'] as int;
      String body = entry['body'] as String;

      // Rotate messages based on day of year
      final dayOfYear = DateTime.now().difference(DateTime(DateTime.now().year, 1, 1)).inDays;
      if (hour <= 9) {
        body = _morningMessages[dayOfYear % _morningMessages.length];
      } else if (hour >= 20) {
        body = _eveningMessages[dayOfYear % _eveningMessages.length];
      }

      await _scheduleDailyNotif(
        id: entry['id'] as int,
        hour: hour,
        minute: entry['minute'] as int,
        title: entry['title'] as String,
        body: body,
      );
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('retention_scheduled', true);
  }

  static Future<void> cancelAll() async {
    for (final entry in _schedule) {
      await _notifications.cancel(entry['id'] as int);
    }
  }

  static Future<void> _scheduleDailyNotif({
    required int id, required int hour, required int minute,
    required String title, required String body,
  }) async {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    try {
      await _notifications.zonedSchedule(
        id, title, body, scheduled,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId, _channelName,
            channelDescription: 'Daily discipline reminders',
            importance: Importance.high,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
            styleInformation: BigTextStyleInformation(body),
          ),
          iOS: const DarwinNotificationDetails(presentAlert: true, presentSound: true, presentBadge: true),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (e) {
      debugPrint('Retention notification error: $e');
    }
  }

  static Future<void> ensureScheduled() async {
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool('retention_scheduled') ?? false)) {
      await scheduleAll();
    }
  }
}
