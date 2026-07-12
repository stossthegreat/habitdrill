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
import 'normal_reminder_registry.dart';

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

      // NO permission requests here. Every one of them auto-firing
      // at launch is what put "alarm permission" on the first screen
      // of onboarding no matter how we structured the flow. All three
      // (notification, exact-alarm, AlarmKit authorization) now
      // happen inline via the onboarding permission screens or lazily
      // inside scheduleAlarm() when the user actually needs them.
      final notifStatus = await Permission.notification.status;
      debugPrint('Notification permission (status only): $notifStatus');

      // Initialize notification plugin.
      //
      // ⚠️ CRITICAL — iOS request*Permission flags MUST all be false.
      // flutter_local_notifications triggers the iOS system prompt the
      // moment initialize() runs when any of these are true. That
      // happens at app launch, BEFORE onboarding renders — silently
      // defeating every "we ask in-context" screen we added. The
      // onboarding permission ask (see _PermissionAsk) calls
      // Permission.notification.request() at the right moment.
      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosInit = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
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

      // Contract/law reminders: single weekly ping per repeat day.
      // No AlarmKit cascade, no escalation ladder — just a normal
      // notification that tells them "hey, your rule/order is up."
      if (NormalReminderRegistry.isNormalReminder(habit.id)) {
        await _scheduleContractReminder(habit);
        return;
      }

      if (habit.repeatDays.isEmpty) {
        debugPrint('   ⚠️ habit has no repeatDays; nothing to schedule');
        return;
      }

      int successCount = 0;
      int failCount = 0;

      // ── Adaptive scheduling ─────────────────────────────────────
      //
      // Everything weekly-repeating so iOS keeps it alive without
      // any re-schedule logic from us. Number of pings per fire is
      // ADAPTIVE based on how many wake alarms the user has, so we
      // stay under iOS's 64 pending-notification cap regardless of
      // how many alarms they create.
      //
      //   1 wake alarm            → 5 pings/day (fire, +30s, +1m, +2m, +3m)
      //   2 wake alarms           → 4 pings/day each   (56 total)
      //   3 wake alarms           → 3 pings/day each   (63 total)
      //   4 wake alarms           → 2 pings/day each   (56 total)
      //   5-9 wake alarms         → 1 ping/day each    (35-63 total)
      //   10+ wake alarms         → still 1 ping/day, some may drop
      //
      // AlarmKit (iOS 26+) gets the same treatment against its ~100
      // per-app cap. On iOS < 26 the user's morning is one single
      // (LOUD, time-sensitive) notification, exactly like a Clock
      // alarm — plus the in-app WakeSirenService taking over once
      // they open the app.

      final wakeHabitCount = _countActiveWakeHabits();
      final pingsPerDay = _pingsForWakeCount(wakeHabitCount);
      final List<Duration> retryOffsets = _retryOffsetsForCount(pingsPerDay);
      debugPrint('   wakeHabits=$wakeHabitCount  pingsPerDay=$pingsPerDay');

      final bool alarmKitAvailable = await AlarmKitService.isAvailable();
      debugPrint('   AlarmKit available: $alarmKitAvailable');

      for (final day in habit.repeatDays) {
        final baseAlarmId = _getAlarmId(habit.id, day);
        final fireDate = _getNextAlarmTime(day, habit.timeOfDay);

        for (int i = 0; i < retryOffsets.length; i++) {
          final fireTime = fireDate.add(retryOffsets[i]);

          // ── Notification (weekly-repeating) ──────────────────────
          final pingId = baseAlarmId * 100 + i;
          try {
            await _notifications.zonedSchedule(
              pingId,
              i == 0 ? '⏰ ${habit.title}' : '🚨 GET UP',
              i == 0
                  ? "The alarm is ringing. Open HabitDrill to shut it up."
                  : 'Still in bed. The debt is growing.',
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
              // Every ping matches weekly — iOS keeps them alive.
              matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
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
              'retry': i,
              'scheduledAt': fireTime.toIso8601String(),
            };
          } catch (e) {
            failCount++;
            debugPrint('   ❌ notif ${_getDayName(day)} #$i: $e');
          }

          // ── AlarmKit (iOS 26+) ──────────────────────────────────
          if (alarmKitAvailable) {
            final akId = _uuidFromInt(baseAlarmId * 100 + i);
            try {
              await AlarmKitService.cancel(akId);
              final ok = await AlarmKitService.schedule(
                id: akId,
                title: i == 0
                    ? 'ORDER: ${habit.title.toUpperCase()}'
                    : 'GET UP: ${habit.title.toUpperCase()}',
                fireAt: fireTime.toLocal(),
                habitId: habit.id,
              );
              if (i == 0) {
                debugPrint(
                  '   🛎 AlarmKit ${_getDayName(day)}: ${ok ? "scheduled" : "failed"}',
                );
              }
            } catch (e) {
              debugPrint('   ❌ AlarmKit ${_getDayName(day)} #$i: $e');
            }
          }
        }
      }

      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('📊 Alarm scheduling summary for "${habit.title}":');
      debugPrint('   ✅ notifications: $successCount / ${habit.repeatDays.length * retryOffsets.length}');
      debugPrint('   ❌ failed: $failCount');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    } catch (e, stack) {
      debugPrint('❌ scheduleAlarm error: $e');
      debugPrint('Stack: $stack');
    }
  }

  /// Schedule a plain, non-cascading reminder for contracts and laws.
  /// One notification per repeat day, matches iOS's dayOfWeekAndTime
  /// so it repeats weekly on its own. NO AlarmKit cascade, NO
  /// escalation ping ladder, NO punishment gate — this ping just
  /// tells them "your contract time is up."
  static Future<void> _scheduleContractReminder(Habit habit) async {
    int successCount = 0;
    for (final day in habit.repeatDays) {
      final baseAlarmId = _getAlarmId(habit.id, day);
      final pingId = baseAlarmId * 100; // slot 0
      final fireTime = _getNextAlarmTime(day, habit.timeOfDay);
      try {
        await _notifications.zonedSchedule(
          pingId,
          '⏰ ${habit.title}',
          habit.type == 'bad_habit'
              ? "Stay honest with your rule."
              : "It's time. Show up.",
          fireTime,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              _channelId,
              _channelName,
              channelDescription: _channelDescription,
              importance: Importance.high,
              priority: Priority.high,
              playSound: true,
              enableVibration: true,
              enableLights: true,
              autoCancel: true,
            ),
            iOS: DarwinNotificationDetails(
              presentAlert: true,
              presentSound: true,
              presentBadge: true,
              interruptionLevel: InterruptionLevel.active,
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          payload: habit.id,
        );
        _scheduledAlarms[pingId] = {
          'habitTitle': habit.title,
          'habitId': habit.id,
          'day': day,
          'time': habit.time,
          'kind': 'contract_reminder',
          'scheduledAt': fireTime.toIso8601String(),
        };
        successCount++;
      } catch (e) {
        debugPrint('   ❌ contract reminder ${_getDayName(day)}: $e');
      }
    }
    debugPrint('📣 Contract reminder scheduled ($successCount days) for "${habit.title}"');
  }

  /// How many wake alarms (type='habit' with time+reminderOn, NOT a
  /// contract reminder) the user currently has on file. Drives
  /// pings-per-day so we never blow through iOS's 64 notification
  /// cap regardless of how many alarms they create.
  static int _countActiveWakeHabits() {
    try {
      final all = LocalStorageService.getAllHabits();
      return all
          .where((h) =>
              h.type == 'habit' &&
              h.time.isNotEmpty &&
              h.reminderOn &&
              !NormalReminderRegistry.isNormalReminder(h.id))
          .length;
    } catch (e) {
      debugPrint('_countActiveWakeHabits failed: $e');
      return 1;
    }
  }

  /// pingsPerDay budget as a function of how many wake habits the
  /// user has, chosen so that (pings × 7 days × habits) never crosses
  /// 60 (iOS 64-cap with a small safety margin).
  static int _pingsForWakeCount(int count) {
    if (count <= 1) return 5;
    if (count == 2) return 4;
    if (count == 3) return 3;
    if (count == 4) return 2;
    return 1; // 5+ habits — clock-alarm style, one ping/morning.
  }

  static List<Duration> _retryOffsetsForCount(int pings) {
    const all = [
      Duration.zero,
      Duration(seconds: 30),
      Duration(minutes: 1),
      Duration(minutes: 2),
      Duration(minutes: 3),
    ];
    if (pings >= all.length) return all;
    return all.sublist(0, pings);
  }

  /// Cancel all alarms for a habit
  static Future<void> cancelAlarm(String habitId) async {
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    debugPrint('🗑️ CANCELLING ALARMS for habit: $habitId');

    // AlarmKit path — quietly cancel every derived UUID for every
    // retry slot from any historical cascade length. Safe on old
    // iOS because AlarmKitService returns false without erroring.
    //
    // Why 200 (was _akCascadeOffsets.length): earlier builds
    // scheduled 30-slot and 180-slot cascades. Only cancelling
    // 0..currentLength-1 left orphan AlarmKit ids sitting in
    // iOS's per-app queue. iOS caps AlarmKit at ~100 total, so a
    // habit re-scheduled after the cascade shrank kept the old
    // orphans AND added the new ids until the ceiling was hit and
    // subsequent schedules silently dropped. Sweeping every slot
    // that ANY historical cascade could have used clears them out.
    for (int day = 0; day < 7; day++) {
      final baseId = _getAlarmId(habitId, day);
      for (int r = 0; r < 200; r++) {
        final akId = _uuidFromInt(baseId * 100 + r);
        try {
          await AlarmKitService.cancel(akId);
        } catch (_) {}
      }
      // Also try the pre-retry legacy UUID (single alarm per day).
      try {
        await AlarmKitService.cancel(_uuidFromInt(baseId));
      } catch (_) {}
    }

    // Get pending notifications BEFORE cancellation
    final pendingBefore = await _notifications.pendingNotificationRequests();
    final habitAlarmIds = <int>[];

    // Up to 100 wake ping slots per day (3 burst + 15 escalation actually
    // used; loop to 100 to catch any leftovers from older versions and
    // legacy *10 IDs).
    for (int day = 0; day < 7; day++) {
      final baseId = _getAlarmId(habitId, day);
      for (int i = 0; i < 100; i++) {
        habitAlarmIds.add(baseId * 100 + i);
        // Legacy *10 scheme — earlier builds; ensure they're captured too.
        if (i < 10) habitAlarmIds.add(baseId * 10 + i);
      }
    }
    
    final relevantBefore = pendingBefore.where((n) => habitAlarmIds.contains(n.id)).toList();
    debugPrint('📊 Found ${relevantBefore.length} pending alarms for this habit');
    
    // Cancel each alarm with error handling
    int successCount = 0;
    int failCount = 0;
    
    for (int day = 0; day < 7; day++) {
      final baseId = _getAlarmId(habitId, day);
      // Cancel every ping slot for this day — new *100 IDs plus any
      // legacy *10 IDs left behind by earlier builds.
      for (int i = 0; i < 100; i++) {
        final newId = baseId * 100 + i;
        try {
          await _notifications.cancel(newId);
          _scheduledAlarms.remove(newId);
          successCount++;
        } catch (e) {
          failCount++;
          debugPrint('   ❌ Failed to cancel alarm ID $newId (${_getDayName(day)} slot $i): $e');
        }
        if (i < 10) {
          final legacyId = baseId * 10 + i;
          try {
            await _notifications.cancel(legacyId);
            _scheduledAlarms.remove(legacyId);
          } catch (_) {}
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
    
    // Do NOT throw when verification finds stragglers. Historically
    // this bubbled out of cancelAlarm and killed the wrapping try in
    // scheduleAlarm, so a single leftover pending notification meant
    // NO alarm got scheduled — silent failure the user sees as "the
    // shark isn't ringing anymore." A stray notification is at worst
    // a duplicate; the fresh schedule below is what matters, and
    // it's idempotent per-id anyway.
    if (relevantAfter.isNotEmpty) {
      debugPrint('   ⚠️ Continuing anyway — pending stragglers are non-fatal.');
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

  /// Weekday encoding matching our repeatDays convention (0=Sun..6=Sat)
  /// derived from a timezone-aware date.
  static int _dayForTz(tz.TZDateTime d) => d.weekday == 7 ? 0 : d.weekday;

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

  /// The wake schedule: 3 burst pings hit the lock screen at t+0/8/16s,
  /// then 20 escalation pings hammer once per minute from t+60s through
  /// t+1200s. Total 23 pings per fire. The debt in each escalation title
  /// matches WakeDebtService (base 10 + 2×min_late, capped at 20 min /
  /// +40 reps) so what the user sees on their lock screen == what they
  /// actually owe.
  ///
  /// Only the burst pings repeat weekly. The escalation pings are
  /// one-shots scheduled for the NEXT upcoming fire and re-generated on
  /// every app resume — see `rescheduleWakeAlarms()`. This dance keeps
  /// us under iOS's 64-slot pending-notification cap even with 3 burst
  /// × 7 weekdays + 20 escalations = 41 pending per habit.
  static List<_WakePing> _wakePingSchedule() => const [
        // Burst — 3 pings. First one is intentionally green ("WAKE UP OR
        // PAY") to offer a choice; the follow-ups turn into full drill-
        // sergeant unhinged mode. No sleep. No mercy.
        _WakePing(Duration.zero,           '🟢 WAKE UP OR PAY',
            'GET UP NOW OR PAY THE DEBT. YOUR CALL, SOLDIER.'),
        _WakePing(Duration(seconds: 8),    '⚠️ ON YOUR FEET!',
            'GET UP GET UP GET UP GET UP. NOW.'),
        _WakePing(Duration(seconds: 16),   '🚨 GET OUT OF BED!',
            'MOVE. RIGHT. NOW. STOP LYING TO YOURSELF.'),
        // Escalation — every minute for 20 minutes, growing debt at
        // +2 reps per minute (matches WakeDebtService.repsPerMinute).
        // After minute 20 the debt cap is hit and no more escalations
        // fire — the alarm/live cascade takes over from there.
        _WakePing(Duration(minutes: 1),    '😡 +2 REPS',
            'STILL IN BED?! GET UP MAGGOT.'),
        _WakePing(Duration(minutes: 2),    '😡 +4 REPS',
            'WHAT ARE YOU DOING?! MOVE!'),
        _WakePing(Duration(minutes: 3),    '🔥 +6 REPS',
            'DISGRACEFUL. GET UP. NOW.'),
        _WakePing(Duration(minutes: 4),    '🔥 +8 REPS',
            'STOP. STOP LYING. GET UP.'),
        _WakePing(Duration(minutes: 5),    '😤 +10 REPS',
            'YOU BROKE THE PROMISE. YOU OWE ME.'),
        _WakePing(Duration(minutes: 6),    '😤 +12 REPS',
            "DEBT'S GROWING. EVERY MINUTE. MOVE."),
        _WakePing(Duration(minutes: 7),    '🔥 +14 REPS',
            'YOU DISGUST ME. GET UP.'),
        _WakePing(Duration(minutes: 8),    '🔥 +16 REPS',
            'STAND UP. RIGHT. NOW.'),
        _WakePing(Duration(minutes: 9),    '💀 +18 REPS',
            "YOU'RE FAILING. AGAIN."),
        _WakePing(Duration(minutes: 10),   '💀 +20 REPS',
            'WEAK. WEAK. WEAK.'),
        _WakePing(Duration(minutes: 11),   '💀 +22 REPS',
            'MOVE OR LIVE WITH IT.'),
        _WakePing(Duration(minutes: 12),   '💀 +24 REPS',
            'DISCIPLINE IS COMING FOR YOU.'),
        _WakePing(Duration(minutes: 13),   '💀 +26 REPS',
            'FINAL WARNING, SOLDIER.'),
        _WakePing(Duration(minutes: 14),   '💀 +28 REPS',
            'YOU CHOSE THIS. LIVE WITH IT.'),
        _WakePing(Duration(minutes: 15),   '💀 +30 REPS',
            'CONTRACT DEAD. GET UP AND PAY.'),
        _WakePing(Duration(minutes: 16),   '💀 +32 REPS',
            'YOU ARE OUT OF MINUTES. MOVE.'),
        _WakePing(Duration(minutes: 17),   '💀 +34 REPS',
            'GET UP. GET UP. GET UP.'),
        _WakePing(Duration(minutes: 18),   '💀 +36 REPS',
            'THIS IS WHO YOU CHOSE TO BE.'),
        _WakePing(Duration(minutes: 19),   '💀 +38 REPS',
            'GET UP OR LIVE THE LIE FOREVER.'),
        _WakePing(Duration(minutes: 20),   '💀 +40 REPS — MAX',
            'DEBT CAPPED. NOW GET UP AND PAY IT.'),
      ];

  /// Which indices in [_wakePingSchedule] are the escalation pings.
  static const int _escalationStart = 3;
  static const int _escalationEnd = 23; // exclusive

  /// Cancel every escalation ping across all days for a habit's wake.
  /// Called the instant wake reps complete — any queued escalation
  /// notification needs to disappear before it can nag a user who
  /// already did the work.
  static Future<void> cancelWakeEscalations(String habitId) async {
    int cancelled = 0;
    for (int day = 0; day < 7; day++) {
      final baseId = _getAlarmId(habitId, day);
      for (int i = _escalationStart; i < 100; i++) {
        try {
          await _notifications.cancel(baseId * 100 + i);
          _scheduledAlarms.remove(baseId * 100 + i);
          cancelled++;
        } catch (_) {}
      }
    }
    // Also cancel any AlarmKit retries queued for the next fire.
    try {
      await cancelWakeAlarmKitRetries(habitId);
    } catch (_) {}
    debugPrint('🛑 Cancelled $cancelled wake escalation pings for $habitId');
  }

  /// Cancel the remaining AlarmKit cascade for TODAY only. Called the
  /// instant wake reps complete so the phone stops re-ringing three
  /// seconds later. DOES NOT touch other weekdays' cascades — those
  /// still need to fire tomorrow, the day after, etc.
  ///
  /// This is the actual "works then doesn't work" root cause: the
  /// previous version looped over all 7 days and cancelled ALL 70
  /// AlarmKit alarms in one shot. Monday reps → cancelled Tuesday
  /// through Sunday too. If the user didn't foreground the app before
  /// Tuesday 6am, Tuesday's cascade never rang.
  static Future<void> cancelWakeAlarmKitRetries(String habitId) async {
    final now = DateTime.now();
    final today = now.weekday == 7 ? 0 : now.weekday;
    final baseAlarmId = _getAlarmId(habitId, today);
    // Sweep 200 slots to also flush any historical cascade orphans
    // (see cancelAlarm for the same reasoning).
    for (int r = 0; r < 200; r++) {
      final uuid = _uuidFromInt(baseAlarmId * 100 + r);
      try {
        await AlarmKitService.cancel(uuid);
      } catch (_) {}
    }
    debugPrint('🛑 Cancelled today\'s AlarmKit cascade for $habitId (day=$today)');
  }

  /// Re-schedule the wake-alarm pings + AlarmKit retries for every
  /// habit with reminderOn. Call on app resume so the escalation loop
  /// always covers the NEXT upcoming fire (escalation is one-shot to
  /// stay under the 64-slot pending-notification cap; without a periodic
  /// re-schedule the third day's wake would have no escalation).
  static Future<void> rescheduleWakeAlarms(Iterable<Habit> habits) async {
    for (final h in habits) {
      if (h.reminderOn && h.time.isNotEmpty) {
        try {
          await scheduleAlarm(h);
        } catch (e) {
          debugPrint('rescheduleWakeAlarms failed for ${h.title}: $e');
        }
      }
    }
  }

  /// One AlarmKit alarm every 10 seconds — 10 alarms, 100 seconds of
  /// nonstop ringing per day. Under the hood these are separate
  /// AlarmKit alarms, but the user experience is "the alarm won't
  /// die": dismiss one → 10 seconds later another rings → dismiss →
  /// another — until they finish reps (cancelWakeAlarmKitRetries
  /// kills every remaining one).
  ///
  /// Why 10 (was 30 for next-fire day only, single seed for other
  /// days): AlarmKit caps at ~100 scheduled alarms PER APP. The old
  /// scheme gave the NEXT fire a 30-alarm cascade but every OTHER
  /// weekday got a single seed alarm — meaning "the alarm worked
  /// perfectly on Monday, then Tuesday morning it just rang once
  /// and I went back to sleep." Every day now gets the same 10-slot
  /// cascade so the pressure never depends on whether the app was
  /// opened after Monday's alarm. Total per habit = 10 × 7 = 70
  /// AlarmKit alarms, well inside the 100-alarm ceiling with room
  /// for a second habit if the user adds one.
  static final List<Duration> _akCascadeOffsets = List<Duration>.generate(
    10,
    (i) => Duration(seconds: 10 * i),
  );

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

  // ────────────────── Diagnostics helpers (public) ──────────────────

  /// All notifications currently scheduled with iOS/Android. Sorted
  /// by id. Consumed by DiagnosticsScreen to show whether the
  /// scheduleAlarm calls actually made it into the OS queue.
  static Future<List<PendingNotificationRequest>> pendingNotifications() async {
    try {
      final all = await _notifications.pendingNotificationRequests();
      all.sort((a, b) => a.id.compareTo(b.id));
      return all;
    } catch (e) {
      debugPrint('pendingNotifications failed: $e');
      return const [];
    }
  }

  /// Dispatch an immediate test notification. Unique id per call
  /// (timestamp-derived) so back-to-back probes don't replace each
  /// other — iOS replaces silently when you reuse an id.
  static Future<bool> fireTestNotificationNow() async {
    try {
      final id = 999000 + (DateTime.now().millisecondsSinceEpoch % 900);
      await _notifications.show(
        id,
        '🧪 HABITDRILL TEST',
        'If you see this, foreground notifications are wired.',
        const NotificationDetails(
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentSound: true,
            presentBadge: true,
            interruptionLevel: InterruptionLevel.timeSensitive,
          ),
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDescription,
            importance: Importance.max,
            priority: Priority.high,
          ),
        ),
      );
      return true;
    } catch (e) {
      debugPrint('fireTestNotificationNow error: $e');
      return false;
    }
  }

  /// Schedule a plain notification 30 seconds from now — end-to-end
  /// probe of the "future alarm" pipeline. Returns the fire time.
  /// Uses a unique id per call (timestamp-derived) so running the
  /// probe twice within 60 seconds gives you TWO alarms not one.
  static Future<DateTime> scheduleTestAlarmIn30Seconds() async {
    final testId = 998000 + (DateTime.now().millisecondsSinceEpoch % 900);
    final fireAt = tz.TZDateTime.now(tz.local).add(const Duration(seconds: 30));
    try {
      await _notifications.zonedSchedule(
        testId,
        '🧪 HABITDRILL TEST ALARM',
        'Scheduled probe — if this fires the alarm pipeline works.',
        fireAt,
        const NotificationDetails(
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentSound: true,
            presentBadge: true,
            interruptionLevel: InterruptionLevel.timeSensitive,
          ),
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDescription,
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e) {
      debugPrint('scheduleTestAlarmIn30Seconds error: $e');
    }
    return DateTime.fromMillisecondsSinceEpoch(fireAt.millisecondsSinceEpoch);
  }

  /// Cancel every notification (habit + test + sergeant). Used from
  /// diagnostics to reset the queue when it looks fried.
  static Future<void> cancelEverything() async {
    try {
      await _notifications.cancelAll();
      _scheduledAlarms.clear();
    } catch (e) {
      debugPrint('cancelEverything failed: $e');
    }
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
