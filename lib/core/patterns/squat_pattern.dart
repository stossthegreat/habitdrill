import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'dart:math' as math;
import 'base_pattern.dart';

class SquatPattern extends BasePattern {
  final double triggerAngle; 
  final double resetAngle;   
  final double? triggerPercent; // Added back to satisfy movement_engine
  final double? resetPercent;   // Added back to satisfy movement_engine
  final String cueGood;
  final String cueBad;
  final bool singleLeg;
  
  RepState _state = RepState.ready;
  bool _isLocked = false;
  int _repCount = 0;
  String _feedback = "";
  bool _justHitTrigger = false;
  double _chargeProgress = 0.0;

  bool _leftActive = false;
  bool _rightActive = false;
  DateTime _lastRepTime = DateTime.now();
  static const int _minTimeBetweenRepsMs = 500;

  SquatPattern({
    this.triggerAngle = 115.0,
    this.resetAngle = 160.0,
    this.triggerPercent, // Constructor now accepts these
    this.resetPercent,   // Constructor now accepts these
    this.cueGood = "Depth!",
    this.cueBad = "Lower!",
    this.singleLeg = false,
  });

  @override RepState get state => _state;
  @override bool get isLocked => _isLocked;
  @override int get repCount => _repCount;
  @override String get feedback => _feedback;
  @override double get chargeProgress => _chargeProgress;
  @override bool get justHitTrigger => _justHitTrigger;

  @override
  String get debugInfo => 'SQUAT\nPct: ${_chargeProgress.toStringAsFixed(1)}%\nState: ${_state.name}\nReps: $_repCount';

  @override
  void captureBaseline(Map<PoseLandmarkType, PoseLandmark> map) {
    _isLocked = true;
    _state = RepState.ready;
    _feedback = "LOCKED";
    _leftActive = false;
    _rightActive = false;
  }

  double _getAngle(PoseLandmark hip, PoseLandmark knee, PoseLandmark ankle) {
    double angle = (math.atan2(ankle.y - knee.y, ankle.x - knee.x) - 
                    math.atan2(hip.y - knee.y, hip.x - knee.x)).abs();
    if (angle > math.pi) angle = 2 * math.pi - angle;
    return angle * (180 / math.pi);
  }

  @override
  bool processFrame(Map<PoseLandmarkType, PoseLandmark> map) {
    _justHitTrigger = false;

    // Anti-cheat gate. Rejects partial-body / hallucinated frames BEFORE
    // we look at knee angles. DO NOT reset _active flags on failure —
    // burpees legitimately go through a non-upright plank phase, and
    // resetting would kill the rep count on the way back up.
    lastFormResult = formGate.check(map);
    if (!lastFormResult.ok) {
      _feedback = lastFormResult.uiMessage;
      return false;
    }

    final lH = map[PoseLandmarkType.leftHip];
    final lK = map[PoseLandmarkType.leftKnee];
    final lA = map[PoseLandmarkType.leftAnkle];

    final rH = map[PoseLandmarkType.rightHip];
    final rK = map[PoseLandmarkType.rightKnee];
    final rA = map[PoseLandmarkType.rightAnkle];

    if (lH == null || lK == null || lA == null || rH == null || rK == null || rA == null) return false;

    // FIX: Variable names now match exactly
    double leftKneeAngle = _getAngle(lH, lK, lA);
    double rightKneeAngle = _getAngle(rH, rK, rA);

    bool repScored = false;

    if (singleLeg) {
      // SINGLE LEG MODE: Only track the deepest knee (the working leg)
      // The resting leg (on bench/elevated) is completely ignored
      double deepest = math.min(leftKneeAngle, rightKneeAngle);

      if (!_leftActive && deepest < triggerAngle) _leftActive = true;
      if (_leftActive && deepest > resetAngle) {
        _leftActive = false;
        repScored = true;
      }
    } else {
      // NORMAL MODE: Track both knees independently (UNCHANGED)
      if (!_leftActive && leftKneeAngle < triggerAngle) _leftActive = true;
      if (!_rightActive && rightKneeAngle < triggerAngle) _rightActive = true;

      if (_leftActive && leftKneeAngle > resetAngle) {
        _leftActive = false;
        repScored = true;
      }
      if (_rightActive && rightKneeAngle > resetAngle) {
        _rightActive = false;
        if (!repScored) repScored = true;
      }
    }

    if (repScored && DateTime.now().difference(_lastRepTime).inMilliseconds > _minTimeBetweenRepsMs) {
      _repCount++;
      _lastRepTime = DateTime.now();
      _justHitTrigger = true;
      _state = RepState.down;
      _feedback = cueGood;
      return true;
    }

    // UI Gauge
    double deepestKnee = math.min(leftKneeAngle, rightKneeAngle);
    _chargeProgress = ((170 - deepestKnee) / (170 - 100)).clamp(0.0, 1.0);
    _state = _chargeProgress > 0.1 ? RepState.goingDown : RepState.ready;
    _feedback = _chargeProgress > 0.7 ? cueGood : cueBad;

    return false;
  }

  @override
  void reset() {
    _repCount = 0;
    _state = RepState.ready;
    _leftActive = false;
    _rightActive = false;
    _lastRepTime = DateTime.now();
    _chargeProgress = 0.0;
  }
}
