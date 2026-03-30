import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../design/tokens.dart';
import '../widgets/date_strip.dart';
import '../screens/settings_screen.dart';
import '../screens/sergeant/punishment_screen.dart';
import '../screens/sergeant/tempted_screen.dart';
import '../screens/paywall_screen.dart';
import '../providers/habit_provider.dart';
import '../services/sergeant_service.dart';
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
      if (mounted) setState(() {});
    }
  }

  void _onDateSelected(DateTime date) {
    setState(() => _selectedDate = date);
  }

  @override
  Widget build(BuildContext context) {
    final habitEngine = ref.watch(habitEngineProvider);
    final allHabits = habitEngine.habits;

    final dayOrders = allHabits.where((h) => h.isScheduledForDate(_selectedDate)).toList();
    final completedCount = dayOrders.where((h) => h.isDoneOn(_selectedDate)).length;
    final total = dayOrders.length;
    final hasFailed = SergeantService.hasPendingPunishment();
    final hasRules = dayOrders.any((h) => h.type == 'bad_habit');

    // Status
    String status;
    Color statusColor;
    if (hasFailed) {
      status = 'FAILED';
      statusColor = AppColors.error;
    } else if (total > 0 && completedCount == total) {
      status = 'CONTROLLED';
      statusColor = AppColors.emerald;
    } else if (total > 0 && completedCount < total) {
      status = 'AT RISK';
      statusColor = Colors.orange;
    } else {
      status = 'NO ORDERS';
      statusColor = AppColors.textTertiary;
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(),

            DateStrip(
              selectedDate: _selectedDate,
              onDateSelected: _onDateSelected,
              accentColor: AppColors.emerald,
            ),

            const SizedBox(height: AppSpacing.lg),

            // STATUS - large, dominant
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppBorderRadius.xl),
                  border: Border.all(color: statusColor.withOpacity(0.3), width: 1.5),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 4,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.md),

            // KILL URGE button - always visible
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
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppBorderRadius.xl),
                    border: Border.all(color: Colors.orange.withOpacity(0.3)),
                  ),
                  child: const Text(
                    'KILL URGE',
                    style: TextStyle(
                      color: Colors.orange,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // ORDERS LIST
            if (dayOrders.isEmpty)
              _buildEmptyState()
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Column(
                  children: dayOrders.asMap().entries.map((entry) {
                    final index = entry.key;
                    final habit = entry.value;
                    final isDone = habit.isDoneOn(_selectedDate);
                    return _buildOrderCard(
                      habit: habit,
                      isDone: isDone,
                      index: index,
                      onToggle: () async {
                        final violation = await ref.read(habitEngineProvider).toggleHabitCompletion(habit.id);
                        if (violation != null && context.mounted) {
                          Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => PunishmentScreen(
                              violation: violation,
                              onComplete: () => Navigator.of(context).pop(),
                            ),
                          ));
                        }
                      },
                    );
                  }).toList(),
                ),
              ),

            const SizedBox(height: 120),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 40, AppSpacing.lg, 0),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.xl),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(AppBorderRadius.xl),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'NO ORDERS SET',
              style: TextStyle(
                color: Colors.white.withOpacity(0.4),
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Tap ORDERS below to set your first order.',
              style: TextStyle(
                color: Colors.white.withOpacity(0.2),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderCard({
    required dynamic habit,
    required bool isDone,
    required int index,
    required VoidCallback onToggle,
  }) {
    String? time;
    if (habit.time != null && habit.time.isNotEmpty) {
      try {
        time = DateFormat('HH:mm').format(DateTime.parse('2025-01-01 ${habit.time}:00'));
      } catch (e) {
        time = null;
      }
    }

    final isRule = habit.type == 'bad_habit';

    // Status text
    String statusText;
    Color statusColor;
    if (isRule) {
      statusText = isDone ? 'FAILED' : 'ACTIVE';
      statusColor = isDone ? AppColors.error : AppColors.emerald;
    } else {
      statusText = isDone ? 'COMPLETED' : 'PENDING';
      statusColor = isDone ? AppColors.emerald : Colors.white.withOpacity(0.4);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: GestureDetector(
        onTap: onToggle,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: isDone && !isRule
                ? AppColors.emerald.withOpacity(0.05)
                : isDone && isRule
                    ? AppColors.error.withOpacity(0.08)
                    : Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(AppBorderRadius.lg),
            border: Border.all(
              color: isDone && !isRule
                  ? AppColors.emerald.withOpacity(0.3)
                  : isDone && isRule
                      ? AppColors.error.withOpacity(0.3)
                      : Colors.white.withOpacity(0.08),
            ),
          ),
          child: Row(
            children: [
              // Left: title + time
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      habit.title.toString().toUpperCase(),
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                    if (time != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        time,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.3),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // Right: status
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: statusColor.withOpacity(0.3)),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate(delay: (index * 40).ms).fadeIn(duration: 200.ms);
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.sm, AppSpacing.xl, AppSpacing.sm, AppSpacing.md),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppBorderRadius.md),
                child: Image.asset('assets/icon/app_icon.png', width: 44, height: 44, fit: BoxFit.cover),
              ),
              const SizedBox(width: 8),
              ShaderMask(
                shaderCallback: (bounds) => AppColors.emeraldGradient.createShader(bounds),
                child: const Text(
                  'DRILLSARJ',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 2),
                ),
              ),
            ],
          ),
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(fullscreenDialog: true, builder: (_) => const PaywallScreen())),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: AppColors.emeraldGradient,
                    borderRadius: BorderRadius.circular(AppBorderRadius.md),
                  ),
                  child: const Text('PRO', style: TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.glassBackground,
                    borderRadius: BorderRadius.circular(AppBorderRadius.md),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: Icon(LucideIcons.settings, color: Colors.white.withOpacity(0.5), size: 20),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
