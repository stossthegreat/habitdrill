import 'violation.dart';

class Exercise {
  final String name;
  final String emoji;
  final int reps;
  bool completed;

  Exercise({
    required this.name,
    required this.emoji,
    required this.reps,
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

  static const Map<String, Map<String, dynamic>> _exerciseDefinitions = {
    'Squats':        {'emoji': '\u{1F9CE}', 'base': 10},
    'Burpees':       {'emoji': '\u{1F4A5}', 'base': 5},
    'High Knees':    {'emoji': '\u{1F3C3}', 'base': 20},
    'Push-ups':      {'emoji': '\u{1F4AA}', 'base': 10},
    'Jumping Jacks': {'emoji': '\u{2B50}',  'base': 15},
  };

  /// Create exercise set scaled to offense number
  /// 1st = base reps, 2nd = 2x, 3rd = 3x, capped at 5x
  factory ExerciseSet.forOffense(int offenseNumber) {
    final multiplier = offenseNumber.clamp(1, 5);
    final level = Violation.getEscalationLevel(offenseNumber);

    final exercises = _exerciseDefinitions.entries.map((entry) {
      final base = entry.value['base'] as int;
      return Exercise(
        name: entry.key,
        emoji: entry.value['emoji'] as String,
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
