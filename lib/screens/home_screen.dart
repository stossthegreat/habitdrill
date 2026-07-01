import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../design/tokens.dart';
import '../widgets/date_strip.dart';
import '../widgets/share_card.dart';
import '../screens/settings_screen.dart';
import '../screens/sergeant/punishment_screen.dart';
import '../screens/sergeant/tempted_screen.dart';
import '../screens/paywall_screen.dart';
import '../providers/habit_provider.dart';
import '../services/sergeant_service.dart';
import '../services/discipline_service.dart';
import '../services/premium_service.dart';
import '../services/analytics_service.dart';
import '../models/habit.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with WidgetsBindingObserver {
  DateTime _selectedDate = DateTime.now();

  // Discipline data
  int _score = 50;
  int _daysControlled = 0;
  int _bestStreak = 0;
  SergeantRank _rank = SergeantRank.private_;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AnalyticsService.logScreenView('home');
    _loadDisciplineData();
    _runDailyCheck();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (mounted) {
        setState(() {});
        _loadDisciplineData();
      }
    }
  }

  Future<void> _loadDisciplineData() async {
    final score = await DisciplineService.getScore();
    final days = await DisciplineService.getDaysControlled();
    final best = await DisciplineService.getBestStreak();
    final rank = await DisciplineService.getRank();
    if (mounted) {
      setState(() {
        _score = score;
        _daysControlled = days;
        _bestStreak = best;
        _rank = rank;
      });
    }
  }

  Future<void> _runDailyCheck() async {
    await DisciplineService.runDailyCheck();
    await _loadDisciplineData();
  }

  void _onDateSelected(DateTime date) {
    setState(() => _selectedDate = date);
  }

  /// Gate pro features - show paywall if not premium
  Future<bool> _requirePro() async {
    final isPro = await PremiumService.isPremium();
    if (!isPro && mounted) {
      Navigator.push(context, MaterialPageRoute(fullscreenDialog: true, builder: (_) => const PaywallScreen()));
      return false;
    }
    return true;
  }

  void _showShareCard() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        margin: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ShareCard(
              score: _score,
              daysControlled: _daysControlled,
              bestStreak: _bestStreak,
              rank: _rank.title,
              totalOrders: 0,
              rulesHeld: 0,
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () {
                ShareCard.shareAsImage(ctx);
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'SHARE',
                  style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: 2),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final habitEngine = ref.watch(habitEngineProvider);
    final allHabits = habitEngine.habits;

    final dayOrders = allHabits.where((h) => h.isScheduledForDate(_selectedDate)).toList();
    final completedCount = dayOrders.where((h) => h.isDoneOn(_selectedDate)).length;
    final total = dayOrders.length;
    final hasFailed = SergeantService.hasPendingPunishment();

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

    final scoreColor = _score >= 80
        ? const Color(0xFF16A34A)
        : _score >= 50
            ? const Color(0xFFF59E0B)
            : const Color(0xFFDC2626);

    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(),

            // ===== SERGEANT STATUS BANNER =====
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 18, horizontal: AppSpacing.lg),
              color: statusColor.withOpacity(0.12),
              child: Row(
                children: [
                  // Status
                  Expanded(
                    child: Text(
                      status,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 4,
                      ),
                    ),
                  ),
                  // Rank badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: statusColor.withOpacity(0.3)),
                    ),
                    child: Text(
                      _rank.title,
                      style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.md),

            // ===== DISCIPLINE SCORE + STREAK (tappable for share) =====
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: GestureDetector(
                onTap: _showShareCard,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0A0A0A),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.06)),
                  ),
                  child: Row(
                    children: [
                      // Score
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'DISCIPLINE',
                            style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 3),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$_score',
                            style: TextStyle(color: scoreColor, fontSize: 42, fontWeight: FontWeight.w900, height: 1),
                          ),
                        ],
                      ),
                      const Spacer(),
                      // Days controlled
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'DAYS CONTROLLED',
                            style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 2),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$_daysControlled',
                            style: const TextStyle(color: Colors.white, fontSize: 42, fontWeight: FontWeight.w900, height: 1),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.md),

            // Date strip
            DateStrip(
              selectedDate: _selectedDate,
              onDateSelected: _onDateSelected,
              accentColor: AppColors.emerald,
            ),

            const SizedBox(height: AppSpacing.md),

            // ===== KILL URGE BUTTON =====
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: GestureDetector(
                onTap: () async {
                  if (!await _requirePro()) return;
                  if (mounted) Navigator.of(context).push(MaterialPageRoute(fullscreenDialog: true, builder: (_) => const TemptedScreen()));
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFFEA580C), Color(0xFFDC2626)]),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(color: const Color(0xFFEA580C).withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 4))],
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.local_fire_department, color: Colors.white, size: 20),
                      SizedBox(width: 8),
                      Text('KILL URGE', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: 2)),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.xl),

            // ===== ORDERS =====
            if (orders.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Text('ORDERS', style: TextStyle(color: Colors.white.withOpacity(0.25), fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 3)),
              ),
              const SizedBox(height: 10),
              ...orders.asMap().entries.map((e) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: _buildOrderCard(e.value, e.value.isDoneOn(_selectedDate), e.key),
              )),
            ],

            // ===== RULES =====
            if (rules.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.lg),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Text('RULES', style: TextStyle(color: Colors.white.withOpacity(0.25), fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 3)),
              ),
              const SizedBox(height: 10),
              ...rules.asMap().entries.map((e) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: _buildRuleCard(e.value, e.value.isDoneOn(_selectedDate), e.key),
              )),
            ],

            if (dayOrders.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 32, AppSpacing.lg, 0),
                child: Text('NO ORDERS SET', style: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 3), textAlign: TextAlign.center),
              ),

            const SizedBox(height: 120),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderCard(Habit habit, bool isDone, int index) {
    String? time;
    if (habit.time.isNotEmpty) {
      try { time = DateFormat('HH:mm').format(DateTime.parse('2025-01-01 ${habit.time}:00')); } catch (_) {}
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: () async {
          final violation = await ref.read(habitEngineProvider).toggleHabitCompletion(habit.id);
          if (violation != null && context.mounted) {
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => PunishmentScreen(violation: violation, onComplete: () => Navigator.of(context).pop())));
          }
          if (!isDone) {
            await DisciplineService.onOrderCompleted();
            await _loadDisciplineData();
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isDone ? const Color(0xFF16A34A).withOpacity(0.06) : const Color(0xFF0D0D0D),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDone ? const Color(0xFF16A34A).withOpacity(0.25) : const Color(0xFF16A34A).withOpacity(0.1)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(color: const Color(0xFF16A34A).withOpacity(0.12), borderRadius: BorderRadius.circular(4)),
                child: const Text('DO', style: TextStyle(color: Color(0xFF16A34A), fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      habit.title.toUpperCase(),
                      style: TextStyle(
                        color: Colors.white.withOpacity(isDone ? 0.4 : 0.9),
                        fontSize: 15, fontWeight: FontWeight.w700,
                        decoration: isDone ? TextDecoration.lineThrough : null, decorationColor: Colors.white30,
                      ),
                    ),
                    if (time != null) Text('DUE $time', style: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 11, fontFamily: 'monospace')),
                  ],
                ),
              ),
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: isDone ? const Color(0xFF16A34A) : Colors.transparent,
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(color: isDone ? const Color(0xFF16A34A) : const Color(0xFF16A34A).withOpacity(0.25), width: 2),
                ),
                child: isDone ? const Icon(Icons.check, color: Colors.black, size: 18) : null,
              ),
            ],
          ),
        ),
      ),
    ).animate(delay: (index * 40).ms).fadeIn(duration: 200.ms);
  }

  Widget _buildRuleCard(Habit habit, bool isBroken, int index) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: () async {
          if (isBroken) return;
          if (!await _requirePro()) return;
          final violation = await ref.read(habitEngineProvider).toggleHabitCompletion(habit.id);
          if (violation != null && context.mounted) {
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => PunishmentScreen(violation: violation, onComplete: () => Navigator.of(context).pop())));
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isBroken ? const Color(0xFFDC2626).withOpacity(0.08) : const Color(0xFF0D0808),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isBroken ? const Color(0xFFDC2626).withOpacity(0.3) : const Color(0xFFDC2626).withOpacity(0.1)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(color: const Color(0xFFDC2626).withOpacity(0.12), borderRadius: BorderRadius.circular(4)),
                child: const Text('AVOID', style: TextStyle(color: Color(0xFFDC2626), fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(habit.title.toUpperCase(), style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 15, fontWeight: FontWeight.w700)),
                    Text(isBroken ? 'RULE BROKEN' : 'STAY CLEAN', style: TextStyle(color: isBroken ? const Color(0xFFDC2626).withOpacity(0.6) : Colors.white.withOpacity(0.15), fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: isBroken ? const Color(0xFFDC2626).withOpacity(0.15) : const Color(0xFFDC2626),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isBroken ? 'FAILED' : 'I BROKE IT',
                  style: TextStyle(color: isBroken ? const Color(0xFFDC2626) : Colors.white, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1),
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
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.xl, AppSpacing.lg, AppSpacing.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.asset('assets/icon/app_icon.png', width: 36, height: 36, fit: BoxFit.cover)),
              const SizedBox(width: 8),
              const Text('HABITDRILL', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 2)),
            ],
          ),
          Row(
            children: [
              GestureDetector(
                onTap: _showShareCard,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(LucideIcons.share2, color: Colors.white.withOpacity(0.4), size: 22),
                ),
              ),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(fullscreenDialog: true, builder: (_) => const PaywallScreen())),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(gradient: AppColors.emeraldGradient, borderRadius: BorderRadius.circular(8)),
                  child: const Text('PRO', style: TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.w800)),
                ),
              ),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(LucideIcons.settings, color: Colors.white.withOpacity(0.35), size: 22),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
