import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../design/tokens.dart';

enum SkeletonState {
  normal,   // White bones - default
  success,  // Electric cyan flash - rep counted
}

/// =============================================================================
/// SKELETON PAINTER - Visual-only EMA smoothing
/// =============================================================================
/// Smoothing is applied ONLY here in the painter for visual rendering.
/// The tracking pipeline (camera → session → patterns) uses raw landmarks.
/// - Visual EMA with alpha=0.45 (responsive, just removes jitter)
/// - Low confidence → point removed (no stale data, no floating)
/// - Large jumps → snap immediately (exercise transitions)
/// - Body connections only (no face landmarks)
/// =============================================================================

class SkeletonPainter extends CustomPainter {
  final List<PoseLandmark>? landmarks;
  final Size imageSize;
  final bool isFrontCamera;
  final SkeletonState skeletonState;
  final double chargeProgress;
  final int powerLevel;
  final Color? userColor; // null = use tier-based color
  final bool showPTAngles; // PT coaching angle display
  final String? ptPatternType; // 'squat', 'push', 'pull', 'hinge', 'curl'

  SkeletonPainter({
    required this.landmarks,
    required this.imageSize,
    this.isFrontCamera = true,
    this.skeletonState = SkeletonState.normal,
    this.chargeProgress = 0.0,
    this.powerLevel = 0,
    this.userColor,
    this.showPTAngles = false,
    this.ptPatternType,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (landmarks == null || landmarks!.isEmpty) return;

    // Build lookup map
    final Map<PoseLandmarkType, PoseLandmark> landmarkMap = {};
    for (final landmark in landmarks!) {
      landmarkMap[landmark.type] = landmark;
    }

    final Color baseColor = _getPhaseColor();

    // Draw using FormSkeletonPainter logic: thick bones, glow, big joints
    _drawConnections(canvas, size, baseColor, landmarkMap);
    _drawJoints(canvas, size, baseColor, landmarkMap);

    // PT Coaching angles — throttled to reduce CPU impact on skeleton smoothness
    if (showPTAngles && ptPatternType != null) {
      _ptPaintCounter++;
      if (_ptPaintCounter % 3 == 0 || _lastPTAngleCanvas == null) {
        _drawPTAnglesDirect(canvas, size, landmarkMap);
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // VISUAL SMOOTHING — painter-only, never touches tracking pipeline
  // ═══════════════════════════════════════════════════════════════════════════
  static final Map<PoseLandmarkType, Offset> _smoothCache = {};
  static int _ptPaintCounter = 0;
  static Canvas? _lastPTAngleCanvas;
  static const double _alpha = 0.50; // 0.50 = more responsive, less lag, still filters jitter

  /// Call when switching exercises or ending workout
  static void resetSmoothing() => _smoothCache.clear();

  Offset? _getPos(PoseLandmarkType type, Size size, Map<PoseLandmarkType, PoseLandmark> landmarkMap) {
    final lm = landmarkMap[type];
    if (lm == null || lm.likelihood < 0.65) {
      // Can't see this joint — REMOVE from cache, don't hold stale position
      _smoothCache.remove(type);
      return null;
    }

    // Raw screen position
    double x = lm.x * size.width / imageSize.width;
    double y = lm.y * size.height / imageSize.height;
    if (isFrontCamera) x = size.width - x;
    final raw = Offset(x, y);

    // Blend with previous position (visual smoothing only)
    final prev = _smoothCache[type];
    if (prev != null) {
      final jump = (raw - prev).distance;
      final screenSize = (size.width + size.height) * 0.5;

      // Big jump (>15% of screen) = snap instantly, don't smooth
      if (jump > screenSize * 0.15) {
        _smoothCache[type] = raw;
        return raw;
      }

      // Normal: blend toward new position
      final smoothed = Offset(
        _alpha * raw.dx + (1 - _alpha) * prev.dx,
        _alpha * raw.dy + (1 - _alpha) * prev.dy,
      );
      _smoothCache[type] = smoothed;
      return smoothed;
    }

    // First frame — use raw
    _smoothCache[type] = raw;
    return raw;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BONES: Thick glow + main bone + highlight (from FormSkeletonPainter)
  // ═══════════════════════════════════════════════════════════════════════════
  void _drawConnections(Canvas canvas, Size size, Color color, Map<PoseLandmarkType, PoseLandmark> landmarkMap) {
    // Body connections only — NO FACE
    final connections = [
      // Torso
      [PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder],
      [PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip],
      [PoseLandmarkType.rightShoulder, PoseLandmarkType.rightHip],
      [PoseLandmarkType.leftHip, PoseLandmarkType.rightHip],
      // Left Arm
      [PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow],
      [PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist],
      // Right Arm
      [PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow],
      [PoseLandmarkType.rightElbow, PoseLandmarkType.rightWrist],
      // Left Leg
      [PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee],
      [PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle],
      // Right Leg
      [PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee],
      [PoseLandmarkType.rightKnee, PoseLandmarkType.rightAnkle],
    ];

    for (final conn in connections) {
      final p1 = _getPos(conn[0], size, landmarkMap);
      final p2 = _getPos(conn[1], size, landmarkMap);
      if (p1 != null && p2 != null) {
        _drawBone(canvas, p1, p2, color);
      }
    }
  }

  /// Draw a thick bone with glow (from FormSkeletonPainter), scaled by tier
  void _drawBone(Canvas canvas, Offset start, Offset end, Color color) {
    final distance = (end - start).distance;
    if (distance < 10) return;

    final glowOpacity = _getBaseGlowOpacity();
    final glowRadius = _getBaseGlowRadius();

    // Glow layer (tier-scaled)
    final glowPaint = Paint()
      ..color = color.withOpacity(glowOpacity)
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, glowRadius);
    canvas.drawLine(start, end, glowPaint);

    // Main bone
    final bonePaint = Paint()
      ..color = color
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(start, end, bonePaint);

    // Inner highlight
    final highlightPaint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(start, end, highlightPaint);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // JOINTS: Glowing circles (from FormSkeletonPainter)
  // ═══════════════════════════════════════════════════════════════════════════
  void _drawJoints(Canvas canvas, Size size, Color color, Map<PoseLandmarkType, PoseLandmark> landmarkMap) {
    // Body joints only — NO FACE
    final joints = [
      PoseLandmarkType.leftShoulder,
      PoseLandmarkType.rightShoulder,
      PoseLandmarkType.leftElbow,
      PoseLandmarkType.rightElbow,
      PoseLandmarkType.leftWrist,
      PoseLandmarkType.rightWrist,
      PoseLandmarkType.leftHip,
      PoseLandmarkType.rightHip,
      PoseLandmarkType.leftKnee,
      PoseLandmarkType.rightKnee,
      PoseLandmarkType.leftAnkle,
      PoseLandmarkType.rightAnkle,
    ];

    for (final joint in joints) {
      final pos = _getPos(joint, size, landmarkMap);
      if (pos != null) {
        _drawJoint(canvas, pos, color, 4.0);
      }
    }
  }

  /// Draw a glowing joint (from FormSkeletonPainter), scaled by tier
  void _drawJoint(Canvas canvas, Offset pos, Color color, double radius) {
    final glowOpacity = _getBaseGlowOpacity();
    final glowRadius = _getBaseGlowRadius();

    // Outer glow (tier-scaled)
    final glowPaint = Paint()
      ..color = color.withOpacity(glowOpacity + 0.1)
      ..style = PaintingStyle.fill
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, glowRadius + 2);
    canvas.drawCircle(pos, radius + 2, glowPaint);

    // Main joint
    final jointPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(pos, radius, jointPaint);

    // Inner highlight
    final highlightPaint = Paint()
      ..color = Colors.white.withOpacity(0.4)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(pos.translate(-1, -1), radius * 0.3, highlightPaint);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TIER-BASED BASE COLOR (from power level)
  // ═══════════════════════════════════════════════════════════════════════════
  Color _getBaseColor() {
    if (userColor != null) return userColor!;
    if (powerLevel >= 1000) return const Color(0xFFFFD700); // GOLD — legend
    if (powerLevel >= 500) return const Color(0xFF00FFFF);  // CYAN — advanced
    if (powerLevel >= 100) return const Color(0xFFCCFF00);  // CYBER LIME — intermediate
    return const Color(0xFFFFFFFF);                          // WHITE — beginner
  }

  double _getBaseGlowOpacity() {
    if (powerLevel >= 1000) return 0.6;
    if (powerLevel >= 500) return 0.45;
    if (powerLevel >= 100) return 0.35;
    return 0.25;
  }

  double _getBaseGlowRadius() {
    if (powerLevel >= 1000) return 12.0;
    if (powerLevel >= 500) return 9.0;
    if (powerLevel >= 100) return 7.0;
    return 5.0;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // COLOR: State modifiers on top of tier base
  // ═══════════════════════════════════════════════════════════════════════════
  Color _getPhaseColor() {
    final base = _getBaseColor();

    // Rep counted → flash BRIGHTER (toward white)
    if (skeletonState == SkeletonState.success) {
      return Color.lerp(base, Colors.white, 0.7)!;
    }

    // Charging (going DOWN) → vivid version of base
    if (chargeProgress >= 0.5) {
      if (userColor != null) {
        // Custom color: boost saturation + lightness for "glow" effect
        final hsl = HSLColor.fromColor(base);
        return hsl
            .withSaturation(1.0)
            .withLightness((hsl.lightness + 0.15).clamp(0.0, 0.85))
            .toColor();
      }
      // Default tier users: keep existing dark green
      return const Color(0xFF00FF41);
    }

    // Standing → base color
    return base.withOpacity(0.9);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PT COACHING ANGLES — DIRECT calculation, same as premium_skeleton_painter
  // No external engine. Calculate from landmarks. Draw immediately.
  // ═══════════════════════════════════════════════════════════════════════════
  void _drawPTAnglesDirect(Canvas canvas, Size size, Map<PoseLandmarkType, PoseLandmark> landmarkMap) {
    final joints = _getJointsForPattern(ptPatternType!);
    final targets = _getTargetsForPattern(ptPatternType!);

    for (final entry in joints.entries) {
      final label = entry.key;
      final types = entry.value; // [p1, vertex, p3] — already on the FIXED side

      // Use the fixed side — no bouncing
      final pos = _getPos(types[1], size, landmarkMap);
      final angle = _calcAngle3(types[0], types[1], types[2], landmarkMap);

      if (pos == null || angle == null) continue;

      // Get target for this angle
      final target = targets[label];
      final targetMin = target?[0] ?? 80.0;
      final targetMax = target?[1] ?? 110.0;

      // Colour: orange → green based on proximity to target
      final Color color;
      final bool inTarget = angle >= targetMin && angle <= targetMax;
      if (inTarget) {
        color = const Color(0xFF00FF41); // Bright green — on target
      } else {
        final distToTarget = angle < targetMin
            ? targetMin - angle
            : angle - targetMax;
        if (distToTarget <= 15) {
          // Close — transitioning orange to green
          final t = 1.0 - (distToTarget / 15.0);
          color = Color.lerp(const Color(0xFFFF8C00), const Color(0xFF00FF41), t)!;
        } else {
          color = const Color(0xFFFF8C00); // Bright orange — far from target
        }
      }

      final angleText = '${angle.toStringAsFixed(0)}°';

      // Black background pill — clean, readable
      final pillCenter = pos + const Offset(30, -10);
      final bgRect = RRect.fromRectAndRadius(
        Rect.fromCenter(center: pillCenter, width: 72, height: 38),
        const Radius.circular(10),
      );
      canvas.drawRRect(bgRect, Paint()..color = Colors.black.withOpacity(0.85));
      canvas.drawRRect(bgRect, Paint()..color = color.withOpacity(0.5)..style = PaintingStyle.stroke..strokeWidth = 1.5);

      // Angle number — big, bold, no label
      final tp = TextPainter(
        text: TextSpan(
          text: angleText,
          style: TextStyle(
            color: color,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, pillCenter - Offset(tp.width / 2, tp.height / 2));
    }
  }

  // Target ranges per pattern per angle label
  Map<String, List<double>> _getTargetsForPattern(String pattern) {
    return switch (pattern) {
      'squat' || 'stepUp' => {
        'KNEE': [95.0, 110.0],  // Good functional depth
        'HIP': [70.0, 90.0],    // Realistic hip angle
      },
      'push' => {
        'ELBOW': [65.0, 90.0],  // Full ROM at bottom
        'SHOULDER': [45.0, 75.0], // Tuck angle
      },
      'pull' => {
        'ELBOW': [40.0, 70.0],  // Full pull at top
        'SHOULDER': [80.0, 110.0],
      },
      'hinge' => {
        'HIP': [160.0, 180.0],  // Green at lockout (standing tall)
        'KNEE': [150.0, 180.0], // Soft bend
      },
      'curl' => {
        'ELBOW': [30.0, 55.0],  // Peak contraction
        'SHOULDER': [0.0, 30.0],
      },
      _ => {
        'KNEE': [95.0, 110.0],
        'ELBOW': [65.0, 90.0],
      },
    };
  }

  // Calculate angle from 3 landmark types — exact same math as premium_skeleton_painter._calcAngle
  double? _calcAngle3(PoseLandmarkType p1, PoseLandmarkType p2, PoseLandmarkType p3, Map<PoseLandmarkType, PoseLandmark> map) {
    final l1 = map[p1], l2 = map[p2], l3 = map[p3];
    if (l1 == null || l2 == null || l3 == null) return null;
    final v1 = Offset(l1.x - l2.x, l1.y - l2.y);
    final v2 = Offset(l3.x - l2.x, l3.y - l2.y);
    final dot = v1.dx * v2.dx + v1.dy * v2.dy;
    final mag1 = math.sqrt(v1.dx * v1.dx + v1.dy * v1.dy);
    final mag2 = math.sqrt(v2.dx * v2.dx + v2.dy * v2.dy);
    if (mag1 < 0.001 || mag2 < 0.001) return null;
    return math.acos((dot / (mag1 * mag2)).clamp(-1.0, 1.0)) * 180 / math.pi;
  }

  // Which 2 angles to show per pattern type
  // FRONT exercises (squat, curl, OHP, pull up, lat pulldown, lateral raise):
  //   angle1 on LEFT side, angle2 on RIGHT side — no overlap
  // SIDE exercises (bench, deadlift, RDL, row, hip thrust):
  //   both angles on LEFT side (the visible side for side camera)
  Map<String, List<PoseLandmarkType>> _getJointsForPattern(String pattern) {
    return switch (pattern) {
      'squat' || 'stepUp' => {
        // FRONT: knee on left, hip on right — no overlap
        'KNEE': [PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle],
        'HIP': [PoseLandmarkType.rightShoulder, PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee],
      },
      'push' => {
        // Could be front (push up, OHP) or side (bench) — use left for both
        'ELBOW': [PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist],
        'SHOULDER': [PoseLandmarkType.rightHip, PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow],
      },
      'pull' => {
        // FRONT: elbow left, shoulder right
        'ELBOW': [PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist],
        'SHOULDER': [PoseLandmarkType.rightHip, PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow],
      },
      'hinge' => {
        // SIDE: both on left (visible side)
        'HIP': [PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee],
        'KNEE': [PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle],
      },
      'curl' => {
        // FRONT: elbow on left, shoulder on right — no overlap
        'ELBOW': [PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist],
        'SHOULDER': [PoseLandmarkType.rightHip, PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow],
      },
      'calf' => {
        'KNEE': [PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle],
      },
      _ => {
        // Default: knee left, elbow right — no overlap
        'KNEE': [PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle],
        'ELBOW': [PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow, PoseLandmarkType.rightWrist],
      },
    };
  }

  PoseLandmarkType _toRight(PoseLandmarkType left) {
    return switch (left) {
      PoseLandmarkType.leftShoulder => PoseLandmarkType.rightShoulder,
      PoseLandmarkType.leftElbow => PoseLandmarkType.rightElbow,
      PoseLandmarkType.leftWrist => PoseLandmarkType.rightWrist,
      PoseLandmarkType.leftHip => PoseLandmarkType.rightHip,
      PoseLandmarkType.leftKnee => PoseLandmarkType.rightKnee,
      PoseLandmarkType.leftAnkle => PoseLandmarkType.rightAnkle,
      _ => left,
    };
  }

  @override
  bool shouldRepaint(covariant SkeletonPainter oldDelegate) {
    return oldDelegate.landmarks != landmarks ||
           oldDelegate.skeletonState != skeletonState ||
           oldDelegate.chargeProgress != chargeProgress ||
           oldDelegate.powerLevel != powerLevel ||
           oldDelegate.userColor != userColor ||
           oldDelegate.showPTAngles != showPTAngles ||
           oldDelegate.ptPatternType != ptPatternType;
  }
}
