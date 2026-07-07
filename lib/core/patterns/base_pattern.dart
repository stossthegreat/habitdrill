import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'form_gate.dart';

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
enum CardioMode {
  kneeRise,    // High knees, mountain climbers, squat jumps
  heelToButt,  // Butt kicks
  legSpread,   // Jumping jacks (removed but enum kept for compatibility)
  bodyDrop,    // Burpees, sprawls
}

abstract class BasePattern {
  // State
  RepState get state;
  bool get isLocked;
  int get repCount;
  String get feedback;
  double get chargeProgress; // 0.0 to 1.0 for power gauge
  bool get justHitTrigger;

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
      return false;
    }
    _lastRepTimestamp = now;
    return true;
  }

  // Anti-cheat gate shared by every pattern. Rejects partial-body reps,
  // low-confidence hallucinated landmarks, phone-swing cheats.
  final FormGate formGate = FormGate();

  /// The current form-gate reason for feedback. If not ok, the pattern's
  /// processFrame should short-circuit and expose this to the UI.
  FormResult lastFormResult = const FormResult(FormReject.ok, '');

  // Actions
  void captureBaseline(Map<PoseLandmarkType, PoseLandmark> landmarks);
  bool processFrame(Map<PoseLandmarkType, PoseLandmark> landmarks);
  void reset();
}
