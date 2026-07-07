import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'dart:math' as math;
import 'base_pattern.dart';

enum PistonMode { shrink, grow }

class PistonPattern extends BasePattern {
  final PoseLandmarkType pointA;
  final PoseLandmarkType pointB;
  final PoseLandmarkType? pointARight;
  final PoseLandmarkType? pointBRight;
  final PistonMode mode;
  final double triggerPercent;
  final double resetPercent;
  final String cueGood;
  final String cueBad;

  RepState _state = RepState.ready;
  bool _baselineCaptured = false;
  int _repCount = 0;
  String _feedback = "";
  bool _justHitTrigger = false;

  double _baselineDistance = 0;
  double _currentPercent = 100;
  double _smoothedPercent = 100;

  static const double _smoothingFactor = 0.3;
  DateTime? _intentTimer;
  DateTime _lastRepTime = DateTime.now();
  static const int _intentDelayMs = 80;
  static const int _minTimeBetweenRepsMs = 200;

  PistonPattern({
    required this.pointA,
    required this.pointB,
    this.pointARight,
    this.pointBRight,
    this.mode = PistonMode.shrink,
    this.triggerPercent = 0.70,
    this.resetPercent = 0.90,
    this.cueGood = "Good!",
    this.cueBad = "More!",
  });

  @override RepState get state => _state;
  @override bool get isLocked => _baselineCaptured;
  @override int get repCount => _repCount;
  @override String get feedback => _feedback;
  @override bool get justHitTrigger => _justHitTrigger;

  @override
  String get debugInfo => 'PISTON ${mode.name}\nDist%: ${_currentPercent.toStringAsFixed(1)}%\nSmooth: ${_smoothedPercent.toStringAsFixed(1)}%\nBase: ${_baselineDistance.toStringAsFixed(1)}\nTrig: ${(triggerPercent * 100).toStringAsFixed(0)}%\nReset: ${(resetPercent * 100).toStringAsFixed(0)}%\nState: ${_state.name}\nReps: $_repCount';

  @override
  double get chargeProgress {
    if (mode == PistonMode.shrink) {
      double range = 100 - (triggerPercent * 100);
      if (range < 1) return 0;
      return ((100 - _currentPercent) / range).clamp(0.0, 1.0);
    } else {
      double range = (triggerPercent * 100) - 100;
      if (range < 1) return 0;
      return ((_currentPercent - 100) / range).clamp(0.0, 1.0);
    }
  }

  double _calcDistance(Map<PoseLandmarkType, PoseLandmark> map) {
    final pA = map[pointA];
    final pAR = pointARight != null ? map[pointARight] : null;
    final pB = map[pointB];
    final pBR = pointBRight != null ? map[pointBRight] : null;

    // Get point A position (average left+right if both available)
    double? aX, aY;
    if (pA != null && pAR != null && pA.likelihood > 0.5 && pAR.likelihood > 0.5) {
      aX = (pA.x + pAR.x) / 2;
      aY = (pA.y + pAR.y) / 2;
    } else if (pA != null && pA.likelihood > 0.5) {
      aX = pA.x;
      aY = pA.y;
    } else if (pAR != null && pAR.likelihood > 0.5) {
      aX = pAR.x;
      aY = pAR.y;
    }

    // Get point B position
    double? bX, bY;
    if (pB != null && pBR != null && pB.likelihood > 0.5 && pBR.likelihood > 0.5) {
      bX = (pB.x + pBR.x) / 2;
      bY = (pB.y + pBR.y) / 2;
    } else if (pB != null && pB.likelihood > 0.5) {
      bX = pB.x;
      bY = pB.y;
    } else if (pBR != null && pBR.likelihood > 0.5) {
      bX = pBR.x;
      bY = pBR.y;
    }

    if (aX == null || aY == null || bX == null || bY == null) return -1;

    return math.sqrt((aX - bX) * (aX - bX) + (aY - bY) * (aY - bY));
  }

  @override
  void captureBaseline(Map<PoseLandmarkType, PoseLandmark> map) {
    double dist = _calcDistance(map);
    if (dist < 1) {
      _feedback = "Body not in frame";
      return;
    }
    _baselineDistance = dist;
    _smoothedPercent = 100;
    _currentPercent = 100;
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

    // Anti-cheat: full-body visible, upright, camera still.
    lastFormResult = formGate.check(map);
    if (!lastFormResult.ok) {
      _feedback = lastFormResult.uiMessage;
      return false;
    }

    double dist = _calcDistance(map);
    if (dist < 0) {
      _feedback = "Stay in frame";
      return false;
    }

    double rawPercent = (dist / _baselineDistance) * 100;
    _smoothedPercent = (_smoothingFactor * rawPercent) + ((1 - _smoothingFactor) * _smoothedPercent);
    _currentPercent = _smoothedPercent;

    bool isTriggered;
    bool isReset;

    if (mode == PistonMode.shrink) {
      isTriggered = _currentPercent <= (triggerPercent * 100);
      isReset = _currentPercent >= (resetPercent * 100);
    } else {
      isTriggered = _currentPercent >= (triggerPercent * 100);
      isReset = _currentPercent <= (resetPercent * 100);
    }

    switch (_state) {
      case RepState.ready:
      case RepState.up:
        if (isTriggered) {
          _intentTimer ??= DateTime.now();
          if (DateTime.now().difference(_intentTimer!).inMilliseconds > _intentDelayMs) {
            _state = RepState.down;
            _feedback = cueGood;
            _intentTimer = null;
            _justHitTrigger = true;
          } else {
            _state = RepState.goingDown;
          }
        } else {
          _intentTimer = null;
          _state = RepState.ready;
          _feedback = "";
        }
        return false;

      case RepState.goingDown:
        if (isTriggered) {
          _intentTimer ??= DateTime.now();
          if (DateTime.now().difference(_intentTimer!).inMilliseconds > _intentDelayMs) {
            _state = RepState.down;
            _feedback = cueGood;
            _intentTimer = null;
            _justHitTrigger = true;
          }
        } else {
          _intentTimer = null;
          _state = RepState.ready;
        }
        return false;

      case RepState.down:
        if (isReset) {
          _state = RepState.goingUp;
        }
        return false;

      case RepState.goingUp:
        if (isReset) {
          if (DateTime.now().difference(_lastRepTime).inMilliseconds > _minTimeBetweenRepsMs) {
            _state = RepState.up;
            _repCount++;
            _lastRepTime = DateTime.now();
            _feedback = "";
            return true;
          }
        } else {
          _state = RepState.down;
        }
        return false;
    }
  }

  @override
  void reset() {
    _repCount = 0;
    _state = RepState.ready;
    _feedback = "";
    _intentTimer = null;
    _baselineCaptured = false;
    _smoothedPercent = 100;
    _currentPercent = 100;
    _justHitTrigger = false;
  }
}
