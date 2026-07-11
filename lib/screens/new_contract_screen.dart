import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../design/tokens.dart';
import '../models/habit.dart';
import '../providers/habit_provider.dart';
import '../services/alarm_service.dart';
import '../services/analytics_service.dart';
import '../services/normal_reminder_registry.dart';
import '../widgets/wheel_time_picker.dart';
import 'contracts_screen.dart' show PresetParams;
import 'main_screen.dart' show MainNav;

class NewContractScreen extends ConsumerStatefulWidget {
  final Habit? edit;
  final PresetParams? preset;

  const NewContractScreen({super.key, this.edit, this.preset});

  @override
  ConsumerState<NewContractScreen> createState() => _NewContractScreenState();
}

class _NewContractScreenState extends ConsumerState<NewContractScreen> {
  final _titleController = TextEditingController();

  String _type = 'habit';
  // Default emoji resolved by type / preset — user-editable via
  // _pickEmoji() below (tap the emoji chip beside the title field).
  String _emoji = '🎯';
  int _durationDays = 30;
  _Frequency _frequency = _Frequency.daily;
  final List<bool> _customDays = List.filled(7, false);
  bool _timeEnabled = false;
  TimeOfDay _time = const TimeOfDay(hour: 9, minute: 0);
  bool _alarmOn = false;
  // Colour is derived, not picked: bad_habit → red, everything else →
  // emerald. Colour picker removed.
  Color get _color =>
      _type == 'bad_habit' ? AppColors.error : AppColors.emerald;
  bool _saving = false;

  bool get _isEdit => widget.edit != null;

  @override
  void initState() {
    super.initState();
    AnalyticsService.logScreenView(_isEdit ? 'edit_contract' : 'new_contract');
    if (_isEdit) {
      _prefillFromHabit(widget.edit!);
    } else if (widget.preset != null) {
      _prefillFromPreset(widget.preset!);
    }
  }

  void _prefillFromPreset(PresetParams p) {
    _titleController.text = p.title;
    _emoji = p.emoji;
    _type = p.type;
    _durationDays = p.targetDays;
    _frequency = _Frequency.daily;
  }

  void _prefillFromHabit(Habit h) {
    _titleController.text = h.title;
    _emoji = h.emoji ?? '🎯';
    _type = h.type;
    final total = h.endDate.difference(h.startDate).inDays;
    _durationDays = total > 0 ? total : 30;
    _timeEnabled = h.time.isNotEmpty;
    if (_timeEnabled) {
      final parts = h.time.split(':');
      _time = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    }
    _alarmOn = h.reminderOn;
    // Map repeatDays to frequency
    final rd = h.repeatDays;
    if (rd.length == 7) {
      _frequency = _Frequency.daily;
    } else if (_setEquals(rd, [1, 2, 3, 4, 5])) {
      _frequency = _Frequency.weekdays;
    } else if (_setEquals(rd, [0, 6])) {
      _frequency = _Frequency.weekends;
    } else {
      _frequency = _Frequency.custom;
      for (final d in rd) {
        if (d >= 0 && d < 7) _customDays[d] = true;
      }
    }
  }

