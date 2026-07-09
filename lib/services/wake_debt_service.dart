import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/habit.dart';
import 'local_storage.dart';

/// Computes the escalating rep debt for a wake alarm.
///
/// Base reps: 10 squats. Every minute the user delays adds +5 reps,
/// capped so nobody owes 500 reps if they slept eight hours.
///
/// Also tracks which habit is currently the "active wake" — the one
/// they are being nagged about right now — so MainScreen can route
/// straight into the wake flow on cold start or resume.
class WakeDebtService {
  static const String _kActiveHabit = 'wake_active_habit';
  static const String _kActiveSince = 'wake_active_since';

  /// Baseline reps the user always owes when the alarm fires.
  static const int baseReps = 10;

  /// Extra reps added for every full minute the alarm is unanswered.
  static const int repsPerMinute = 5;

  /// Hard cap so total debt never exceeds this many reps.
  static const int maxDebtReps = 100;

  /// Change-notifier that PunishmentGate listens to. Every markActive /
  /// clearActive call toggles this value so the gate re-checks and
  /// swaps MainScreen for MorningAlarmScreen (or back) immediately —
  /// no waiting for a polling tick.
  static final ValueNotifier<int> wakeChanged = ValueNotifier(0);
  static void _notifyChanged() => wakeChanged.value++;

  /// Mark a habit as the currently-active wake target.
  ///
  /// Called by the notification-tap router the moment we open the wake
  /// screen. Persists so a background→foreground cycle still finds it.
  static Future<void> markActive(String habitId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kActiveHabit, habitId);
    await prefs.setInt(
      _kActiveSince,
      DateTime.now().millisecondsSinceEpoch,
    );
    _notifyChanged();
    debugPrint('WakeDebt: marked active habit $habitId');
  }

  /// Clear the active wake — user completed the reps or the alarm was
  /// disarmed. Called from the exercise screen on success.
  static Future<void> clearActive() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kActiveHabit);
    await prefs.remove(_kActiveSince);
    _notifyChanged();
    debugPrint('WakeDebt: cleared');
  }

  /// Find any wake habit whose scheduled fire happened in the last 30
  /// minutes AND that isn't marked done today. If one exists, the app
  /// should be in punishment mode — no matter what tab the user was on.
  static Habit? findDueWakeHabit() {
    final now = DateTime.now();
    final today = now.weekday == 7 ? 0 : now.weekday;
    for (final h in LocalStorageService.getAllHabits()) {
      if (!h.reminderOn || h.time.isEmpty) continue;
      if (!h.repeatDays.contains(today)) continue;
      if (h.isDoneOn(now)) continue;
      try {
        final parts = h.time.split(':');
        final fire = DateTime(now.year, now.month, now.day,
            int.parse(parts[0]), int.parse(parts[1]));
        final diff = now.difference(fire);
        // Fire happened within the last 30 min (or is happening RIGHT
        // now — small negative diff, up to 5s before, catches races).
        if (diff.inSeconds >= -5 && diff.inMinutes <= 30) return h;
      } catch (_) {}
    }
    return null;
  }

  /// The habit ID of the current active wake, or null if none.
  static Future<String?> getActiveHabitId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kActiveHabit);
  }

  /// Whether there is currently an unanswered wake alarm.
  static Future<bool> hasActive() async =>
      (await getActiveHabitId()) != null;

  /// The scheduled fire time for today's occurrence of this habit,
  /// derived from `habit.time`. If the time hasn't come yet today,
  /// falls back to yesterday's fire (the user snoozed overnight).
  static DateTime? scheduledFireForToday(Habit habit) {
    if (habit.time.isEmpty) return null;
    try {
      final parts = habit.time.split(':');
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      final now = DateTime.now();
      var fire = DateTime(now.year, now.month, now.day, hour, minute);
      if (fire.isAfter(now)) {
        fire = fire.subtract(const Duration(days: 1));
      }
      return fire;
    } catch (_) {
      return null;
    }
  }

  /// How many minutes late the user is versus the scheduled fire.
  /// Returns 0 if we can't determine.
  static int minutesLate(Habit habit) {
    final fire = scheduledFireForToday(habit);
    if (fire == null) return 0;
    final elapsed = DateTime.now().difference(fire).inMinutes;
    return elapsed < 0 ? 0 : elapsed;
  }

  /// Total reps the user owes RIGHT NOW for this habit: base plus
  /// escalation. Recomputed every time the wake or exercise screen
  /// asks — the number ticks up while they stall.
  static int totalRepsFor(Habit habit) {
    final debt = (minutesLate(habit) * repsPerMinute).clamp(0, maxDebtReps);
    return baseReps + debt;
  }
}
