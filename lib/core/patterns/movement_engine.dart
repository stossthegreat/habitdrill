import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'base_pattern.dart';
import 'squat_pattern.dart';
import 'push_pattern.dart';
import 'high_knee_pattern.dart';
import 'piston_pattern.dart';

/// Pattern types for HabitDrill exercises
enum PatternType { squat, push, highKnee, piston }

/// Exercise configuration
class ExerciseConfig {
  final PatternType patternType;
  final Map<String, dynamic> params;

  const ExerciseConfig({
    required this.patternType,
    this.params = const {},
  });
}

/// =============================================================================
/// MOVEMENT ENGINE - Master Controller (HabitDrill Edition)
/// =============================================================================
/// Maps the 5 HabitDrill exercises to their pattern types.
/// Creates the right pattern instance for each exercise.
/// =============================================================================

class MovementEngine {
  BasePattern? _activePattern;
  BasePattern? get activePattern => _activePattern;
  String? _currentExerciseId;

  // Getters - delegate to active pattern
  int get repCount => _activePattern?.repCount ?? 0;
  String get feedback => _activePattern?.feedback ?? '';
  double get chargeProgress => _activePattern?.chargeProgress ?? 0;
  bool get justHitTrigger => _activePattern?.justHitTrigger ?? false;
  bool get isLocked => _activePattern?.isLocked ?? false;
  RepState get state => _activePattern?.state ?? RepState.ready;
  String? get currentExerciseId => _currentExerciseId;

  /// Set the current exercise - creates the appropriate pattern
  void setExercise(String exerciseId) {
    _currentExerciseId = exerciseId.toLowerCase().replaceAll(' ', '_').replaceAll('-', '_');

    final config = exercises[_currentExerciseId];
    if (config == null) {
      // Default to squat pattern for unknown exercises
      _activePattern = SquatPattern();
      return;
    }

    _activePattern = _createPattern(config);
  }

  /// LEGACY: Alias for setExercise for backwards compatibility
  void loadExercise(String exerciseId) => setExercise(exerciseId);

  /// Check if an exercise has a pattern configured
  static bool hasPattern(String exerciseId) {
    final normalized = exerciseId.toLowerCase().replaceAll(' ', '_').replaceAll('-', '_');
    return exercises.containsKey(normalized);
  }

  /// Capture baseline position (Map version)
  void captureBaseline(dynamic landmarks) {
    if (_activePattern == null) return;

    // Handle both List<PoseLandmark> and Map<PoseLandmarkType, PoseLandmark>
    if (landmarks is List<PoseLandmark>) {
      final map = {for (var lm in landmarks) lm.type: lm};
      _activePattern!.captureBaseline(map);
    } else if (landmarks is Map<PoseLandmarkType, PoseLandmark>) {
      _activePattern!.captureBaseline(landmarks);
    }
  }

  /// Process a frame - returns true if rep was counted
  bool processFrame(dynamic landmarks) {
    if (_activePattern == null) return false;

    // Handle both List<PoseLandmark> and Map<PoseLandmarkType, PoseLandmark>
    if (landmarks is List<PoseLandmark>) {
      final map = {for (var lm in landmarks) lm.type: lm};
      return _activePattern!.processFrame(map);
    } else if (landmarks is Map<PoseLandmarkType, PoseLandmark>) {
      return _activePattern!.processFrame(landmarks);
    }

    return false;
  }

  /// Reset the current pattern
  void reset() {
    _activePattern?.reset();
  }

  /// Create pattern instance from config
  BasePattern _createPattern(ExerciseConfig config) {
    switch (config.patternType) {
      case PatternType.squat:
        return SquatPattern(
          triggerPercent: config.params['triggerPercent'] ?? 0.78,
          resetPercent: config.params['resetPercent'] ?? 0.92,
          cueGood: config.params['cueGood'] ?? 'Depth!',
          cueBad: config.params['cueBad'] ?? 'Lower!',
          singleLeg: config.params['singleLeg'] ?? false,
        );

      case PatternType.push:
        return PushPattern(
          inverted: config.params['inverted'] ?? false,
          cueGood: config.params['cueGood'] ?? 'Good!',
          cueBad: config.params['cueBad'] ?? 'Lower!',
          extensionThreshold: config.params['extensionThreshold'] as double?,
          flexionThreshold: config.params['flexionThreshold'] as double?,
        );

      case PatternType.highKnee:
        return HighKneePattern(
          cueGood: config.params['cueGood'] ?? 'Drive!',
          cueBad: config.params['cueBad'] ?? 'Higher!',
          triggerThreshold: (config.params['triggerThreshold'] ?? 0.06).toDouble(),
        );

      case PatternType.piston:
        return PistonPattern(
          pointA: config.params['pointA'] ?? PoseLandmarkType.leftAnkle,
          pointB: config.params['pointB'] ?? PoseLandmarkType.rightAnkle,
          mode: config.params['mode'] ?? PistonMode.grow,
          triggerPercent: (config.params['triggerPercent'] ?? 1.80).toDouble(),
          resetPercent: (config.params['resetPercent'] ?? 1.30).toDouble(),
          cueGood: config.params['cueGood'] ?? 'Jump!',
          cueBad: config.params['cueBad'] ?? 'Wider!',
        );
    }
  }

  /// ==========================================================================
  /// EXERCISE DATABASE - HabitDrill exercises only
  /// ==========================================================================
  static const Map<String, ExerciseConfig> exercises = {

    // Squats - standard squat pattern
    'squats': ExerciseConfig(patternType: PatternType.squat),

    // Burpees - squat phase detection
    'burpees': ExerciseConfig(patternType: PatternType.squat, params: {
      'triggerPercent': 0.80,
      'cueGood': 'Explode!',
      'cueBad': 'Lower!',
    }),

    // High Knees - alternating knee drive
    'high_knees': ExerciseConfig(patternType: PatternType.highKnee, params: {
      'cueGood': 'Drive!',
      'cueBad': 'Higher!',
    }),

    // Push-ups - push pattern
    'push_ups': ExerciseConfig(patternType: PatternType.push, params: {
      'cueGood': 'Good!',
      'cueBad': 'Lower!',
    }),
  };
}
