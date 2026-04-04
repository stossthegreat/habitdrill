import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/violation.dart';
import '../models/exercise_set.dart';
import '../models/escalation_config.dart';
import '../models/habit.dart';
import 'local_storage.dart';
import 'alarm_service.dart';

class SergeantService {
  static const String _violationsBoxName = 'violations';
  static Box<Violation>? _violationsBox;

  static Future<void> initialize() async {
    _violationsBox = await Hive.openBox<Violation>(_violationsBoxName);
    debugPrint('SergeantService initialized with ${_violationsBox?.length ?? 0} violations');
  }

  // ==================== VIOLATION CRUD ====================

  static Future<void> saveViolation(Violation violation) async {
    await _violationsBox?.put(violation.id, violation);
  }

  static List<Violation> getAllViolations() =>
      _violationsBox?.values.toList() ?? [];

  static List<Violation> getPendingViolations() =>
      getAllViolations().where((v) => !v.punishmentCompleted).toList();

  static bool hasPendingPunishment() =>
      getPendingViolations().isNotEmpty;

  /// Get the worst pending violation (highest escalation)
  static Violation? getWorstPendingViolation() {
    final pending = getPendingViolations();
    if (pending.isEmpty) return null;
    pending.sort((a, b) => b.escalationLevel.compareTo(a.escalationLevel));
    return pending.first;
  }

  // ==================== VIOLATION CREATION ====================

  /// Get cumulative offense count for a habit
  static int getOffenseCount(String habitId) {
    return getAllViolations().where((v) => v.habitId == habitId).length;
  }

  /// Create a violation when a bad habit is indulged
  static Future<Violation> triggerBadHabitViolation(Habit habit) async {
    final offenseNumber = getOffenseCount(habit.id) + 1;
    final violation = Violation(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      habitId: habit.id,
      habitTitle: habit.title,
      violationType: 'indulged',
      occurredAt: DateTime.now(),
      scheduledFor: DateTime.now(),
      offenseNumber: offenseNumber,
      escalationLevel: Violation.getEscalationLevel(offenseNumber),
    );

    await saveViolation(violation);
    // Schedule escalating notifications
    await AlarmService.scheduleSergeantNotifications(violation);
    debugPrint('Created violation: ${habit.title} (offense #$offenseNumber, level ${violation.escalationLevel})');
    return violation;
  }

  /// Create a violation when a habit is missed
  static Future<Violation> triggerMissedHabitViolation(Habit habit, DateTime scheduledDate) async {
    // Don't create duplicate violations for the same habit+date
    final existing = getAllViolations().where((v) =>
        v.habitId == habit.id &&
        v.scheduledFor.year == scheduledDate.year &&
        v.scheduledFor.month == scheduledDate.month &&
        v.scheduledFor.day == scheduledDate.day).toList();
    if (existing.isNotEmpty) return existing.first;

    final offenseNumber = getOffenseCount(habit.id) + 1;
    final violation = Violation(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      habitId: habit.id,
      habitTitle: habit.title,
      violationType: 'missed',
      occurredAt: DateTime.now(),
      scheduledFor: scheduledDate,
      offenseNumber: offenseNumber,
      escalationLevel: Violation.getEscalationLevel(offenseNumber),
    );

    await saveViolation(violation);
    await AlarmService.scheduleSergeantNotifications(violation);
    debugPrint('Created missed violation: ${habit.title} (offense #$offenseNumber)');
    return violation;
  }

  // ==================== VIOLATION SCANNING ====================

  /// Scan for missed orders on a given date (end of day check)
  static Future<List<Violation>> scanForViolations(DateTime date) async {
    final habits = LocalStorageService.getAllHabits();
    final violations = <Violation>[];

    for (final habit in habits) {
      // Skip bad habits (those are triggered manually via "I BROKE IT")
      if (habit.type == 'bad_habit') continue;

      if (habit.isScheduledForDate(date) && !habit.isDoneOn(date)) {
        final violation = await triggerMissedHabitViolation(habit, date);
        violations.add(violation);
      }
    }

    if (violations.isNotEmpty) {
      debugPrint('Scan found ${violations.length} violations for ${date.toIso8601String()}');
    }
    return violations;
  }

