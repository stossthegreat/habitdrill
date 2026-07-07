import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../design/tokens.dart';
import '../services/discipline_service.dart';
import '../services/ledger_service.dart';

class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  int _days = 0;
  int _best = 0;
  int _totalOrders = 0;
  int _punishments = 0;
  int _reps = 0;
  int _score = 50;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final ledger = await LedgerService.read();
    final score = await DisciplineService.getScore();
    final days = await DisciplineService.getDaysControlled();
    final best = await DisciplineService.getBestStreak();
    final orders = await DisciplineService.getTotalOrdersCompleted();
    if (!mounted) return;
    setState(() {
      _days = days;
      _best = best;
      _totalOrders = orders;
      _punishments = ledger.punishmentsCompleted;
      _reps = ledger.totalReps;
      _score = score;
      _loaded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final medals = _buildMedals();
    final earnedCount = medals.where((m) => m.earned).length;
    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: null,
      ),
      body: SafeArea(
        child: !_loaded
            ? const Center(child: CircularProgressIndicator(color: AppColors.emerald))
            : SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 22,
                          decoration: BoxDecoration(color: AppColors.amber, borderRadius: BorderRadius.circular(2)),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'ACHIEVEMENTS',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 3,
                            height: 1,
                          ),
                        ),
                      ],
                    ).animate().fadeIn(),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.only(left: 18),
                      child: Text(
                        '$earnedCount / ${medals.length} earned. Keep marching.',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.4),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    for (int i = 0; i < medals.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _MedalRow(medal: medals[i])
                            .animate(delay: (60 + i * 50).ms)
                            .fadeIn(duration: 250.ms)
                            .slideX(begin: 0.03, end: 0),
                      ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
      ),
    );
  }

  List<_Medal> _buildMedals() {
    return [
      _Medal(
        icon: LucideIcons.sunrise,
        title: 'FIRST RISE',
        detail: 'Dismiss your first alarm.',
        earned: _totalOrders >= 1,
        progress: _totalOrders >= 1 ? 1 : 0,
      ),
      _Medal(
        icon: LucideIcons.flame,
        title: 'IGNITED',
        detail: '3-day streak.',
        earned: _best >= 3,
        progress: (_best / 3).clamp(0.0, 1.0),
      ),
      _Medal(
        icon: LucideIcons.medal,
        title: 'IRON WEEK',
        detail: '7 days controlled.',
        earned: _best >= 7,
        progress: (_best / 7).clamp(0.0, 1.0),
      ),
      _Medal(
        icon: LucideIcons.trophy,
        title: 'DISCIPLINED',
        detail: '30 days controlled.',
        earned: _best >= 30,
        progress: (_best / 30).clamp(0.0, 1.0),
      ),
      _Medal(
        icon: LucideIcons.crown,
        title: 'IRON WILL',
        detail: '90 days controlled.',
        earned: _best >= 90,
        progress: (_best / 90).clamp(0.0, 1.0),
      ),
      _Medal(
        icon: LucideIcons.shield,
        title: 'DEBT PAID',
        detail: 'Complete your first punishment.',
        earned: _punishments >= 1,
        progress: _punishments >= 1 ? 1 : 0,
      ),
      _Medal(
        icon: LucideIcons.dumbbell,
        title: 'HUNDRED REPS',
        detail: '100 verified reps.',
        earned: _reps >= 100,
        progress: (_reps / 100).clamp(0.0, 1.0),
      ),
      _Medal(
        icon: LucideIcons.target,
        title: 'ONE THOUSAND',
        detail: '1,000 verified reps.',
        earned: _reps >= 1000,
        progress: (_reps / 1000).clamp(0.0, 1.0),
      ),
      _Medal(
        icon: LucideIcons.zap,
        title: 'HIGH DISCIPLINE',
        detail: 'Discipline score 80+.',
        earned: _score >= 80,
        progress: (_score / 80).clamp(0.0, 1.0),
      ),
      _Medal(
        icon: LucideIcons.star,
        title: 'LEGEND',
        detail: '365 days controlled.',
        earned: _best >= 365,
        progress: (_best / 365).clamp(0.0, 1.0),
      ),
    ];
  }
}

class _Medal {
  final IconData icon;
  final String title;
  final String detail;
  final bool earned;
  final double progress;

  const _Medal({
    required this.icon,
    required this.title,
    required this.detail,
    required this.earned,
    required this.progress,
  });
}

class _MedalRow extends StatelessWidget {
  final _Medal medal;
  const _MedalRow({required this.medal});

  @override
  Widget build(BuildContext context) {
    final accent = medal.earned ? AppColors.amber : Colors.white.withOpacity(0.25);
    return GestureDetector(
      onTap: () => HapticFeedback.selectionClick(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: medal.earned ? AppColors.amber.withOpacity(0.06) : const Color(0xFF0B0B0B),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: medal.earned ? AppColors.amber.withOpacity(0.35) : Colors.white.withOpacity(0.05),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: medal.earned ? AppColors.amber.withOpacity(0.15) : Colors.white.withOpacity(0.04),
                shape: BoxShape.circle,
                border: Border.all(color: accent.withOpacity(0.5), width: 1.5),
              ),
              alignment: Alignment.center,
              child: Icon(
                medal.icon,
                color: accent,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    medal.title,
                    style: TextStyle(
                      color: medal.earned ? Colors.white : Colors.white.withOpacity(0.55),
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    medal.detail,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.45),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (!medal.earned && medal.progress > 0) ...[
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: medal.progress,
                        minHeight: 3,
                        backgroundColor: Colors.white.withOpacity(0.06),
                        valueColor: AlwaysStoppedAnimation(AppColors.amber.withOpacity(0.7)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            Icon(
              medal.earned ? LucideIcons.check : LucideIcons.lock,
              color: accent,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}
