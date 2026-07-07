import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../design/tokens.dart';
import '../models/habit.dart';
import '../services/wake_debt_service.dart';
import 'sergeant/wake_exercise_screen.dart';

/// The morning wake alarm — Erly-killer.
///
/// Full-black screen. Massive time. Order title. A red pill showing the
/// debt owed right now. The ONLY exit is a slide-to-punishment bar that
/// hands off to the wake exercise. No dismiss. No snooze. No mercy.
///
/// Audio blasts from AVAudioSession playback category (bypasses silent
/// switch) and the phone vibrates every second until the user slides.
class MorningAlarmScreen extends ConsumerStatefulWidget {
  final Habit habit;
  const MorningAlarmScreen({super.key, required this.habit});

  @override
  ConsumerState<MorningAlarmScreen> createState() => _MorningAlarmScreenState();
}

class _MorningAlarmScreenState extends ConsumerState<MorningAlarmScreen> {
  final AudioPlayer _player = AudioPlayer();
  Timer? _hapticTimer;
  Timer? _tickTimer;
  bool _handingOff = false;

  @override
  void initState() {
    super.initState();
    WakeDebtService.markActive(widget.habit.id);
    _startAlarm();
    // Tick every 10s so the debt counter climbs live in front of them.
    _tickTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _startAlarm() async {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    try {
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.setVolume(1.0);
      await _player.play(AssetSource('images/sergeant_intro.mp4'));
    } catch (e) {
      debugPrint('alarm audio failed: $e');
    }
    _hapticTimer = Timer.periodic(const Duration(milliseconds: 900), (_) {
      HapticFeedback.heavyImpact();
    });
  }

  Future<void> _handoffToExercise() async {
    if (_handingOff) return;
    _handingOff = true;
    _hapticTimer?.cancel();
    _tickTimer?.cancel();
    await _player.stop();
    HapticFeedback.heavyImpact();
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => WakeExerciseScreen(habit: widget.habit),
      ),
    );
  }

  @override
  void dispose() {
    _hapticTimer?.cancel();
    _tickTimer?.cancel();
    _player.stop();
    _player.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = TimeOfDay.now();
    final timeStr = DateFormat('HH:mm').format(DateTime(2025, 1, 1, t.hour, t.minute));
    final reps = WakeDebtService.totalRepsFor(widget.habit);
    final late = WakeDebtService.minutesLate(widget.habit);

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            const Positioned.fill(child: _AngryPulse()),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const SizedBox(height: 32),
                    _AlarmBadge(late: late),
                    const Spacer(),
                    Text(
                      timeStr,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 108,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -6,
                        height: 1,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ).animate(onPlay: (c) => c.repeat(reverse: true))
                        .fade(begin: 1, end: 0.72, duration: 900.ms),
                    const SizedBox(height: 8),
                    Text(
                      'HABITDRILL',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.4),
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 6,
                      ),
                    ),
                    const SizedBox(height: 28),
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
                    const SizedBox(height: 20),
                    _RepsPill(reps: reps),
                    const Spacer(flex: 2),
                    _SlideToPunish(onCompleted: _handoffToExercise),
                    const SizedBox(height: 32),
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

// ────────────────────────── Angry red pulse ──────────────────────────

class _AngryPulse extends StatelessWidget {
  const _AngryPulse();
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

// ────────────────────────── ALARM badge with minutes-late ──────────

class _AlarmBadge extends StatelessWidget {
  final int late;
  const _AlarmBadge({required this.late});

  @override
  Widget build(BuildContext context) {
    final label = late <= 0 ? 'ALARM' : '$late MIN LATE';
    return Container(
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
            label,
            style: TextStyle(
              color: AppColors.error,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 3,
            ),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────── Reps-to-escape pill ──────────────────────

class _RepsPill extends StatelessWidget {
  final int reps;
  const _RepsPill({required this.reps});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFEA580C), Color(0xFFDC2626)],
        ),
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: AppColors.error.withOpacity(0.45),
            blurRadius: 24,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Text(
        '$reps SQUATS TO ESCAPE',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w900,
          letterSpacing: 2,
        ),
      ),
    );
  }
}

// ────────────────────────── Slide-to-punish bar ──────────────────────

class _SlideToPunish extends StatefulWidget {
  final VoidCallback onCompleted;
  const _SlideToPunish({required this.onCompleted});

  @override
  State<_SlideToPunish> createState() => _SlideToPunishState();
}

class _SlideToPunishState extends State<_SlideToPunish> {
  double _drag = 0;
  bool _fired = false;

  static const double _thumbSize = 62;
  static const double _height = 74;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final maxDrag = c.maxWidth - _thumbSize - 6;
      return Container(
        height: _height,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(_height / 2),
          border: Border.all(color: Colors.white.withOpacity(0.12), width: 1),
        ),
        child: Stack(
          children: [
            // Fill trail behind the thumb.
            Positioned(
              left: 3,
              top: 3,
              bottom: 3,
              width: _thumbSize + _drag,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.emerald.withOpacity(0.9),
                      AppColors.emerald.withOpacity(0.4),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(_height / 2),
                ),
              ),
            ),
            // Center hint text — dims as thumb travels.
            Positioned.fill(
              child: Center(
                child: Opacity(
                  opacity: (1 - (_drag / maxDrag).clamp(0.0, 1.0)).clamp(0.15, 1.0),
                  child: Text(
                    'SLIDE TO PUNISHMENT ▶',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.75),
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 3,
                    ),
                  ),
                ),
              ),
            ),
            // Draggable thumb.
            Positioned(
              left: 3 + _drag,
              top: 3,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragUpdate: (d) {
                  if (_fired) return;
                  setState(() {
                    _drag = (_drag + d.delta.dx).clamp(0.0, maxDrag);
                  });
                },
                onHorizontalDragEnd: (_) {
                  if (_fired) return;
                  if (_drag >= maxDrag - 4) {
                    _fired = true;
                    widget.onCompleted();
                  } else {
                    setState(() => _drag = 0);
                  }
                },
                child: Container(
                  width: _thumbSize,
                  height: _thumbSize,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white.withOpacity(0.25),
                        blurRadius: 18,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.arrow_forward_rounded,
                    color: Colors.black,
                    size: 30,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }
}
