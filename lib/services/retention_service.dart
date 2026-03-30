import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';

/// Daily retention notifications - the sergeant pulls users back in
class RetentionService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static const String _channelId = 'daily_sergeant';
  static const String _channelName = 'Daily Sergeant';

  // Notification schedule: hour, message pairs
  static const List<Map<String, dynamic>> _schedule = [
    {
      'id': 500001,
      'hour': 7,
      'minute': 0,
      'title': 'DRILLSARJ',
      'body': 'Orders active. Complete them or face punishment.',
    },
    {
      'id': 500002,
      'hour': 8,
      'minute': 30,
      'title': 'DRILLSARJ',
      'body': 'Status check. Are your orders completed?',
    },
    {
      'id': 500003,
      'hour': 12,
      'minute': 0,
      'title': 'DRILLSARJ',
      'body': 'Midday. Orders still pending.',
    },
    {
      'id': 500004,
      'hour': 15,
      'minute': 0,
      'title': 'DRILLSARJ',
      'body': 'Time is running out. Complete your orders.',
    },
    {
      'id': 500005,
      'hour': 20,
      'minute': 0,
      'title': 'DRILLSARJ',
      'body': 'Final hours. Incomplete orders = punishment.',
    },
    {
      'id': 500006,
      'hour': 22,
      'minute': 0,
      'title': 'DRILLSARJ',
      'body': 'Last chance. Complete or train.',
    },
  ];

  // Rotating motivational messages for variety
  static const List<String> _morningVariants = [
    'Orders active. Execute.',
    'New day. Same discipline.',
    'Your orders are waiting.',
    'Status: PENDING. Fix that.',
    'Execute your orders today.',
    'Day starts now. No excuses.',
    'Orders set. Get moving.',
  ];

  static const List<String> _eveningVariants = [
    'Orders still incomplete.',
    'Complete or face punishment.',
    'Status check. Open the app.',
    'Incomplete orders = punishment.',
    'Last hours. Complete your orders.',
    'Tomorrow starts with your failures.',
  ];

  /// Initialize the retention notification channel
  static Future<void> initialize() async {
    final androidPlugin = _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    const channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: 'Daily motivation and accountability from the drill sergeant',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    await androidPlugin?.createNotificationChannel(channel);
  }

  /// Schedule all daily retention notifications
  static Future<void> scheduleAll() async {
    // Cancel any existing retention notifications first
    await cancelAll();

    for (final entry in _schedule) {
      await _scheduleDailyNotification(
        id: entry['id'] as int,
        hour: entry['hour'] as int,
        minute: entry['minute'] as int,
        title: entry['title'] as String,
        body: entry['body'] as String,
      );
    }

    // Save that we've set up retention
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('retention_scheduled', true);

    debugPrint('Scheduled ${_schedule.length} daily retention notifications');
  }

  /// Cancel all retention notifications
  static Future<void> cancelAll() async {
    for (final entry in _schedule) {
      await _notifications.cancel(entry['id'] as int);
    }
  }

  static Future<void> _scheduleDailyNotification({
    required int id,
    required int hour,
    required int minute,
    required String title,
    required String body,
  }) async {
    // Use rotating messages for morning/evening
    String actualBody = body;
    if (hour <= 9) {
      actualBody = _morningVariants[DateTime.now().day % _morningVariants.length];
    } else if (hour >= 20) {
      actualBody = _eveningVariants[DateTime.now().day % _eveningVariants.length];
    }

    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    try {
      await _notifications.zonedSchedule(
        id,
        title,
        actualBody,
        scheduledDate,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: 'Daily motivation and accountability',
            importance: Importance.high,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
            styleInformation: BigTextStyleInformation(actualBody),
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentSound: true,
            presentBadge: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time, // Repeat daily
      );
    } catch (e) {
      debugPrint('Failed to schedule retention notification $id: $e');
    }
  }

  /// Check if retention is set up, schedule if not
  static Future<void> ensureScheduled() async {
    final prefs = await SharedPreferences.getInstance();
    final scheduled = prefs.getBool('retention_scheduled') ?? false;
    if (!scheduled) {
      await scheduleAll();
    }
  }
}
