import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:intl/intl.dart';
import '../design/tokens.dart';
import '../widgets/glass_card.dart';
import '../widgets/glass_button.dart';
import '../widgets/date_strip.dart';
import '../widgets/system_card.dart';
import '../providers/habit_provider.dart';
import '../models/habit.dart';
import '../models/habit_system.dart';
import '../services/local_storage.dart';
import '../services/analytics_service.dart';

class PlannerScreen extends ConsumerStatefulWidget {
  const PlannerScreen({super.key});

  @override
  ConsumerState<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends ConsumerState<PlannerScreen>
    with SingleTickerProviderStateMixin {
  bool _isInitialized = false;
  DateTime _selectedDate = DateTime.now();
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();
  String _selectedType = 'habit';
  String _frequency = 'daily';
  int _everyNDays = 2;

  final _titleController = TextEditingController();
  final _timeController = TextEditingController(text: '07:00');
  final _formKey = GlobalKey<FormState>();
  late TabController _tabController;

  Color _selectedColor = AppColors.emerald;
  String? _selectedEmoji;
  bool _reminderOn = false;
  bool _timeEnabled = false;
  final List<bool> _repeatDays = List.generate(7, (index) => false);
  final List<String> _dayNames = ['Sun','Mon','Tue','Wed','Thu','Fri','Sat'];

  @override
  void initState() {
    super.initState();
    AnalyticsService.logScreenView('planner');
    _initializeScreen();
    // 2 tabs: Add New + Manage (start on Manage)
    _tabController = TabController(length: 2, vsync: this, initialIndex: 1);
    _onTypeChanged(_selectedType);
  }

  Future<void> _initializeScreen() async {
    try {
      await ref.read(habitEngineProvider).loadHabits();
      if (mounted) {
        setState(() => _isInitialized = true);
      }
    } catch (e) {
      debugPrint('Error initializing planner: $e');
      if (mounted) {
        setState(() => _isInitialized = true);
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _timeController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _onDateSelected(DateTime d) => setState(() => _selectedDate = d);

  void _onTypeChanged(String type) {
    setState(() {
      _selectedType = type;
      for (int i = 0; i < 7; i++) {
        if (type == 'habit' || type == 'bad_habit') {
          _repeatDays[i] = i >= 1 && i <= 5; // Weekdays default
        } else {
          _repeatDays[i] = i == DateTime.now().weekday % 7;
        }
      }
      // Bad habits default to red color
      if (type == 'bad_habit') {
        _selectedColor = AppColors.error;
      }
    });
  }

  void _toggleRepeatDay(int i) => setState(() => _repeatDays[i] = !_repeatDays[i]);

  Future<void> _selectStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked;
        if (_endDate.isBefore(_startDate)) {
          _endDate = _startDate.add(const Duration(days: 30));
        }
      });
    }
  }

