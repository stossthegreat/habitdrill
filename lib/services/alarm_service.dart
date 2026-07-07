import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:uuid/uuid.dart';

import '../models/habit.dart';
import '../models/violation.dart';
import '../models/escalation_config.dart';
import 'alarmkit_service.dart';

class AlarmService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static const String _channelId = 'habit_alarms';
  static const String _channelName = 'Habit Alarms';
  static const String _channelDescription =
      'Alarm notifications for habit reminders';

  // 🔥 Track scheduled alarms in memory for the AlarmTestScreen
  // key: alarmId, value: metadata
  static final Map<int, Map<String, dynamic>> _scheduledAlarms = {};

  /// Initialize alarm service - MUST be called from main()
  static Future<void> initialize() async {
    if (_initialized) {
      debugPrint('⚠️ AlarmService already initialized');
      return;
    }

    try {
      debugPrint('🔧 Initializing AlarmService...');

      // Request permissions
      final notifStatus = await Permission.notification.request();
      debugPrint('Notification permission: $notifStatus');

      // Exact alarm permission is Android-only
      if (Platform.isAndroid) {
        final alarmStatus = await Permission.scheduleExactAlarm.request();
        debugPrint('Exact alarm permission: $alarmStatus');
      }

      // AlarmKit permission is iOS 26+ only. Bridge returns "unsupported"
      // on older iOS, so this is a safe no-op there.
      if (Platform.isIOS && await AlarmKitService.isAvailable()) {
        final status = await AlarmKitService.authorizationStatus();
        if (status == 'notDetermined') {
          final result = await AlarmKitService.requestAuthorization();
          debugPrint('AlarmKit permission: $result');
        } else {
          debugPrint('AlarmKit permission (existing): $status');
        }
      }

      // Initialize notification plugin
      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosInit = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      const initSettings = InitializationSettings(
        android: androidInit,
        iOS: iosInit,
      );

      await _notifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );
      debugPrint('✅ Notification plugin initialized');

      // Step 4: Create notification channels with MAXIMUM PRIORITY and SOUND
      // Channel 1: Habit reminders
      const habitChannel = AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDescription,
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        enableLights: true,
      );

      // Channel 2: Coach messages (briefs, debriefs, nudges, letters)
      const coachChannel = AndroidNotificationChannel(
        'coach_messages',
        'Coach Messages',
        description: 'Notifications for briefs, debriefs, nudges, and letters',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
        enableLights: true,
      );

      final androidPlugin = _notifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      
      // Channel 3: Drill Sergeant (max priority, aggressive)
      const sergeantChannel = AndroidNotificationChannel(
        'drill_sergeant',
        'Drill Sergeant',
        description: 'Accountability notifications from the drill sergeant',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        enableLights: true,
      );

      await androidPlugin?.createNotificationChannel(habitChannel);
      await androidPlugin?.createNotificationChannel(coachChannel);
      await androidPlugin?.createNotificationChannel(sergeantChannel);
      debugPrint('✅ Notification channels created (habits + coach + sergeant)');

      _initialized = true;
      debugPrint('🎉 AlarmService fully initialized!');
    } catch (e, stack) {
      debugPrint('❌ AlarmService initialization failed: $e');
      debugPrint('Stack trace: $stack');
    }
  }

  /// Where MainScreen picks up a fresh alarm tap (habitId + tap time).
  static const String _kLastAlarmHabit = 'last_alarm_tapped_habit';
  static const String _kLastAlarmAt = 'last_alarm_tapped_at';

  static Future<void> _saveAlarmTap(String? habitId) async {
    if (habitId == null || habitId.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kLastAlarmHabit, habitId);
      await prefs.setInt(_kLastAlarmAt, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      debugPrint('saveAlarmTap failed: $e');
    }
  }

  /// Returns the habit id the user just tapped an alarm for, if the tap
  /// happened within the last 5 minutes. Otherwise returns null. Consumes
  /// the flag so the same tap can't fire twice.
  static Future<String?> consumeRecentAlarmTap() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final habitId = prefs.getString(_kLastAlarmHabit);
      final at = prefs.getInt(_kLastAlarmAt);
      if (habitId == null || at == null) return null;
      final ageMs = DateTime.now().millisecondsSinceEpoch - at;
      await prefs.remove(_kLastAlarmHabit);
      await prefs.remove(_kLastAlarmAt);
      if (ageMs > const Duration(minutes: 5).inMilliseconds) return null;
      return habitId;
    } catch (_) {
      return null;
    }
  }

  /// Check if the app was launched by a notification tap (cold start).
  /// Call this from main() before runApp so we can route to the alarm screen.
  static Future<void> handleColdStartAlarm() async {
    try {
      final details = await _notifications.getNotificationAppLaunchDetails();
      if (details?.didNotificationLaunchApp ?? false) {
        await _saveAlarmTap(details?.notificationResponse?.payload);
      }
    } catch (e) {
      debugPrint('handleColdStartAlarm failed: $e');
    }
  }

  static void _onNotificationTapped(NotificationResponse response) {
    debugPrint('🔔 Notification tapped: ${response.payload}');
    _saveAlarmTap(response.payload);
  }

  /// Schedule weekly alarms for a habit using local notifications only
  static Future<void> scheduleAlarm(Habit habit) async {
    if (!habit.reminderOn) {
      debugPrint(
          '⏰ scheduleAlarm skipped: reminderOn=false for "${habit.title}"');
      return;
    }

    if (habit.time.isEmpty) {
      debugPrint(
          '❌ scheduleAlarm FAILED: time is EMPTY for "${habit.title}"');
      return;
    }

    try {
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('🔔 scheduleAlarm called for "${habit.title}"');
      debugPrint('   - time: ${habit.time}');
      debugPrint('   - reminderOn: ${habit.reminderOn}');
      debugPrint('   - repeatDays: ${habit.repeatDays}');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      // Cancel existing alarms so we don't duplicate notifications
      await cancelAlarm(habit.id);

      int successCount = 0;
      int failCount = 0;

      // On iOS 26+ we ALSO schedule via AlarmKit — real system alarms that
      // ring through the silent switch and Focus modes by design. On older
      // iOS this returns false and we rely on the notification burst below.
      final bool alarmKitAvailable = await AlarmKitService.isAvailable();
      if (alarmKitAvailable) {
        // AlarmKit needs UUIDs. We derive a stable one per (habit, day) from
        // the same alarm ID so re-scheduling replaces cleanly.
        for (final day in habit.repeatDays) {
          final baseAlarmId = _getAlarmId(habit.id, day);
          final akId = _uuidFromInt(baseAlarmId);
          final fireDate = _getNextAlarmTime(day, habit.timeOfDay);
          try {
            await AlarmKitService.cancel(akId);
            final ok = await AlarmKitService.schedule(
              id: akId,
              title: 'ORDER: ${habit.title.toUpperCase()}',
              fireAt: fireDate.toLocal(),
            );
            debugPrint('   🛎️ AlarmKit ${_getDayName(day)}: ${ok ? "scheduled" : "failed"}');
          } catch (e) {
            debugPrint('   ❌ AlarmKit ${_getDayName(day)}: $e');
          }
        }
      }

      // Pound them awake. 10 back-to-back time-sensitive notifications
      // 4 seconds apart = 40 seconds of relentless ringing. Every ping is
      // a Sound file play + banner + vibration. No mercy.
      const int burstCount = 10;
      const Duration burstSpacing = Duration(seconds: 4);

      for (final day in habit.repeatDays) {
        final baseAlarmId = _getAlarmId(habit.id, day);
        final scheduledTime = _getNextAlarmTime(day, habit.timeOfDay);

        debugPrint('📅 Scheduling alarm burst for ${_getDayName(day)}:');
        debugPrint('   - baseAlarmId: $baseAlarmId');
        debugPrint('   - time: ${habit.time}');
        debugPrint('   - first ping: $scheduledTime');
        debugPrint('   - burst: ${burstCount}x every ${burstSpacing.inSeconds}s');

        for (int i = 0; i < burstCount; i++) {
          // Each burst notification gets a unique id (base * 10 + burst index).
          // Burst i=0 fires at scheduledTime; i=1 at +8s; etc.
          final burstId = baseAlarmId * 10 + i;
          final fireTime = scheduledTime.add(burstSpacing * i);

          try {
            await _notifications.zonedSchedule(
              burstId,
              'ORDER: ${habit.title.toUpperCase()}',
              _getAlarmMessage(),
              fireTime,
              const NotificationDetails(
                android: AndroidNotificationDetails(
                  _channelId,
                  _channelName,
                  channelDescription: _channelDescription,
                  importance: Importance.max,
                  priority: Priority.high,
                  playSound: true,
                  enableVibration: true,
                  enableLights: true,
                  fullScreenIntent: true,
                  ongoing: false,
                  autoCancel: true,
                ),
                iOS: DarwinNotificationDetails(
                  presentAlert: true,
                  presentSound: true,
                  presentBadge: true,
                  interruptionLevel: InterruptionLevel.timeSensitive,
                  sound: 'alarm.caf',
                ),
              ),
              androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
              // Only the FIRST ping in the burst matches weekly. The follow-up
              // pings are one-shots — they'll fire once when we schedule them
              // and be re-created for next week when the first ping fires and
              // scheduleAlarm runs again on the returning weekday.
              matchDateTimeComponents: i == 0 ? DateTimeComponents.dayOfWeekAndTime : null,
              uiLocalNotificationDateInterpretation:
                  UILocalNotificationDateInterpretation.absoluteTime,
              payload: habit.id,
            );

            successCount++;
            _scheduledAlarms[burstId] = {
              'habitTitle': habit.title,
              'habitId': habit.id,
              'day': day,
              'time': habit.time,
              'burst': i,
              'scheduledAt': fireTime.toIso8601String(),
            };
          } catch (e) {
            failCount++;
            debugPrint('   ❌ ERROR burst $i for ${_getDayName(day)}: $e');
          }
        }
      }

      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('📊 Alarm scheduling summary for "${habit.title}":');
      debugPrint('   ✅ Success: $successCount');
      debugPrint('   ❌ Failed: $failCount');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    } catch (e, stack) {
      debugPrint('❌ scheduleAlarm error: $e');
      debugPrint('Stack: $stack');
    }
  }

  /// Cancel all alarms for a habit
  static Future<void> cancelAlarm(String habitId) async {
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    debugPrint('🗑️ CANCELLING ALARMS for habit: $habitId');

    // AlarmKit path — quietly cancel every derived UUID. Safe on old iOS
    // because AlarmKitService returns false without erroring.
    for (int day = 0; day < 7; day++) {
      final akId = _uuidFromInt(_getAlarmId(habitId, day));
      try {
        await AlarmKitService.cancel(akId);
      } catch (_) {}
    }

    // Get pending notifications BEFORE cancellation
    final pendingBefore = await _notifications.pendingNotificationRequests();
    final habitAlarmIds = <int>[];

    // Burst of 10 per day, 7 days a week → 70 ids per habit.
    for (int day = 0; day < 7; day++) {
      final baseId = _getAlarmId(habitId, day);
      for (int i = 0; i < 10; i++) {
        habitAlarmIds.add(baseId * 10 + i);
      }
    }
    
    final relevantBefore = pendingBefore.where((n) => habitAlarmIds.contains(n.id)).toList();
    debugPrint('📊 Found ${relevantBefore.length} pending alarms for this habit');
    
    // Cancel each alarm with error handling
    int successCount = 0;
    int failCount = 0;
    
    for (int day = 0; day < 7; day++) {
      final baseId = _getAlarmId(habitId, day);
      // Cancel every burst notification (i = 0..4) for this day.
      for (int i = 0; i < 10; i++) {
        final id = baseId * 10 + i;
        try {
          await _notifications.cancel(id);
          _scheduledAlarms.remove(id);
          successCount++;
        } catch (e) {
          failCount++;
          debugPrint('   ❌ Failed to cancel alarm ID $id (${_getDayName(day)} burst $i): $e');
        }
      }
    }
    
    // Verify cancellation at OS level
    final pendingAfter = await _notifications.pendingNotificationRequests();
    final relevantAfter = pendingAfter.where((n) => habitAlarmIds.contains(n.id)).toList();
    
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    debugPrint('📊 Cancellation Summary for habit: $habitId');
    debugPrint('   ✅ Successfully cancelled: $successCount');
    debugPrint('   ❌ Failed to cancel: $failCount');
    debugPrint('   📋 Pending BEFORE: ${relevantBefore.length}');
    debugPrint('   📋 Pending AFTER: ${relevantAfter.length}');
    debugPrint('   ${relevantAfter.isEmpty ? "✅ All alarms verified cancelled!" : "⚠️ WARNING: ${relevantAfter.length} alarms still pending!"}');
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    
    // Throw error if verification failed
    if (relevantAfter.isNotEmpty) {
      throw Exception('Failed to cancel all alarms: ${relevantAfter.length} still pending');
    }
  }

  /// Cancel all alarms
  static Future<void> cancelAll() async {
    await _notifications.cancelAll();
    _scheduledAlarms.clear();
    debugPrint('🗑️ All alarms cancelled');
  }

  /// Get next alarm time (tz-aware) for a given day and time
  static tz.TZDateTime _getNextAlarmTime(int weekday, TimeOfDay time) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );

    final targetWeekday = weekday == 0 ? DateTime.sunday : weekday;

    while (scheduled.weekday != targetWeekday || !scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    return scheduled;
  }

  /// Generate unique alarm ID
  static int _getAlarmId(String habitId, int day) {
    return ((habitId.hashCode.abs() % 900000) + 100000) * 10 + day;
  }

  /// Deterministic UUID from an int — used to give AlarmKit a stable ID
  /// per (habit, day) so re-scheduling replaces cleanly.
  static String _uuidFromInt(int seed) {
    const uuid = Uuid();
    return uuid.v5(Uuid.NAMESPACE_URL, 'habitdrill.alarm.$seed');
  }

  /// Get day name for logging
  static String _getDayName(int day) {
    const days = [
      'Sunday',
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday'
    ];
    return days[day];
  }

  /// Get drill sergeant alarm message
  static String _getAlarmMessage() {
    const messages = [
      "This order is due. Execute now.",
      "Time's up. Complete your order.",
      "Your order is waiting. Move.",
      "Due now. Don't make me wait.",
      "Order due. Complete or face punishment.",
      "This is your time. Execute.",
      "Due now. No excuses.",
      "Order active. Get it done.",
    ];
    final index = DateTime.now().minute % messages.length;
    return messages[index];
  }

  /// Schedule a test alarm (fires in 1 minute)
  static Future<void> scheduleTestAlarm() async {
    try {
      final testTime = tz.TZDateTime.now(tz.local).add(const Duration(minutes: 1));
      const testId = 999999;

      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('🧪 SCHEDULING TEST ALARM');
      debugPrint('   - Current time: ${tz.TZDateTime.now(tz.local)}');
      debugPrint('   - Test alarm time: $testTime');
      debugPrint('   - Alarm ID: $testId');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      await _notifications.zonedSchedule(
        testId,
        '🧪 TEST ALARM',
        'This is a 1-minute test alarm. If you see this, alarms work!',
        testTime,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDescription,
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentSound: true,
            presentBadge: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );

      debugPrint('✅ Test alarm scheduled successfully!');
      debugPrint('⏰ Should fire at: $testTime');

      // 🔥 Track test alarm as well
      _scheduledAlarms[testId] = {
        'habitTitle': '🧪 TEST ALARM',
        'habitId': 'test',
        'day': 0,
        'time': '${testTime.hour.toString().padLeft(2, '0')}:${testTime.minute.toString().padLeft(2, '0')}',
        'scheduledAt': testTime.toIso8601String(),
      };
    } catch (e, stack) {
      debugPrint('❌ Test alarm error: $e');
      debugPrint('Stack: $stack');
    }
  }

  /// Check if service is initialized
  static bool isInitialized() {
    return _initialized;
  }

  /// Verify that a specific habit's alarms are fully cancelled
  static Future<bool> verifyAlarmCancelled(String habitId) async {
    final habitAlarmIds = <int>[];
    for (int day = 0; day < 7; day++) {
      final baseId = _getAlarmId(habitId, day);
      for (int i = 0; i < 10; i++) {
        habitAlarmIds.add(baseId * 10 + i);
      }
    }
    
    final pending = await _notifications.pendingNotificationRequests();
    final stillPending = pending.where((n) => habitAlarmIds.contains(n.id)).toList();
    
    if (stillPending.isNotEmpty) {
      debugPrint('⚠️ verifyAlarmCancelled FAILED for $habitId: ${stillPending.length} alarms still pending');
      for (final alarm in stillPending) {
        debugPrint('   - Pending alarm ID: ${alarm.id}');
      }
      return false;
    }
    
    debugPrint('✅ verifyAlarmCancelled SUCCESS for $habitId: All alarms cleared');
    return true;
  }

  /// 🔍 Expose scheduled alarms for AlarmTestScreen
  static List<Map<String, dynamic>> getScheduledAlarms() {
    return _scheduledAlarms.entries.map((entry) {
      return {
        'id': entry.key,
        'habitTitle': entry.value['habitTitle'] ?? 'Unknown',
        'habitId': entry.value['habitId'] ?? 'Unknown',
        'day': entry.value['day'] ?? 0,
      };
    }).toList();
  }

  // ==================== DRILL SERGEANT NOTIFICATIONS ====================

  /// Schedule escalating notifications for a violation
  static Future<void> scheduleSergeantNotifications(Violation violation) async {
    final delays = EscalationConfig.notificationDelayMinutes;

    for (int i = 0; i < delays.length; i++) {
      final delay = delays[i];
      final message = EscalationConfig.getMessage(
        violation.escalationLevel,
        i,
        violation.habitTitle,
      );
      final notifId = _getSergeantNotifId(violation.id, i);
      final fireTime = tz.TZDateTime.now(tz.local).add(Duration(minutes: delay));

      try {
        await _notifications.zonedSchedule(
          notifId,
          'HABITDRILL',
          message,
          fireTime,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'drill_sergeant',
              'Drill Sergeant',
              channelDescription: 'Accountability notifications from the drill sergeant',
              importance: Importance.max,
              priority: Priority.max,
              playSound: true,
              enableVibration: true,
              fullScreenIntent: true,
            ),
            iOS: DarwinNotificationDetails(
              presentAlert: true,
              presentSound: true,
              presentBadge: true,
              interruptionLevel: InterruptionLevel.timeSensitive,
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
        debugPrint('Scheduled sergeant notification #$i at +${delay}min: $message');
      } catch (e) {
        debugPrint('Failed to schedule sergeant notification: $e');
      }
    }
  }

  /// Cancel all sergeant notifications for a violation
  static Future<void> cancelSergeantNotifications(String violationId) async {
    final delays = EscalationConfig.notificationDelayMinutes;
    for (int i = 0; i < delays.length; i++) {
      await _notifications.cancel(_getSergeantNotifId(violationId, i));
    }
    debugPrint('Cancelled sergeant notifications for violation: $violationId');
  }

  /// Send an immediate sergeant notification
  static Future<void> sendSergeantNotification(String title, String body) async {
    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch % 100000 + 800000,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'drill_sergeant',
          'Drill Sergeant',
          channelDescription: 'Accountability notifications from the drill sergeant',
          importance: Importance.max,
          priority: Priority.max,
          playSound: true,
          enableVibration: true,
          fullScreenIntent: true,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentSound: true,
          presentBadge: true,
        ),
      ),
    );
  }

  static int _getSergeantNotifId(String violationId, int index) {
    return (violationId.hashCode.abs() % 90000) + 700000 + index;
  }
}
