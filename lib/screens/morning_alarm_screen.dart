import 'dart:async';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../design/tokens.dart';
import '../models/habit.dart';
import '../providers/habit_provider.dart';

/// Full-screen "you set an alarm, it's time" experience. Loops audio at
/// full volume (bypasses silent switch via the AVAudioSession.playback
/// category we set globally in main.dart). Only way out is hold-to-dismiss.
class MorningAlarmScreen extends ConsumerStatefulWidget {
  final Habit habit;
  const MorningAlarmScreen({super.key, required this.habit});

  @override
  ConsumerState<MorningAlarmScreen> createState() => _MorningAlarmScreenState();
}

class _MorningAlarmScreenState extends ConsumerState<MorningAlarmScreen> {
  final AudioPlayer _player = AudioPlayer();
  Timer? _hapticTimer;
  Timer? _holdTimer;
  double _holdProgress = 0;
  bool _dismissing = false;

  static const _holdDuration = Duration(seconds: 3);

  @override
  void initState() {
    super.initState();
    _startAlarm();
  }

  Future<void> _startAlarm() async {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    // Blast the sergeant intro on loop — placeholder until you drop
    // an actual alarm.caf into assets. Volume forced to 1.0.
    try {
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.setVolume(1.0);
      await _player.play(AssetSource('images/sergeant_intro.mp4'));
    } catch (e) {
      debugPrint('alarm audio failed: $e');
    }
    // Vibrate every second.
    _hapticTimer = Timer.periodic(const Duration(milliseconds: 900), (_) {
      HapticFeedback.heavyImpact();
    });
  }

  void _holdStart() {
    HapticFeedback.mediumImpact();
    _holdTimer?.cancel();
    _holdTimer = Timer.periodic(const Duration(milliseconds: 50), (t) {
      setState(() {
        _holdProgress += 50 / _holdDuration.inMilliseconds;
        if (_holdProgress >= 1) {
          _holdProgress = 1;
          _dismiss();
          t.cancel();
        }
      });
    });
  }

  void _holdEnd() {
    if (_holdProgress >= 1) return;
    _holdTimer?.cancel();
    setState(() => _holdProgress = 0);
  }

  Future<void> _dismiss() async {
    if (_dismissing) return;
    _dismissing = true;
    _hapticTimer?.cancel();
    await _player.stop();
    HapticFeedback.heavyImpact();
    // Mark the habit done for today (so the streak advances).
    try {
      await ref.read(habitEngineProvider).toggleHabitCompletion(widget.habit.id);
    } catch (_) {}
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _hapticTimer?.cancel();
    _holdTimer?.cancel();
    _player.stop();
    _player.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = TimeOfDay.now();
    final timeStr = DateFormat('h:mm').format(DateTime(2025, 1, 1, t.hour, t.minute));
    final period = t.period == DayPeriod.am ? 'AM' : 'PM';
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // Angry red pulse background
            Positioned.fill(
              child: _AngryPulse(),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const Spacer(),
                    // Big time
                    Text(
                      timeStr,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 96,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -4,
                        height: 1,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ).animate(onPlay: (c) => c.repeat(reverse: true))
                        .fade(begin: 1, end: 0.75, duration: 900.ms),
                    const SizedBox(height: 4),
                    Text(
                      period,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 6,
                      ),
                    ),
                    const SizedBox(height: 26),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.error.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.error, width: 1.5),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: AppColors.error,
                              borderRadius: BorderRadius.circular(4),
                              boxShadow: [BoxShadow(color: AppColors.error.withOpacity(0.9), blurRadius: 8)],
                            ),
                          ).animate(onPlay: (c) => c.repeat(reverse: true))
                              .fade(begin: 1, end: 0.3, duration: 500.ms),
                          const SizedBox(width: 8),
                          Text(
                            'ALARM',
                            style: TextStyle(
                              color: AppColors.error,
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    Text(
                      widget.habit.title.toUpperCase(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Get up. Punch the day in the face.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.55),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const Spacer(flex: 2),
                    _HoldToDismiss(
                      progress: _holdProgress,
                      onStart: _holdStart,
                      onEnd: _holdEnd,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'HOLD TO DISMISS',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.4),
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 3,
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AngryPulse extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(0, -0.3),
          radius: 1.2,
          colors: [
            AppColors.error.withOpacity(0.25),
            AppColors.error.withOpacity(0.05),
            Colors.black,
          ],
          stops: const [0.0, 0.4, 1.0],
        ),
      ),
    ).animate(onPlay: (c) => c.repeat(reverse: true))
        .fade(begin: 1, end: 0.55, duration: 800.ms);
  }
}

class _HoldToDismiss extends StatelessWidget {
  final double progress;
  final VoidCallback onStart;
  final VoidCallback onEnd;

  const _HoldToDismiss({
    required this.progress,
    required this.onStart,
    required this.onEnd,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => onStart(),
      onTapUp: (_) => onEnd(),
      onTapCancel: onEnd,
      onLongPressStart: (_) => onStart(),
      onLongPressEnd: (_) => onEnd(),
      child: SizedBox(
        width: 200,
        height: 200,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Outer ring
            Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withOpacity(0.15), width: 2),
              ),
            ),
            // Fill ring
            SizedBox(
              width: 200,
              height: 200,
              child: CustomPaint(painter: _RingProgressPainter(progress: progress)),
            ),
            // Center pulse
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 130 + (progress * 10),
              height: 130 + (progress * 10),
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    AppColors.emerald.withOpacity(0.7 + progress * 0.3),
                    AppColors.emerald.withOpacity(0.4),
                  ],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.emerald.withOpacity(0.4 + progress * 0.4),
                    blurRadius: 32 + progress * 20,
                    spreadRadius: progress * 6,
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Icon(
                progress >= 1 ? Icons.check : Icons.notifications_off_rounded,
                color: Colors.black,
                size: 44,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RingProgressPainter extends CustomPainter {
  final double progress;
  _RingProgressPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 1;
    final paint = Paint()
      ..color = AppColors.emerald
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final glowPaint = Paint()
      ..color = AppColors.emerald.withOpacity(0.6)
      ..strokeWidth = 8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawArc(rect, -pi / 2, 2 * pi * progress, false, glowPaint);
    canvas.drawArc(rect, -pi / 2, 2 * pi * progress, false, paint);
  }

  @override
  bool shouldRepaint(covariant _RingProgressPainter old) => old.progress != progress;
}
