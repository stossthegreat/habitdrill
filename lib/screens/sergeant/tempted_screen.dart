import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:video_player/video_player.dart';
import '../../design/tokens.dart';
import '../../models/exercise_set.dart';
import '../../models/escalation_config.dart';
import '../../models/violation.dart';
import 'exercise_circuit_screen.dart';
import '../../services/analytics_service.dart';

/// When user feels tempted to break a bad habit, they can proactively
/// do a workout to fight the urge. This is the POSITIVE path.
class TemptedScreen extends StatefulWidget {
  final String? habitTitle;

  const TemptedScreen({super.key, this.habitTitle});

  @override
  State<TemptedScreen> createState() => _TemptedScreenState();
}

enum _TemptedPhase { video, exercises, complete }

class _TemptedScreenState extends State<TemptedScreen> {
  late List<Exercise> _exercises;
  _TemptedPhase _phase = _TemptedPhase.video;
  VideoPlayerController? _videoController;
  bool _videoReady = false;

  @override
  void initState() {
    super.initState();
    AnalyticsService.logScreenView('tempted');
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _exercises = ExerciseSet.tempted().exercises;
    _initVideo();
  }

  @override
  void dispose() {
    _videoController?.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  Future<void> _initVideo() async {
    try {
      _videoController = VideoPlayerController.asset(EscalationConfig.temptedVideo);
      await _videoController!.initialize();
      _videoController!.addListener(_onVideoEnd);
      if (mounted) {
        setState(() => _videoReady = true);
        _videoController!.play();
      }
    } catch (e) {
      debugPrint('Tempted video not available: $e');
      if (mounted) _launchWorkout();
    }
  }

  void _onVideoEnd() {
    if (_videoController != null &&
        _videoController!.value.isInitialized &&
        _videoController!.value.position >= _videoController!.value.duration &&
        _videoController!.value.duration > Duration.zero) {
      _videoController!.removeListener(_onVideoEnd);
      if (mounted) _launchWorkout();
    }
  }

  void _launchWorkout() {
    // Create a tempted violation (20 burpees only)
    final dummyViolation = Violation(
      id: 'tempted_${DateTime.now().millisecondsSinceEpoch}',
      habitId: 'tempted',
      habitTitle: widget.habitTitle ?? 'Temptation',
      violationType: 'tempted',
      occurredAt: DateTime.now(),
      scheduledFor: DateTime.now(),
      offenseNumber: 0,
      escalationLevel: 0,
    );

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ExerciseCircuitScreen(
          violation: dummyViolation,
          onComplete: () {
            Navigator.of(context).pop();
          },
        ),
      ),
    );
  }

  void _toggleExercise(int index) {
    setState(() {
      _exercises[index].completed = !_exercises[index].completed;
    });
  }

  void _complete() {
    setState(() => _phase = _TemptedPhase.complete);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_phase == _TemptedPhase.complete) return _buildSuccess();
    if (_phase == _TemptedPhase.video) return _buildVideoPhase();

    final allDone = _exercises.every((e) => e.completed);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.orange.withOpacity(0.08),
              Colors.black,
              Colors.black,
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Close button
                Align(
                  alignment: Alignment.topLeft,
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close, color: Colors.white54, size: 20),
                    ),
                  ),
                ),

                const SizedBox(height: AppSpacing.lg),

                // Header
                const Icon(Icons.local_fire_department, size: 48, color: Colors.orange)
                    .animate().fadeIn().shake(delay: 300.ms),

                const SizedBox(height: AppSpacing.md),

                const Text(
                  'URGE DETECTED',
                  style: TextStyle(
                    color: Colors.orange,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 3,
                  ),
                  textAlign: TextAlign.center,
                ).animate(delay: 200.ms).fadeIn(),

                const SizedBox(height: AppSpacing.sm),

                if (widget.habitTitle != null)
                  Text(
                    '"${widget.habitTitle}"',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 16,
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
                  ).animate(delay: 400.ms).fadeIn(),

                const SizedBox(height: AppSpacing.sm),

                Text(
                  'Kill it with work.',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.3),
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ).animate(delay: 500.ms).fadeIn(),

                const SizedBox(height: AppSpacing.xl),

                // Exercise list
                Expanded(
                  child: ListView.builder(
                    itemCount: _exercises.length,
                    itemBuilder: (context, index) {
                      final ex = _exercises[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: GestureDetector(
                          onTap: () => _toggleExercise(index),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            padding: const EdgeInsets.all(AppSpacing.lg),
                            decoration: BoxDecoration(
                              color: ex.completed
                                  ? AppColors.emerald.withOpacity(0.1)
                                  : Colors.white.withOpacity(0.04),
                              borderRadius: BorderRadius.circular(AppBorderRadius.xl),
                              border: Border.all(
                                color: ex.completed
                                    ? AppColors.emerald.withOpacity(0.5)
                                    : Colors.orange.withOpacity(0.15),
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              children: [
                                Text(ex.emoji, style: const TextStyle(fontSize: 32)),
                                const SizedBox(width: AppSpacing.md),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        ex.name,
                                        style: TextStyle(
                                          color: ex.completed ? AppColors.emerald : Colors.white,
                                          fontSize: 17,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      Text(
                                        '${ex.reps} reps',
                                        style: TextStyle(
                                          color: ex.completed
                                              ? AppColors.emerald.withOpacity(0.7)
                                              : Colors.orange.withOpacity(0.8),
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: ex.completed ? AppColors.emerald : Colors.transparent,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: ex.completed ? AppColors.emerald : Colors.white24,
                                      width: 2,
                                    ),
                                  ),
                                  child: ex.completed
                                      ? const Icon(Icons.check, color: Colors.black, size: 20)
                                      : null,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ).animate(delay: (600 + index * 100).ms)
                          .fadeIn(duration: 300.ms)
                          .slideX(begin: 0.08, end: 0);
                    },
                  ),
                ),

                const SizedBox(height: AppSpacing.md),

                // Done button
                AnimatedOpacity(
                  opacity: allDone ? 1.0 : 0.3,
                  duration: const Duration(milliseconds: 300),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: allDone
                          ? AppColors.emeraldGradient
                          : const LinearGradient(colors: [Colors.grey, Colors.grey]),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: allDone ? _complete : null,
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Text(
                            allDone ? 'URGE DEFEATED' : 'COMPLETE ALL EXERCISES',
                            style: TextStyle(
                              color: allDone ? Colors.black : Colors.white38,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: AppSpacing.lg),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVideoPhase() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _videoReady && _videoController != null
          ? Center(
              child: AspectRatio(
                aspectRatio: _videoController!.value.aspectRatio,
                child: VideoPlayer(_videoController!),
              ),
            )
          : const Center(child: CircularProgressIndicator(color: Colors.orange)),
    );
  }

  Widget _buildSuccess() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.shield, size: 80, color: AppColors.emerald)
                .animate().scale(
                  begin: const Offset(0.5, 0.5),
                  end: const Offset(1, 1),
                  duration: 400.ms,
                ),
            const SizedBox(height: AppSpacing.xl),
            const Text(
              'URGE KILLED.',
              style: TextStyle(
                color: AppColors.emerald,
                fontSize: 28,
                fontWeight: FontWeight.w900,
                letterSpacing: 3,
              ),
            ).animate(delay: 200.ms).fadeIn(),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Controlled.',
              style: TextStyle(
                color: Colors.white.withOpacity(0.4),
                fontSize: 15,
              ),
              textAlign: TextAlign.center,
            ).animate(delay: 500.ms).fadeIn(),
          ],
        ),
      ),
    );
  }
}
