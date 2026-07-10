import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../design/tokens.dart';
import '../../models/exercise_set.dart';
import '../../models/habit.dart';
import '../../providers/habit_provider.dart';
import '../../services/alarm_service.dart';
import '../../services/discipline_service.dart';
import '../../services/wake_debt_service.dart';
import '../../services/wake_mission_prefs.dart';
import '../../services/wake_siren_service.dart';
import 'exercise_circuit_screen.dart';
import 'wake_complete_screen.dart';

/// Wake-alarm exercise flow, three-phase:
///
///   1. INTRO  — plays assets/videos/sergeant_morning.mp4 (unhinged
///               drill sergeant morning bark). Skips gracefully if the
///               asset is missing (fresh checkouts, dev machines).
///   2. SETUP  — 5-second countdown with a HUGE on-screen brief and
///               synchronised sergeant TTS-style caption: "PHONE ON THE
///               FLOOR. GET YOUR FULL BODY INTO POSITION."
///   3. REPS   — hands off to ExerciseCircuitScreen (camera + pose
///               detection), which runs its own inner countdown and
///               counts the user's chosen mission with escalating debt.
class WakeExerciseScreen extends ConsumerStatefulWidget {
  final Habit habit;
  const WakeExerciseScreen({super.key, required this.habit});

  @override
  ConsumerState<WakeExerciseScreen> createState() => _WakeExerciseScreenState();
}

enum _WakePhase { intro, setup, reps }

class _WakeExerciseScreenState extends ConsumerState<WakeExerciseScreen> {
  _WakePhase _phase = _WakePhase.intro;
  ExerciseSet? _set;

  // Video
  VideoPlayerController? _videoController;
  bool _videoReady = false;

