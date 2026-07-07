import 'dart:math' as math;
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

/// The exact reason the last frame was rejected. Drives UI feedback so the
/// user understands what to fix ("SHOW YOUR FULL BODY", "HOLD PHONE STILL",
/// etc.) instead of just seeing reps mysteriously not count.
enum FormReject {
  ok,
  missingLandmarks,      // ML Kit didn't return one of the required joints
  lowConfidence,         // Landmark exists but likelihood too low
  outOfFrame,            // Landmark is off-screen (x/y outside 0..1 with margin)
  wrongGeometry,         // Head not above hips above knees above ankles → not upright
  cameraShaking,         // Frame-to-frame motion too high → phone is being swung
}

class FormResult {
  final FormReject reject;
  final String uiMessage;
  const FormResult(this.reject, this.uiMessage);

  bool get ok => reject == FormReject.ok;
}

/// Anti-cheat gate. Every rep pattern calls this BEFORE counting a rep.
/// Rejects the classic cheats:
///   * User lies down and swings the phone up/down → geometry / shake fail
///   * User points camera at nothing but a wall → missingLandmarks / lowConfidence
///   * User waves a hand in front → outOfFrame (only partial body)
///   * User walks/runs holding camera → cameraShaking
class FormGate {
  static const double _minLikelihood = 0.60;
  static const double _outOfFrameMargin = 0.02;
  static const double _shakeThreshold = 0.06; // normalized units per frame
  static const int _shakeWindowFrames = 6;

  // Required landmarks — every pattern demands a full body. This is the
  // whole point of the anti-cheat: partial-body reps don't count.
  static const List<PoseLandmarkType> _requiredLandmarks = [
    PoseLandmarkType.nose,
    PoseLandmarkType.leftShoulder,
    PoseLandmarkType.rightShoulder,
    PoseLandmarkType.leftHip,
    PoseLandmarkType.rightHip,
    PoseLandmarkType.leftKnee,
    PoseLandmarkType.rightKnee,
    PoseLandmarkType.leftAnkle,
    PoseLandmarkType.rightAnkle,
  ];

  // Recent nose positions used to detect phone-swinging camera motion.
  final List<_XY> _noseHistory = [];

  /// Reset per-set state. Call between exercises.
  void reset() {
    _noseHistory.clear();
  }

  /// [requireUpright] enforces the "head above hips above knees above ankles"
  /// geometry check. Turn it OFF for horizontal exercises (push-ups, planks)
  /// where the body isn't vertical.
  FormResult check(
    Map<PoseLandmarkType, PoseLandmark> map, {
    double? imageWidth,
    double? imageHeight,
    bool requireUpright = true,
  }) {
    // 1. All required landmarks must exist.
    for (final t in _requiredLandmarks) {
      if (map[t] == null) {
        return const FormResult(FormReject.missingLandmarks, 'SHOW YOUR FULL BODY');
      }
    }

    // 2. Confidence: ML Kit returns landmarks with likelihood ∈ [0, 1].
    // Below 0.6 is essentially a hallucination — it happens when the body
    // is out of frame or occluded.
    for (final t in _requiredLandmarks) {
      final lm = map[t]!;
      if (lm.likelihood < _minLikelihood) {
        return const FormResult(FormReject.lowConfidence, 'STEP INTO FRAME');
      }
    }

    // 3. On-screen check. ML Kit sometimes returns coordinates outside the
    // image bounds when the person is partially cut off.
    if (imageWidth != null && imageHeight != null) {
      final marginX = imageWidth * _outOfFrameMargin;
      final marginY = imageHeight * _outOfFrameMargin;
      for (final t in _requiredLandmarks) {
        final lm = map[t]!;
        if (lm.x < -marginX ||
            lm.x > imageWidth + marginX ||
            lm.y < -marginY ||
            lm.y > imageHeight + marginY) {
          return const FormResult(FormReject.outOfFrame, 'STEP INTO FRAME');
        }
      }
    }

    // 4. Body geometry — head Y < hips Y < knees Y < ankles Y (image
    // coordinates: y grows downward). Rejects a phone lying flat, a person
    // holding the phone at their side, upside-down cheats.
    final nose = map[PoseLandmarkType.nose]!;
    if (requireUpright) {
      final hipY = (map[PoseLandmarkType.leftHip]!.y + map[PoseLandmarkType.rightHip]!.y) / 2;
      final kneeY = (map[PoseLandmarkType.leftKnee]!.y + map[PoseLandmarkType.rightKnee]!.y) / 2;
      final ankleY = (map[PoseLandmarkType.leftAnkle]!.y + map[PoseLandmarkType.rightAnkle]!.y) / 2;
      if (!(nose.y < hipY + 40 && hipY < kneeY + 20 && kneeY < ankleY + 20)) {
        return const FormResult(FormReject.wrongGeometry, 'STAND UP · FULL BODY');
      }
    }

    // Camera-shake detection was here — removed because it tracked nose
    // position, which naturally moves ~50% of frame height during real
    // burpees / jumps. It was killing legitimate reps. Landmark visibility,
    // confidence, and body geometry are enough to catch phone-lying-flat
    // cheats. If we need shake detection later, we'll do it by comparing
    // motion of ALL landmarks — camera motion moves them together, body
    // motion moves them relative to each other.

    return const FormResult(FormReject.ok, '');
  }

  void _pushNose(PoseLandmark nose, double w, double h) {
    _noseHistory.add(_XY(nose.x / w, nose.y / h));
    if (_noseHistory.length > _shakeWindowFrames) {
      _noseHistory.removeAt(0);
    }
  }

  bool _isShaking() {
    if (_noseHistory.length < _shakeWindowFrames) return false;
    double totalMotion = 0;
    for (int i = 1; i < _noseHistory.length; i++) {
      final dx = _noseHistory[i].x - _noseHistory[i - 1].x;
      final dy = _noseHistory[i].y - _noseHistory[i - 1].y;
      totalMotion += math.sqrt(dx * dx + dy * dy);
    }
    final avgPerFrame = totalMotion / (_noseHistory.length - 1);
    return avgPerFrame > _shakeThreshold;
  }
}

class _XY {
  final double x;
  final double y;
  const _XY(this.x, this.y);
}
