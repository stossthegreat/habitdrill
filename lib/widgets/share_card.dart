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

/// New rank-forward profile share card. Used by the Profile tab.
/// Fixed 4:5 aspect ratio so it looks identical on IG/Twitter/Discord.
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

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 4 / 5,
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF050505), Color(0xFF0A100D)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.emerald.withOpacity(0.35), width: 1.5),
        ),
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 5,
                      height: 18,
                      decoration: BoxDecoration(
                        color: AppColors.emerald,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'HABITDRILL',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.65),
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 3,
                      ),
                    ),
                  ],
                ),
                Text(
                  '$daysSinceStart D',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.35),
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(
              'RANK',
              style: TextStyle(
                color: Colors.white.withOpacity(0.35),
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 4,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              rank,
              style: const TextStyle(
                color: AppColors.emerald,
                fontSize: 34,
                fontWeight: FontWeight.w900,
                letterSpacing: 4,
                height: 1,
              ),
            ),
            const SizedBox(height: 18),
            Container(height: 1, color: Colors.white.withOpacity(0.08)),
            const SizedBox(height: 18),
            _ProfileStatLine(label: 'Honour', value: '$honour', color: AppColors.amber),
            const SizedBox(height: 10),
            _ProfileStatLine(label: 'Discipline Score', value: _fmt(disciplineScore), color: AppColors.emerald),
            const SizedBox(height: 10),
            _ProfileStatLine(label: 'Current Streak', value: '$currentStreak Days'),
            const SizedBox(height: 10),
            _ProfileStatLine(label: 'Longest Contract', value: '$longestContract Days'),
            const SizedBox(height: 10),
            _ProfileStatLine(label: 'Debt Paid', value: '${_fmt(totalReps)} Reps'),
            const Spacer(),
            Text(
              'VERIFIED',
              style: TextStyle(
                color: AppColors.emerald.withOpacity(0.75),
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 5,
              ),
            ),
          ],
        ),
      ),
    );
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

class _ProfileStatLine extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _ProfileStatLine({required this.label, required this.value, this.color = Colors.white});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.w900,
            fontFamily: 'monospace',
            letterSpacing: 0.4,
          ),
        ),
      ],
    );
  }
}