  // Setup countdown
  int _countdown = 5;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    // Defensive: WakeSirenService.start() is idempotent. If the user
    // opened this screen via cold-start (skipping MorningAlarmScreen)
    // we still want the siren wailing.
    WakeSirenService.start();
    _buildSet();
    _initVideo();
  }

  /// Build the ExerciseSet by combining the user's chosen mission (from
  /// WakeMissionPrefs) with the pledged rep count, plus escalating debt
  /// reps accumulated while they stalled.
  Future<void> _buildSet() async {
    final mission = await WakeMissionPrefs.getMission(widget.habit.id);
    final pledged = await WakeMissionPrefs.getReps(widget.habit.id);
    final debt = WakeDebtService.minutesLate(widget.habit) *
        WakeDebtService.repsPerMinute;
    final total = pledged +
        debt.clamp(0, WakeDebtService.maxDebtReps);

    if (!mounted) return;
    setState(() {
      _set = ExerciseSet(
        exercises: [
          Exercise(
            name: mission.name,
            engineId: mission.engineId,
            emoji: mission.emoji,
            reps: total,
          ),
        ],
        escalationLevel: 0,
        offenseNumber: 0,
      );
    });
  }

  Future<void> _initVideo() async {
    try {
      _videoController = VideoPlayerController.asset(
        'assets/videos/sergeant_morning.mp4',
      );
      await _videoController!.initialize();
      _videoController!.addListener(_onVideoTick);
      await _videoController!.setVolume(1.0);
      await _videoController!.play();
      if (mounted) setState(() => _videoReady = true);
    } catch (e) {
      debugPrint('sergeant_morning.mp4 missing or failed: $e — skipping intro');
      _startSetup();
    }
  }

  void _onVideoTick() {
    final c = _videoController;
    if (c == null) return;
    if (c.value.isInitialized &&
        c.value.duration > Duration.zero &&
        c.value.position >= c.value.duration) {
      c.removeListener(_onVideoTick);
      _startSetup();
    }
  }

  void _startSetup() {
    if (!mounted) return;
    setState(() {
      _phase = _WakePhase.setup;
      _countdown = 5;
    });
    HapticFeedback.heavyImpact();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      HapticFeedback.mediumImpact();
      setState(() => _countdown--);
      if (_countdown <= 0) {
        t.cancel();
        HapticFeedback.heavyImpact();
        setState(() => _phase = _WakePhase.reps);
      }
    });
  }

  Future<void> _onWakeComplete() async {
    // Mark the habit done for today so the streak advances and the
    // AT-RISK/CONTROLLED banner flips green. Guard against re-toggle:
    // toggleHabitCompletion flips state, and if the user re-enters wake
    // after already completing today (shouldn't happen but…) we'd
    // silently un-mark. Only fire when it isn't already done.
    try {
      if (!widget.habit.isDoneOn(DateTime.now())) {
        await ref
            .read(habitEngineProvider)
            .toggleHabitCompletion(widget.habit.id);
        await DisciplineService.onOrderCompleted();
      }
    } catch (_) {}

    // Stop the nag: cancel every escalation ping still queued for this
    // habit, and drop the active-wake flag so cold-start doesn't route
    // straight back into the wake screen.
    try {
      await AlarmService.cancelWakeEscalations(widget.habit.id);
    } catch (_) {}
    // KILL THE SHARK. Reps are done, siren stops.
    try {
      await WakeSirenService.stop();
    } catch (_) {}
    await WakeDebtService.clearActive();

    // Hand off to the payoff screen — big MISSION COMPLETE + share card.
    // The user pushed through the sergeant; make them feel like a winner
    // and give them one tap to brag about it.
    if (!mounted) return;
    final set = _set;
    final ex = set?.exercises.isNotEmpty == true ? set!.exercises.first : null;
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => WakeCompleteScreen(
          habitTitle: widget.habit.title,
          reps: ex?.reps ?? 0,
          exerciseName: ex?.name ?? 'Reps',
          onClose: () {
            Navigator.of(context).popUntil((r) => r.isFirst);
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _videoController?.removeListener(_onVideoTick);
    _videoController?.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 380),
          child: _buildPhase(),
        ),
      ),
    );
  }

  Widget _buildPhase() {
    switch (_phase) {
      case _WakePhase.intro:
        return _buildIntro();
      case _WakePhase.setup:
        return _buildSetup();
      case _WakePhase.reps:
        return _buildReps();
    }
  }

  Widget _buildIntro() {
    if (!_videoReady || _videoController == null) {
      return const _Loading(key: ValueKey('intro_loading'));
    }
    return Container(
      key: const ValueKey('intro'),
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: AspectRatio(
              aspectRatio: _videoController!.value.aspectRatio,
              child: VideoPlayer(_videoController!),
            ),
          ),
          // Skip button — for QA / dev only. Tap the top-right corner.
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            right: 12,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                _videoController?.pause();
                _startSetup();
              },
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Text(
                  'SKIP',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.35),
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2.5,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSetup() {
    return Container(
      key: const ValueKey('setup'),
      color: Colors.black,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Center(
                child: Text(
                  'GET INTO POSITION',
                  style: TextStyle(
                    color: AppColors.emerald,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 4,
                  ),
                ),
              ).animate().fadeIn(),
              const SizedBox(height: 22),
              // Instruction 1 — big, unmissable.
              Text(
                'PHONE ON\nTHE FLOOR.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 42,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1,
                  height: 1.02,
                ),
              ).animate(delay: 100.ms).fadeIn().slideY(begin: 0.05, end: 0),
              const SizedBox(height: 16),
              Text(
                'STAND BACK.\nFULL BODY IN FRAME.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.85),
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                  height: 1.1,
                ),
              ).animate(delay: 300.ms).fadeIn().slideY(begin: 0.05, end: 0),
              const Spacer(),
              // Massive countdown number.
              Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 260),
                  transitionBuilder: (child, anim) => ScaleTransition(
                    scale: Tween(begin: 1.35, end: 1.0).animate(anim),
                    child: FadeTransition(opacity: anim, child: child),
                  ),
                  child: Text(
                    _countdown <= 0 ? 'GO' : '$_countdown',
                    key: ValueKey(_countdown),
                    style: TextStyle(
                      color: _countdown <= 1 ? AppColors.emerald : Colors.white,
                      fontSize: 168,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -8,
                      height: 1,
                      shadows: [
                        Shadow(
                          color: (_countdown <= 1 ? AppColors.emerald : Colors.white)
                              .withOpacity(0.35),
                          blurRadius: 32,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const Spacer(),
              Text(
                'MOVE.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.35),
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 6,
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReps() {
    final set = _set;
    if (set == null) return const _Loading(key: ValueKey('reps_loading'));
    return ExerciseCircuitScreen(
      key: const ValueKey('reps'),
      overrideSet: set,
      skipAdvice: true,
      ownsNavigation: true,
      onComplete: _onWakeComplete,
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
}
