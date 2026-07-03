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

  /// Dynamic punishment sets — variety keeps it unpredictable, but same
  /// offense always resolves to the same set so retries are fair.
  /// Always brutal. Always ends with the same completion screen.
  ///
  /// Offense 1 → "Sudden" (one heavy exercise, ~30 reps)
  /// Offense 2 → "Pair" (two exercises, ~35 total reps)
  /// Offense 3+ → "Full circuit" (four exercises, 80+ total reps)
  factory ExerciseSet.forOffense(int offenseNumber) {
    final level = Violation.getEscalationLevel(offenseNumber);
    // Deterministic per-offense pick, so a retry gives the same set.
    final rng = _SeededRandom(offenseNumber * 31 + 7);
    final exercises = _pickExercises(offenseNumber, rng);
    return ExerciseSet(
      exercises: exercises,
      escalationLevel: level,
      offenseNumber: offenseNumber,
    );
  }
}

// ────────────────────────── Exercise picking ──────────────────────────

Exercise _squats(int reps) => Exercise(name: 'Squats', engineId: 'squats', emoji: '\u{1F9CE}', reps: reps);
Exercise _burpees(int reps) => Exercise(name: 'Burpees', engineId: 'burpees', emoji: '\u{1F4A5}', reps: reps);
Exercise _highKnees(int reps) => Exercise(name: 'High Knees', engineId: 'high_knees', emoji: '\u{1F3C3}', reps: reps);
Exercise _pushUps(int reps) => Exercise(name: 'Push-ups', engineId: 'push_ups', emoji: '\u{1F4AA}', reps: reps);

List<Exercise> _pickExercises(int offense, _SeededRandom rng) {
  if (offense <= 1) {
    // SUDDEN: one brutal exercise. Pick one at random.
    final options = <List<Exercise>>[
      [_burpees(25)],
      [_pushUps(40)],
      [_squats(50)],
      [_highKnees(60)],
    ];
    return options[rng.next(options.length)];
  }
  if (offense == 2) {
    // PAIR: two exercises. Different combos for variety.
    final options = <List<Exercise>>[
      [_squats(20), _pushUps(20)],
      [_burpees(15), _highKnees(30)],
      [_pushUps(25), _squats(25)],
      [_burpees(20), _pushUps(15)],
    ];
    return options[rng.next(options.length)];
  }
  // FULL CIRCUIT: all four. Escalates with offense count.
  final reps = offense >= 4 ? 25 : 20;
  return [
    _squats(reps),
    _burpees(reps),
    _highKnees(reps),
    _pushUps(reps),
  ];
}

/// Tiny deterministic PRNG. Same seed → same sequence. No dart:math import
/// needed at construction time.
class _SeededRandom {
  int _state;
  _SeededRandom(int seed) : _state = seed == 0 ? 1 : seed;

  int next(int max) {
    // xorshift32 — plenty for picking from a 4-item list.
    _state ^= _state << 13;
    _state ^= _state >> 17;
    _state ^= _state << 5;
    _state &= 0x7FFFFFFF;
    return _state % max;
  }
}
