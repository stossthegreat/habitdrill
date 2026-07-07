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

      // TWO-STAGE NO-MERCY LOOP.
      //
      // Stage 1 — WAKE BURST (5 pings @ 4s apart, i=0..4):
      //   Bold red "⚠️ WAKE UP!" pings hammer the lock screen back-to-back
      //   for ~20 seconds. Time-sensitive so they punch through Focus/DND.
      //
      // Stage 2 — REPS ESCALATION (3 pings, i=5..7):
      //   If the user doesn't tap in and finish their reps, the phone keeps
      //   ringing. At +1min, +5min, +15min a new ping fires announcing the
      //   growing rep debt ("😡 +5 REPS", "🔥 +25 REPS", "💀 +75 REPS").
      //   These get cancelled the moment the user completes reps —
      //   see cancelWakeEscalations().
      //
      // 8 pings × 7 weekdays = 56 pending — under iOS's 64-slot cap.
      // Only i=0 repeats weekly; the rest are one-shots that get re-created
      // when the weekly ping fires and scheduleAlarm re-runs.

      final wakeSchedule = _wakePingSchedule();

      for (final day in habit.repeatDays) {
        final baseAlarmId = _getAlarmId(habit.id, day);
        final scheduledTime = _getNextAlarmTime(day, habit.timeOfDay);

        debugPrint('📅 Scheduling wake pings for ${_getDayName(day)}:');
        debugPrint('   - baseAlarmId: $baseAlarmId');
        debugPrint('   - time: ${habit.time}');
        debugPrint('   - first ping: $scheduledTime');
        debugPrint('   - ${wakeSchedule.length} pings total (5 burst + 3 escalation)');

        for (int i = 0; i < wakeSchedule.length; i++) {
          final ping = wakeSchedule[i];
          final pingId = baseAlarmId * 10 + i;
          final fireTime = scheduledTime.add(ping.offset);

          try {
            await _notifications.zonedSchedule(
              pingId,
              ping.title,
              ping.body,
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
                ),
              ),
              androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
              // Only the first ping matches weekly — the rest re-schedule
              // when the weekly ping fires next week.
              matchDateTimeComponents:
                  i == 0 ? DateTimeComponents.dayOfWeekAndTime : null,
              uiLocalNotificationDateInterpretation:
                  UILocalNotificationDateInterpretation.absoluteTime,
              payload: habit.id,
            );

            successCount++;
            _scheduledAlarms[pingId] = {
              'habitTitle': habit.title,
              'habitId': habit.id,
              'day': day,
              'time': habit.time,
              'burst': i,
              'scheduledAt': fireTime.toIso8601String(),
            };
          } catch (e) {
            failCount++;
            debugPrint('   ❌ ERROR ping $i for ${_getDayName(day)}: $e');
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

    // Up to 10 wake ping slots per day (5 burst + 3 escalation actually used;
    // loop to 10 to catch any leftovers from older versions).
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

  /// The 8-ping wake schedule: 5 burst pings hammer the lock screen for
  /// ~20 seconds, then 3 escalation pings nag the user with growing rep
  /// debt if they haven't tapped in. Cancelled the moment reps complete.
  static List<_WakePing> _wakePingSchedule() => const [
        // Burst — 5 pings, 4 seconds apart.
        _WakePing(Duration.zero, '⚠️ WAKE UP!', "Time's up. Do it now."),
        _WakePing(Duration(seconds: 4), '⚠️ WAKE UP!', 'Get up. Move.'),
        _WakePing(Duration(seconds: 8), '⚠️ WAKE UP!', 'This is not a suggestion.'),
        _WakePing(Duration(seconds: 12), '⚠️ WAKE UP!', 'Move.'),
        _WakePing(Duration(seconds: 16), '⚠️ WAKE UP!', 'Last chance before punishment.'),
        // Escalation — nag the rep debt while they lie in bed.
        _WakePing(Duration(minutes: 1), '😡 +5 REPS', 'You are late. Get up.'),
        _WakePing(Duration(minutes: 5), '🔥 +25 REPS', 'This is embarrassing. Get up.'),
        _WakePing(Duration(minutes: 15), '💀 +75 REPS', 'You broke the contract. Move.'),
      ];

  /// Cancel only the escalation pings (indices 5–7) for a habit's wake.
  /// Called from the wake-exercise screen the instant reps complete — the
  /// initial burst is done by that point but any queued escalation pings
  /// need to stop RIGHT NOW so the user isn't punished after success.
  static Future<void> cancelWakeEscalations(String habitId) async {
    int cancelled = 0;
    for (int day = 0; day < 7; day++) {
      final baseId = _getAlarmId(habitId, day);
      for (int i = 5; i < 10; i++) {
        try {
          await _notifications.cancel(baseId * 10 + i);
          _scheduledAlarms.remove(baseId * 10 + i);
          cancelled++;
        } catch (_) {}
      }
    }
    debugPrint('🛑 Cancelled $cancelled wake escalation pings for $habitId');
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

/// A single scheduled wake-alarm ping: what to show, and when after the
/// scheduled fire time to fire it.
class _WakePing {
  final Duration offset;
  final String title;
  final String body;
  const _WakePing(this.offset, this.title, this.body);
}
