import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../design/tokens.dart';
import '../models/habit.dart';
import '../providers/habit_provider.dart';
import '../services/alarm_service.dart';
import '../services/analytics_service.dart';
// Screen Time UI is dormant. Services stay in the tree so we can flip
// the flag when the entitlement lands.
// import '../services/screen_time_prefs.dart';
// import '../services/screen_time_service.dart';
// Screen Time UI is commented out — see below. Setup screen kept in the
// tree but no route in.
// import 'law_screen_time_setup_screen.dart';
import 'new_contract_screen.dart';
import 'new_contract_templates_screen.dart';
import 'new_wake_alarm_screen.dart';

class ContractsScreen extends ConsumerStatefulWidget {
  const ContractsScreen({super.key});

  @override
  ConsumerState<ContractsScreen> createState() => _ContractsScreenState();
}

class _ContractsScreenState extends ConsumerState<ContractsScreen> {
  @override
  void initState() {
    super.initState();
    AnalyticsService.logScreenView('contracts');
  }

  Future<void> _openEdit(Habit habit) async {
    HapticFeedback.selectionClick();
    await Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => NewContractScreen(edit: habit),
      ),
    );
  }

  Future<void> _openTemplates() async {
    HapticFeedback.selectionClick();
    await Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const NewContractTemplatesScreen(),
      ),
    );
  }

  Future<void> _openNewWakeAlarm({Habit? edit}) async {
    HapticFeedback.selectionClick();
    await Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => NewWakeAlarmScreen(edit: edit),
      ),
    );
  }

  // Screen Time setup is dormant. Kept as a comment so the wiring is
  // one uncomment away when we come back to it.
  //
  // Future<void> _openScreenTimeSetup(Habit habit) async {
  //   HapticFeedback.selectionClick();
  //   await Navigator.of(context).push(
  //     MaterialPageRoute(
  //       fullscreenDialog: true,
  //       builder: (_) => LawScreenTimeSetupScreen(habit: habit),
  //     ),
  //   );
  //   if (mounted) setState(() {});
  // }

  Future<void> _showAddSheet() async {
    HapticFeedback.mediumImpact();
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AddSheet(),
    );
    if (choice == 'alarm') {
      await _openNewWakeAlarm();
    } else if (choice == 'contract') {
      HapticFeedback.selectionClick();
      // Empty title so the field stays as placeholder — user types
      // their own goal. Type + default emoji + duration primed.
      await Navigator.of(context).push(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => const NewContractScreen(
            preset: PresetParams(
              title: '',
              emoji: '🎯',
              targetDays: 30,
              type: 'habit',
            ),
          ),
        ),
      );
    } else if (choice == 'law') {
      HapticFeedback.selectionClick();
      await Navigator.of(context).push(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => const NewContractScreen(
            preset: PresetParams(
              title: '',
              emoji: '🚫',
              targetDays: 90,
              type: 'bad_habit',
            ),
          ),
        ),
      );
    } else if (choice == 'templates') {
      await _openTemplates();
    }
  }

  Future<void> _toggleAlarm(Habit h, bool on) async {
    HapticFeedback.selectionClick();
    final updated = h.copyWith(reminderOn: on);
    await ref.read(habitEngineProvider).updateHabit(updated);
    if (on && updated.time.isNotEmpty) {
      await AlarmService.scheduleAlarm(updated);
    } else {
      await AlarmService.cancelAlarm(h.id);
    }
  }

  Future<void> _confirmDelete(Habit h) async {
    HapticFeedback.mediumImpact();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => _DeleteDialog(title: h.title),
    );
    if (confirmed == true) {
      await ref.read(habitEngineProvider).deleteHabit(h.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final engine = ref.watch(habitEngineProvider);
    final now = DateTime.now();
    final all = List<Habit>.from(engine.habits);
    all.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final active = all.where((h) {
      final end = DateTime(h.endDate.year, h.endDate.month, h.endDate.day);
      final today = DateTime(now.year, now.month, now.day);
      return !end.isBefore(today);
    }).toList();
    final history = all.where((h) {
      final end = DateTime(h.endDate.year, h.endDate.month, h.endDate.day);
      final today = DateTime(now.year, now.month, now.day);
      return end.isBefore(today);
    }).toList();

    // Wake alarms = active habits with a scheduled time. Everything else
    // is a plain contract. Two visually distinct sections so users see
    // what's ringing them at what time before they see their promises.
    final wakeAlarms = active.where((h) => h.time.isNotEmpty).toList();
    final contracts = active.where((h) => h.time.isEmpty).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.emerald,
          backgroundColor: const Color(0xFF0B0B0B),
          onRefresh: () async => ref.read(habitEngineProvider).loadHabits(),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              const SliverToBoxAdapter(child: _Header()),
              if (wakeAlarms.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: _SectionLabel(label: 'ALARMS', count: wakeAlarms.length),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList.builder(
                    itemCount: wakeAlarms.length,
                    itemBuilder: (context, i) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _WakeAlarmCard(
                        habit: wakeAlarms[i],
                        index: i,
                        onEdit: () => _openNewWakeAlarm(edit: wakeAlarms[i]),
                        onToggle: (v) => _toggleAlarm(wakeAlarms[i], v),
                        onLongPress: () => _confirmDelete(wakeAlarms[i]),
                      ),
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 20)),
              ],
              SliverToBoxAdapter(
                child: _SectionLabel(
                  label: 'LAWS & CONTRACTS',
                  count: contracts.length,
                ),
              ),
              if (contracts.isEmpty)
                const SliverToBoxAdapter(child: _EmptyState())
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList.builder(
                    itemCount: contracts.length,
                    itemBuilder: (context, i) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _ContractCard(
                        habit: contracts[i],
                        index: i,
                        onTap: () => _openEdit(contracts[i]),
                        onLongPress: () => _confirmDelete(contracts[i]),
                        // onVerify: Screen Time verification is dormant.
                        onVerify: null,
                      ),
                    ),
                  ),
                ),
              if (history.isNotEmpty) ...[
                const SliverToBoxAdapter(child: SizedBox(height: 32)),
                SliverToBoxAdapter(child: _SectionLabel(label: 'HISTORY', count: history.length)),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList.builder(
                    itemCount: history.length,
                    itemBuilder: (context, i) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _HistoryRow(habit: history[i]),
                    ),
                  ),
                ),
              ],
              // Bottom padding — leave room for the FAB + the nav bar.
              const SliverToBoxAdapter(child: SizedBox(height: 120)),
            ],
          ),
        ),
      ),
      floatingActionButton: _AddFab(onTap: _showAddSheet),
    );
  }
}

