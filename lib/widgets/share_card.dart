import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../design/tokens.dart';

/// Military-style share card for screenshots and sharing
class ShareCard extends StatelessWidget {
  final int score;
  final int daysControlled;
  final int bestStreak;
  final String rank;
  final int totalOrders;
  final int rulesHeld;

  const ShareCard({
    super.key,
    required this.score,
    required this.daysControlled,
    required this.bestStreak,
    required this.rank,
    required this.totalOrders,
    required this.rulesHeld,
  });

  static final GlobalKey _cardKey = GlobalKey();

  static Future<void> shareAsImage(BuildContext context) async {
    try {
      final boundary = _cardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/habitdrill_stats.png');
      await file.writeAsBytes(byteData.buffer.asUint8List());

      await Share.shareXFiles([XFile(file.path)], text: 'My discipline score on HabitDrill');
    } catch (e) {
      debugPrint('Share error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final scoreColor = score >= 80
        ? const Color(0xFF16A34A)
        : score >= 50
            ? const Color(0xFFF59E0B)
            : const Color(0xFFDC2626);

    return RepaintBoundary(
      key: _cardKey,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: const Color(0xFF0A0A0A),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // App icon + name
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset('assets/icon/app_icon.png', width: 28, height: 28),
                ),
                const SizedBox(width: 8),
                const Text(
                  'HABITDRILL',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 3),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Divider
            Container(height: 1, color: Colors.white.withOpacity(0.08)),

            const SizedBox(height: 24),

            // Discipline score - BIG
            Text(
              'DISCIPLINE',
              style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 4),
            ),
            const SizedBox(height: 8),
            Text(
              '$score',
              style: TextStyle(color: scoreColor, fontSize: 64, fontWeight: FontWeight.w900),
            ),

            const SizedBox(height: 8),

            // Rank
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: scoreColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: scoreColor.withOpacity(0.3)),
              ),
              child: Text(
                rank,
                style: TextStyle(color: scoreColor, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 2),
              ),
            ),

            const SizedBox(height: 28),

            // Stats grid
            Row(
              children: [
                _stat('DAYS\nCONTROLLED', '$daysControlled'),
                _divider(),
                _stat('BEST\nSTREAK', '$bestStreak'),
                _divider(),
                _stat('ORDERS\nCOMPLETED', '$totalOrders'),
              ],
            ),

            if (rulesHeld > 0) ...[
              const SizedBox(height: 16),
              Text(
                'RULES HELD: $rulesHeld DAYS',
                style: TextStyle(color: Colors.white.withOpacity(0.25), fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 2),
              ),
            ],

            const SizedBox(height: 24),

            Container(height: 1, color: Colors.white.withOpacity(0.08)),

            const SizedBox(height: 16),

            Text(
              'DISCIPLINE ENFORCEMENT SYSTEM',
              style: TextStyle(color: Colors.white.withOpacity(0.15), fontSize: 9, fontWeight: FontWeight.w600, letterSpacing: 2),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat(String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 1, height: 1.3),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _divider() {
    return Container(width: 1, height: 40, color: Colors.white.withOpacity(0.08));
  }
}

/// Beast-mode profile share card. 4:5 for IG/Twitter/Discord parity.
/// HUD corner brackets, monumental rank display, dotted-leader stat rows,
/// decorative VERIFIED seal, grain overlay, gradient tint.
class ProfileShareCard extends StatelessWidget {
  final String rank;
  final int honour;
  final int disciplineScore;
  final int currentStreak;
  final int longestContract;
  final int totalReps;
  final int daysSinceStart;

  const ProfileShareCard({
    super.key,
    required this.rank,
    required this.honour,
    required this.disciplineScore,
    required this.currentStreak,
    required this.longestContract,
    required this.totalReps,
    required this.daysSinceStart,
  });

