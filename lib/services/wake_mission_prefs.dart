import 'package:shared_preferences/shared_preferences.dart';

/// Per-wake-alarm mission choice: which exercise the user picked as their
/// morning punishment, and how many reps of it they signed up for.
///
/// Stored in SharedPreferences keyed by `habit.id` so we don't need to add
/// Hive fields (which would require regenerating the .g.dart adapters).
///
/// The wake exercise screen (see WakeExerciseScreen) reads these to build
/// the ExerciseSet the user pledged to do — the user chose the mission,
/// not the drill sergeant.
class WakeMissionPrefs {
  /// The four missions we support today — one entry per pose the
  /// pose-detector engine already knows how to count.
  static const List<Mission> missions = [
    Mission(id: 'squats', name: 'Squats', engineId: 'squats', emoji: '\u{1F9CE}'),
    Mission(id: 'push_ups', name: 'Push-ups', engineId: 'push_ups', emoji: '\u{1F4AA}'),
    Mission(id: 'burpees', name: 'Burpees', engineId: 'burpees', emoji: '\u{1F4A5}'),
    Mission(id: 'high_knees', name: 'High Knees', engineId: 'high_knees', emoji: '\u{1F3C3}'),
  ];

  static const String defaultMissionId = 'squats';
  static const int defaultReps = 20;

  /// Minimum morning reps per mission. High knees are pretty low
  /// intensity per rep so we ask for 20 to actually get the heart
  /// rate up; push-ups / squats / burpees are heavier so 10 is a
  /// meaningful bar. Enforced at pledge time (RepsPicker in
  /// onboarding + NewWakeAlarmScreen) AND at fire time
  /// (WakeExerciseScreen bumps anything under the floor).
  static int minRepsFor(String missionId) {
    switch (missionId) {
      case 'high_knees':
        return 20;
      default:
        return 10;
    }
  }

  static String _typeKey(String habitId) => 'wake_mission_type.$habitId';
  static String _repsKey(String habitId) => 'wake_mission_reps.$habitId';

  static Future<void> setMission(
    String habitId, {
    required String missionId,
    required int reps,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_typeKey(habitId), missionId);
    await prefs.setInt(_repsKey(habitId), reps);
  }

  static Future<Mission> getMission(String habitId) async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(_typeKey(habitId)) ?? defaultMissionId;
    return missions.firstWhere(
      (m) => m.id == id,
      orElse: () => missions.first,
    );
  }

  static Future<int> getReps(String habitId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_repsKey(habitId)) ?? defaultReps;
  }

  static Future<void> clear(String habitId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_typeKey(habitId));
    await prefs.remove(_repsKey(habitId));
  }
}

class Mission {
  final String id;
  final String name;
  final String engineId; // pose engine identifier (matches ExerciseSet)
  final String emoji;
  const Mission({
    required this.id,
    required this.name,
    required this.engineId,
    required this.emoji,
  });
}
