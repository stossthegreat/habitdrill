import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

import '../design/tokens.dart';
import '../models/violation.dart';
import '../services/ledger_service.dart';
import '../services/discipline_service.dart';
import '../services/sergeant_service.dart';
import '../services/local_storage.dart';
import '../services/analytics_service.dart';
import '../widgets/share_card.dart';
import 'sergeant/punishment_screen.dart';
import 'achievements_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with WidgetsBindingObserver {
  LedgerSnapshot? _ledger;
  int _score = 0;
  int _currentStreak = 0;
  int _bestStreak = 0;
  int _totalOrders = 0;
  int _contractsCompleted = 0;
  double _completionRate = 0;
  List<Violation> _pendingDebt = const [];
  final GlobalKey _shareKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    AnalyticsService.logScreenView('profile');
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  Future<void> _load() async {
    final ledger = await LedgerService.read();
    final score = await DisciplineService.getScore();
    final streak = await DisciplineService.getDaysControlled();
    final best = await DisciplineService.getBestStreak();
    final orders = await DisciplineService.getTotalOrdersCompleted();
    // Contracts completed = habits whose endDate is past AND streak > 0.
    final now = DateTime.now();
    final habits = LocalStorageService.getAllHabits();
    final completed = habits.where((h) {
      return h.endDate.isBefore(now) && h.streak > 0;
    }).length;
    // Completion rate: total kept vs (total kept + broken). Uses discipline
    // orders + punishments as broken proxy.
    final rate = (orders + ledger.punishmentsCompleted == 0)
        ? 100
        : ((orders / (orders + ledger.punishmentsCompleted)) * 100).round();
    final pending = SergeantService.getPendingViolations();
    if (!mounted) return;
    setState(() {
      _ledger = ledger;
      _score = score;
      _currentStreak = streak;
      _bestStreak = best;
      _totalOrders = orders;
      _contractsCompleted = completed;
      _completionRate = rate.toDouble();
      _pendingDebt = pending;
    });
  }

  Future<void> _share() async {
    HapticFeedback.mediumImpact();
    try {
      final boundary = _shareKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) return;
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/habitdrill_profile.png');
      await file.writeAsBytes(bytes.buffer.asUint8List());
      await Share.shareXFiles([XFile(file.path)], text: 'Every promise is a contract.');
    } catch (_) {}
  }

  Future<void> _payDebt(Violation v) async {
    HapticFeedback.heavyImpact();
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PunishmentScreen(
          violation: v,
          onComplete: () => Navigator.of(context).pop(),
        ),
      ),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      body: SafeArea(
        child: _ledger == null
            ? const Center(child: CircularProgressIndicator(color: AppColors.emerald))
            : RefreshIndicator(
                color: AppColors.emerald,
                backgroundColor: const Color(0xFF0B0B0B),
                onRefresh: _load,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _Header(),
                      if (_pendingDebt.isNotEmpty)
                        _DebtBanner(
                          count: _pendingDebt.length,
                          onTap: () => _payDebt(_pendingDebt.first),
                        ),
                      _PrivatePill(daysSinceStart: _ledger!.daysSinceStart),
                      const SizedBox(height: 24),
                      _StatsList(
                        score: _score,
                        currentStreak: _currentStreak,
                        bestStreak: _bestStreak,
                        contractsCompleted: _contractsCompleted,
                        punishments: _ledger!.punishmentsCompleted,
                        completionRate: _completionRate.round(),
                      ),
                      const SizedBox(height: 24),
                      _ActionRow(
                        onAchievements: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const AchievementsScreen()),
                        ),
                        onShare: _share,
                      ),
                      const SizedBox(height: 20),
                      // Hidden RepaintBoundary — used by _share() but not
                      // shown to the user. Keeps share-card layout stable.
                      Offstage(
                        offstage: true,
                        child: RepaintBoundary(
                          key: _shareKey,
                          child: ProfileShareCard(
                            rank: _rankTitle(_bestStreak),
                            honour: _score,
                            disciplineScore: _score,
                            currentStreak: _currentStreak,
                            longestContract: _bestStreak,
                            totalReps: _ledger!.totalReps,
                            daysSinceStart: _ledger!.daysSinceStart,
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  String _rankTitle(int best) {
    if (best >= 365) return 'LEGEND';
    if (best >= 90) return 'IRON WILL';
    if (best >= 30) return 'DISCIPLINED';
    if (best >= 7) return 'BUILDING';
    if (best >= 3) return 'IGNITED';
    return 'PRIVATE';
  }
}

// ────────────────────────── Header ──────────────────────────

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 6,
                height: 22,
                decoration: BoxDecoration(
                  color: AppColors.cyan,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'PROFILE',
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
              'Your reputation.',
              style: TextStyle(
                color: Colors.white.withOpacity(0.35),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms);
  }
}

// ────────────────────────── PRIVATE + Day X pill ──────────────────

class _PrivatePill extends StatelessWidget {
  final int daysSinceStart;
  const _PrivatePill({required this.daysSinceStart});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.amber.withOpacity(0.12),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.amber.withOpacity(0.5), width: 1),
            ),
            child: Text(
              'PRIVATE',
              style: TextStyle(
                color: AppColors.amber,
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 2.5,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'DAY $daysSinceStart',
            style: TextStyle(
              color: Colors.white.withOpacity(0.4),
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 2.5,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    ).animate(delay: 100.ms).fadeIn();
  }
}

