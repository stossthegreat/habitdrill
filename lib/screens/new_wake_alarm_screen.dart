import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../design/tokens.dart';
import '../models/habit.dart';
import '../providers/habit_provider.dart';
import '../services/analytics_service.dart';
import '../services/wake_mission_prefs.dart';
import '../widgets/wheel_time_picker.dart';

/// New (or edit) Wake Alarm — the standalone morning-punishment builder.
/// Structure mirrors the reference screenshot: name → time → days →
/// mission → sound → save. Dark military skin, not Erly's off-white.
///
/// A wake alarm is stored as a Habit with `type='habit'`, `reminderOn=true`,
/// and a non-empty `time`. That's what our existing alarm scheduling +
/// wake-flow logic already keys off. The mission choice (squats/push-ups/…)
/// lives in SharedPreferences via WakeMissionPrefs, keyed by habit.id.
class NewWakeAlarmScreen extends ConsumerStatefulWidget {
  final Habit? edit;
  const NewWakeAlarmScreen({super.key, this.edit});

  @override
  ConsumerState<NewWakeAlarmScreen> createState() =>
      _NewWakeAlarmScreenState();
}

class _NewWakeAlarmScreenState extends ConsumerState<NewWakeAlarmScreen> {
  final _nameController = TextEditingController(text: 'Morning Rise');

  bool _scheduled = true;
  TimeOfDay _time = const TimeOfDay(hour: 7, minute: 0);
  final List<bool> _days = List.filled(7, true); // default: every day
  Mission _mission = WakeMissionPrefs.missions.first;
  int _reps = WakeMissionPrefs.defaultReps;
  bool _saving = false;

  bool get _isEdit => widget.edit != null;

  @override
  void initState() {
    super.initState();
    AnalyticsService.logScreenView(
      _isEdit ? 'edit_wake_alarm' : 'new_wake_alarm',
    );
    if (_isEdit) _prefill();
  }

  Future<void> _prefill() async {
    final h = widget.edit!;
    _nameController.text = h.title;
    if (h.time.isNotEmpty) {
      final parts = h.time.split(':');
      _time = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    }
    for (int i = 0; i < 7; i++) {
      _days[i] = h.repeatDays.contains(i);
    }
    _mission = await WakeMissionPrefs.getMission(h.id);
    _reps = await WakeMissionPrefs.getReps(h.id);
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    HapticFeedback.selectionClick();
    final picked = await showWheelTimePicker(
      context,
      initial: _time,
      title: 'WAKE TIME',
    );
    if (picked != null) setState(() => _time = picked);
  }

