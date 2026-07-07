import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/exercise_set.dart';
import '../../models/habit.dart';
import '../../providers/habit_provider.dart';
import '../../services/alarm_service.dart';
import '../../services/discipline_service.dart';
import '../../services/wake_debt_service.dart';
import 'exercise_circuit_screen.dart';

/// Wake-alarm exercise flow. Wraps ExerciseCircuitScreen with a squats-only
/// drill sized by the current wake debt (see [WakeDebtService.totalRepsFor]).
///
/// On completion: marks the habit done for today, clears the wake debt,
/// cancels any escalating sergeant pings, and pops to root.
class WakeExerciseScreen extends ConsumerStatefulWidget {
  final Habit habit;
  const WakeExerciseScreen({super.key, required this.habit});

  @override
  ConsumerState<WakeExerciseScreen> createState() => _WakeExerciseScreenState();
}

class _WakeExerciseScreenState extends ConsumerState<WakeExerciseScreen> {
  late final ExerciseSet _set;

  @override
  void initState() {
    super.initState();
    final reps = WakeDebtService.totalRepsFor(widget.habit);
    _set = ExerciseSet(
      exercises: [
        Exercise(
          name: 'Squats',
          engineId: 'squats',
          emoji: '\u{1F9CE}',
          reps: reps,
        ),
      ],
      escalationLevel: 0,
      offenseNumber: 0,
    );
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
    await WakeDebtService.clearActive();
  }

  @override
  Widget build(BuildContext context) {
    return ExerciseCircuitScreen(
      overrideSet: _set,
      onComplete: _onWakeComplete,
    );
  }
}
