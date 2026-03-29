import 'package:flutter/foundation.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../core/patterns/movement_engine.dart';

/// Manages the active workout session for Drillsarj.
/// Connects: Pose Detection -> MovementEngine -> Rep Counting
class WorkoutSession {
  MovementEngine _engine = MovementEngine();
  MovementEngine? get movementEngine => _engine;
  String _currentExerciseId = '';
  String get debugExerciseId => _currentExerciseId;
  bool _baselineCaptured = false;

  // Current state
  int _currentSetIndex = 0;
  int _targetReps = 0;
  int _targetSets = 0;
  bool _isActive = false;
  bool _isResting = false;

  // Time-based exercise tracking for HIIT circuits
  int? _timeSeconds;
  DateTime? _exerciseStartTime;

  // Track actual reps completed per set
  final List<int> _completedRepsPerSet = [];

  // Callbacks
  Function(int totalReps)? onRepCounted;
  Function(int setIndex)? onSetComplete;
  VoidCallback? onWorkoutComplete;
  Function(String message)? onFeedback;

  // Getters
  bool get isActive => _isActive;
  bool get isResting => _isResting;
  int get currentReps => _engine.repCount ?? 0;
  int get currentSet => _currentSetIndex + 1;
  int get targetReps => _targetReps;
  int get targetSets => _targetSets;
  bool get isExerciseComplete => _currentSetIndex >= _targetSets;
  double get currentAngle => (_engine.chargeProgress * 100);
  double get formScore => (_engine.chargeProgress * 100);
  String get feedback => _engine.feedback ?? '';
  String get exerciseName => _currentExerciseId;
  String get phase => _engine.state.name ?? '';
  double get chargeProgress => _engine.chargeProgress;

  // Time-based getters
  bool get isTimeBased => _timeSeconds != null;
  int get timeRemaining {
    if (_timeSeconds == null || _exerciseStartTime == null) return 0;
    final elapsed = DateTime.now().difference(_exerciseStartTime!).inSeconds;
    return (_timeSeconds! - elapsed).clamp(0, _timeSeconds!);
  }
  int get targetTime => _timeSeconds ?? 0;

  // Completed reps per set
  List<int> get completedRepsPerSet => List.unmodifiable(_completedRepsPerSet);

  /// Strip difficulty prefix from exercise ID.
  /// Converts "beginner_squat" -> "squat", "intermediate_bench_press" -> "bench_press"
  String _stripDifficultyPrefix(String exerciseId) {
    final normalized = exerciseId.toLowerCase().trim();
    if (normalized.startsWith('beginner_')) {
      return normalized.substring(9);
    } else if (normalized.startsWith('intermediate_')) {
      return normalized.substring(13);
    } else if (normalized.startsWith('advanced_')) {
      return normalized.substring(9);
    }
    return normalized;
  }

  Future<void> init() async {
    // No-op, kept for interface compatibility
  }

  /// Start tracking an exercise
  Future<void> startExercise({
    required String exerciseId,
    required int sets,
    required int reps,
    int? timeSeconds,
  }) async {
    final baseExerciseId = _stripDifficultyPrefix(exerciseId);

    if (!MovementEngine.hasPattern(baseExerciseId)) {
      print('WARNING: No tracking pattern for: $baseExerciseId (original: $exerciseId)');
    }

    _currentExerciseId = baseExerciseId;
    _engine.loadExercise(baseExerciseId);
    _engine.reset();
    _baselineCaptured = false;
    _targetSets = sets;
    _targetReps = reps;
    _currentSetIndex = 0;
    _isActive = true;
    _isResting = false;

    _timeSeconds = timeSeconds;
    _exerciseStartTime = timeSeconds != null ? DateTime.now() : null;

    _completedRepsPerSet.clear();
  }

  /// Convert List<PoseLandmark> to Map<PoseLandmarkType, PoseLandmark>
  Map<PoseLandmarkType, PoseLandmark> _landmarksToMap(List<PoseLandmark> landmarks) {
    final map = <PoseLandmarkType, PoseLandmark>{};
    for (final landmark in landmarks) {
      map[landmark.type] = landmark;
    }
    return map;
  }

  /// Process pose landmarks from camera.
  /// Call this every frame with the detected landmarks.
  void processPose(List<PoseLandmark> landmarks) {
    if (!_isActive || _isResting) return;

    final landmarkMap = _landmarksToMap(landmarks);

    // Capture baseline on first frame to lock on to user
    if (!_baselineCaptured) {
      _engine.captureBaseline(landmarkMap);
      _baselineCaptured = true;
      return;
    }

    bool repCompleted = _engine.processFrame(landmarkMap);

    if (repCompleted) {
      _onRepCompleted();
    }

    if (_engine.feedback.isNotEmpty) {
      onFeedback?.call(_engine.feedback);
    }
  }

  void _onRepCompleted() {
    final reps = _engine.repCount;

    onRepCounted?.call(reps);

    // Check if set complete
    if (reps >= _targetReps) {
      _onSetComplete();
    }
  }

  void _onSetComplete() {
    final actualReps = _engine.repCount ?? 0;
    _completedRepsPerSet.add(actualReps);

    final completedSet = _currentSetIndex + 1;

    if (_currentSetIndex < _targetSets - 1) {
      // More sets to go
      _currentSetIndex++;
      onSetComplete?.call(completedSet);
      _isResting = true;
      _isActive = true;
    } else {
      // Last set complete
      onSetComplete?.call(completedSet);
      _isActive = false;
      _isResting = false;
      onWorkoutComplete?.call();
    }
  }

  /// Call when rest is complete and ready for next set
  void startNextSet() {
    if (!_isResting) return;

    _isResting = false;
    _engine.reset();
    _baselineCaptured = false;

    onFeedback?.call('Set ${_currentSetIndex + 1}. Go!');
  }

  /// Manually skip to next set (if user wants to end set early)
  void skipToNextSet() {
    final actualReps = _engine.repCount ?? 0;
    _completedRepsPerSet.add(actualReps);

    final completedSet = _currentSetIndex + 1;

    if (_currentSetIndex < _targetSets - 1) {
      _currentSetIndex++;
      onSetComplete?.call(completedSet);
      _isResting = true;
      _isActive = true;
    } else {
      onSetComplete?.call(completedSet);
      _isActive = false;
      _isResting = false;
      onWorkoutComplete?.call();
    }
  }

  /// Reset the current exercise (start over)
  void resetExercise() {
    _engine.reset();
    _baselineCaptured = false;
    _currentSetIndex = 0;
    _isResting = false;
  }

  /// Stop the session
  void stop() {
    _isActive = false;
    _isResting = false;
    _engine.reset();
    _currentExerciseId = '';
  }

  Future<void> dispose() async {
    // No-op, kept for interface compatibility
  }
}
