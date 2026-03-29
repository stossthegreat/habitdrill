import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../design/tokens.dart';
import '../widgets/date_strip.dart';
import '../widgets/system_card.dart';
import '../screens/settings_screen.dart';
import '../screens/sergeant/punishment_screen.dart';
import '../screens/sergeant/tempted_screen.dart';
import '../screens/paywall_screen.dart';
import '../providers/habit_provider.dart';
import '../services/local_storage.dart';
import '../services/sergeant_service.dart';
import '../models/habit_system.dart';
import '../models/habit.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with WidgetsBindingObserver {
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Refresh habits when app comes to foreground
      if (mounted) setState(() {});
    }
  }

  void _onDateSelected(DateTime date) {
    setState(() {
      _selectedDate = date;
    });
  }

  @override
  Widget build(BuildContext context) {
    final habitEngine = ref.watch(habitEngineProvider);
    final allHabits = habitEngine.habits;

    // Filter habits for selected date
    final dayHabits = allHabits.where((habit) {
      return habit.isScheduledForDate(_selectedDate);
    }).toList();

    // Load all systems
    final allSystems = LocalStorageService.getAllSystems();

    // Group habits by systemId
    final Map<String, List<dynamic>> systemHabitsMap = {};
    final List<dynamic> standaloneHabits = [];

    for (final habit in dayHabits) {
      if (habit.systemId != null && habit.systemId!.isNotEmpty) {
        if (!systemHabitsMap.containsKey(habit.systemId)) {
          systemHabitsMap[habit.systemId!] = [];
        }
        systemHabitsMap[habit.systemId!]!.add(habit);
      } else {
        standaloneHabits.add(habit);
      }
    }

    // Date-aware completion
    final completedCount = dayHabits.where((h) => h.isDoneOn(_selectedDate)).length;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            _buildHomeHeader(),

            // Date strip
            DateStrip(
              selectedDate: _selectedDate,
              onDateSelected: _onDateSelected,
              accentColor: AppColors.emerald,
            ),

            const SizedBox(height: AppSpacing.md),

            // "I'm Tempted" quick action - shows when user has bad habits
            if (allHabits.any((h) => h.type == 'bad_habit'))
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: GestureDetector(
                  onTap: () {
                    Navigator.of(context).push(MaterialPageRoute(
                      fullscreenDialog: true,
                      builder: (_) => const TemptedScreen(),
                    ));
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.orange.withOpacity(0.15),
                          Colors.red.withOpacity(0.08),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(AppBorderRadius.xl),
                      border: Border.all(color: Colors.orange.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.local_fire_department, color: Colors.orange.withOpacity(0.9), size: 22),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            'Feeling tempted? Tap to fight the urge',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: Colors.orange.withOpacity(0.9),
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        Icon(LucideIcons.chevronRight, color: Colors.orange.withOpacity(0.5), size: 18),
                      ],
                    ),
                  ),
                ),
              ),

            const SizedBox(height: AppSpacing.lg),

            // Habit cards (System cards + Standalone habits)
            if (dayHabits.isEmpty)
              _buildEmptyState(),

            if (dayHabits.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Column(
                  children: [
                    // System Cards
                    ...allSystems.where((system) => systemHabitsMap.containsKey(system.id)).map((system) {
                      final systemHabits = systemHabitsMap[system.id]!.cast<Habit>();
                      return SystemCard(
                        system: system,
                        habits: systemHabits,
                        selectedDate: _selectedDate,
                        onToggleHabit: (habit) async {
                          await ref.read(habitEngineProvider.notifier).toggleHabitCompletion(habit.id);
                        },
                      );
                    }),

                    // Standalone Habit Cards
                    ...standaloneHabits.asMap().entries.map((entry) {
                      final index = entry.key;
                      final habit = entry.value;
                      final isDone = habit.isDoneOn(_selectedDate);

                      return _buildHabitCard(
                        habit: habit,
                        isDone: isDone,
                        index: index + allSystems.length,
                        onToggle: () async {
                          final violation = await ref.read(habitEngineProvider).toggleHabitCompletion(habit.id);
                          if (violation != null && context.mounted) {
                            // Bad habit triggered - show punishment
                            Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => PunishmentScreen(
                                violation: violation,
                                onComplete: () => Navigator.of(context).pop(),
                              ),
                            ));
                          }
                        },
                      );
                    }),
                  ],
                ),
              ),

            // Bottom padding for FAB
            const SizedBox(height: 120),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 60, AppSpacing.lg, 0),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.emerald.withOpacity(0.1),
              AppColors.emerald.withOpacity(0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(AppBorderRadius.xl),
          border: Border.all(
            color: AppColors.emerald.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.emerald.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                LucideIcons.target,
                size: 36,
                color: AppColors.emerald,
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
              'Tap the Planner button below\nto create your first habit',
              style: AppTextStyles.body.copyWith(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHabitCard({
    required dynamic habit,
    required bool isDone,
    required int index,
    required VoidCallback onToggle,
  }) {
    // Handle empty time
    String? time;
    if (habit.time != null && habit.time.isNotEmpty) {
      try {
        final timeFormatter = DateFormat('HH:mm');
        time = timeFormatter.format(DateTime.parse('2025-01-01 ${habit.time}:00'));
      } catch (e) {
        time = null;
      }
    }

    final habitColor = habit.color;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: GestureDetector(
        onTap: onToggle,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: isDone
                ? habitColor.withOpacity(0.05)
                : Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(AppBorderRadius.xl),
            border: Border.all(
              color: isDone
                  ? habitColor.withOpacity(0.3)
                  : Colors.white.withOpacity(0.1),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Emoji or icon
                  if (habit.emoji != null)
                    Text(
                      habit.emoji!,
                      style: const TextStyle(fontSize: 32),
                    )
                  else
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: habitColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        LucideIcons.flame,
                        size: 20,
                        color: habitColor,
                      ),
                    ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Time + Alarm + Status chip
                        Row(
                          children: [
                            if (time != null) ...[
                              Text(
                                time,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: habitColor,
                                  fontFamily: 'monospace',
                                  letterSpacing: 1,
                                ),
                              ),
                              const SizedBox(width: 4),
                              if (habit.reminderOn) ...[
                                Icon(
                                  LucideIcons.bellRing,
                                  size: 12,
                                  color: habitColor.withOpacity(0.8),
                                ),
                              ],
                              const SizedBox(width: AppSpacing.sm),
                              Text('\u2022', style: TextStyle(color: Colors.white38)),
                              const SizedBox(width: AppSpacing.sm),
                            ],
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: habitColor.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: habitColor.withOpacity(0.3),
                                ),
                              ),
                              child: Text(
                                habit.type == 'bad_habit'
                                    ? (isDone ? 'slipped' : 'tracking')
                                    : (isDone ? 'done' : 'planned'),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  color: habitColor,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        // Title
                        Text(
                          habit.title,
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 17,
                            color: Colors.white.withOpacity(0.95),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Streak flame indicator
                  if (habit.streak > 0) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(AppBorderRadius.sm),
                        border: Border.all(
                          color: AppColors.warning.withOpacity(0.3),
                          width: 0.5,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            LucideIcons.flame,
                            size: 14,
                            color: AppColors.warning,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${habit.streak}',
                            style: AppTextStyles.label.copyWith(
                              color: AppColors.warning,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  // Checkmark / Bad habit icon
                  habit.type == 'bad_habit'
                      ? Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.error.withOpacity(isDone ? 0.3 : 0.15),
                            borderRadius: BorderRadius.circular(AppBorderRadius.md),
                            border: Border.all(color: AppColors.error.withOpacity(0.5)),
                          ),
                          child: Text(
                            isDone ? 'LOGGED' : 'I SLIPPED',
                            style: const TextStyle(
                              color: AppColors.error,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        )
                      : Icon(
                          isDone ? LucideIcons.checkCircle2 : LucideIcons.circle,
                          size: 28,
                          color: isDone
                              ? habitColor
                              : Colors.white.withOpacity(0.3),
                        ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              // Progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(AppBorderRadius.full),
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppBorderRadius.full),
                  ),
                  child: Stack(
                    children: [
                      FractionallySizedBox(
                        widthFactor: isDone ? 1.0 : 0.56,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                habitColor.withOpacity(0.8),
                                habitColor,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(AppBorderRadius.full),
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
      ),
    ).animate(delay: (index * 30).ms)
      .fadeIn(duration: 260.ms)
      .scale(begin: const Offset(0.98, 0.98), end: const Offset(1, 1));
  }

  Widget _buildHomeHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        AppSpacing.xl,
        AppSpacing.sm,
        AppSpacing.md,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // App icon + "Drillsarj" text
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppBorderRadius.md),
                child: Image.asset(
                  'assets/icon/app_icon.png',
                  width: 44,
                  height: 44,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 8),
              ShaderMask(
                shaderCallback: (bounds) => AppColors.emeraldGradient
                    .createShader(bounds),
                child: const Text(
                  'Drillsarj',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ],
          ),

          Row(
            children: [
              // Get Pro button
              GestureDetector(
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(
                    fullscreenDialog: true,
                    builder: (_) => const PaywallScreen(),
                  ));
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: AppColors.emeraldGradient,
                    borderRadius: BorderRadius.circular(AppBorderRadius.md),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.emerald.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(LucideIcons.crown, color: Colors.black, size: 14),
                      SizedBox(width: 4),
                      Text(
                        'PRO',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Settings icon
              GestureDetector(
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(
                    builder: (_) => const SettingsScreen(),
                  ));
                },
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.glassBackground,
                    borderRadius: BorderRadius.circular(AppBorderRadius.md),
                    border: Border.all(color: AppColors.emerald.withOpacity(0.2)),
                  ),
                  child: const Icon(LucideIcons.settings, color: AppColors.emerald, size: 22),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
