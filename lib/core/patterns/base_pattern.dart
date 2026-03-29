import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

/// =============================================================================
/// BASE PATTERN CONTRACT
/// =============================================================================
/// Every pattern file MUST implement these methods.
/// This ensures all patterns talk to the app the same way.
/// =============================================================================

enum RepState { ready, goingDown, down, goingUp, up }

/// =============================================================================
/// CARDIO MODES - Different tracking for different cardio exercises
/// =============================================================================
/// kneeRise:   HIGH KNEES - Track knee Y rising from baseline
/// heelToButt: BUTT KICKS - Track knee angle closing (heel toward butt)
/// legSpread:  JUMPING JACKS - Track ankle X distance spreading apart
/// bodyDrop:   BURPEES - Track shoulder Y dropping down
/// =============================================================================
enum CardioMode {
  kneeRise,    // High knees, mountain climbers, squat jumps
  heelToButt,  // Butt kicks
  legSpread,   // Jumping jacks, star jumps, plank jacks
  bodyDrop,    // Burpees, sprawls
}

abstract class BasePattern {
  // State
  RepState get state;
  bool get isLocked;
  int get repCount;
  String get feedback;
  double get chargeProgress; // 0.0 to 1.0 for power gauge
  bool get justHitTrigger; // <-- ADDED for UI green flash

  // Debug
  String get debugInfo => '';

  // Universal rep cooldown — prevents ghost reps across all patterns
  DateTime _lastRepTimestamp = DateTime(2000);
  static const int _minRepIntervalMs = 200;

  /// Call this from subclass when counting a rep.
  /// Returns false if cooldown hasn't elapsed (ghost rep).
  bool canCountRep() {
    final now = DateTime.now();
    if (now.difference(_lastRepTimestamp).inMilliseconds < _minRepIntervalMs) {
      return false; // Too fast — ghost rep
    }
    _lastRepTimestamp = now;
    return true;
  }

  // Actions
  void captureBaseline(Map<PoseLandmarkType, PoseLandmark> landmarks);
  bool processFrame(Map<PoseLandmarkType, PoseLandmark> landmarks); // Returns true if rep counted
  void reset();
}
