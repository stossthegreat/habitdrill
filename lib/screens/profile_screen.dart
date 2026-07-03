import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
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

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with WidgetsBindingObserver {
  LedgerSnapshot? _ledger;
  int _score = 0;
  SergeantRank _rank = SergeantRank.private_;
  int _currentStreak = 0;
  int _bestStreak = 0;
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
    final rank = await DisciplineService.getRank();
    final streak = await DisciplineService.getDaysControlled();
    final best = await DisciplineService.getBestStreak();
    // Best-effort: also fold in per-habit streaks so long-running habits
    // contribute to "best streak."
    for (final h in LocalStorageService.getAllHabits()) {
      if (h.streak > best) {
        await LedgerService.updateLongestContract(h.streak);
      }
    }
    final pending = SergeantService.getPendingViolations();
    if (!mounted) return;
    setState(() {
      _ledger = ledger;
      _score = score;
      _rank = rank;
      _currentStreak = streak;
      _bestStreak = best > ledger.longestContract ? best : ledger.longestContract;
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
                      _RankBadge(
                        rank: _rank.title,
                        daysSinceStart: _ledger!.daysSinceStart,
                      ),
                      const SizedBox(height: 20),
                      _StreakFlame(
                        current: _currentStreak,
                        best: _bestStreak,
                      ),
                      const SizedBox(height: 24),
                      _CoreStats(
                        score: _score,
                        best: _bestStreak,
                        totalReps: _ledger!.totalReps,
                        punishments: _ledger!.punishmentsCompleted,
                      ),
                      const SizedBox(height: 24),
                      _ReputationBlock(snap: _ledger!),
                      const SizedBox(height: 32),
                      _SharePreview(
                        shareKey: _shareKey,
                        snap: _ledger!,
                        score: _score,
                        rank: _rank.title,
                        streak: _currentStreak,
                        best: _bestStreak,
                      ),
                      const SizedBox(height: 20),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: _ShareButton(onTap: _share),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
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
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: AppColors.error.withOpacity(0.1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.error.withOpacity(0.45), width: 1),
          ),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: AppColors.error,
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: [BoxShadow(color: AppColors.error.withOpacity(0.7), blurRadius: 8)],
                ),
              ).animate(onPlay: (c) => c.repeat(reverse: true)).fadeIn().then().fade(begin: 1, end: 0.3, duration: 700.ms),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      count == 1 ? 'DEBT OUTSTANDING' : '$count DEBTS OUTSTANDING',
                      style: const TextStyle(
                        color: AppColors.error,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tap to pay.',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.55),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, color: AppColors.error.withOpacity(0.75), size: 14),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.1, end: 0);
  }
}

// ────────────────────────── Rank badge ──────────────────────────

class _RankBadge extends StatelessWidget {
  final String rank;
  final int daysSinceStart;
  const _RankBadge({required this.rank, required this.daysSinceStart});

  @override
  Widget build(BuildContext context) {
    final serial = daysSinceStart.toString().padLeft(6, '0');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF080A08), Color(0xFF0B100D), Color(0xFF080A08)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: AppColors.emerald.withOpacity(0.45), width: 1.5),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.emerald.withOpacity(0.18),
                blurRadius: 50,
                spreadRadius: -12,
              ),
            ],
          ),
          child: Stack(
            children: [
              const Positioned.fill(child: _BadgeGlow()),
              Positioned.fill(child: CustomPaint(painter: _BadgeReticlePainter())),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 26, 24, 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white.withOpacity(0.18), width: 1),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        'RANK · #$serial',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 3.5,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    _MonumentalRank(rank: rank),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(width: 18, height: 1, color: Colors.white.withOpacity(0.15)),
                        const SizedBox(width: 10),
                        Text(
                          'DAY $daysSinceStart',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 3,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(width: 18, height: 1, color: Colors.white.withOpacity(0.15)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate(delay: 100.ms).fadeIn(duration: 500.ms).slideY(begin: 0.08, end: 0);
  }
}

class _MonumentalRank extends StatelessWidget {
  final String rank;
  const _MonumentalRank({required this.rank});

  @override
  Widget build(BuildContext context) {
    return Text(
      rank,
      textAlign: TextAlign.center,
      style: TextStyle(
        color: AppColors.emerald,
        fontSize: 44,
        fontWeight: FontWeight.w900,
        letterSpacing: 5,
        height: 0.95,
        shadows: [
          Shadow(color: AppColors.emerald.withOpacity(0.6), blurRadius: 24),
        ],
      ),
    ).animate(delay: 300.ms).fadeIn(duration: 500.ms).then().shimmer(
          duration: 2400.ms,
          color: Colors.white.withOpacity(0.6),
          delay: 1200.ms,
        );
  }
}

class _BadgeGlow extends StatelessWidget {
  const _BadgeGlow();
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(0, -0.4),
          radius: 0.9,
          colors: [
            AppColors.emerald.withOpacity(0.18),
            AppColors.emerald.withOpacity(0.03),
            Colors.transparent,
          ],
          stops: const [0.0, 0.4, 1.0],
        ),
      ),
    );
  }
}

