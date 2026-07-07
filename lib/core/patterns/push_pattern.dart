import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'dart:math' as math;
import 'base_pattern.dart';

/// =============================================================================
/// PUSH PATTERN - Elbow Angle Logic (GEOMETRY BASED)
/// =============================================================================
/// Used for: push_ups, bench_press, overhead_press, dips, shoulder_press.
///
/// REFACTOR 2026-01-19: Switched from "Distance" to "Elbow Angle".
/// Distance fails on floor/low angles due to perspective distortion.
/// Angles are absolute and work from any camera position.
/// =============================================================================

class PushPattern extends BasePattern {
  final bool inverted; // false = Pushup (Start Extended), true = OHP (Start Bent)
  final String cueGood;
  final String cueBad;
  final double extensionThreshold;
  final double flexionThreshold;

  RepState _state = RepState.ready;
  bool _baselineCaptured = false;
  int _repCount = 0;
  String _feedback = "";
  bool _justHitTrigger = false;

  // DEFAULT THRESHOLDS
  static const double _defaultExtensionThreshold = 150.0;
  static const double _defaultFlexionThreshold = 95.0;
  static const double _ohpExtensionThreshold = 138.0;  // Relaxed for OHP

  // Current angle for UI gauge
  double _currentAngle = 180;
  double _smoothedAngle = 180;

  static const double _smoothingFactor = 0.3;
  DateTime? _intentTimer;
  DateTime _lastRepTime = DateTime.now();
  static const int _intentDelayMs = 200;
  static const int _minTimeBetweenRepsMs = 400;

  PushPattern({
    this.inverted = false,
    this.cueGood = "Good depth!",
    this.cueBad = "Lock out!",
    double? extensionThreshold,
    double? flexionThreshold,
  }) : extensionThreshold = extensionThreshold ??
         (inverted ? _ohpExtensionThreshold : _defaultExtensionThreshold),
       flexionThreshold = flexionThreshold ?? _defaultFlexionThreshold;

  @override RepState get state => _state;
  @override bool get isLocked => _baselineCaptured;
  @override int get repCount => _repCount;
  @override String get feedback => _feedback;
  @override bool get justHitTrigger => _justHitTrigger;

  @override
  String get debugInfo => 'PUSH\nAngle: ${_smoothedAngle.toStringAsFixed(1)}\nInv: $inverted\nState: ${_state.name}\nReps: $_repCount';

  @override
  double get chargeProgress {
    // UI Progress Bar Logic
    if (inverted) {
      // OHP: Start Bent (flexionThreshold) -> Goal Straight (extensionThreshold)
      return ((_currentAngle - flexionThreshold) / (extensionThreshold - flexionThreshold)).clamp(0.0, 1.0);
    } else {
      // Pushup: Start Straight (180) -> Goal Bent (flexionThreshold)
      return ((180 - _currentAngle) / (180 - flexionThreshold)).clamp(0.0, 1.0);
    }
  }

  /// Helper: Calculate angle (0-180) at vertex (Shoulder-Elbow-Wrist)
  double _calculateAngle(PoseLandmark first, PoseLandmark middle, PoseLandmark last) {
    double dx1 = first.x - middle.x;
    double dy1 = first.y - middle.y;
    double dx2 = last.x - middle.x;
    double dy2 = last.y - middle.y;

    double dot = dx1 * dx2 + dy1 * dy2;
    double mag1 = math.sqrt(dx1 * dx1 + dy1 * dy1);
    double mag2 = math.sqrt(dx2 * dx2 + dy2 * dy2);

    if (mag1 * mag2 == 0) return 180;

    double cosine = (dot / (mag1 * mag2)).clamp(-1.0, 1.0);
    return (math.acos(cosine) * 180 / math.pi);
  }

  @override
  void captureBaseline(Map<PoseLandmarkType, PoseLandmark> map) {
    final lShoulder = map[PoseLandmarkType.leftShoulder];
    final rShoulder = map[PoseLandmarkType.rightShoulder];
    final lElbow = map[PoseLandmarkType.leftElbow];
    final rElbow = map[PoseLandmarkType.rightElbow];
    final lWrist = map[PoseLandmarkType.leftWrist];
    final rWrist = map[PoseLandmarkType.rightWrist];

    if ((lShoulder == null && rShoulder == null) ||
        (lElbow == null && rElbow == null) ||
        (lWrist == null && rWrist == null)) {
      _feedback = "Body not in frame";
      return;
    }

    _baselineCaptured = true;
    _state = RepState.ready;
    _feedback = "LOCKED";
  }

