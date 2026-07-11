import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/habit.dart';
import '../models/violation.dart';
import '../services/local_storage.dart';
import '../services/alarm_service.dart';
import '../services/sergeant_service.dart';
import '../services/discipline_service.dart';

class HabitEngine extends ChangeNotifier {
  final LocalStorageService localStorageService;
  List<Habit> _habits = [];
  bool _isSyncing = false;

  List<Habit> get habits => _habits;
  bool get isSyncing => _isSyncing;

  HabitEngine(this.localStorageService);

  Future<void> loadHabits() async {
    _habits = LocalStorageService.getAllHabits();
    notifyListeners();
    debugPrint('✅ Loaded ${_habits.length} habits');
  }

  Future<void> addHabit(Habit h) async {
    await LocalStorageService.saveHabit(h);
    _habits.add(h);
    notifyListeners();

    // Schedule the alarm in the background — awaiting it was blocking
    // the save-flow UI for 1-2s while AlarmService tore down 7×20
    // pending notifications and re-scheduled them. The caller
    // (NewContractScreen / NewWakeAlarmScreen) can now pop
    // immediately.
    if (h.reminderOn && h.time.isNotEmpty) {
      // ignore: unawaited_futures
      Future(() async {
        try {
          await AlarmService.scheduleAlarm(h);
          debugPrint('✅ Alarm scheduled (async) for habit: ${h.title}');
        } catch (e) {
          debugPrint('⚠️ Failed to schedule alarm for habit "${h.title}": $e');
        }
      });
    } else {
      debugPrint('⏰ No alarm scheduled for "${h.title}" (reminderOn=${h.reminderOn}, time="${h.time}")');
    }
  }

  Future<void> deleteHabit(String id) async {
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    debugPrint('🗑️ DELETING HABIT: $id');
    
    // Find habit details for logging
    final habit = _habits.firstWhere((h) => h.id == id, orElse: () => Habit(
      id: id,
      title: 'Unknown',
      type: 'habit',
      time: '',
      startDate: DateTime.now(),
      endDate: DateTime.now(),
      repeatDays: [],
      createdAt: DateTime.now(),
    ));
    
    debugPrint('   📝 Habit: "${habit.title}"');
    debugPrint('   ⏰ Had reminders: ${habit.reminderOn}');
    debugPrint('   🕐 Time: ${habit.time}');
    
    // Step 1: Cancel alarms FIRST (before deleting from storage)
    try {
      debugPrint('🔔 Step 1: Cancelling alarms...');
      await AlarmService.cancelAlarm(id);
      debugPrint('✅ Alarm cancellation completed');
      
      // Step 2: Verify cancellation succeeded
      debugPrint('🔍 Step 2: Verifying cancellation...');
      final verified = await AlarmService.verifyAlarmCancelled(id);
      
      if (!verified) {
        debugPrint('⚠️ WARNING: Alarm verification failed! Retrying cancellation...');
        // Retry once
        await AlarmService.cancelAlarm(id);
        final retryVerified = await AlarmService.verifyAlarmCancelled(id);
        
        if (!retryVerified) {
          throw Exception('Failed to cancel alarms after retry');
        }
        debugPrint('✅ Retry successful - alarms verified cancelled');
      } else {
        debugPrint('✅ Verification passed - alarms confirmed cancelled');
      }
    } catch (e, stack) {
      debugPrint('❌ CRITICAL ERROR: Failed to cancel alarms for habit: $id');
      debugPrint('Error: $e');
      debugPrint('Stack: $stack');
      // Continue with deletion but log the error
      debugPrint('⚠️ Continuing with habit deletion despite alarm cancellation failure');
    }
    
    // Step 3: Delete from storage
    debugPrint('💾 Step 3: Deleting from storage...');
    await LocalStorageService.deleteHabit(id);
    
    // Step 4: Remove from memory
    debugPrint('🧠 Step 4: Removing from memory...');
    _habits.removeWhere((x) => x.id == id);
    
    // Step 5: Notify listeners
    notifyListeners();
    
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    debugPrint('✅ DELETION COMPLETE for: "${habit.title}"');
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  }

  Future<void> completeHabit(String id) async {
    final idx = _habits.indexWhere((x) => x.id == id);
    if (idx == -1) return;

    final h = _habits[idx];
    final updated = h.copyWith(
      done: true,
      completedAt: DateTime.now(),
      streak: h.streak + 1,
      xp: h.xp + 15,
    );

    await LocalStorageService.saveHabit(updated);
    _habits[idx] = updated;
    notifyListeners();
    debugPrint('✅ Completed habit: ${h.title}');
  }