  /// Scan for OVERDUE orders TODAY (time has passed, not completed).
  /// Call this on app open/resume.
  static Future<List<Violation>> scanForOverdueToday() async {
    final now = DateTime.now();
    final habits = LocalStorageService.getAllHabits();
    final violations = <Violation>[];

    for (final habit in habits) {
      if (habit.type == 'bad_habit') continue;
      if (!habit.isScheduledForDate(now)) continue;
      if (habit.isDoneOn(now)) continue;
      if (habit.time.isEmpty) continue; // No time set = check at end of day

      // Parse the due time
      try {
        final parts = habit.time.split(':');
        final dueHour = int.parse(parts[0]);
        final dueMinute = int.parse(parts[1]);
        final dueTime = DateTime(now.year, now.month, now.day, dueHour, dueMinute);

        // Add 30min grace period
        final deadline = dueTime.add(const Duration(minutes: 30));

        if (now.isAfter(deadline)) {
          final violation = await triggerMissedHabitViolation(habit, now);
          violations.add(violation);
        }
      } catch (e) {
        debugPrint('Error parsing time for ${habit.title}: $e');
      }
    }

    if (violations.isNotEmpty) {
      debugPrint('Found ${violations.length} overdue orders today');
    }
    return violations;
  }

  // ==================== PUNISHMENT FLOW ====================

  /// Get the exercise set for a violation
  static ExerciseSet getExerciseSet(Violation violation) {
    if (violation.violationType == 'tempted') {
      return ExerciseSet.tempted();
    }
    return ExerciseSet.forOffense(violation.offenseNumber);
  }

  /// Get the video path for a violation
  static String getVideoPath(Violation violation) =>
      EscalationConfig.videoAssets[violation.escalationLevel.clamp(1, 3)]!;

  /// Clear a violation after punishment is completed
  static Future<void> clearViolation(String violationId) async {
    final violation = _violationsBox?.get(violationId);
    if (violation == null) return;

    violation.punishmentCompleted = true;
    violation.clearedAt = DateTime.now();
    await violation.save();
    await AlarmService.cancelSergeantNotifications(violationId);
    debugPrint('Cleared violation: ${violation.habitTitle}');
  }

  /// Clear all pending violations (after completing punishment for worst one)
  static Future<void> clearAllPending() async {
    final pending = getPendingViolations();
    for (final v in pending) {
      v.punishmentCompleted = true;
      v.clearedAt = DateTime.now();
      await v.save();
      await AlarmService.cancelSergeantNotifications(v.id);
    }
    debugPrint('Cleared ${pending.length} pending violations');
  }

  // ==================== AI CONTEXT ====================

  /// Get user behavior context for AI prompt injection
  static Map<String, dynamic> getSergeantContext() {
    final violations = getAllViolations();
    final habits = LocalStorageService.getAllHabits();
    final now = DateTime.now();

    // Most violated habits
    final violationCounts = <String, int>{};
    for (final v in violations) {
      violationCounts[v.habitTitle] = (violationCounts[v.habitTitle] ?? 0) + 1;
    }

    return {
      'totalViolations': violations.length,
      'pendingPunishments': getPendingViolations().length,
      'totalHabits': habits.length,
      'todayFulfillment': LocalStorageService.getTodayFulfillmentPercentage(),
      'currentStreak': LocalStorageService.calculateCurrentStreak(),
      'mostViolatedHabits': violationCounts,
      'recentViolations': violations
          .where((v) => now.difference(v.occurredAt).inDays < 7)
          .map((v) => {'habit': v.habitTitle, 'type': v.violationType, 'date': v.occurredAt.toIso8601String()})
          .toList(),
    };
  }

  /// Build a prompt string for the AI drill sergeant
  static String buildSergeantPrompt(Violation violation) {
    final ctx = getSergeantContext();
    final level = violation.escalationLevel;

    String intensity;
    if (level == 1) {
      intensity = 'disappointed but firm';
    } else if (level == 2) {
      intensity = 'angry and intense';
    } else {
      intensity = 'absolutely furious, full drill sergeant rage';
    }

    return '''You are a drill sergeant in a fitness accountability app called HabitDrill.
The user just ${violation.violationType == 'indulged' ? 'indulged in a bad habit' : 'missed their habit'}: "${violation.habitTitle}".
This is offense #${violation.offenseNumber} for this habit.

Your tone should be: $intensity.

User context:
- Total violations: ${ctx['totalViolations']}
- Today's fulfillment: ${ctx['todayFulfillment']}%
- Current streak: ${ctx['currentStreak']} days
- Most violated habits: ${ctx['mostViolatedHabits']}

Give a short, intense drill sergeant response (2-3 sentences max). Be motivating through tough love. End by telling them they have exercises to complete.''';
  }
}
