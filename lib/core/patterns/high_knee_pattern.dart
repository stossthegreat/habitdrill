import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'dart:math' as math;
import 'base_pattern.dart';

/// High Knees, Marching, Skaters, A-Skip, B-Skip, Running in Place
///
/// SAFEGUARDS:
/// 1. Normalized by leg length — distance from camera doesn't matter
/// 2. Confidence gate — skip unreliable frames
/// 3. 100ms cooldown + 80ms intent timer — no ghost reps
/// 4. Independent left/right for speed

class HighKneePattern extends BasePattern {
  final String cueGood;
  final String cueBad;
  final double triggerThreshold;

  RepState _state = RepState.ready;
  bool _isLocked = false;
  int _repCount = 0;
  String _feedback = '';
  double _chargeProgress = 0.0;
  bool _justHitTrigger = false;

  double _leftPeak = 999.0;
  double _rightPeak = 999.0;
  double _leftBase = 0.0;
  double _rightBase = 0.0;
  bool _leftActive = false;
  bool _rightActive = false;

  // Anti-ghost
  DateTime _lastRepTime = DateTime.now();
  static const int _minTimeBetweenRepsMs = 100;
  DateTime? _leftIntentTimer;
  DateTime? _rightIntentTimer;
  static const int _intentDelayMs = 80;

  // Confidence threshold
  static const double _minConfidence = 0.7;

  HighKneePattern({
    this.cueGood = 'Drive!',
    this.cueBad = 'Higher!',
    this.triggerThreshold = 0.06,
  });

  @override RepState get state => _state;
  @override bool get isLocked => _isLocked;
  @override int get repCount => _repCount;
  @override String get feedback => _feedback;
  @override double get chargeProgress => _chargeProgress;
  @override bool get justHitTrigger => _justHitTrigger;
  @override String get debugInfo => 'HIGH KNEE\nReps: $_repCount';

  @override
  void captureBaseline(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    _isLocked = true;
    _state = RepState.ready;
    _feedback = 'LOCKED';
    _resetMemory();
  }

  @override
  bool processFrame(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    _justHitTrigger = false;

    // Anti-cheat: full-body visible, upright. Don't reset _active flags —
    // transient gate misses shouldn't kill a legitimate rep.
    lastFormResult = formGate.check(landmarks);
    if (!lastFormResult.ok) {
      _feedback = lastFormResult.uiMessage;
      return false;
    }

    final lH = landmarks[PoseLandmarkType.leftHip];
    final rH = landmarks[PoseLandmarkType.rightHip];
    final lK = landmarks[PoseLandmarkType.leftKnee];
    final rK = landmarks[PoseLandmarkType.rightKnee];
    final lA = landmarks[PoseLandmarkType.leftAnkle];
    final rA = landmarks[PoseLandmarkType.rightAnkle];

    if (lH == null || rH == null || lK == null || rK == null || lA == null || rA == null) return false;

    // CONFIDENCE GATE — skip unreliable frames
    if (lH.likelihood < _minConfidence || rH.likelihood < _minConfidence ||
        lK.likelihood < _minConfidence || rK.likelihood < _minConfidence) {
      return false;
    }

    // NORMALIZE BY LEG LENGTH
    double leftLeg = math.sqrt(math.pow(lH.x - lA.x, 2) + math.pow(lH.y - lA.y, 2));
    double rightLeg = math.sqrt(math.pow(rH.x - rA.x, 2) + math.pow(rH.y - rA.y, 2));
    double legLength = (leftLeg + rightLeg) / 2.0;
    if (legLength < 1.0) legLength = 1.0;

    double leftVal = (lK.y - lH.y) / legLength;
    double rightVal = (rK.y - rH.y) / legLength;

    // Initial base calibration
    if (_leftBase == 0.0) _leftBase = leftVal;
    if (_rightBase == 0.0) _rightBase = rightVal;

    bool repScored = false;

    // LEFT LEG
    if (leftVal < _leftPeak) _leftPeak = leftVal;
    if (!_leftActive && leftVal < _leftBase - 0.04) _leftActive = true;
    if (_leftActive && leftVal > _leftPeak + triggerThreshold) {
      _leftIntentTimer ??= DateTime.now();
      if (DateTime.now().difference(_leftIntentTimer!).inMilliseconds > _intentDelayMs &&
          DateTime.now().difference(_lastRepTime).inMilliseconds > _minTimeBetweenRepsMs) {
        _repCount++;
        _justHitTrigger = true;
        _lastRepTime = DateTime.now();
        _leftIntentTimer = null;
        _leftActive = false;
        _leftPeak = 999.0;
        _leftBase = leftVal;
        repScored = true;
      }
    } else {
      _leftIntentTimer = null;
    }

    // RIGHT LEG
    if (rightVal < _rightPeak) _rightPeak = rightVal;
    if (!_rightActive && rightVal < _rightBase - 0.04) _rightActive = true;
    if (_rightActive && rightVal > _rightPeak + triggerThreshold) {
      _rightIntentTimer ??= DateTime.now();
      if (DateTime.now().difference(_rightIntentTimer!).inMilliseconds > _intentDelayMs &&
          DateTime.now().difference(_lastRepTime).inMilliseconds > _minTimeBetweenRepsMs) {
        _repCount++;
        _justHitTrigger = true;
        _lastRepTime = DateTime.now();
        _rightIntentTimer = null;
        _rightActive = false;
        _rightPeak = 999.0;
        _rightBase = rightVal;
        repScored = true;
      }
    } else {
      _rightIntentTimer = null;
    }

    // Gauge
    double currentDepth = math.max((_leftBase - leftVal), (_rightBase - rightVal));
    _chargeProgress = (currentDepth / 0.25).clamp(0.0, 1.0);
    _state = repScored ? RepState.down : RepState.ready;
    _feedback = _chargeProgress > 0.6 ? cueGood : cueBad;

    return repScored;
  }

  void _resetMemory() {
    _leftPeak = 999.0; _rightPeak = 999.0;
    _leftBase = 0.0; _rightBase = 0.0;
    _leftActive = false; _rightActive = false;
    _lastRepTime = DateTime.now();
    _leftIntentTimer = null;
    _rightIntentTimer = null;
  }

  @override
  void reset() {
    _repCount = 0;
    _state = RepState.ready;
    _feedback = '';
    _chargeProgress = 0.0;
    _justHitTrigger = false;
    _resetMemory();
  }
}
