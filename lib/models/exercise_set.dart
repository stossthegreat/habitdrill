import 'violation.dart';

class Exercise {
  final String name;
  final String engineId; // Maps to MovementEngine exercise ID
  final String emoji;
  final int reps;
  int completedReps;
  bool completed;

  Exercise({
    required this.name,
    required this.engineId,
    required this.emoji,
    required this.reps,
    this.completedReps = 0,
    this.completed = false,
  });
}

class ExerciseSet {
  final List<Exercise> exercises;
  final int escalationLevel;
  final int offenseNumber;

  ExerciseSet({
    required this.exercises,
    required this.escalationLevel,
    required this.offenseNumber,
  });

  bool get allCompleted => exercises.every((e) => e.completed);

  // name, engineId (matches movement_engine.dart), emoji, base reps
  static const List<Map<String, dynamic>> _exerciseDefinitions = [
    {'name': 'Squats',        'id': 'squats',        'emoji': '\u{1F9CE}', 'base': 10},
    {'name': 'Burpees',       'id': 'burpees',       'emoji': '\u{1F4A5}', 'base': 5},
    {'name': 'High Knees',    'id': 'high_knees',    'emoji': '\u{1F3C3}', 'base': 20},
    {'name': 'Push-ups',      'id': 'push_ups',      'emoji': '\u{1F4AA}', 'base': 10},
    {'name': 'Jumping Jacks', 'id': 'jumping_jacks', 'emoji': '\u{2B50}',  'base': 15},
  ];

  /// Create exercise set scaled to offense number
  /// 1st = base reps, 2nd = 2x, 3rd = 3x, capped at 5x
  factory ExerciseSet.forOffense(int offenseNumber) {
    final multiplier = offenseNumber.clamp(1, 5);
    final level = Violation.getEscalationLevel(offenseNumber);

    final exercises = _exerciseDefinitions.map((def) {
      final base = def['base'] as int;
      return Exercise(
        name: def['name'] as String,
        engineId: def['id'] as String,
        emoji: def['emoji'] as String,
        reps: base * multiplier,
      );
    }).toList();

    return ExerciseSet(
      exercises: exercises,
      escalationLevel: level,
      offenseNumber: offenseNumber,
    );
  }
}
