import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../design/tokens.dart';
import '../models/habit.dart';
import '../services/screen_time_prefs.dart';
import '../services/screen_time_service.dart';

/// Turns a Law (bad_habit) into an OS-verified contract.
///
/// Flow:
///   1. If Family Controls is unauthorized, prompt with a purpose-first
///      screen — "HabitDrill watches so you can't lie."
///   2. Pick which app category counts (Social / Entertainment / Games /
///      All). Default: Social.
///   3. Set a daily budget in minutes. Default: 30.
///   4. Optional: enable Shield mode (blocks the category outright once
///      budget is spent; punishment unlocks a 5-minute window). Off by
///      default — measure first, shield later.
///   5. Live preview showing today's actual number ticking up.
///
/// All calls today are stubbed (see `ScreenTimeService`). The UI is
/// production-ready; flipping the entitlement flag in Swift makes every
/// number here become real Family Controls data.
class LawScreenTimeSetupScreen extends StatefulWidget {
  final Habit habit;
  const LawScreenTimeSetupScreen({super.key, required this.habit});

  @override
  State<LawScreenTimeSetupScreen> createState() =>
      _LawScreenTimeSetupScreenState();
}

class _LawScreenTimeSetupScreenState extends State<LawScreenTimeSetupScreen> {
  static const List<int> _budgetChoices = [0, 5, 15, 30, 60, 120];

  String _categoryId = 'social';
  int _budget = 30;
  bool _shield = false;
  bool _saving = false;
  String _authStatus = 'unknown';
  int _todayMinutes = 0;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _load();
    _refreshAuth();
    _refreshLive();
    // Every 3 seconds, refresh the live-usage number so the user sees
    // it climb even while sitting on this setup screen.
    _tick = Timer.periodic(const Duration(seconds: 3), (_) => _refreshLive());
  }

  Future<void> _load() async {
    final cat = await ScreenTimePrefs.getCategory(widget.habit.id);
    final budget = await ScreenTimePrefs.getBudget(widget.habit.id);
    final shield = await ScreenTimePrefs.getShield(widget.habit.id);
    if (!mounted) return;
    setState(() {
      _categoryId = cat;
      _budget = budget;
      _shield = shield;
    });
  }

  Future<void> _refreshAuth() async {
    final s = await ScreenTimeService.authorizationStatus();
    if (!mounted) return;
    setState(() => _authStatus = s);
  }

  Future<void> _refreshLive() async {
    final m = await ScreenTimeService.minutesUsedToday(_categoryId);
    if (!mounted) return;
    setState(() => _todayMinutes = m);
  }

  Future<void> _requestAuth() async {
    HapticFeedback.mediumImpact();
    final s = await ScreenTimeService.requestAuthorization();
    if (!mounted) return;
    setState(() => _authStatus = s);
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    HapticFeedback.heavyImpact();
    await ScreenTimePrefs.setVerified(
      widget.habit.id,
      verified: true,
      categoryId: _categoryId,
      budgetMinutes: _budget,
      shield: _shield,
    );
    if (_shield) {
      await ScreenTimeService.startShield(_categoryId);
    } else {
      await ScreenTimeService.stopShield(_categoryId);
    }
    if (mounted) Navigator.of(context).pop(true);
  }

  Future<void> _disable() async {
    HapticFeedback.mediumImpact();
    await ScreenTimeService.stopShield(_categoryId);
    await ScreenTimePrefs.clear(widget.habit.id);
    if (mounted) Navigator.of(context).pop(false);
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isAuthorized = _authStatus == 'authorized';
    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(onCancel: () => Navigator.of(context).pop(false)),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Header(habitTitle: widget.habit.title),
                    const SizedBox(height: 22),
                    if (!isAuthorized) ...[
                      _AuthCard(
                        status: _authStatus,
                        onRequest: _requestAuth,
                      ),
                      const SizedBox(height: 18),
                    ],
                    _SectionLabel('CATEGORY'),
                    for (final cat in ScreenTimeCategory.all_)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _CategoryRow(
                          category: cat,
                          selected: cat.id == _categoryId,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _categoryId = cat.id);
                            _refreshLive();
                          },
                        ),
                      ),
                    const SizedBox(height: 22),
                    _SectionLabel('DAILY BUDGET'),
                    _BudgetChips(
                      current: _budget,
                      choices: _budgetChoices,
                      onPick: (v) {
                        HapticFeedback.selectionClick();
                        setState(() => _budget = v);
                      },
                    ),
                    const SizedBox(height: 22),
                    _SectionLabel('LIVE'),
                    _LiveTile(
                      minutesUsed: _todayMinutes,
                      budgetMinutes: _budget,
                      authorized: isAuthorized,
                    ),
                    const SizedBox(height: 22),
                    _SectionLabel('SHIELD'),
                    _ShieldTile(
                      value: _shield,
                      onChanged: (v) {
                        HapticFeedback.selectionClick();
                        setState(() => _shield = v);
                      },
                    ),
                    const SizedBox(height: 32),
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
              child: Column(
                children: [
                  _PrimaryCTA(
                    label: 'LOCK IT IN',
                    loading: _saving,
                    onTap: isAuthorized ? _save : _requestAuth,
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _disable,
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        'Disable verification',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.35),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ────────────────────────── Header ────────────────────────────────

class _TopBar extends StatelessWidget {
  final VoidCallback onCancel;
  const _TopBar({required this.onCancel});

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
          const Expanded(
            child: Center(
              child: Text(
                'VERIFIED LAW',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 3,
                ),
              ),
            ),
          ),
          const SizedBox(width: 68),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String habitTitle;
  const _Header({required this.habitTitle});

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
              decoration: BoxDecoration(
                color: AppColors.emerald,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                habitTitle.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                  height: 1,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.only(left: 18),
          child: Text(
            "HabitDrill watches so you can't lie.",
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 2),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white.withOpacity(0.45),
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 3,
        ),
      ),
    );
  }
}