// ────────────────────────── Small + FAB ──────────────────────────

class _AddFab extends StatelessWidget {
  final VoidCallback onTap;
  const _AddFab({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Was 70 — too close to the nav bar. 110 lifts it a real
      // finger's width above the tab bar so the tap target is
      // unambiguous and matches the rest of the app's floating buttons.
      padding: const EdgeInsets.only(bottom: 110),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            gradient: AppColors.emeraldGradient,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.emerald.withOpacity(0.45),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(
            LucideIcons.plus,
            color: Colors.black,
            size: 26,
          ),
        ),
      ),
    );
  }
}

// ────────────────────────── FAB action sheet ────────────────────────

class _AddSheet extends StatelessWidget {
  const _AddSheet();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0B0B0B),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 20,
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
          const SizedBox(height: 20),
          _SheetOption(
            icon: LucideIcons.alarmClock,
            title: 'NEW WAKE ALARM',
            subtitle: 'Fires at a set time. You pick the reps.',
            onTap: () => Navigator.of(context).pop('alarm'),
          ),
          _SheetOption(
            icon: LucideIcons.scroll,
            title: 'NEW CONTRACT',
            subtitle: 'A goal to build. Exercise, study, whatever compounds.',
            onTap: () => Navigator.of(context).pop('contract'),
          ),
          _SheetOption(
            icon: LucideIcons.ban,
            title: 'NEW LAW',
            subtitle: 'A rule to break. Vape, porn, junk. We pick the price.',
            onTap: () => Navigator.of(context).pop('law'),
          ),
          _SheetOption(
            icon: LucideIcons.layoutGrid,
            title: 'BROWSE TEMPLATES',
            subtitle: 'Pick from the popular ones.',
            onTap: () => Navigator.of(context).pop('templates'),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

class _SheetOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _SheetOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.emerald.withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.emerald.withOpacity(0.3)),
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: AppColors.emerald, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.45),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
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

// ────────────────────────── Wake alarm card ─────────────────────────

class _WakeAlarmCard extends StatelessWidget {
  final Habit habit;
  final int index;
  final VoidCallback onEdit;
  final ValueChanged<bool> onToggle;
  final VoidCallback onLongPress;