  bool _setEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    final sa = a.toSet();
    final sb = b.toSet();
    return sa.difference(sb).isEmpty;
  }

  List<int> _repeatDaysFromFrequency() {
    switch (_frequency) {
      case _Frequency.daily:
        return [0, 1, 2, 3, 4, 5, 6];
      case _Frequency.weekdays:
        return [1, 2, 3, 4, 5];
      case _Frequency.weekends:
        return [0, 6];
      case _Frequency.custom:
        final out = <int>[];
        for (int i = 0; i < 7; i++) {
          if (_customDays[i]) out.add(i);
        }
        return out.isEmpty ? [0, 1, 2, 3, 4, 5, 6] : out;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _pickEmoji() async {
    HapticFeedback.selectionClick();
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        height: 340,
        decoration: const BoxDecoration(
          color: Color(0xFF0B0B0B),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: EmojiPicker(
          onEmojiSelected: (category, emoji) {
            setState(() => _emoji = emoji.emoji);
            Navigator.of(context).pop();
          },
          config: Config(
            height: 300,
            checkPlatformCompatibility: true,
            emojiViewConfig: const EmojiViewConfig(
              emojiSizeMax: 28,
              backgroundColor: Color(0xFF0B0B0B),
              columns: 7,
              buttonMode: ButtonMode.MATERIAL,
            ),
            skinToneConfig: const SkinToneConfig(),
            categoryViewConfig: const CategoryViewConfig(
              backgroundColor: Color(0xFF0B0B0B),
              iconColorSelected: AppColors.emerald,
              indicatorColor: AppColors.emerald,
            ),
            bottomActionBarConfig: const BottomActionBarConfig(
              backgroundColor: Color(0xFF0B0B0B),
              buttonColor: Color(0xFF161616),
              buttonIconColor: AppColors.emerald,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickTime() async {
    // Wheel picker — same UX as the wake-alarm flow. The Material
    // clock face was too easy to mis-tap; the iOS wheel is universally
    // familiar and hard to fumble at 6 a.m.
    final picked = await showWheelTimePicker(
      context,
      initial: _time,
      title: 'ALARM TIME',
    );
    if (picked != null) setState(() => _time = picked);
  }

  Future<void> _save() async {
    if (_saving) return;
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    HapticFeedback.mediumImpact();
    setState(() => _saving = true);

    // Emoji picker removed — use the preset/edit value, falling back
    // to a per-type default so the card never renders blank.
    final emoji = _emoji.isNotEmpty
        ? _emoji
        : (_type == 'bad_habit' ? '🚫' : '🎯');
    final timeStr = _timeEnabled
        ? '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}'
        : '';
    final reminderOn = _timeEnabled && _alarmOn && timeStr.isNotEmpty;
    final repeatDays = _repeatDaysFromFrequency();
    final startDate = _isEdit ? widget.edit!.startDate : DateTime.now();
    final endDate = startDate.add(Duration(days: _durationDays));

    Habit? saved;
    try {
      final engine = ref.read(habitEngineProvider);
      if (_isEdit) {
        final updated = widget.edit!.copyWith(
          title: title,
          type: _type,
          time: timeStr,
          startDate: startDate,
          endDate: endDate,
          repeatDays: repeatDays,
          reminderOn: reminderOn,
          colorValue: _color.value,
          emoji: emoji,
        );
        await engine.updateHabit(updated);
        saved = updated;
      } else {
        saved = await engine.createHabit(
          title: title,
          type: _type,
          time: timeStr,
          startDate: startDate,
          endDate: endDate,
          repeatDays: repeatDays,
          reminderOn: reminderOn,
          color: _color,
          emoji: emoji,
        );
      }
    } catch (e) {
      debugPrint('Contract save failed: $e');
      if (mounted) setState(() => _saving = false);
      return;
    }
    // Register the id as a NORMAL reminder (single ping, no wake
    // cascade) and schedule the alarm. AWAITED — a previous
    // fire-and-forget variant left alarms unscheduled when the pop
    // tore down the state before the background Future ran. That
    // was the "alarm we had is broken again" regression.
    if (saved != null && reminderOn && timeStr.isNotEmpty) {
      try {
        await NormalReminderRegistry.mark(saved.id);
        await AlarmService.scheduleAlarm(saved);
      } catch (e) {
        debugPrint('Contract reminder scheduling failed: $e');
      }
    } else if (saved != null) {
      try {
        await NormalReminderRegistry.unmark(saved.id);
      } catch (_) {}
    }
    // 1) Explicitly switch MainScreen to the Contracts tab BEFORE
    //    popping. Without this the user would land on whatever tab
    //    was last active (usually Today), matching the "stuck" bug
    //    they reported. MainNav is a global ValueNotifier that
    //    MainScreen listens to.
    // 2) popUntil(isFirst) then walks back past every pushed route
    //    (create screen, templates, wherever they came from) and
    //    drops them at the root — which is now the Contracts tab.
    if (mounted) {
      MainNav.goToContracts();
      Navigator.of(context).popUntil((r) => r.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canSave = _titleController.text.trim().isNotEmpty && !_saving;
    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(
              onClose: () => Navigator.of(context).pop(),
              isEdit: _isEdit,
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Hero(isEdit: _isEdit),
                    const SizedBox(height: 28),
                    _Section(
                      label: 'TITLE',
                      child: Row(
                        children: [
                          _EmojiChip(emoji: _emoji, onTap: _pickEmoji),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _TitleField(
                              // Placeholder shifts with type — hollowed-out
                              // example, never pre-typed. User fills their own.
                              titleController: _titleController,
                              hint: _type == 'bad_habit'
                                  ? 'e.g. Quit Vape'
                                  : 'e.g. Exercise',
                              onChanged: () => setState(() {}),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    _Section(
                      label: 'TYPE',
                      child: _TypeSelector(
                        current: _type,
                        onChanged: (t) => setState(() => _type = t),
                      ),
                    ),
                    const SizedBox(height: 22),
                    _Section(
                      label: 'DURATION',
                      child: _DurationSelector(
                        current: _durationDays,
                        onChanged: (v) => setState(() => _durationDays = v),
                      ),
                    ),
                    const SizedBox(height: 22),
                    _Section(
                      label: 'FREQUENCY',
                      child: _FrequencySelector(
                        current: _frequency,
                        customDays: _customDays,
                        onChanged: (f) => setState(() => _frequency = f),
                        onCustomToggle: (i) => setState(() => _customDays[i] = !_customDays[i]),
                      ),
                    ),
                    const SizedBox(height: 22),
                    _Section(
                      label: 'ALARM',
                      child: _TimeAndAlarm(
                        timeEnabled: _timeEnabled,
                        time: _time,
                        alarmOn: _alarmOn,
                        onToggleTime: (v) => setState(() {
                          _timeEnabled = v;
                          // Enabling a time defaults the alarm ON.
                          // Turning time off turns the alarm off too.
                          _alarmOn = v;
                        }),
                        onPickTime: _pickTime,
                        onToggleAlarm: (v) => setState(() => _alarmOn = v),
                      ),
                    ),
                    // Colour picker removed — colour is derived from the
                    // type: bad_habit → red, everything else → emerald.
                    // Users never asked for pastel personalisation and
                    // the picker was making the screen too tall.
                    if (_isEdit) ...[
                      const SizedBox(height: 28),
                      _DeleteButton(onTap: () => _confirmDelete(context)),
                    ],
                    const SizedBox(height: 28),
                  ],
                ),
              ),
            ),
            _SaveButton(
              enabled: canSave,
              saving: _saving,
              isEdit: _isEdit,
              onTap: _save,
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    HapticFeedback.mediumImpact();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF0B0B0B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: Colors.white.withOpacity(0.06)),
        ),
        title: const Text(
          'BREAK CONTRACT?',
          style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: 2),
        ),
        content: Text(
          'This will delete "${widget.edit!.title}" and cancel any alarms.',
          style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('CANCEL', style: TextStyle(color: Colors.white.withOpacity(0.5), fontWeight: FontWeight.w800, letterSpacing: 1.5)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('BREAK', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await ref.read(habitEngineProvider).deleteHabit(widget.edit!.id);
      if (mounted) Navigator.of(context).pop();
    }
  }
}

enum _Frequency { daily, weekdays, weekends, custom }

// ────────────────────────── Top bar + hero ──────────────────────────

class _TopBar extends StatelessWidget {
  final VoidCallback onClose;
  final bool isEdit;
  const _TopBar({required this.onClose, required this.isEdit});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            isEdit ? 'EDIT' : 'DRAFT',
            style: TextStyle(
              color: Colors.white.withOpacity(0.35),
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 3,
            ),
          ),
          IconButton(
            onPressed: onClose,
            icon: Icon(Icons.close, color: Colors.white.withOpacity(0.4), size: 22),
          ),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  final bool isEdit;
  const _Hero({required this.isEdit});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 6,
              height: 22,
              decoration: BoxDecoration(color: AppColors.emerald, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(width: 12),
            Text(
              isEdit ? 'EDIT CONTRACT' : 'YOUR CONTRACT',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w900,
                letterSpacing: 3,
                height: 1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.only(left: 18),
          child: Text(
            isEdit ? 'Change the terms of your word.' : 'Signing means it is your word.',
            style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }
}

// ────────────────────────── Section wrapper ──────────────────────────

class _Section extends StatelessWidget {
  final String label;
  final Widget child;
  const _Section({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label),
        const SizedBox(height: 10),
        child,
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          text,
          style: TextStyle(
            color: Colors.white.withOpacity(0.45),
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 4,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: Container(height: 1, color: Colors.white.withOpacity(0.06))),
      ],
    );
  }
}

// ────────────────────────── Emoji chip ──────────────────────────

class _EmojiChip extends StatelessWidget {
  final String emoji;
  final VoidCallback onTap;
  const _EmojiChip({required this.emoji, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: const Color(0xFF0B0B0B),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.06), width: 1),
        ),
        alignment: Alignment.center,
        child: Text(
          emoji,
          style: const TextStyle(fontSize: 26, height: 1),
        ),
      ),
    );
  }
}

// ────────────────────────── Title field ──────────────────────────

class _TitleField extends StatelessWidget {
  final TextEditingController titleController;
  final String hint;
  final VoidCallback onChanged;
  const _TitleField({
    required this.titleController,
    required this.hint,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF0B0B0B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.06), width: 1),
      ),
      alignment: Alignment.centerLeft,
      child: TextField(
        controller: titleController,
        onChanged: (_) => onChanged(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w700,
          letterSpacing: 1,
        ),
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: hint,
          hintStyle: TextStyle(
            color: Colors.white.withOpacity(0.2),
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

// ────────────────────────── Type selector ──────────────────────────

class _TypeSelector extends StatelessWidget {
  final String current;
  final ValueChanged<String> onChanged;
  const _TypeSelector({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    const types = [
      _TypeOption('habit', 'ORDER'),
      _TypeOption('bad_habit', 'RULE'),
    ];
    return Row(
      children: [
        for (int i = 0; i < types.length; i++)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: i < types.length - 1 ? 8 : 0),
              child: _selectorChip(
                label: types[i].label,
                selected: current == types[i].id,
                accent: types[i].id == 'bad_habit' ? AppColors.error : AppColors.emerald,
                onTap: () => onChanged(types[i].id),
              ),
            ),
          ),
      ],
    );
  }
}

class _TypeOption {
  final String id;
  final String label;
  const _TypeOption(this.id, this.label);
}

Widget _selectorChip({
  required String label,
  required bool selected,
  Color accent = AppColors.emerald,
  required VoidCallback onTap,
}) {
  return GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: selected ? accent.withOpacity(0.15) : const Color(0xFF0B0B0B),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: selected ? accent.withOpacity(0.5) : Colors.white.withOpacity(0.05),
          width: 1,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(
          color: selected ? accent : Colors.white.withOpacity(0.55),
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: 2,
        ),
      ),
    ),
  );
}

// ────────────────────────── Duration selector ──────────────────────────

class _DurationSelector extends StatelessWidget {
  final int current;
  final ValueChanged<int> onChanged;
  const _DurationSelector({required this.current, required this.onChanged});

  static const List<int> options = [7, 30, 60, 75, 90, 120, 365];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((n) {
        final selected = n == current;
        return GestureDetector(
          onTap: () => onChanged(n),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
            decoration: BoxDecoration(
              color: selected ? AppColors.emerald.withOpacity(0.15) : const Color(0xFF0B0B0B),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: selected ? AppColors.emerald.withOpacity(0.5) : Colors.white.withOpacity(0.05),
                width: 1,
              ),
            ),
            child: Text(
              '$n DAYS',
              style: TextStyle(
                color: selected ? AppColors.emerald : Colors.white.withOpacity(0.55),
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ────────────────────────── Frequency selector ──────────────────────────

class _FrequencySelector extends StatelessWidget {
  final _Frequency current;
  final List<bool> customDays;
  final ValueChanged<_Frequency> onChanged;
  final ValueChanged<int> onCustomToggle;

  const _FrequencySelector({
    required this.current,
    required this.customDays,
    required this.onChanged,
    required this.onCustomToggle,
  });

  @override
  Widget build(BuildContext context) {
    const labels = ['DAILY', 'WEEKDAYS', 'WEEKENDS', 'CUSTOM'];
    const vals = [_Frequency.daily, _Frequency.weekdays, _Frequency.weekends, _Frequency.custom];
    return Column(
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List.generate(labels.length, (i) {
            final selected = current == vals[i];
            return GestureDetector(
              onTap: () => onChanged(vals[i]),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                decoration: BoxDecoration(
                  color: selected ? AppColors.emerald.withOpacity(0.15) : const Color(0xFF0B0B0B),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: selected ? AppColors.emerald.withOpacity(0.5) : Colors.white.withOpacity(0.05),
                    width: 1,
                  ),
                ),
                child: Text(
                  labels[i],
                  style: TextStyle(
                    color: selected ? AppColors.emerald : Colors.white.withOpacity(0.55),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            );
          }),
        ),
        if (current == _Frequency.custom) ...[
          const SizedBox(height: 12),
          _CustomDaysRow(customDays: customDays, onToggle: onCustomToggle),
        ],
      ],
    );
  }
}

class _CustomDaysRow extends StatelessWidget {
  final List<bool> customDays;
  final ValueChanged<int> onToggle;
  const _CustomDaysRow({required this.customDays, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    // Model uses 0=Sun..6=Sat. Display order: Mon..Sun.
    const displayOrder = [1, 2, 3, 4, 5, 6, 0];
    const displayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return Row(
      children: List.generate(7, (i) {
        final idx = displayOrder[i];
        final on = customDays[idx];
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i < 6 ? 6 : 0),
            child: GestureDetector(
              onTap: () => onToggle(idx),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                height: 40,
                decoration: BoxDecoration(
                  color: on ? AppColors.emerald : const Color(0xFF0B0B0B),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: on ? AppColors.emerald : Colors.white.withOpacity(0.06),
                    width: 1,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  displayLabels[i],
                  style: TextStyle(
                    color: on ? Colors.black : Colors.white.withOpacity(0.55),
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

// ────────────────────────── Time + alarm ──────────────────────────

class _TimeAndAlarm extends StatelessWidget {
  final bool timeEnabled;
  final TimeOfDay time;
  final bool alarmOn;
  final ValueChanged<bool> onToggleTime;
  final VoidCallback onPickTime;
  final ValueChanged<bool> onToggleAlarm;

  const _TimeAndAlarm({
    required this.timeEnabled,
    required this.time,
    required this.alarmOn,
    required this.onToggleTime,
    required this.onPickTime,
    required this.onToggleAlarm,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _switchTile(
          label: 'AT A SPECIFIC TIME',
          value: timeEnabled,
          onChanged: onToggleTime,
        ),
        if (timeEnabled) ...[
          const SizedBox(height: 8),
          GestureDetector(
            onTap: onPickTime,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF0B0B0B),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withOpacity(0.06), width: 1),
              ),
              child: Row(
                children: [
                  Icon(Icons.access_time, color: AppColors.emerald.withOpacity(0.85), size: 16),
                  const SizedBox(width: 10),
                  Text(
                    time.format(context),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'CHANGE',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.35),
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          _switchTile(
            label: 'REMIND ME WITH AN ALARM',
            value: alarmOn,
            onChanged: onToggleAlarm,
          ),
        ],
      ],
    );
  }

  Widget _switchTile({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF0B0B0B),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withOpacity(0.06), width: 1),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.75),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                ),
              ),
            ),
            Switch.adaptive(
              value: value,
              onChanged: onChanged,
              activeColor: AppColors.emerald,
            ),
          ],
        ),
      ),
    );
  }
}

// (Color picker removed — colour derives from type.)

// ────────────────────────── Delete + save buttons ──────────────────────

class _DeleteButton extends StatelessWidget {
  final VoidCallback onTap;
  const _DeleteButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.error.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.error.withOpacity(0.4), width: 1),
        ),
        alignment: Alignment.center,
        child: Text(
          'BREAK CONTRACT',
          style: TextStyle(
            color: AppColors.error,
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 3,
          ),
        ),
      ),
    );
  }
}

class _SaveButton extends StatelessWidget {
  final bool enabled;
  final bool saving;
  final bool isEdit;
  final VoidCallback onTap;
  const _SaveButton({
    required this.enabled,
    required this.saving,
    required this.isEdit,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            gradient: enabled ? AppColors.emeraldGradient : null,
            color: enabled ? null : const Color(0xFF0B0B0B),
            borderRadius: BorderRadius.circular(14),
            border: enabled ? null : Border.all(color: Colors.white.withOpacity(0.05), width: 1),
            boxShadow: enabled
                ? [BoxShadow(color: AppColors.emerald.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 6))]
                : null,
          ),
          alignment: Alignment.center,
          child: saving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                )
              : Text(
                  isEdit ? 'UPDATE CONTRACT' : 'SIGN CONTRACT',
                  style: TextStyle(
                    color: enabled ? Colors.black : Colors.white.withOpacity(0.3),
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 3,
                  ),
                ),
        ),
      ),
    );
  }
}
