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
      final file = File('${dir.path}/drillsarj_stats.png');
      await file.writeAsBytes(byteData.buffer.asUint8List());

      await Share.shareXFiles([XFile(file.path)], text: 'My discipline score on Drillsarj');
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
                  'DRILLSARJ',
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