  const _WakeAlarmCard({
    required this.habit,
    required this.index,
    required this.onEdit,
    required this.onToggle,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onEdit,
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
        decoration: BoxDecoration(
          color: const Color(0xFF0B0B0B),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: habit.reminderOn
                ? AppColors.emerald.withOpacity(0.25)
                : Colors.white.withOpacity(0.05),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  habit.time,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1,
                    fontFeatures: [FontFeature.tabularFigures()],
                    height: 1,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  habit.title.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.6,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _daysLabel(habit.repeatDays),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.35),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Switch.adaptive(
                  value: habit.reminderOn,
                  onChanged: onToggle,
                  activeColor: AppColors.emerald,
                ),
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: onEdit,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          LucideIcons.pencil,
                          color: Colors.white.withOpacity(0.6),
                          size: 12,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'EDIT',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    )
        .animate(delay: (index * 60).ms)
        .fadeIn(duration: 300.ms)
        .slideY(begin: 0.04, end: 0);
  }

  String _daysLabel(List<int> days) {
    if (days.length == 7) return 'EVERY DAY';
    if (days.length == 5 &&
        days.contains(1) &&
        days.contains(2) &&
        days.contains(3) &&
        days.contains(4) &&
        days.contains(5)) {
      return 'WEEKDAYS';
    }
    if (days.length == 2 && days.contains(0) && days.contains(6)) {
      return 'WEEKENDS';
    }
    const labels = ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'];
    return days.map((d) => labels[d]).join(' · ');
  }
}

// ────────────────────────── Header ──────────────────────────

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 6,
                height: 22,
                decoration: BoxDecoration(
                  color: AppColors.emerald,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'CONTRACTS',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 4,
                  height: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.only(left: 18),
            child: Text(
              'Every promise creates accountability.',
              style: TextStyle(
                color: Colors.white.withOpacity(0.35),
                fontSize: 12,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms);
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  final int? count;
  const _SectionLabel({required this.label, this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.45),
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 4,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Container(height: 1, color: Colors.white.withOpacity(0.06))),
          if (count != null) ...[
            const SizedBox(width: 10),
            Text(
              count.toString().padLeft(2, '0'),
              style: TextStyle(
                color: Colors.white.withOpacity(0.35),
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ────────────────────────── Contract card ──────────────────────────

class _ContractCard extends StatefulWidget {
  final Habit habit;
  final int index;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback? onVerify;

  const _ContractCard({
    required this.habit,
    required this.index,
    required this.onTap,
    required this.onLongPress,
    this.onVerify,
  });

  @override
  State<_ContractCard> createState() => _ContractCardState();
}

class _ContractCardState extends State<_ContractCard> {
  // Screen Time state is dormant — kept as stubs so widget.onVerify == null
  // continues to work and we don't have to reshape the widget when we
  // come back to it.
  final bool _verified = false;
  final int _minutesToday = 0;
  final int _budgetMinutes = 0;

  Future<void> _loadVerificationState() async {
    // no-op while Screen Time is off
  }

  @override
  Widget build(BuildContext context) {
    final view = _ContractView.fromHabit(widget.habit);
    final accent = view.accent;
    return GestureDetector(
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0B0B0B),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.05), width: 1),
        ),
        padding: const EdgeInsets.fromLTRB(20, 18, 18, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(view.emoji, style: const TextStyle(fontSize: 28, height: 1)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.habit.title.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.4,
                          height: 1.1,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        view.typeLabel,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.35),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                _DayBadge(view: view, accent: accent),
              ],
            ),
            if (view.hasTarget) ...[
              const SizedBox(height: 16),
              _ProgressBar(progress: view.progress, accent: accent),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${(view.progress * 100).round()}%',
                    style: TextStyle(
                      color: accent.withOpacity(0.85),
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  Text(
                    '${view.daysRemaining} DAYS LEFT',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.35),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ],
            // Screen Time verify chip is dormant — the whole feature is
            // commented out until we come back to it. When it returns,
            // wire onVerify from ContractsScreen and the block below
            // renders again automatically.
            //
            // if (widget.onVerify != null) ...[
            //   const SizedBox(height: 14),
            //   _VerifiedChip(...)
            // ],
          ],
        ),
      ),
    ).animate(delay: (widget.index * 70).ms).fadeIn(duration: 350.ms).slideY(begin: 0.05, end: 0);
  }
}

class _VerifiedChip extends StatelessWidget {
  final bool verified;
  final int minutesUsed;
  final int budget;
  final String categoryLabel;
  final VoidCallback onTap;

