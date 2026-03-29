import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../design/tokens.dart';
import '../../models/violation.dart';
import '../../models/exercise_set.dart';
import '../../services/sergeant_service.dart';

class ExerciseCircuitScreen extends StatefulWidget {
  final Violation violation;
  final VoidCallback onComplete;

  const ExerciseCircuitScreen({
    super.key,
    required this.violation,
    required this.onComplete,
  });

  @override
  State<ExerciseCircuitScreen> createState() => _ExerciseCircuitScreenState();
}

class _ExerciseCircuitScreenState extends State<ExerciseCircuitScreen> {
  late ExerciseSet _exerciseSet;
  bool _showComplete = false;

  @override
  void initState() {
    super.initState();
    _exerciseSet = SergeantService.getExerciseSet(widget.violation);
  }

  void _toggleExercise(int index) {
    setState(() {
      _exerciseSet.exercises[index].completed =
          !_exerciseSet.exercises[index].completed;
    });
  }

  void _completeCircuit() {
    setState(() => _showComplete = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) widget.onComplete();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_showComplete) return _buildDismissed();

    final allDone = _exerciseSet.allCompleted;

    return Container(
      key: const ValueKey('exercises'),
      color: Colors.black,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.lg),

              // Header
              Text(
                'EXERCISE CIRCUIT',
                style: TextStyle(
                  color: Colors.red.withOpacity(0.9),
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 3,
                ),
                textAlign: TextAlign.center,
              ).animate().fadeIn(),

              const SizedBox(height: AppSpacing.sm),

              Text(
                'Offense #${widget.violation.offenseNumber} — ${_exerciseSet.offenseNumber}x multiplier',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.4),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: AppSpacing.xl),

              // Exercise list
              Expanded(
                child: ListView.builder(
                  itemCount: _exerciseSet.exercises.length,
                  itemBuilder: (context, index) {
                    final exercise = _exerciseSet.exercises[index];
                    return _buildExerciseCard(exercise, index);
                  },
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              // Complete button
              AnimatedOpacity(
                opacity: allDone ? 1.0 : 0.3,
                duration: const Duration(milliseconds: 300),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: allDone
                        ? AppColors.emeraldGradient
                        : const LinearGradient(colors: [Colors.grey, Colors.grey]),
                    borderRadius: BorderRadius.circular(AppBorderRadius.lg),
                    boxShadow: allDone
                        ? [BoxShadow(
                            color: AppColors.emerald.withOpacity(0.4),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          )]
                        : [],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: allDone ? _completeCircuit : null,
                      borderRadius: BorderRadius.circular(AppBorderRadius.lg),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                        child: Text(
                          allDone ? 'CIRCUIT COMPLETE' : 'COMPLETE ALL EXERCISES',
                          style: TextStyle(
                            color: allDone ? Colors.black : Colors.white38,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.5,
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
    );
  }

  Widget _buildExerciseCard(Exercise exercise, int index) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: GestureDetector(
        onTap: () => _toggleExercise(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: exercise.completed
                ? AppColors.emerald.withOpacity(0.1)
                : Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(AppBorderRadius.xl),
            border: Border.all(
              color: exercise.completed
                  ? AppColors.emerald.withOpacity(0.5)
                  : Colors.red.withOpacity(0.2),
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              // Emoji
              Text(
                exercise.emoji,
                style: const TextStyle(fontSize: 36),
              ),
              const SizedBox(width: AppSpacing.md),
              // Name + reps
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      exercise.name,
                      style: TextStyle(
                        color: exercise.completed
                            ? AppColors.emerald
                            : Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${exercise.reps} reps',
                      style: TextStyle(
                        color: exercise.completed
                            ? AppColors.emerald.withOpacity(0.7)
                            : Colors.red.withOpacity(0.8),
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              // Checkbox
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: exercise.completed
                      ? AppColors.emerald
                      : Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: exercise.completed
                        ? AppColors.emerald
                        : Colors.white.withOpacity(0.3),
                    width: 2,
                  ),
                ),
                child: exercise.completed
                    ? const Icon(Icons.check, color: Colors.black, size: 24)
                    : null,
              ),
            ],
          ),
        ),
      ),
    ).animate(delay: (index * 100).ms)
        .fadeIn(duration: 300.ms)
        .slideX(begin: 0.1, end: 0);
  }

  Widget _buildDismissed() {
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.check_circle_outline,
              size: 80,
              color: AppColors.emerald,
            ).animate().scale(
              begin: const Offset(0.5, 0.5),
              end: const Offset(1, 1),
              duration: 400.ms,
            ),
            const SizedBox(height: AppSpacing.xl),
            const Text(
              'DISMISSED.',
              style: TextStyle(
                color: AppColors.emerald,
                fontSize: 28,
                fontWeight: FontWeight.w900,
                letterSpacing: 3,
              ),
            ).animate(delay: 200.ms).fadeIn(),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Don\'t let it happen again.',
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ).animate(delay: 500.ms).fadeIn(),
          ],
        ),
      ),
    );
  }
}