class _BadgeReticlePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.emerald.withOpacity(0.7)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    const inset = 10.0;
    const bracket = 16.0;
    canvas.drawLine(Offset(inset, inset + bracket), Offset(inset, inset), paint);
    canvas.drawLine(Offset(inset, inset), Offset(inset + bracket, inset), paint);
    canvas.drawLine(Offset(size.width - inset - bracket, inset), Offset(size.width - inset, inset), paint);
    canvas.drawLine(Offset(size.width - inset, inset), Offset(size.width - inset, inset + bracket), paint);
    canvas.drawLine(Offset(inset, size.height - inset - bracket), Offset(inset, size.height - inset), paint);
    canvas.drawLine(Offset(inset, size.height - inset), Offset(inset + bracket, size.height - inset), paint);
    canvas.drawLine(Offset(size.width - inset - bracket, size.height - inset), Offset(size.width - inset, size.height - inset), paint);
    canvas.drawLine(Offset(size.width - inset, size.height - inset), Offset(size.width - inset, size.height - inset - bracket), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ────────────────────────── Streak flame hero ──────────────────────────

class _StreakFlame extends StatelessWidget {
  final int current;
  final int best;
  const _StreakFlame({required this.current, required this.best});

  @override
  Widget build(BuildContext context) {
    final alive = current > 0;
    final color = alive ? AppColors.fire : Colors.white.withOpacity(0.2);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 28),
        decoration: BoxDecoration(
          color: alive ? AppColors.fire.withOpacity(0.06) : const Color(0xFF0B0B0B),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: alive ? AppColors.fire.withOpacity(0.35) : Colors.white.withOpacity(0.05),
            width: 1.5,
          ),
          boxShadow: alive
              ? [BoxShadow(color: AppColors.fire.withOpacity(0.18), blurRadius: 40, spreadRadius: -10)]
              : null,
        ),
        child: Column(
          children: [
            // The flame emoji + shimmer
            Stack(
              alignment: Alignment.center,
              children: [
                if (alive)
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          AppColors.fire.withOpacity(0.3),
                          AppColors.fire.withOpacity(0.05),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                Text(
                  '🔥',
                  style: TextStyle(fontSize: 70, height: 1, color: alive ? null : Colors.white.withOpacity(0.15)),
                ).animate(onPlay: (c) => c.repeat(reverse: true))
                    .scaleXY(begin: 1, end: alive ? 1.06 : 1, duration: 1400.ms, curve: Curves.easeInOut),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              '$current',
              style: TextStyle(
                color: color,
                fontSize: 56,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
                height: 1,
                fontFeatures: const [FontFeature.tabularFigures()],
                shadows: alive
                    ? [Shadow(color: AppColors.fire.withOpacity(0.7), blurRadius: 24)]
                    : null,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              current == 1 ? 'DAY STREAK' : 'DAY STREAK',
              style: TextStyle(
                color: color.withOpacity(0.85),
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 4,
              ),
            ),
            if (best > current) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'BEST · $best',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.55),
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2.5,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    ).animate(delay: 200.ms).fadeIn(duration: 500.ms).slideY(begin: 0.06, end: 0);
  }
}

// ────────────────────────── Core stats block ──────────────────────────

class _CoreStats extends StatelessWidget {
  final int score;
  final int best;
  final int totalReps;
  final int punishments;

  const _CoreStats({
    required this.score,
    required this.best,
    required this.totalReps,
    required this.punishments,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0B0B0B),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.05), width: 1),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          children: [
            _AnimatedRow(label: 'Discipline', value: score, valueColor: AppColors.emerald, suffix: ' / 100'),
            _AnimatedRow(label: 'Best Streak', value: best, suffix: ' Days'),
            _AnimatedRow(label: 'Punishments', value: punishments, valueColor: AppColors.amber),
            _AnimatedRow(label: 'Reps Paid', value: totalReps, format: _fmt, last: true),
          ],
        ),
      ),
    ).animate(delay: 300.ms).fadeIn(duration: 400.ms);
  }

  static String _fmt(int n) {
    final s = n.toString();
    final b = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
      b.write(s[i]);
    }
    return b.toString();
  }
}