  const _VerifiedChip({
    required this.verified,
    required this.minutesUsed,
    required this.budget,
    required this.categoryLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (!verified) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons.eye, size: 12, color: Colors.white.withOpacity(0.5)),
              const SizedBox(width: 6),
              Text(
                'VERIFY WITH SCREEN TIME',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.55),
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
        ),
      );
    }
    final over = budget > 0 && minutesUsed > budget;
    final progress = budget == 0
        ? (minutesUsed > 0 ? 1.0 : 0.0)
        : (minutesUsed / budget).clamp(0.0, 1.0).toDouble();
    final chipColor = over ? AppColors.error : AppColors.emerald;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        decoration: BoxDecoration(
          color: chipColor.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: chipColor.withOpacity(0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(LucideIcons.eye, size: 12, color: chipColor),
                const SizedBox(width: 6),
                Text(
                  over ? 'BROKEN' : 'VERIFIED',
                  style: TextStyle(
                    color: chipColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
                const Spacer(),
                Text(
                  '$minutesUsed${budget > 0 ? "/$budget" : ""} MIN',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 3,
                backgroundColor: Colors.white.withOpacity(0.06),
                valueColor: AlwaysStoppedAnimation(chipColor),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DayBadge extends StatelessWidget {
  final _ContractView view;
  final Color accent;
  const _DayBadge({required this.view, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: accent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accent.withOpacity(0.25), width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            view.progressLabel,
            style: TextStyle(
              color: accent,
              fontSize: 14,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
              height: 1,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 3),
          Text(
            view.hasTarget ? 'DAYS' : 'DAY STREAK',
            style: TextStyle(
              color: accent.withOpacity(0.6),
              fontSize: 8,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final double progress;
  final Color accent;
  const _ProgressBar({required this.progress, required this.accent});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) => Container(
        height: 3,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(2),
        ),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Container(
            width: c.maxWidth * progress,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ),
    );
  }
}

// ────────────────────────── New contract grid ──────────────────────────

class _NewContractGrid extends StatelessWidget {
  final ValueChanged<_Preset> onPreset;
  final VoidCallback onBuildOwn;
  const _NewContractGrid({required this.onPreset, required this.onBuildOwn});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 2.4,
          ),
          itemCount: _Preset.presets.length,
          itemBuilder: (context, i) => _TemplateChip(
            preset: _Preset.presets[i],
            onTap: () => onPreset(_Preset.presets[i]),
          ).animate(delay: (i * 40).ms).fadeIn(duration: 250.ms),
        ),
        const SizedBox(height: 10),
        _BuildYourOwnCard(onTap: onBuildOwn).animate(delay: 300.ms).fadeIn(duration: 250.ms),
      ],
    );
  }
}

class _TemplateChip extends StatelessWidget {
  final _Preset preset;
  final VoidCallback onTap;
  const _TemplateChip({required this.preset, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF0B0B0B),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.05), width: 1),
        ),
        child: Row(
          children: [
            Text(preset.emoji, style: const TextStyle(fontSize: 20, height: 1)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                preset.title.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BuildYourOwnCard extends StatelessWidget {
  final VoidCallback onTap;
  const _BuildYourOwnCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.emerald.withOpacity(0.15), AppColors.emerald.withOpacity(0.05)],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.emerald.withOpacity(0.35), width: 1),
        ),
        child: const Center(
          child: Text(
            '+  BUILD MY OWN',
            style: TextStyle(
              color: AppColors.emerald,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 3,
            ),
          ),
        ),
      ),
    );
  }
}

// ────────────────────────── History row + empty state + delete dialog ──

class _HistoryRow extends StatelessWidget {
  final Habit habit;
  const _HistoryRow({required this.habit});

