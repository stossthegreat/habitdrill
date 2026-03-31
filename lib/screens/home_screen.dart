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

    // Separate orders and rules
    final orders = dayOrders.where((h) => h.type != 'bad_habit').toList();
    final rules = dayOrders.where((h) => h.type == 'bad_habit').toList();

    // Status
    String status;
    Color statusColor;
    if (hasFailed) {
      status = 'FAILED';
      statusColor = const Color(0xFFDC2626);
    } else if (total > 0 && completedCount == total) {
      status = 'CONTROLLED';
      statusColor = const Color(0xFF16A34A);
    } else if (total > 0) {
      status = 'AT RISK';
      statusColor = const Color(0xFFF59E0B);
    } else {
      status = 'STANDBY';
      statusColor = Colors.white24;
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

            // ===== 1. STATUS BANNER (full width, solid bg, NOT a card) =====
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 20),
              margin: const EdgeInsets.only(top: AppSpacing.md),
              color: statusColor.withOpacity(0.15),
              child: Text(
                status,
                style: TextStyle(
                  color: statusColor,
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 6,
                ),
                textAlign: TextAlign.center,
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // ===== 2. KILL URGE (glowing button, raised, pressable) =====
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
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFEA580C), Color(0xFFDC2626)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFEA580C).withOpacity(0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Text(
                    'KILL URGE',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 3,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.xl),

            // ===== 3. ORDERS (green border, "DO" label) =====
            if (orders.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Text(
                  'ORDERS',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.3),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 3,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              ...orders.asMap().entries.map((entry) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: _buildOrderCard(entry.value, entry.value.isDoneOn(_selectedDate), entry.key),
              )),
            ],

            // ===== 4. RULES (red border, "AVOID" label) =====
            if (rules.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.lg),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Text(
                  'RULES',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.3),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 3,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              ...rules.asMap().entries.map((entry) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: _buildRuleCard(entry.value, entry.value.isDoneOn(_selectedDate), entry.key),
              )),
            ],

            if (dayOrders.isEmpty) _buildEmptyState(),

            const SizedBox(height: 120),
          ],
        ),
      ),
    );
  }

  // ===== ORDER CARD: green accent, "DO" tag, tap = COMPLETED =====
  Widget _buildOrderCard(Habit habit, bool isDone, int index) {
    String? time;
    if (habit.time.isNotEmpty) {
      try {
        time = DateFormat('HH:mm').format(DateTime.parse('2025-01-01 ${habit.time}:00'));
      } catch (_) {}
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: () async {
          final violation = await ref.read(habitEngineProvider).toggleHabitCompletion(habit.id);
          if (violation != null && context.mounted) {
            Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => PunishmentScreen(violation: violation, onComplete: () => Navigator.of(context).pop()),
            ));
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isDone ? const Color(0xFF16A34A).withOpacity(0.08) : const Color(0xFF111111),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDone ? const Color(0xFF16A34A).withOpacity(0.4) : const Color(0xFF16A34A).withOpacity(0.15),
              width: isDone ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              // DO tag
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF16A34A).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'DO',
                  style: TextStyle(color: Color(0xFF16A34A), fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1),
                ),
              ),
              const SizedBox(width: 12),
              // Title + time
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      habit.title.toUpperCase(),
                      style: TextStyle(
                        color: Colors.white.withOpacity(isDone ? 0.5 : 0.9),
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        decoration: isDone ? TextDecoration.lineThrough : null,
                        decorationColor: Colors.white38,
                      ),
                    ),
                    if (time != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        'DUE $time',
                        style: TextStyle(color: Colors.white.withOpacity(0.25), fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.w600),
                      ),
                    ],
                  ],
                ),
              ),
              // Status button
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isDone ? const Color(0xFF16A34A) : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: isDone ? null : Border.all(color: const Color(0xFF16A34A).withOpacity(0.3)),
                ),
                child: Text(
                  isDone ? 'COMPLETED' : 'START',
                  style: TextStyle(
                    color: isDone ? Colors.black : const Color(0xFF16A34A),
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

  // ===== RULE CARD: red accent, "AVOID" tag, tap = I BROKE IT =====
  Widget _buildRuleCard(Habit habit, bool isBroken, int index) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: () async {
          if (isBroken) return; // Already logged
          final violation = await ref.read(habitEngineProvider).toggleHabitCompletion(habit.id);
          if (violation != null && context.mounted) {
            Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => PunishmentScreen(violation: violation, onComplete: () => Navigator.of(context).pop()),
            ));
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isBroken ? const Color(0xFFDC2626).withOpacity(0.1) : const Color(0xFF1A0A0A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isBroken ? const Color(0xFFDC2626).withOpacity(0.4) : const Color(0xFFDC2626).withOpacity(0.15),
              width: isBroken ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              // AVOID tag
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFDC2626).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'AVOID',
                  style: TextStyle(color: Color(0xFFDC2626), fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1),
                ),
              ),
              const SizedBox(width: 12),
              // Title
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      habit.title.toUpperCase(),
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      isBroken ? 'RULE BROKEN' : 'STAY CLEAN',
                      style: TextStyle(
                        color: isBroken ? const Color(0xFFDC2626).withOpacity(0.7) : Colors.white.withOpacity(0.2),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
              // Action button
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isBroken ? const Color(0xFFDC2626).withOpacity(0.2) : const Color(0xFFDC2626),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isBroken ? 'FAILED' : 'I BROKE IT',
                  style: TextStyle(
                    color: isBroken ? const Color(0xFFDC2626) : Colors.white,
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

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 40, AppSpacing.lg, 0),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.xl),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.02),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: Column(
          children: [
            Text('NO ORDERS', style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 3)),
            const SizedBox(height: 8),
            Text('Tap ORDERS to set your first order.', style: TextStyle(color: Colors.white.withOpacity(0.15), fontSize: 13)),
          ],
        ),
      ),
    );
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
                child: Image.asset('assets/icon/app_icon.png', width: 40, height: 40, fit: BoxFit.cover),
              ),
              const SizedBox(width: 8),
              const Text(
                'DRILLSARJ',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 2),
              ),
            ],
          ),
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(fullscreenDialog: true, builder: (_) => const PaywallScreen())),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: AppColors.emeraldGradient,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('PRO', style: TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.w800)),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
                child: Icon(LucideIcons.settings, color: Colors.white.withOpacity(0.3), size: 22),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