  @override
  bool processFrame(Map<PoseLandmarkType, PoseLandmark> map) {
    if (!_baselineCaptured) {
      _feedback = "Waiting for lock";
      return false;
    }

    _justHitTrigger = false;

    // Anti-cheat: full-body visible, camera still. Skip the upright
    // geometry check because push-ups are horizontal.
    lastFormResult = formGate.check(map, requireUpright: false);
    if (!lastFormResult.ok) {
      _feedback = lastFormResult.uiMessage;
      return false;
    }

    // =======================================================
    // PUSH LOGIC (Angle Based)
    // =======================================================
    final lShoulder = map[PoseLandmarkType.leftShoulder];
    final rShoulder = map[PoseLandmarkType.rightShoulder];
    final lElbow = map[PoseLandmarkType.leftElbow];
    final rElbow = map[PoseLandmarkType.rightElbow];
    final lWrist = map[PoseLandmarkType.leftWrist];
    final rWrist = map[PoseLandmarkType.rightWrist];

    double angleL = 180;
    double angleR = 180;
    int validArms = 0;

    if (lShoulder != null && lElbow != null && lWrist != null && lShoulder.likelihood > 0.5) {
      angleL = _calculateAngle(lShoulder, lElbow, lWrist);
      validArms++;
    }
    if (rShoulder != null && rElbow != null && rWrist != null && rShoulder.likelihood > 0.5) {
      angleR = _calculateAngle(rShoulder, rElbow, rWrist);
      validArms++;
    }

    if (validArms == 0) {
      _feedback = "Arms not visible";
      return false;
    }

    double rawAngle = 180;
    if (validArms == 2) {
       rawAngle = (angleL + angleR) / 2;
    } else {
       rawAngle = (angleL < 180) ? angleL : angleR; 
    }

    _smoothedAngle = (_smoothingFactor * rawAngle) + ((1 - _smoothingFactor) * _smoothedAngle);
    _currentAngle = _smoothedAngle;

    bool isBent = _currentAngle <= flexionThreshold;
    bool isStraight = _currentAngle >= extensionThreshold;

    // 3. State Machine
    if (inverted) {
      // INVERTED (OHP): Start Bent -> Push Up (Straight) -> Return (Bent)
      switch (_state) {
        case RepState.ready: 
        case RepState.goingUp:
          if (isStraight) { // HIT TOP
             _intentTimer ??= DateTime.now();
             if (DateTime.now().difference(_intentTimer!).inMilliseconds > _intentDelayMs) {
                _state = RepState.up; // Locked out
                _feedback = cueGood;
                _intentTimer = null;
                _justHitTrigger = true;
             }
          }
          break;

        case RepState.up: // At Top
          if (isBent) { // CAME DOWN
             if (DateTime.now().difference(_lastRepTime).inMilliseconds > _minTimeBetweenRepsMs) {
                _repCount++;
                _lastRepTime = DateTime.now();
                _state = RepState.ready;
                _feedback = "";
                return true; 
             }
          }
          break;
          
        default:
          break;
      }

    } else {
      // STANDARD (PUSHUP): Start Straight -> Go Down (Bent) -> Push Up (Straight)
      switch (_state) {
        case RepState.ready: // At Top
        case RepState.goingDown:
          if (isBent) { // HIT BOTTOM
             _intentTimer ??= DateTime.now();
             if (DateTime.now().difference(_intentTimer!).inMilliseconds > _intentDelayMs) {
                _state = RepState.down; // Replaced 'midpoint' with 'down'
                _feedback = "Push!";
                _intentTimer = null;
                _justHitTrigger = true;
             }
          }
          break;

        case RepState.down: // At Bottom (Replaced 'midpoint')
          if (isStraight) { // CAME UP
             if (DateTime.now().difference(_lastRepTime).inMilliseconds > _minTimeBetweenRepsMs) {
                _repCount++;
                _lastRepTime = DateTime.now();
                _state = RepState.ready;
                _feedback = "";
                return true; 
             }
          }
          break;
          
        default:
          _state = RepState.ready;
          break;
      }
    }

    return false;
  }

  @override
  void reset() {
    _repCount = 0;
    _state = RepState.ready;
    _feedback = "";
    _baselineCaptured = false;
    _currentAngle = 180;
    _smoothedAngle = 180;
    _intentTimer = null;
    _justHitTrigger = false;
  }
}
