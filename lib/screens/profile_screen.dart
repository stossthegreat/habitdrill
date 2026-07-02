import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

import '../design/tokens.dart';
import '../services/ledger_service.dart';
import '../services/contract_service.dart';
import '../services/analytics_service.dart';
import '../models/contract.dart';
import '../widgets/share_card.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  LedgerSnapshot? _snap;
  int _currentStreak = 0;
  int _longestContract = 0;
  final GlobalKey _shareKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    AnalyticsService.logScreenView('profile');
    _load();
  }

  Future<void> _load() async {
    final snap = await LedgerService.read();
    final contracts = await ContractService.loadAll();
    var streak = 0;
    var longest = snap.longestContract;
    for (final c in contracts) {
      if (c.status == ContractStatus.active && c.daysCompleted > streak) {
        streak = c.daysCompleted;
      }
      if (c.daysCompleted > longest) longest = c.daysCompleted;
    }
    if (longest > snap.longestContract) {
      await LedgerService.updateLongestContract(longest);
    }
    if (!mounted) return;
    setState(() {
      _snap = snap;
      _currentStreak = streak;
      _longestContract = longest;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      body: SafeArea(
        child: _snap == null
            ? const Center(child: CircularProgressIndicator(color: AppColors.emerald))
            : SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _Header(),
                    _RankBadge(
                      rank: _snap!.rank,
                      daysSinceStart: _snap!.daysSinceStart,
                    ),
                    const SizedBox(height: 24),
                    _StatBlock(
                      snap: _snap!,
                      currentStreak: _currentStreak,
                      longestContract: _longestContract,
                    ),
                    const SizedBox(height: 32),
                    _SharePreview(
                      shareKey: _shareKey,
                      snap: _snap!,
                      streak: _currentStreak,
                      longest: _longestContract,
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
    );
  }
}

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
    final words = rank.split(' ');
    return Column(
      children: [
        for (int i = 0; i < words.length; i++)
          Text(
            words[i],
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.emerald,
              fontSize: words.length > 1 ? 40 : 44,
              fontWeight: FontWeight.w900,
              letterSpacing: 5,
              height: 0.95,
              shadows: [
                Shadow(color: AppColors.emerald.withOpacity(0.6), blurRadius: 24),
              ],
            ),
          ).animate(delay: (300 + i * 100).ms).fadeIn(duration: 500.ms).then().shimmer(
                duration: 2400.ms,
                color: Colors.white.withOpacity(0.6),
                delay: 1200.ms,
              ),
      ],
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

class _StatBlock extends StatelessWidget {
  final LedgerSnapshot snap;
  final int currentStreak;
  final int longestContract;

  const _StatBlock({
    required this.snap,
    required this.currentStreak,
    required this.longestContract,
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
            _AnimatedRow(label: 'Honour', value: snap.honour, valueColor: AppColors.amber),
            _AnimatedRow(label: 'Discipline Score', value: snap.disciplineScore, valueColor: AppColors.emerald, format: _fmt),
            _AnimatedRow(label: 'Current Streak', value: currentStreak, suffix: ' Days'),
            _AnimatedRow(label: 'Longest Contract', value: longestContract, suffix: ' Days'),
            _AnimatedRow(label: 'Total Debt Paid', value: snap.totalReps, suffix: ' Reps', format: _fmt, last: true),
          ],
        ),
      ),
    ).animate(delay: 300.ms).fadeIn(duration: 400.ms);
  }

  static String _fmt(int n) {
    final s = n.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buffer.write(',');
      buffer.write(s[i]);
    }
    return buffer.toString();
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

class _SharePreview extends StatelessWidget {
  final GlobalKey shareKey;
  final LedgerSnapshot snap;
  final int streak;
  final int longest;
  const _SharePreview({
    required this.shareKey,
    required this.snap,
    required this.streak,
    required this.longest,
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
                Expanded(
                  child: Container(height: 1, color: Colors.white.withOpacity(0.06)),
                ),
              ],
            ),
          ),
          RepaintBoundary(
            key: shareKey,
            child: ProfileShareCard(
              rank: snap.rank,
              honour: snap.honour,
              disciplineScore: snap.disciplineScore,
              currentStreak: streak,
              longestContract: longest,
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