  Future<void> _selectEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: _startDate,
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (picked != null) setState(() => _endDate = picked);
  }

  Future<void> _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
            primary: AppColors.emerald,
            onSurface: AppColors.textPrimary,
          ),
          timePickerTheme: const TimePickerThemeData(
            backgroundColor: AppColors.baseDark2,
            dialBackgroundColor: AppColors.baseDark3,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _timeController.text =
            '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      });
    }
  }

  Future<void> _pickEmoji() async {
    await showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        height: 300,
        decoration: const BoxDecoration(
          color: AppColors.baseDark2,
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppBorderRadius.xl)),
        ),
        child: EmojiPicker(
          onEmojiSelected: (category, emoji) {
            setState(() {
              _selectedEmoji = emoji.emoji;
            });
            Navigator.pop(context);
          },
          config: Config(
            height: 256,
            checkPlatformCompatibility: true,
            emojiViewConfig: EmojiViewConfig(
              emojiSizeMax: 28,
              backgroundColor: AppColors.baseDark2,
              columns: 7,
              buttonMode: ButtonMode.MATERIAL,
            ),
            skinToneConfig: const SkinToneConfig(),
            categoryViewConfig: const CategoryViewConfig(
              backgroundColor: AppColors.baseDark2,
              iconColorSelected: AppColors.emerald,
              indicatorColor: AppColors.emerald,
            ),
            bottomActionBarConfig: const BottomActionBarConfig(
              backgroundColor: AppColors.baseDark2,
              buttonColor: AppColors.baseDark3,
              buttonIconColor: AppColors.emerald,
            ),
          ),
        ),
      ),
    );
  }

  List<int> _getRepeatDays() {
    switch (_frequency) {
      case 'daily': return [0,1,2,3,4,5,6];
      case 'weekdays': return [1,2,3,4,5];
      case 'weekends': return [0,6];
      case 'custom': return [
        for (int i=0;i<_repeatDays.length;i++) if(_repeatDays[i]) i
      ];
      default: return [1,2,3,4,5];
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    try {
      await ref.read(habitEngineProvider).createHabit(
        title: _titleController.text.trim(),
        type: _selectedType,
        time: _timeEnabled ? _timeController.text : '',
        startDate: DateTime.now(),
        endDate: _endDate,
        repeatDays: _getRepeatDays(),
        color: _selectedColor,
        emoji: _selectedEmoji,
        reminderOn: _reminderOn,
      );

      _titleController.clear();
      _timeController.text = '07:00';
      setState(() {
        _frequency = 'daily';
        _selectedColor = AppColors.emerald;
        _selectedEmoji = null;
        _reminderOn = false;
        _timeEnabled = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children:[
          const Icon(LucideIcons.check,color:Colors.white,size:16),
          const SizedBox(width:8),
          Text('${_selectedType.capitalize()} created successfully!')
        ]),
        backgroundColor: AppColors.success,
      ));

      setState(() => _selectedDate = DateTime.now());
      _tabController.animateTo(1);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error: $e'),
        backgroundColor: AppColors.error,
      ));
    }
  }

  void _updateFrequency(String newFrequency) {
    setState(() {
      _frequency = newFrequency;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                color: const Color(0xFFFF6B35),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Loading...',
                style: AppTextStyles.body.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(LucideIcons.x, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFFFF6B35), Color(0xFFFF8C42)],
          ).createShader(bounds),
          child: const Text(
            'Planner',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: Stack(
        children: [
          NestedScrollView(
            headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
              return [
                // Date strip
                SliverToBoxAdapter(
                  child: DateStrip(
                    selectedDate: _selectedDate,
                    onDateSelected: _onDateSelected,
                    accentColor: const Color(0xFFFF6B35),
                  ),
                ),
                SliverToBoxAdapter(
                  child: const SizedBox(height: AppSpacing.md),
                ),

                // Tab bar (2 tabs: Add New + Manage)
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                    decoration: BoxDecoration(
                      color: AppColors.glassBackground,
                      borderRadius: BorderRadius.circular(AppBorderRadius.lg),
                      border: Border.all(color: AppColors.glassBorder),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      tabs: const [Tab(text:'NEW ORDER'),Tab(text:'ACTIVE')],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: const SizedBox(height: AppSpacing.lg),
                ),
              ];
            },
            body: TabBarView(
              controller: _tabController,
              children: [_buildAddNewTab(), _buildManageTab()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddNewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: const Color(0xFF0A0A0A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.emerald.withOpacity(0.12)),
        ),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _typeSelector(),
              const SizedBox(height: AppSpacing.lg),
              _textField('Title', _titleController,
                  icon: _selectedType == 'habit'
                      ? LucideIcons.flame
                      : LucideIcons.alarmCheck),
              const SizedBox(height: AppSpacing.lg),
              _emojiField(),
              const SizedBox(height: AppSpacing.lg),
              _timeToggle(),
              if (_timeEnabled) ...[
                const SizedBox(height: AppSpacing.lg),
                _timeField(),
              ],
              const SizedBox(height: AppSpacing.lg),
              if (_timeEnabled) _alarmToggle(),
              if (_timeEnabled) const SizedBox(height: AppSpacing.lg),
              _dateField('Start Date', _startDate, _selectStartDate),
              const SizedBox(height: AppSpacing.lg),
              _dateField('End Date', _endDate, _selectEndDate),
              const SizedBox(height: AppSpacing.lg),
              _frequencySelector(),
              const SizedBox(height: AppSpacing.lg),
              _colorPicker(),
              const SizedBox(height: AppSpacing.xl),
              _commitButton(),
              const SizedBox(height: 150),
            ],
          ),
        ),
      ),
    );
  }

  Widget _typeSelector() => Row(
        children: [
          Expanded(
              child: GlassButton(
            onPressed: () => _onTypeChanged('habit'),
            backgroundColor: _selectedType == 'habit'
                ? AppColors.emerald
                : const Color(0xFF0D0D0D),
            borderColor: _selectedType == 'habit'
                ? AppColors.emerald
                : Colors.white.withOpacity(0.08),
            child: Text('ORDER',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: _selectedType == 'habit'
                      ? Colors.black
                      : AppColors.textSecondary,
                )),
          )),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
              child: GlassButton(
            onPressed: () => _onTypeChanged('task'),
            backgroundColor: _selectedType == 'task'
                ? AppColors.cyan
                : const Color(0xFF0D0D0D),
            borderColor: _selectedType == 'task'
                ? AppColors.cyan
                : Colors.white.withOpacity(0.08),
            child: Text('TASK',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: _selectedType == 'task'
                      ? Colors.black
                      : AppColors.textSecondary,
                )),
          )),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
              child: GlassButton(
            onPressed: () => _onTypeChanged('bad_habit'),
            backgroundColor: _selectedType == 'bad_habit'
                ? AppColors.error
                : const Color(0xFF0D0D0D),
            borderColor: _selectedType == 'bad_habit'
                ? AppColors.error
                : Colors.white.withOpacity(0.08),
            child: Text('RULE',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: _selectedType == 'bad_habit'
                      ? Colors.white
                      : AppColors.textSecondary,
                  fontSize: 13,
                )),
          )),
        ],
      );

  Widget _textField(String label, TextEditingController c,
          {required IconData icon}) =>
      TextFormField(
        controller: c,
        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          hintText: 'Order title...',
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.2)),
          prefixIcon: Icon(icon, color: AppColors.emerald.withOpacity(0.6)),
          filled: true,
          fillColor: const Color(0xFF0D0D0D),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.emerald.withOpacity(0.15)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.emerald.withOpacity(0.15)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.emerald.withOpacity(0.5), width: 1.5),
          ),
        ),
        validator: (v) => v == null || v.trim().isEmpty ? 'Enter a title' : null,
      );

  Widget _emojiField() => GestureDetector(
        onTap: _pickEmoji,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: const Color(0xFF0D0D0D),
            border: Border.all(color: AppColors.emerald.withOpacity(0.15)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                LucideIcons.smile,
                color: AppColors.textTertiary,
                size: 20,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                _selectedEmoji ?? 'Pick an emoji (optional)',
                style: AppTextStyles.body.copyWith(
                  color: _selectedEmoji != null
                      ? AppColors.textPrimary
                      : AppColors.textQuaternary,
                  fontSize: _selectedEmoji != null ? 24 : 16,
                ),
              ),
              const Spacer(),
              Icon(
                LucideIcons.chevronDown,
                color: AppColors.textTertiary,
                size: 16,
              ),
            ],
          ),
        ),
      );

  Widget _timeToggle() => Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: const Color(0xFF0D0D0D),
          border: Border.all(color: AppColors.emerald.withOpacity(0.15)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              LucideIcons.clock,
              color: _timeEnabled ? AppColors.emerald : AppColors.textTertiary,
              size: 20,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Set Specific Time',
                    style: AppTextStyles.bodySemiBold.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _timeEnabled ? 'Time will show on card' : 'No specific time (all-day)',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textTertiary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: _timeEnabled,
              onChanged: (value) {
                setState(() {
                  _timeEnabled = value;
                  if (!value) {
                    _reminderOn = false;
                  }
                });
              },
              activeColor: AppColors.emerald,
              activeTrackColor: AppColors.emerald.withOpacity(0.3),
            ),
          ],
        ),
      );

  Widget _alarmToggle() => Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: const Color(0xFF0D0D0D),
          border: Border.all(color: AppColors.emerald.withOpacity(0.15)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              _reminderOn ? LucideIcons.bell : LucideIcons.bellOff,
              color: _reminderOn ? AppColors.emerald : AppColors.textTertiary,
              size: 20,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Reminder Alarm',
                    style: AppTextStyles.bodySemiBold.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _reminderOn ? 'Alarm enabled for this habit' : 'Tap to enable alarm notifications',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textTertiary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: _reminderOn,
              onChanged: (value) {
                setState(() {
                  _reminderOn = value;
                });
              },
              activeColor: AppColors.emerald,
              activeTrackColor: AppColors.emerald.withOpacity(0.3),
            ),
          ],
        ),
      );

  Widget _timeField() => GestureDetector(
        onTap: _selectTime,
        child: AbsorbPointer(
          child: TextFormField(
            controller: _timeController,
            style: AppTextStyles.body,
            decoration: const InputDecoration(
              prefixIcon:
                  Icon(LucideIcons.clock, color: AppColors.textTertiary),
              suffixIcon: Icon(LucideIcons.chevronDown,
                  color: AppColors.textTertiary),
            ),
          ),
        ),
      );

  Widget _dateField(String label, DateTime date, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: const Color(0xFF0D0D0D),
            border: Border.all(color: AppColors.emerald.withOpacity(0.15)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(children: [
            Icon(LucideIcons.calendar,
                color: AppColors.emerald.withOpacity(0.5), size: 16),
            const SizedBox(width: AppSpacing.sm),
            Text('${date.day}/${date.month}/${date.year}',
                style: AppTextStyles.body),
          ]),
        ),
      );

  Widget _frequencySelector() => Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          _FrequencyChip('Daily', 'daily', _frequency, _updateFrequency),
          _FrequencyChip('Weekdays', 'weekdays', _frequency, _updateFrequency),
          _FrequencyChip('Weekends', 'weekends', _frequency, _updateFrequency),
          _FrequencyChip('Custom', 'custom', _frequency, _updateFrequency),
        ],
      );

  Widget _colorPicker() {
    final colors = [
      AppColors.emerald,
      AppColors.cyan,
      AppColors.warning,
      AppColors.purple,
      AppColors.rose
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Habit Color',
            style: AppTextStyles.captionSmall
                .copyWith(color: AppColors.textTertiary)),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: colors
              .map((c) => GestureDetector(
                    onTap: () => setState(() => _selectedColor = c),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: _selectedColor == c
                                ? Colors.white
                                : Colors.transparent,
                            width: 2),
                      ),
                    ),
                  ))
              .toList(),
        )
      ],
    );
  }

  Widget _commitButton() => SizedBox(
        width: double.infinity,
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            gradient: AppColors.emeraldGradient,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: AppColors.emerald.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _submitForm,
              borderRadius: BorderRadius.circular(14),
              child: const Center(
                child: Text(
                  'SET ORDER',
                  style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 2),
                ),
              ),
            ),
          ),
        ),
      );

  // ---------------------------------------------------------
  // MANAGE TAB
  // ---------------------------------------------------------
  Widget _buildManageTab() {
    final habitEngine = ref.watch(habitEngineProvider);
    final filtered = habitEngine.habits
        .where((h) => h.isScheduledForDate(_selectedDate))
        .toList();

    if (filtered.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 60),
        child: Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFFFF6B35).withOpacity(0.1),
                    const Color(0xFFFF8C42).withOpacity(0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(AppBorderRadius.xl),
                border: Border.all(
                  color: const Color(0xFFFF6B35).withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF6B35).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      LucideIcons.target,
                      size: 36,
                      color: const Color(0xFFFF6B35),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'No Habits Yet',
                    style: AppTextStyles.h3.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'No orders for this day.',
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  GestureDetector(
                    onTap: () => _tabController.animateTo(0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: AppSpacing.md,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFFFF6B35),
                            const Color(0xFFFF8C42),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(AppBorderRadius.md),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            LucideIcons.plus,
                            color: Colors.white,
                            size: 20,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Text(
                            'NEW ORDER',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // Load all systems
    final allSystems = LocalStorageService.getAllSystems();

    // Group habits by systemId
    final Map<String, List<Habit>> systemHabitsMap = {};
    final List<Habit> standaloneHabits = [];

    for (final habit in filtered) {
      if (habit.systemId != null && habit.systemId!.isNotEmpty) {
        if (!systemHabitsMap.containsKey(habit.systemId)) {
          systemHabitsMap[habit.systemId!] = [];
        }
        systemHabitsMap[habit.systemId!]!.add(habit);
      } else {
        standaloneHabits.add(habit);
      }
    }

    return RefreshIndicator(
      onRefresh: () async => await ref.read(habitEngineProvider).loadHabits(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          150,
        ),
        children: [
          // System Cards
          ...allSystems.where((system) => systemHabitsMap.containsKey(system.id)).map((system) {
            final systemHabits = systemHabitsMap[system.id]!;
            return SystemCard(
              system: system,
              habits: systemHabits,
              selectedDate: DateTime.now(),
              onDeleteHabits: () async {
                final selectedHabits = await showDialog<List<String>>(
                  context: context,
                  builder: (context) => _HabitSelectionDialog(
                    systemName: system.name,
                    habits: systemHabits,
                  ),
                );

                if (selectedHabits != null && selectedHabits.isNotEmpty) {
                  for (final habitId in selectedHabits) {
                    await ref.read(habitEngineProvider.notifier).deleteHabit(habitId);
                  }

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Deleted ${selectedHabits.length} habit(s) from ${system.name}'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                  }
                }
              },
            );
          }),

          // Standalone Habit Cards
          ...standaloneHabits.map((habit) => Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: _buildHabitCard(habit),
          )),
        ],
      ),
    );
  }

  // ---------------------------------------------------------
  // HABIT CARD
  // ---------------------------------------------------------
  Widget _buildHabitCard(Habit habit) {
    final accent = habit.color ??
        (habit.type == 'habit' ? AppColors.emerald : AppColors.cyan);

    final progressPercent = habit.streak > 0 ? (habit.streak % 10) / 10 : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.baseDark2,
        borderRadius: BorderRadius.circular(AppBorderRadius.xl),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Emoji or icon
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: accent.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(AppBorderRadius.md),
                        border: Border.all(
                          color: accent.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: habit.emoji != null
                          ? Center(
                              child: Text(
                                habit.emoji!,
                                style: const TextStyle(fontSize: 32),
                              ),
                            )
                          : Icon(
                              habit.type == 'habit'
                                  ? LucideIcons.flame
                                  : LucideIcons.checkCircle,
                              color: accent,
                              size: 28,
                            ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            habit.title,
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 17,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Row(
                            children: [
                              Text(
                                habit.type.toUpperCase(),
                                style: AppTextStyles.captionSmall.copyWith(
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              Text(
                                ' \u2022 ',
                                style: TextStyle(
                                  color: AppColors.textTertiary,
                                ),
                              ),
                              Text(
                                _getFrequencyText(habit.repeatDays),
                                style: AppTextStyles.captionSmall.copyWith(
                                  color: AppColors.textTertiary,
                                ),
                              ),
                              if (habit.reminderOn) ...[
                                Text(
                                  ' \u2022 ',
                                  style: TextStyle(
                                    color: AppColors.textTertiary,
                                  ),
                                ),
                                Icon(
                                  LucideIcons.bellRing,
                                  size: 12,
                                  color: AppColors.cyan,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  habit.time,
                                  style: AppTextStyles.captionSmall.copyWith(
                                    color: AppColors.cyan,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Settings menu
                    PopupMenuButton<String>(
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(AppBorderRadius.sm),
                        ),
                        child: Icon(
                          LucideIcons.settings,
                          size: 18,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      onSelected: (value) async {
                        if (value == 'edit') {
                          _editHabit(habit);
                        } else if (value == 'delete') {
                          _deleteHabit(habit);
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(children: [
                            Icon(LucideIcons.edit, size: 16),
                            SizedBox(width: 8),
                            Text('Edit'),
                          ]),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(children: [
                            Icon(LucideIcons.trash, size: 16, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Delete', style: TextStyle(color: Colors.red)),
                          ]),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                // Time display
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: accent.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(AppBorderRadius.sm),
                        border: Border.all(
                          color: accent.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            LucideIcons.clock,
                            size: 14,
                            color: accent,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            habit.time,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: accent,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Icon(
                      LucideIcons.flame,
                      size: 16,
                      color: AppColors.textTertiary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${habit.streak}d',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Progress bar
          Container(
            height: 6,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(AppBorderRadius.xl),
                bottomRight: Radius.circular(AppBorderRadius.xl),
              ),
            ),
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(AppBorderRadius.xl),
                bottomRight: Radius.circular(AppBorderRadius.xl),
              ),
              child: LinearProgressIndicator(
                value: progressPercent > 0 ? progressPercent : 0.15,
                backgroundColor: Colors.transparent,
                valueColor: AlwaysStoppedAnimation<Color>(accent),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getFrequencyText(List<int> days) {
    if (days.length == 7) return 'Daily';
    if (days.length == 5 && days.contains(1) && days.contains(5)) return 'Weekdays';
    if (days.length == 2 && days.contains(0) && days.contains(6)) return 'Weekends';
    return '${days.length} days/week';
  }

  void _editHabit(Habit h) {
    _tabController.animateTo(0);
    setState(() {
      _titleController.text = h.title;
      _timeController.text = h.time;
      _selectedType = h.type;
      _startDate = h.startDate;
      _endDate = h.endDate;
      for (int i = 0; i < 7; i++) {
        _repeatDays[i] = h.repeatDays.contains(i);
      }
    });
  }

  void _deleteHabit(Habit h) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.baseDark2,
        title: Text('Delete ${h.type.capitalize()}',
            style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600)),
        content: Text('Are you sure you want to delete "${h.title}"?',
            style: AppTextStyles.body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel',
                style:
                    AppTextStyles.body.copyWith(color: AppColors.textTertiary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete',
                style: AppTextStyles.body
                    .copyWith(color: AppColors.error, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(habitEngineProvider.notifier).deleteHabit(h.id);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${h.title} deleted'),
        backgroundColor: AppColors.error.withOpacity(0.9),
      ));
    }
  }
}

class _FrequencyChip extends StatelessWidget {
  final String label;
  final String value;
  final String currentFrequency;
  final Function(String) onSelected;

  const _FrequencyChip(
      this.label, this.value, this.currentFrequency, this.onSelected,
      {super.key});

  @override
  Widget build(BuildContext context) {
    final sel = currentFrequency == value;
    return GestureDetector(
      onTap: () => onSelected(value),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color:
              sel ? AppColors.emerald.withOpacity(0.2) : AppColors.glassBackground,
          border:
              Border.all(color: sel ? AppColors.emerald : AppColors.glassBorder),
          borderRadius: BorderRadius.circular(AppBorderRadius.full),
        ),
        child: Text(label,
            style: AppTextStyles.captionSmall
                .copyWith(color: sel ? AppColors.emerald : AppColors.textTertiary)),
      ),
    );
  }
}

// Dialog for selecting habit to delete from a system
class _HabitSelectionDialog extends StatefulWidget {
  final String systemName;
  final List<Habit> habits;

  const _HabitSelectionDialog({
    required this.systemName,
    required this.habits,
  });

  @override
  State<_HabitSelectionDialog> createState() => _HabitSelectionDialogState();
}

class _HabitSelectionDialogState extends State<_HabitSelectionDialog> {
  String? selectedHabitId;

  @override
  void initState() {
    super.initState();
    selectedHabitId = null;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1a1a2e),
      title: Text(
        'Delete Habit from ${widget.systemName}',
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Select ONE habit to delete:',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: widget.habits.length,
                itemBuilder: (context, index) {
                  final habit = widget.habits[index];
                  final isSelected = selectedHabitId == habit.id;

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          selectedHabitId = null;
                        } else {
                          selectedHabitId = habit.id;
                        }
                      });
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.orange.withOpacity(0.2)
                            : Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected
                              ? Colors.orange
                              : Colors.white.withOpacity(0.1),
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isSelected
                                ? Icons.radio_button_checked
                                : Icons.radio_button_unchecked,
                            color: isSelected ? Colors.orange : Colors.white.withOpacity(0.3),
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              habit.title,
                              style: TextStyle(
                                color: Colors.white.withOpacity(isSelected ? 1.0 : 0.7),
                                fontSize: 14,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
        ),
        TextButton(
          onPressed: selectedHabitId == null
              ? null
              : () => Navigator.pop(context, [selectedHabitId!]),
          style: TextButton.styleFrom(
            backgroundColor: selectedHabitId == null
                ? Colors.grey.withOpacity(0.2)
                : Colors.orange.withOpacity(0.2),
          ),
          child: Text(
            'Delete habit',
            style: TextStyle(
              color: selectedHabitId == null ? Colors.grey : Colors.orange,
            ),
          ),
        ),
      ],
    );
  }
}

extension StringC on String {
  String capitalize() =>
      isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
}
