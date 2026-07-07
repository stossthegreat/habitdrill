import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/exercise_set.dart';
import '../../models/habit.dart';
import '../../providers/habit_provider.dart';
import '../../services/alarm_service.dart';
import '../../services/discipline_service.dart';
import '../../services/wake_debt_service.dart';
import '../../services/wake_mission_prefs.dart';
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
  ExerciseSet? _set;

  @override
  void initState() {
    super.initState();
    _buildSet();
  }

  /// Build the ExerciseSet by combining the user's chosen mission (from
  /// WakeMissionPrefs) with the pledged rep count, plus escalating debt
  /// reps accumulated while they stalled. Fallback: squats.
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
    // While the mission is loading from SharedPreferences (single frame),
    // show a black holding screen so we don't flash a broken ExerciseSet.
    final set = _set;
    if (set == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }
    return ExerciseCircuitScreen(
      overrideSet: set,
      onComplete: _onWakeComplete,
    );
  }
}