  String get _serial => daysSinceStart.toString().padLeft(6, '0');

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 4 / 5,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color(0xFF040604),
                Color(0xFF060A08),
                Color(0xFF040604),
              ],
              stops: [0.0, 0.5, 1.0],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: AppColors.emerald.withOpacity(0.5), width: 1.5),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Stack(
            children: [
              const Positioned.fill(child: _EmberGlow()),
              Positioned.fill(child: CustomPaint(painter: _CornerBracketsPainter())),
              Padding(
                padding: const EdgeInsets.fromLTRB(26, 26, 26, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _TopBar(serial: _serial),
                    const Spacer(flex: 2),
                    _RankHero(rank: rank, daysSinceStart: daysSinceStart),
                    const Spacer(flex: 2),
                    _StatBlock(
                      honour: honour,
                      score: disciplineScore,
                      streak: currentStreak,
                      longest: longestContract,
                      reps: totalReps,
                    ),
                    const Spacer(flex: 1),
                    _VerifiedSeal(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ────────────────────────── Ember background glow ──────────────────────────

class _EmberGlow extends StatelessWidget {
  const _EmberGlow();
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(0, -0.35),
          radius: 0.9,
          colors: [
            AppColors.emerald.withOpacity(0.14),
            AppColors.emerald.withOpacity(0.03),
            Colors.transparent,
          ],
          stops: const [0.0, 0.35, 1.0],
        ),
      ),
    );
  }
}

// ────────────────────────── Corner brackets (HUD reticle) ──────────────────

class _CornerBracketsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.emerald.withOpacity(0.7)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    const inset = 14.0;
    const bracket = 22.0;
    // Top-left
    canvas.drawLine(Offset(inset, inset + bracket), Offset(inset, inset), paint);
    canvas.drawLine(Offset(inset, inset), Offset(inset + bracket, inset), paint);
    // Top-right
    canvas.drawLine(Offset(size.width - inset - bracket, inset), Offset(size.width - inset, inset), paint);
    canvas.drawLine(Offset(size.width - inset, inset), Offset(size.width - inset, inset + bracket), paint);
    // Bottom-left
    canvas.drawLine(Offset(inset, size.height - inset - bracket), Offset(inset, size.height - inset), paint);
    canvas.drawLine(Offset(inset, size.height - inset), Offset(inset + bracket, size.height - inset), paint);
    // Bottom-right
    canvas.drawLine(Offset(size.width - inset - bracket, size.height - inset), Offset(size.width - inset, size.height - inset), paint);
    canvas.drawLine(Offset(size.width - inset, size.height - inset), Offset(size.width - inset, size.height - inset - bracket), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ────────────────────────── Top bar ──────────────────────────

class _TopBar extends StatelessWidget {
  final String serial;
  const _TopBar({required this.serial});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 16,
              decoration: BoxDecoration(
                color: AppColors.emerald,
                borderRadius: BorderRadius.circular(1),
                boxShadow: [
                  BoxShadow(color: AppColors.emerald.withOpacity(0.5), blurRadius: 6),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'HABITDRILL',
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 3.5,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        Row(
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: AppColors.emerald,
                borderRadius: BorderRadius.circular(3),
                boxShadow: [
                  BoxShadow(color: AppColors.emerald.withOpacity(0.7), blurRadius: 6),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '#$serial',
              style: TextStyle(
                color: Colors.white.withOpacity(0.4),
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ────────────────────────── Monumental rank hero ──────────────────────────

class _RankHero extends StatelessWidget {
  final String rank;
  final int daysSinceStart;
  const _RankHero({required this.rank, required this.daysSinceStart});

  @override
  Widget build(BuildContext context) {
    // Multi-line words look better centered — split into lines.
    final words = rank.split(' ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white.withOpacity(0.15), width: 1),
            borderRadius: BorderRadius.circular(3),
          ),
          child: Text(
            'RANK',
            style: TextStyle(
              color: Colors.white.withOpacity(0.55),
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 5,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
        const SizedBox(height: 18),
        for (int i = 0; i < words.length; i++) ...[
          if (i > 0) const SizedBox(height: 2),
          Text(
            words[i],
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.emerald,
              fontSize: words.length > 1 ? 52 : 56,
              fontWeight: FontWeight.w900,
              letterSpacing: 6,
              height: 0.95,
              shadows: [
                Shadow(
                  color: AppColors.emerald.withOpacity(0.5),
                  blurRadius: 24,
                ),
              ],
            ),
          ),
        ],
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
    );
  }
}

// ────────────────────────── Stat block ──────────────────────────

class _StatBlock extends StatelessWidget {
  final int honour;
  final int score;
  final int streak;
  final int longest;
  final int reps;
  const _StatBlock({
    required this.honour,
    required this.score,
    required this.streak,
    required this.longest,
    required this.reps,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.35),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.06), width: 1),
      ),
      child: Column(
        children: [
          _StatRow(label: 'DISCIPLINE', value: '$score / 100', highlight: AppColors.emerald),
          const SizedBox(height: 10),
          _StatRow(label: 'STREAK', value: '$streak D', highlight: AppColors.fire),
          const SizedBox(height: 10),
          _StatRow(label: 'BEST', value: '$longest D'),
          const SizedBox(height: 10),
          _StatRow(label: 'REPS PAID', value: _fmt(reps)),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? highlight;
  const _StatRow({required this.label, required this.value, this.highlight});

  @override
  Widget build(BuildContext context) {
    final color = highlight ?? Colors.white;
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.55),
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 2.5,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: CustomPaint(
            painter: _DottedLeaderPainter(),
            child: const SizedBox(height: 12),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 13,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

class _DottedLeaderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.14)
      ..strokeWidth = 1;
    const spacing = 4.0;
    final y = size.height / 2;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, y), Offset(x + 1.5, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ────────────────────────── Verified seal ──────────────────────────

class _VerifiedSeal extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          '╱',
          style: TextStyle(color: AppColors.emerald.withOpacity(0.7), fontSize: 14, fontWeight: FontWeight.w900),
        ),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.emerald.withOpacity(0.6), width: 1),
            borderRadius: BorderRadius.circular(3),
          ),
          child: Text(
            'VERIFIED',
            style: TextStyle(
              color: AppColors.emerald,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 5,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          '╲',
          style: TextStyle(color: AppColors.emerald.withOpacity(0.7), fontSize: 14, fontWeight: FontWeight.w900),
        ),
      ],
    );
  }
}

// ────────────────────────── Number formatting ──────────────────────────

String _fmt(int n) {
  final s = n.toString();
  final buffer = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buffer.write(',');
    buffer.write(s[i]);
  }
  return buffer.toString();
}
