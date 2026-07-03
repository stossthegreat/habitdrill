import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../design/tokens.dart';
import '../models/habit.dart';
import '../providers/habit_provider.dart';
import '../services/analytics_service.dart';
import 'new_contract_screen.dart';

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

  Future<void> _openNewContract({Habit? edit, _Preset? preset}) async {
    HapticFeedback.selectionClick();
    await Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => NewContractScreen(edit: edit, preset: preset?.toParams()),
      ),
    );
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
              SliverToBoxAdapter(child: _SectionLabel(label: 'ACTIVE', count: active.length)),
              if (active.isEmpty)
                const SliverToBoxAdapter(child: _EmptyState())
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList.builder(
                    itemCount: active.length,
                    itemBuilder: (context, i) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _ContractCard(
                        habit: active[i],
                        index: i,
                        onTap: () => _openNewContract(edit: active[i]),
                        onLongPress: () => _confirmDelete(active[i]),
                      ),
                    ),
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 32)),
              const SliverToBoxAdapter(child: _SectionLabel(label: 'NEW CONTRACT')),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverToBoxAdapter(
                  child: _NewContractGrid(
                    onPreset: (p) => _openNewContract(preset: p),
                    onBuildOwn: () => _openNewContract(),
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
              const SliverToBoxAdapter(child: SizedBox(height: 40)),
            ],
          ),
        ),
      ),
    );
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

class _ContractCard extends StatelessWidget {
  final Habit habit;
  final int index;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _ContractCard({
    required this.habit,
    required this.index,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final view = _ContractView.fromHabit(habit);
    final accent = view.accent;
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
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
                        habit.title.toUpperCase(),
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
          ],
        ),
      ),
    ).animate(delay: (index * 70).ms).fadeIn(duration: 350.ms).slideY(begin: 0.05, end: 0);
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