  @override
  Widget build(BuildContext context) {
    final view = _ContractView.fromHabit(habit);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF080808),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.03), width: 1),
      ),
      child: Row(
        children: [
          Text(view.emoji, style: const TextStyle(fontSize: 18, height: 1)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              habit.title.toUpperCase(),
              style: TextStyle(
                color: Colors.white.withOpacity(0.55),
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            'ENDED',
            style: TextStyle(
              color: Colors.white.withOpacity(0.3),
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }
}

class _NewContractButton extends StatelessWidget {
  final VoidCallback onTap;
  const _NewContractButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          gradient: AppColors.emeraldGradient,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: AppColors.emerald.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(LucideIcons.plus, color: Colors.black, size: 20),
            SizedBox(width: 8),
            Text(
              'NEW CONTRACT',
              style: TextStyle(
                color: Colors.black,
                fontSize: 14,
                fontWeight: FontWeight.w900,
                letterSpacing: 3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 28),
        decoration: BoxDecoration(
          color: const Color(0xFF080808),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.04), width: 1),
        ),
        child: Column(
          children: [
            Text(
              'NO ACTIVE CONTRACTS',
              style: TextStyle(
                color: Colors.white.withOpacity(0.35),
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 3,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Pick one below to make your first promise.',
              style: TextStyle(
                color: Colors.white.withOpacity(0.25),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeleteDialog extends StatelessWidget {
  final String title;
  const _DeleteDialog({required this.title});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF0B0B0B),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.white.withOpacity(0.06)),
      ),
      title: const Text(
        'BREAK CONTRACT?',
        style: TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w900,
          letterSpacing: 2,
        ),
      ),
      content: Text(
        'This will delete "$title" and cancel any alarms attached to it.',
        style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(
            'CANCEL',
            style: TextStyle(color: Colors.white.withOpacity(0.5), fontWeight: FontWeight.w800, letterSpacing: 1.5),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text(
            'BREAK',
            style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w900, letterSpacing: 1.5),
          ),
        ),
      ],
    );
  }
}

// ────────────────────────── Contract view (derived from Habit) ──────────

class _ContractView {
  final String emoji;
  final int daysCompleted;
  final int? targetDays;
  final double progress;
  final int daysRemaining;
  final int streak;
  final String typeLabel;
  final Color accent;

  const _ContractView({
    required this.emoji,
    required this.daysCompleted,
    required this.targetDays,
    required this.progress,
    required this.daysRemaining,
    required this.streak,
    required this.typeLabel,
    required this.accent,
  });

  bool get hasTarget => targetDays != null;
  String get progressLabel => hasTarget ? '$daysCompleted / $targetDays' : '$streak Days';

  static _ContractView fromHabit(Habit h) {
    final now = DateTime.now();
    final start = DateTime(h.startDate.year, h.startDate.month, h.startDate.day);
    final end = DateTime(h.endDate.year, h.endDate.month, h.endDate.day);
    final total = end.difference(start).inDays;
    final elapsed = now.difference(start).inDays.clamp(0, total);
    // A "contract" (time-bounded challenge) is a Habit whose window is > 6 days
    // and less than a full year — anything longer is treated as an open-ended
    // streak habit.
    final bool timeBounded = total >= 7 && total <= 365;
    return _ContractView(
      emoji: h.emoji ?? _defaultEmoji(h.type),
      daysCompleted: elapsed,
      targetDays: timeBounded ? total : null,
      progress: total == 0 ? 0 : (elapsed / total).clamp(0.0, 1.0),
      daysRemaining: (total - elapsed).clamp(0, total),
      streak: h.streak,
      typeLabel: _typeLabel(h.type),
      accent: h.type == 'bad_habit' ? AppColors.error : AppColors.emerald,
    );
  }

  static String _typeLabel(String type) {
    switch (type) {
      case 'bad_habit':
        return 'RULE';
      case 'task':
        return 'TASK';
      default:
        return 'ORDER';
    }
  }

  static String _defaultEmoji(String type) {
    switch (type) {
      case 'bad_habit':
        return '🚫';
      case 'task':
        return '📋';
      default:
        return '🎯';
    }
  }
}

// ────────────────────────── Presets ──────────────────────────

class _Preset {
  final String title;
  final String emoji;
  final int targetDays;
  final String type; // habit | bad_habit | task

  const _Preset({
    required this.title,
    required this.emoji,
    required this.targetDays,
    required this.type,
  });

  PresetParams toParams() => PresetParams(
        title: title,
        emoji: emoji,
        targetDays: targetDays,
        type: type,
      );

  static const List<_Preset> presets = [
    _Preset(title: 'Quit Vape', emoji: '🚭', targetDays: 90, type: 'bad_habit'),
    _Preset(title: '75 Hard', emoji: '🔥', targetDays: 75, type: 'habit'),
    _Preset(title: 'Monk Mode', emoji: '🧘', targetDays: 30, type: 'habit'),
    _Preset(title: 'No Sugar', emoji: '🍬', targetDays: 30, type: 'bad_habit'),
    _Preset(title: 'Creator Mode', emoji: '🎨', targetDays: 30, type: 'habit'),
  ];
}

/// Shared preset params passed into NewContractScreen.
class PresetParams {
  final String title;
  final String emoji;
  final int targetDays;
  final String type;

  const PresetParams({
    required this.title,
    required this.emoji,
    required this.targetDays,
    required this.type,
  });
}
