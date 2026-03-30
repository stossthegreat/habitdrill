import 'violation.dart';

class Exercise {
  final String name;
  final String engineId;
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

  /// Tempted workout: just 20 burpees (proactive, not punishment)
  factory ExerciseSet.tempted() {
    return ExerciseSet(
      exercises: [
        Exercise(name: 'Burpees', engineId: 'burpees', emoji: '\u{1F4A5}', reps: 20),
      ],
      escalationLevel: 0,
      offenseNumber: 0,
    );
  }

  /// Punishment circuit based on offense number:
  /// Strike 1 = 10 of each
  /// Strike 2 = 15 of each
  /// Strike 3+ = 20 of each
  factory ExerciseSet.forOffense(int offenseNumber) {
    final level = Violation.getEscalationLevel(offenseNumber);

    int reps;
    if (offenseNumber <= 1) {
      reps = 10;
    } else if (offenseNumber == 2) {
      reps = 15;
    } else {
      reps = 20;
    }

    return ExerciseSet(
      exercises: [
        Exercise(name: 'Squats', engineId: 'squats', emoji: '\u{1F9CE}', reps: reps),
        Exercise(name: 'Burpees', engineId: 'burpees', emoji: '\u{1F4A5}', reps: reps),
        Exercise(name: 'High Knees', engineId: 'high_knees', emoji: '\u{1F3C3}', reps: reps),
        Exercise(name: 'Push-ups', engineId: 'push_ups', emoji: '\u{1F4AA}', reps: reps),
        Exercise(name: 'Jumping Jacks', engineId: 'jumping_jacks', emoji: '\u{2B50}', reps: reps),
      ],
      escalationLevel: level,
      offenseNumber: offenseNumber,
    );
  }
}