// ────────────────────────── Auth prompt ──────────────────────────

class _AuthCard extends StatelessWidget {
  final String status;
  final VoidCallback onRequest;
  const _AuthCard({required this.status, required this.onRequest});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: AppColors.emerald.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.emerald.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.eye, color: AppColors.emerald, size: 18),
              const SizedBox(width: 8),
              Text(
                'ACCESS REQUIRED',
                style: TextStyle(
                  color: AppColors.emerald,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            "Turn on Screen Time access.\nWe check the OS, not your word.",
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w800,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: onRequest,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.emerald,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'GRANT ACCESS',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2.5,
                ),
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 350.ms);
  }
}

// ────────────────────────── Category row ─────────────────────────

class _CategoryRow extends StatelessWidget {
  final ScreenTimeCategory category;
  final bool selected;
  final VoidCallback onTap;
  const _CategoryRow({
    required this.category,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.emerald.withOpacity(0.08)
              : const Color(0xFF0B0B0B),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? AppColors.emerald.withOpacity(0.5)
                : Colors.white.withOpacity(0.05),
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Row(
          children: [
            Text(category.emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category.label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    category.description,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.4),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: selected ? AppColors.emerald : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected
                      ? AppColors.emerald
                      : Colors.white.withOpacity(0.3),
                  width: 1.5,
                ),
              ),
              child: selected
                  ? const Icon(Icons.check, color: Colors.black, size: 12)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

// ────────────────────────── Budget chips ─────────────────────────

class _BudgetChips extends StatelessWidget {
  final int current;
  final List<int> choices;
  final ValueChanged<int> onPick;
  const _BudgetChips({
    required this.current,
    required this.choices,
    required this.onPick,
  });

  String _label(int mins) {
    if (mins == 0) return 'ZERO';
    if (mins < 60) return '${mins}m';
    return '${mins ~/ 60}h';
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final v in choices)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => onPick(v),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: v == current
                        ? AppColors.emerald
                        : Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    _label(v),
                    style: TextStyle(
                      color: v == current
                          ? Colors.black
                          : Colors.white.withOpacity(0.75),
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ────────────────────────── Live usage tile ──────────────────────

class _LiveTile extends StatelessWidget {
  final int minutesUsed;
  final int budgetMinutes;
  final bool authorized;
  const _LiveTile({
    required this.minutesUsed,
    required this.budgetMinutes,
    required this.authorized,
  });

  @override
  Widget build(BuildContext context) {
    final over = budgetMinutes > 0 && minutesUsed > budgetMinutes;
    final progress = budgetMinutes == 0
        ? (minutesUsed > 0 ? 1.0 : 0.0)
        : (minutesUsed / budgetMinutes).clamp(0.0, 1.0).toDouble();
    final barColor = over
        ? AppColors.error
        : (progress > 0.75 ? const Color(0xFFF59E0B) : AppColors.emerald);
    final statusText = !authorized
        ? 'SIMULATED'
        : over
            ? 'BROKEN'
            : progress > 0.75
                ? 'AT RISK'
                : 'ON TRACK';

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        color: const Color(0xFF0B0B0B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'TODAY',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.45),
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: barColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: barColor.withOpacity(0.4)),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    color: barColor,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$minutesUsed',
                style: TextStyle(
                  color: barColor,
                  fontSize: 40,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1,
                  height: 1,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  budgetMinutes == 0
                      ? 'min · budget 0'
                      : 'min / $budgetMinutes min',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.45),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white.withOpacity(0.06),
              valueColor: AlwaysStoppedAnimation(barColor),
              minHeight: 5,
            ),
          ),
          if (!authorized) ...[
            const SizedBox(height: 10),
            Text(
              'These numbers are simulated until Screen Time access is granted.',
              style: TextStyle(
                color: Colors.white.withOpacity(0.35),
                fontSize: 11,
                fontWeight: FontWeight.w500,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ────────────────────────── Shield toggle ────────────────────────

class _ShieldTile extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  const _ShieldTile({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 12, 14),
      decoration: BoxDecoration(
        color: const Color(0xFF0B0B0B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.shieldOff, color: AppColors.error, size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Block, not just watch',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'When the budget hits zero, the apps go grey. Reps unlock '
                  'them for 5 min.',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.45),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.emerald,
          ),
        ],
      ),
    );
  }
}

// ────────────────────────── Primary CTA ──────────────────────────

class _PrimaryCTA extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback onTap;
  const _PrimaryCTA({
    required this.label,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          gradient: AppColors.emeraldGradient,
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(
              color: AppColors.emerald.withOpacity(0.4),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.black),
              )
            : Text(
                label,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 3,
                ),
              ),
      ),
    );
  }
}