// ────────────────────────── Debt banner ──────────────────────────

class _DebtBanner extends StatelessWidget {
  final int count;
  final VoidCallback onTap;
  const _DebtBanner({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.error.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.error.withOpacity(0.4), width: 1),
          ),
          child: Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(color: AppColors.error, borderRadius: BorderRadius.circular(3)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  count == 1 ? 'DEBT OUTSTANDING · TAP TO PAY' : '$count DEBTS OUTSTANDING · TAP',
                  style: TextStyle(
                    color: AppColors.error,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
              ),
              Icon(LucideIcons.chevronRight, color: AppColors.error.withOpacity(0.7), size: 14),
            ],
          ),
        ),
      ),
    );
  }
}

// ────────────────────────── The stats list (numbers only) ──────────

class _StatsList extends StatelessWidget {
  final int score;
  final int currentStreak;
  final int bestStreak;
  final int contractsCompleted;
  final int punishments;
  final int completionRate;

  const _StatsList({
    required this.score,
    required this.currentStreak,
    required this.bestStreak,
    required this.contractsCompleted,
    required this.punishments,
    required this.completionRate,
  });

  @override
  Widget build(BuildContext context) {
    final rows = <(String, String, Color)>[
      ('Discipline', score.toString(), AppColors.emerald),
      ('Current Streak', currentStreak.toString(), Colors.white),
      ('Longest', bestStreak.toString(), Colors.white),
      ('Contracts Completed', contractsCompleted.toString(), Colors.white),
      ('Punishments', punishments.toString(), AppColors.amber),
      ('Completion Rate', '$completionRate%', AppColors.emerald),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0B0B0B),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.05), width: 1),
        ),
        child: Column(
          children: [
            for (int i = 0; i < rows.length; i++)
              _StatRow(
                label: rows[i].$1,
                value: rows[i].$2,
                valueColor: rows[i].$3,
                last: i == rows.length - 1,
              ),
          ],
        ),
      ),
    ).animate(delay: 200.ms).fadeIn(duration: 400.ms);
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;
  final bool last;

  const _StatRow({
    required this.label,
    required this.value,
    required this.valueColor,
    required this.last,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      decoration: BoxDecoration(
        border: last
            ? null
            : Border(bottom: BorderSide(color: Colors.white.withOpacity(0.04), width: 1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.3,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────── Action row (achievements + share) ────

class _ActionRow extends StatelessWidget {
  final VoidCallback onAchievements;
  final VoidCallback onShare;
  const _ActionRow({required this.onAchievements, required this.onShare});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: _ActionButton(
              icon: LucideIcons.award,
              label: 'ACHIEVEMENTS',
              onTap: onAchievements,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _ActionButton(
              icon: LucideIcons.share2,
              label: 'SHARE',
              onTap: onShare,
              emerald: true,
            ),
          ),
        ],
      ),
    ).animate(delay: 350.ms).fadeIn();
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool emerald;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.emerald = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: emerald ? AppColors.emeraldGradient : null,
          color: emerald ? null : const Color(0xFF0B0B0B),
          borderRadius: BorderRadius.circular(12),
          border: emerald
              ? null
              : Border.all(color: Colors.white.withOpacity(0.06), width: 1),
          boxShadow: emerald
              ? [BoxShadow(color: AppColors.emerald.withOpacity(0.35), blurRadius: 18, offset: const Offset(0, 6))]
              : null,
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: emerald ? Colors.black : Colors.white.withOpacity(0.85), size: 16),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: emerald ? Colors.black : Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