class _AnimatedRow extends StatelessWidget {
  final String label;
  final int value;
  final Color valueColor;
  final String suffix;
  final String Function(int)? format;
  final bool last;

  const _AnimatedRow({
    required this.label,
    required this.value,
    this.valueColor = Colors.white,
    this.suffix = '',
    this.format,
    this.last = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
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
                color: Colors.white.withOpacity(0.55),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          TweenAnimationBuilder<int>(
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            tween: IntTween(begin: 0, end: value),
            builder: (context, v, _) {
              final str = format != null ? format!(v) : v.toString();
              return Text(
                '$str$suffix',
                style: TextStyle(
                  color: valueColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ────────────────────────── Reputation block (rep breakdown) ─────────

class _ReputationBlock extends StatelessWidget {
  final LedgerSnapshot snap;
  const _ReputationBlock({required this.snap});

  @override
  Widget build(BuildContext context) {
    final rows = <(String, int)>[
      ('Squats', snap.repsFor('squats')),
      ('Burpees', snap.repsFor('burpees')),
      ('High Knees', snap.repsFor('high_knees')),
      ('Push-ups', snap.repsFor('push_ups')),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 10),
            child: Row(
              children: [
                Text(
                  'VERIFIED REPS',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.45),
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 4,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(child: Container(height: 1, color: Colors.white.withOpacity(0.06))),
                const SizedBox(width: 10),
                Text(
                  DateFormat('d MMM').format(snap.disciplineSince).toUpperCase(),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.35),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF0B0B0B),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.05), width: 1),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Column(
              children: [
                for (int i = 0; i < rows.length; i++)
                  _AnimatedRow(label: rows[i].$1, value: rows[i].$2),
                _AnimatedRow(
                  label: 'TOTAL',
                  value: snap.totalReps,
                  valueColor: AppColors.emerald,
                  last: true,
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate(delay: 400.ms).fadeIn(duration: 400.ms);
  }
}

// ────────────────────────── Share preview + button ──────────────────

class _SharePreview extends StatelessWidget {
  final GlobalKey shareKey;
  final LedgerSnapshot snap;
  final int score;
  final String rank;
  final int streak;
  final int best;
  const _SharePreview({
    required this.shareKey,
    required this.snap,
    required this.score,
    required this.rank,
    required this.streak,
    required this.best,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 10),
            child: Row(
              children: [
                Text(
                  'SHARE CARD',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.45),
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 4,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(child: Container(height: 1, color: Colors.white.withOpacity(0.06))),
              ],
            ),
          ),
          RepaintBoundary(
            key: shareKey,
            child: ProfileShareCard(
              rank: rank,
              honour: score,
              disciplineScore: score,
              currentStreak: streak,
              longestContract: best,
              totalReps: snap.totalReps,
              daysSinceStart: snap.daysSinceStart,
            ),
          ),
        ],
      ),
    ).animate(delay: 500.ms).fadeIn(duration: 500.ms).slideY(begin: 0.03, end: 0);
  }
}

class _ShareButton extends StatelessWidget {
  final VoidCallback onTap;
  const _ShareButton({required this.onTap});

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
              color: AppColors.emerald.withOpacity(0.35),
              blurRadius: 22,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: const Text(
          'SHARE PROFILE',
          style: TextStyle(
            color: Colors.black,
            fontSize: 14,
            fontWeight: FontWeight.w900,
            letterSpacing: 3.5,
          ),
        ),
      ),
    ).animate(delay: 700.ms).fadeIn(duration: 400.ms);
  }
}