  Future<void> _pickMission() async {
    HapticFeedback.selectionClick();
    final result = await showModalBottomSheet<_MissionResult>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _MissionPicker(mission: _mission, reps: _reps),
    );
    if (result != null) {
      setState(() {
        _mission = result.mission;
        _reps = result.reps;
      });
    }
  }

  bool get _canSave =>
      _nameController.text.trim().isNotEmpty && _days.any((d) => d);

  Future<void> _save() async {
    if (_saving || !_canSave) return;
    _saving = true;
    HapticFeedback.mediumImpact();

    final timeStr =
        '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}';
    final repeatDays = <int>[
      for (int i = 0; i < 7; i++)
        if (_days[i]) i,
    ];
    // One-time alarm → only today's weekday.
    final actualRepeatDays = _scheduled
        ? repeatDays
        : <int>[DateTime.now().weekday % 7];

    final engine = ref.read(habitEngineProvider);
    final Habit saved;
    if (_isEdit) {
      final h = widget.edit!;
      saved = h.copyWith(
        title: _nameController.text.trim(),
        type: 'habit',
        time: timeStr,
        repeatDays: actualRepeatDays,
        reminderOn: true,
      );
      await engine.updateHabit(saved);
    } else {
      final now = DateTime.now();
      saved = Habit(
        id: now.millisecondsSinceEpoch.toString(),
        title: _nameController.text.trim(),
        type: 'habit',
        time: timeStr,
        startDate: now,
        endDate: now.add(const Duration(days: 365 * 5)),
        repeatDays: actualRepeatDays,
        createdAt: now,
        emoji: '⏰', // alarm clock — the wake alarm marker
        reminderOn: true,
      );
      await engine.addHabit(saved);
    }

    await WakeMissionPrefs.setMission(
      saved.id,
      missionId: _mission.id,
      reps: _reps,
    );

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(
              onCancel: () => Navigator.of(context).pop(),
              title: _isEdit ? 'EDIT ALARM' : 'NEW ALARM',
            ),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    // Scheduled is the only mode — one-time was noise.
                    // _ModeToggle removed.
                    _NameField(controller: _nameController, onChanged: (_) => setState(() {})),
                    const SizedBox(height: 12),
                    _RowCard(
                      leading: Icons.access_time_rounded,
                      label: 'Alarm Time',
                      value: _time.format(context),
                      onTap: _pickTime,
                    ),
                    const SizedBox(height: 12),
                    ...[
                      _DaysCard(
                        days: _days,
                        onToggle: (i) => setState(() => _days[i] = !_days[i]),
                      ),
                    ],
                    const SizedBox(height: 12),
                    _MissionCard(
                      mission: _mission,
                      reps: _reps,
                      onTap: _pickMission,
                    ),
                    const SizedBox(height: 12),
                    _RowCard(
                      leading: Icons.volume_up_rounded,
                      label: 'Alarm Sound',
                      value: 'Sergeant · Loud',
                      onTap: null,
                      trailing: Icon(
                        LucideIcons.chevronRight,
                        color: Colors.white.withOpacity(0.2),
                        size: 16,
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                8,
                20,
                MediaQuery.of(context).padding.bottom + 20,
              ),
              child: _SaveButton(
                enabled: _canSave,
                onTap: _save,
                label: _isEdit ? 'SAVE ALARM' : 'ARM ALARM',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ────────────────────────── Top bar ──────────────────────────

class _TopBar extends StatelessWidget {
  final VoidCallback onCancel;
  final String title;
  const _TopBar({required this.onCancel, required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Row(
        children: [
          TextButton(
            onPressed: onCancel,
            style: TextButton.styleFrom(
              foregroundColor: Colors.white.withOpacity(0.7),
            ),
            child: const Text(
              'Cancel',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w900,
                letterSpacing: 3,
              ),
            ),
          ),
          const SizedBox(width: 76),
        ],
      ),
    );
  }
}

// ────────────────────────── Scheduled / One time toggle ─────────────

class _ModeToggle extends StatelessWidget {
  final bool scheduled;
  final ValueChanged<bool> onChange;
  const _ModeToggle({required this.scheduled, required this.onChange});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: const Color(0xFF0B0B0B),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.05), width: 1),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ToggleHalf(
              label: 'Scheduled',
              active: scheduled,
              onTap: () => onChange(true),
            ),
          ),
          Expanded(
            child: _ToggleHalf(
              label: 'One time',
              active: !scheduled,
              onTap: () => onChange(false),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToggleHalf extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _ToggleHalf({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.black : Colors.white.withOpacity(0.55),
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

// ────────────────────────── Name field ──────────────────────────

class _NameField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  const _NameField({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0B0B0B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.05), width: 1),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
        cursorColor: AppColors.emerald,
        decoration: InputDecoration(
          hintText: 'Alarm name',
          hintStyle: TextStyle(
            color: Colors.white.withOpacity(0.3),
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          border: InputBorder.none,
        ),
      ),
    );
  }
}

// ────────────────────────── Row card (time / sound) ─────────────────

class _RowCard extends StatelessWidget {
  final IconData? leading;
  final String label;
  final String value;
  final VoidCallback? onTap;
  final Widget? trailing;
  const _RowCard({
    this.leading,
    required this.label,
    required this.value,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0B0B0B),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.05), width: 1),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        child: Row(
          children: [
            if (leading != null) ...[
              Icon(leading, color: Colors.white.withOpacity(0.55), size: 20),
              const SizedBox(width: 14),
            ],
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            Text(
              value,
              style: TextStyle(
                color: Colors.white.withOpacity(0.55),
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 8),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }
}

// ────────────────────────── Days circles ───────────────────────────

class _DaysCard extends StatelessWidget {
  final List<bool> days;
  final ValueChanged<int> onToggle;
  const _DaysCard({required this.days, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    const labels = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0B0B0B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.05), width: 1),
      ),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'On these days',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (int i = 0; i < 7; i++)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onToggle(i);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: days[i] ? AppColors.emerald : Colors.transparent,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: days[i]
                            ? AppColors.emerald
                            : Colors.white.withOpacity(0.2),
                        width: 1.5,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      labels[i],
                      style: TextStyle(
                        color: days[i] ? Colors.black : Colors.white.withOpacity(0.55),
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ────────────────────────── Mission card ───────────────────────────

class _MissionCard extends StatelessWidget {
  final Mission mission;
  final int reps;
  final VoidCallback onTap;
  const _MissionCard({
    required this.mission,
    required this.reps,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0B0B0B),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.05), width: 1),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.emerald.withOpacity(0.12),
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.emerald.withOpacity(0.35)),
              ),
              alignment: Alignment.center,
              child: const Icon(
                LucideIcons.target,
                color: AppColors.emerald,
                size: 18,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Mission',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '$reps ${mission.name}',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.55),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              LucideIcons.chevronRight,
              color: Colors.white.withOpacity(0.35),
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}

// ────────────────────────── Mission picker sheet ────────────────────

class _MissionResult {
  final Mission mission;
  final int reps;
  const _MissionResult(this.mission, this.reps);
}

class _MissionPicker extends StatefulWidget {
  final Mission mission;
  final int reps;
  const _MissionPicker({required this.mission, required this.reps});

  @override
  State<_MissionPicker> createState() => _MissionPickerState();
}

class _MissionPickerState extends State<_MissionPicker> {
  late Mission _mission = widget.mission;
  late int _reps = widget.reps;

  static const List<int> _repOptions = [10, 15, 20, 25, 30, 40, 50];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0B0B0B),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'PICK YOUR MISSION',
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w900,
              letterSpacing: 3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'You choose the punishment. Then live with it.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.4),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 20),
          for (final m in WakeMissionPrefs.missions)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: _MissionRow(
                mission: m,
                selected: m.id == _mission.id,
                onTap: () => setState(() => _mission = m),
              ),
            ),
          const SizedBox(height: 22),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'REPS',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.4),
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final r in _repOptions)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: GestureDetector(
                              onTap: () => setState(() => _reps = r),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: _reps == r
                                      ? AppColors.emerald
                                      : Colors.white.withOpacity(0.06),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  '$r',
                                  style: TextStyle(
                                    color: _reps == r
                                        ? Colors.black
                                        : Colors.white.withOpacity(0.7),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _SaveButton(
              enabled: true,
              onTap: () => Navigator.of(context).pop(_MissionResult(_mission, _reps)),
              label: 'LOCK IT IN',
            ),
          ),
        ],
      ),
    );
  }
}

class _MissionRow extends StatelessWidget {
  final Mission mission;
  final bool selected;
  final VoidCallback onTap;
  const _MissionRow({
    required this.mission,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.emerald.withOpacity(0.08)
              : Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? AppColors.emerald.withOpacity(0.5)
                : Colors.white.withOpacity(0.05),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Text(mission.emoji, style: const TextStyle(fontSize: 22, height: 1)),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                mission.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle, color: AppColors.emerald, size: 22),
          ],
        ),
      ),
    );
  }
}

// ────────────────────────── Save button ────────────────────────────

class _SaveButton extends StatelessWidget {
  final bool enabled;
  final VoidCallback onTap;
  final String label;
  const _SaveButton({
    required this.enabled,
    required this.onTap,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: enabled ? Colors.white : Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(999),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: Colors.white.withOpacity(0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: enabled ? Colors.black : Colors.white.withOpacity(0.35),
            fontSize: 14,
            fontWeight: FontWeight.w900,
            letterSpacing: 3,
          ),
        ),
      ),
    );
  }
}
