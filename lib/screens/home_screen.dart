import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../design/tokens.dart';
import '../widgets/date_strip.dart';
import '../widgets/share_card.dart';
import '../screens/achievements_screen.dart';
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
    final hasFailed = SergeantService.hasPendingPunishment();

    // Split the day. The wake alarm gets its own hero — different weight
    // from a regular contract because it is the keystone habit and the
    // one thing the whole app is built around.
    final wakeAlarms = dayOrders
        .where((h) => h.type == 'habit' && h.time.isNotEmpty && h.reminderOn)
        .toList();
    final orders = dayOrders
        .where((h) => h.type != 'bad_habit' && !wakeAlarms.contains(h))
        .toList();
    final rules = dayOrders.where((h) => h.type == 'bad_habit').toList();

    // Orders (positive habits) count as "safe" when done.
    // Rules (bad habits) count as "safe" when NOT pressed — the user
    // held the line. Pressing "I broke it" is confessing a slip, so
    // toggling a rule ON = broken state, not completed.
    final ordersDone = orders.where((h) => h.isDoneOn(_selectedDate)).length;
    final rulesBroken = rules.where((h) => h.isDoneOn(_selectedDate)).length;
    final allOrdersDone = orders.isNotEmpty && ordersDone == orders.length;
    final anyRuleBroken = rulesBroken > 0;

    // Status
    String status;
    Color statusColor;
    if (hasFailed || anyRuleBroken) {
      // Pending punishment OR a rule confessed today → broken state.
      // hasFailed also catches the case where a rule was pressed on a
      // prior day and the punishment is still pending.
      status = 'BROKEN';
      statusColor = const Color(0xFFDC2626);
    } else if (orders.isEmpty && rules.isNotEmpty) {
      // Rules-only day and none broken → held the line.
      status = 'CONTROLLED';
      statusColor = const Color(0xFF16A34A);
    } else if (allOrdersDone) {
      // All positive orders done and no rules broken.
      status = 'CONTROLLED';
      statusColor = const Color(0xFF16A34A);
    } else if (orders.isNotEmpty) {
      // Positive orders remain undone.
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

            // Date strip pushed right up under AT RISK banner
            const SizedBox(height: 6),
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

            // ===== WAKE ALARM HERO =====
            // Own section, above ORDERS. Different visual from the
            // contract cards below — this is the keystone habit.
            if (wakeAlarms.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Text(
                  'MORNING RISE',
                  style: TextStyle(
                    color: AppColors.emerald.withOpacity(0.6),
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 3,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              for (int i = 0; i < wakeAlarms.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  child: _buildWakeHero(wakeAlarms[i], wakeAlarms[i].isDoneOn(_selectedDate), i),
                ),
              const SizedBox(height: AppSpacing.xl),
            ],

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

            const SizedBox(height: 24),

            // ===== DISCIPLINE SCORE + DAYS CONTROLLED — now at the bottom =====
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

            const SizedBox(height: 120),
          ],
        ),
      ),
    );
  }

  /// Big Morning Rise card. Shows the fire time huge, name, streak,
  /// and a status pill. Deliberately different visual weight from the
  /// contract cards below — this is the keystone habit and shouldn't
  /// look like just another to-do.
  Widget _buildWakeHero(Habit habit, bool isDone, int index) {
    String time = habit.time;
    try {
      time = DateFormat('HH:mm').format(DateTime.parse('2025-01-01 ${habit.time}:00'));
    } catch (_) {}
    final streak = habit.streak;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(20, 18, 18, 18),
      decoration: BoxDecoration(
        color: const Color(0xFF0B0B0B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDone
              ? AppColors.emerald.withOpacity(0.5)
              : Colors.white.withOpacity(0.06),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Big time — the only thing that dominates.
          Text(
            time,
            style: TextStyle(
              color: isDone
                  ? AppColors.emerald
                  : Colors.white.withOpacity(0.98),
              fontSize: 44,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.5,
              height: 1,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  habit.title.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.6,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      _daysLabel(habit.repeatDays),
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.35),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                      ),
                    ),
                    if (streak > 0) ...[
                      Text(
                        '  ·  ',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.15),
                          fontSize: 10,
                        ),
                      ),
                      const Text('🔥', style: TextStyle(fontSize: 10)),
                      Text(
                        ' $streak',
                        style: TextStyle(
                          color: AppColors.fire.withOpacity(0.9),
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // Status indicator — small circle. Emerald ring + check when
          // done, quiet alarm icon when armed.
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isDone
                  ? AppColors.emerald.withOpacity(0.15)
                  : Colors.white.withOpacity(0.04),
              shape: BoxShape.circle,
              border: Border.all(
                color: isDone
                    ? AppColors.emerald
                    : Colors.white.withOpacity(0.15),
                width: 1.4,
              ),
            ),
            alignment: Alignment.center,
            child: Icon(
              isDone ? Icons.check_rounded : Icons.alarm_rounded,
              color: isDone
                  ? AppColors.emerald
                  : Colors.white.withOpacity(0.55),
              size: 20,
            ),
          ),
        ],
      ),
    ).animate(delay: (index * 60).ms).fadeIn(duration: 300.ms).slideY(begin: 0.04, end: 0);
  }

  String _daysLabel(List<int> days) {
    if (days.length == 7) return 'EVERY DAY';
    if (days.length == 5 &&
        [1, 2, 3, 4, 5].every(days.contains)) return 'WEEKDAYS';
    if (days.length == 2 && days.contains(0) && days.contains(6)) return 'WEEKENDS';
    const l = ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'];
    return days.map((d) => l[d]).join(' · ');
  }

  Widget _buildOrderCard(Habit habit, bool isDone, int index) {
    String? time;
    if (habit.time.isNotEmpty) {
      try { time = DateFormat('HH:mm').format(DateTime.parse('2025-01-01 ${habit.time}:00')); } catch (_) {}
    }
    final emoji = habit.emoji ?? '🎯';
    final streak = habit.streak;

    Future<void> toggle() async {
      HapticFeedback.mediumImpact();
      final violation = await ref.read(habitEngineProvider).toggleHabitCompletion(habit.id);
      if (violation != null && context.mounted) {
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => PunishmentScreen(violation: violation, onComplete: () => Navigator.of(context).pop())));
      }
      if (!isDone) {
        await DisciplineService.onOrderCompleted();
        await _loadDisciplineData();
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: toggle,
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 16, 12, 16),
          decoration: BoxDecoration(
            color: const Color(0xFF0B0B0B),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDone ? AppColors.emerald.withOpacity(0.35) : Colors.white.withOpacity(0.05),
              width: 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 26, height: 1)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      habit.title.toUpperCase(),
                      style: TextStyle(
                        color: Colors.white.withOpacity(isDone ? 0.45 : 0.95),
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.4,
                        height: 1.1,
                        decoration: isDone ? TextDecoration.lineThrough : null,
                        decorationColor: Colors.white38,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          'ORDER',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.35),
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                          ),
                        ),
                        if (streak > 0) ...[
                          Text(
                            '  ·  ',
                            style: TextStyle(color: Colors.white.withOpacity(0.15), fontSize: 10),
                          ),
                          Text('🔥', style: const TextStyle(fontSize: 10)),
                          Text(
                            ' $streak',
                            style: TextStyle(
                              color: AppColors.fire.withOpacity(0.8),
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                        ],
                        if (time != null) ...[
                          Text(
                            '  ·  ',
                            style: TextStyle(color: Colors.white.withOpacity(0.15), fontSize: 10),
                          ),
                          Text(
                            time,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.35),
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _TickCircle(done: isDone, onTap: toggle),
            ],
          ),
        ),
      ),
    ).animate(delay: (index * 50).ms).fadeIn(duration: 250.ms).slideY(begin: 0.04, end: 0);
  }

  Widget _buildRuleCard(Habit habit, bool isBroken, int index) {
    final emoji = habit.emoji ?? '🚫';
    final streak = habit.streak;

    Future<void> confess() async {
      if (isBroken) return;
      if (!await _requirePro()) return;
      HapticFeedback.heavyImpact();
      final violation = await ref.read(habitEngineProvider).toggleHabitCompletion(habit.id);
      if (violation != null && context.mounted) {
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => PunishmentScreen(violation: violation, onComplete: () => Navigator.of(context).pop())));
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: confess,
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 16, 12, 16),
          decoration: BoxDecoration(
            color: isBroken ? AppColors.error.withOpacity(0.06) : const Color(0xFF0B0B0B),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isBroken ? AppColors.error.withOpacity(0.35) : Colors.white.withOpacity(0.05),
              width: 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 26, height: 1)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      habit.title.toUpperCase(),
                      style: TextStyle(
                        color: Colors.white.withOpacity(isBroken ? 0.6 : 0.95),
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.4,
                        height: 1.1,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          'RULE',
                          style: TextStyle(
                            color: (isBroken ? AppColors.error : Colors.white).withOpacity(0.5),
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                          ),
                        ),
                        if (!isBroken && streak > 0) ...[
                          Text(
                            '  ·  ',
                            style: TextStyle(color: Colors.white.withOpacity(0.15), fontSize: 10),
                          ),
                          Text('CLEAN ', style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1)),
                          Text(
                            '$streak D',
                            style: TextStyle(
                              color: AppColors.emerald.withOpacity(0.85),
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                        ],
                        if (isBroken) ...[
                          Text(
                            '  ·  ',
                            style: TextStyle(color: Colors.white.withOpacity(0.15), fontSize: 10),
                          ),
                          Text(
                            'BROKEN',
                            style: TextStyle(
                              color: AppColors.error.withOpacity(0.75),
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _BrokeItButton(isBroken: isBroken, onTap: confess),
            ],
          ),
        ),
      ),
    ).animate(delay: (index * 50).ms).fadeIn(duration: 250.ms).slideY(begin: 0.04, end: 0);
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.md, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: 'Habit',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.3,
                  ),
                ),
                TextSpan(
                  text: 'Drill',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: AppColors.emerald,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Streak — big fire icon with the number visible outside the
              // badge so it reads instantly.
              _HeaderIcon(
                icon: LucideIcons.flame,
                color: AppColors.fire,
                badge: _bestStreak > 0 ? '$_bestStreak' : null,
                onTap: _showShareCard,
              ),
              const SizedBox(width: 6),
              _HeaderIcon(
                icon: LucideIcons.award,
                color: const Color(0xFFF59E0B),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AchievementsScreen()),
                ),
              ),
              const SizedBox(width: 6),
              // Settings replaces Share here. Share moved to the Profile
              // tab where the share card actually lives.
              _HeaderIcon(
                icon: LucideIcons.settings,
                color: Colors.white.withOpacity(0.7),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeaderIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String? badge;
  final VoidCallback onTap;
  const _HeaderIcon({required this.icon, required this.color, this.badge, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Ringed disc — icons now render as status badges (36pt
            // circle with colored border and matching glow) so the
            // streak flame and the achievement medal command the row.
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withOpacity(0.14),
                shape: BoxShape.circle,
                border: Border.all(color: color.withOpacity(0.55), width: 1),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.4),
                    blurRadius: 14,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: color, size: 19),
            ),
            if (badge != null)
              Positioned(
                right: -6,
                top: -4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF050505), width: 1.5),
                  ),
                  constraints: const BoxConstraints(minWidth: 16),
                  alignment: Alignment.center,
                  child: Text(
                    badge!,
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ────────────────────────── Tick target for daily orders ──────────

class _TickCircle extends StatelessWidget {
  final bool done;
  final VoidCallback onTap;
  const _TickCircle({required this.done, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          gradient: done ? AppColors.emeraldGradient : null,
          color: done ? null : Colors.transparent,
          shape: BoxShape.circle,
          border: Border.all(
            color: done ? AppColors.emerald : AppColors.emerald.withOpacity(0.4),
            width: 2,
          ),
          boxShadow: done
              ? [BoxShadow(color: AppColors.emerald.withOpacity(0.35), blurRadius: 16, offset: const Offset(0, 4))]
              : null,
        ),
        alignment: Alignment.center,
        child: done
            ? const Icon(Icons.check, color: Colors.black, size: 22)
            : Icon(Icons.check, color: AppColors.emerald.withOpacity(0.35), size: 20),
      ),
    );
  }
}

// ────────────────────────── "I broke it" button for rules ─────────

class _BrokeItButton extends StatelessWidget {
  final bool isBroken;
  final VoidCallback onTap;
  const _BrokeItButton({required this.isBroken, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: isBroken ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isBroken ? AppColors.error.withOpacity(0.12) : AppColors.error,
          borderRadius: BorderRadius.circular(10),
          border: isBroken
              ? Border.all(color: AppColors.error.withOpacity(0.35), width: 1)
              : null,
          boxShadow: isBroken
              ? null
              : [BoxShadow(color: AppColors.error.withOpacity(0.35), blurRadius: 14, offset: const Offset(0, 4))],
        ),
        child: Text(
          isBroken ? 'FAILED' : 'I BROKE IT',
          style: TextStyle(
            color: isBroken ? AppColors.error : Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
          ),
        ),
      ),
    );
  }
}