  Future<Habit> createHabit({
    required String title,
    required String type,
    required String time,
    DateTime? startDate,
    DateTime? endDate,
    List<int>? repeatDays,
    Color? color,
    String? emoji,
    bool reminderOn = false,
    String? systemId,
  }) async {
    // Debug logging
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    debugPrint('🔍 createHabit called with:');
    debugPrint('   📝 title: "$title"');
    debugPrint('   🕐 time: "$time"');
    debugPrint('   🔔 reminderOn: $reminderOn');
    debugPrint('   📋 type: $type');
    debugPrint('   🎨 color: ${color?.value.toRadixString(16)}');
    debugPrint('   😀 emoji: $emoji');
    debugPrint('   🔗 systemId: $systemId');
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    // Validate: Don't create alarm if no time set
    bool actualReminderOn = reminderOn;
    if (reminderOn && time.isEmpty) {
      debugPrint('⚠️ WARNING: reminderOn=true but time is EMPTY! Forcing reminderOn=false');
      actualReminderOn = false;
    }

    final habit = Habit(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title.trim(),
      type: type,
      time: time,
      startDate: startDate ?? DateTime.now(),
      endDate: endDate ?? DateTime.now().add(const Duration(days: 365)),
      repeatDays: repeatDays ?? _getDefaultRepeatDays(type),
      createdAt: DateTime.now(),
      colorValue: color?.value ?? 0xFF10B981,
      emoji: emoji,
      reminderOn: actualReminderOn,
      systemId: systemId,
    );

    debugPrint('✅ Habit object created:');
    debugPrint('   - id: ${habit.id}');
    debugPrint('   - reminderOn: ${habit.reminderOn}');
    debugPrint('   - time: "${habit.time}"');
    debugPrint('   - repeatDays: ${habit.repeatDays}');

    await addHabit(habit);

    if (habit.reminderOn) {
      debugPrint('✅ Alarm SHOULD be scheduled for "${habit.title}"');
    } else {
      debugPrint('⏰ Alarm NOT scheduled (reminderOn=${habit.reminderOn})');
    }
    return habit;
  }

  Future<void> updateHabit(Habit updated) async {
    await LocalStorageService.saveHabit(updated);
    final idx = _habits.indexWhere((h) => h.id == updated.id);
    if (idx != -1) {
      _habits[idx] = updated;
      notifyListeners();

      // Fire-and-forget the alarm cancel+reschedule. Same reason as
      // addHabit — this cascade of iOS notification calls was the
      // multi-second pause between SAVE tap and the Contracts tab
      // showing up. The persistence and in-memory update above are
      // synchronous, so the UI is already correct by the time this
      // runs in the background.
      // ignore: unawaited_futures
      Future(() async {
        try {
          await AlarmService.cancelAlarm(updated.id);
          if (updated.reminderOn && updated.time.isNotEmpty) {
            await AlarmService.scheduleAlarm(updated);
            debugPrint('🔔 Rescheduled (async) alarm for "${updated.title}"');
          }
        } catch (e) {
          debugPrint('⚠️ Failed to reschedule alarm for "${updated.title}": $e');
        }
      });
    }
  }

  /// Returns a Violation if a bad habit was triggered, null otherwise
  Future<Violation?> toggleHabitCompletion(String habitId) async {
    final habit = _habits.firstWhere((h) => h.id == habitId);

    // Bad habits: "completing" means user indulged → trigger sergeant.
    // Streak is a CLEAN-DAYS counter for Laws; pressing "I broke it"
    // resets it to 0. The daily check job increments it by 1 for every
    // day a rule wasn't broken (see DisciplineService.runDailyCheck).
    if (habit.type == 'bad_habit') {
      final violation = await SergeantService.triggerBadHabitViolation(habit);
      final updated = habit.copyWith(
        done: true,
        completedAt: DateTime.now(),
        streak: 0,
      );
      await LocalStorageService.saveHabit(updated);
      final idx = _habits.indexWhere((h) => h.id == habitId);
      if (idx != -1) {
        _habits[idx] = updated;
        notifyListeners();
      }
      return violation;
    }

    // Normal habits: toggle done/undone.
    //
    // Streak rule: increment ONCE per day when we transition from
    // undone → done. Un-ticking (done → undone, e.g. the user tapped
    // by accident and untapped) MUST NOT wipe the streak — that
    // regression was destroying users' progress on a mis-tap and is
    // fixed here. Streak only resets when a day passes without a
    // completion, and that reset is owned by the daily-check job.
    final today = DateTime.now();
    final isCurrentlyDone = habit.isDoneOn(today);
    final nowDone = !isCurrentlyDone;

    final updated = habit.copyWith(
      done: nowDone,
      completedAt: nowDone ? today : null,
      streak: nowDone ? habit.streak + 1 : habit.streak,
      xp: nowDone ? habit.xp + 15 : habit.xp,
    );

    await LocalStorageService.saveHabit(updated);
    final idx = _habits.indexWhere((h) => h.id == habitId);
    if (idx != -1) {
      _habits[idx] = updated;
      notifyListeners();
    }
    return null;
  }

  List<int> _getDefaultRepeatDays(String type) =>
      (type == 'habit' || type == 'bad_habit') ? [1, 2, 3, 4, 5] : [DateTime.now().weekday % 7];

  Future<void> syncAllHabits() async {
    _isSyncing = true;
    notifyListeners();

    try {
      await loadHabits();
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }
}
