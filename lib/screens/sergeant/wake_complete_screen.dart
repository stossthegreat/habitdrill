import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../design/tokens.dart';

/// Shown the moment the user finishes their morning wake reps. It's the
/// payoff — the whole point of enduring the alarm cascade. Confetti-free
/// but loud: MISSION COMPLETE, a shareable brag card, and one button
/// back to base.
///
/// The share card is captured from a hidden RepaintBoundary at 3× pixel
/// ratio and dropped as a temporary PNG that share_plus dispatches to
/// the system share sheet.
class WakeCompleteScreen extends StatefulWidget {
  final String habitTitle;
  final int reps;
  final String exerciseName;
  final VoidCallback onClose;

  const WakeCompleteScreen({
    super.key,
    required this.habitTitle,
    required this.reps,
    required this.exerciseName,
    required this.onClose,
  });

  @override
  State<WakeCompleteScreen> createState() => _WakeCompleteScreenState();
}

class _WakeCompleteScreenState extends State<WakeCompleteScreen> {
  final GlobalKey _cardKey = GlobalKey();
  bool _sharing = false;

  @override
  void initState() {
    super.initState();
    HapticFeedback.heavyImpact();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  Future<void> _share() async {
    if (_sharing) return;
    _sharing = true;
    HapticFeedback.mediumImpact();
    try {
      final ctx = _cardKey.currentContext;
      if (ctx == null) return;
      final boundary = ctx.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;
      final bytes = byteData.buffer.asUint8List();
      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/habitdrill_win_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(bytes);
      await Share.shareXFiles(
        [XFile(file.path)],
        text:
            'I start my day by punching procrastination in the tacos 💪😡💀\nHabitDrill.',
      );
    } catch (e) {
      debugPrint('share failed: $e');
    } finally {
      _sharing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                const SizedBox(height: 8),
                _MissionBadge(),
                const SizedBox(height: 22),
                const Text(
                  'MISSION\nCOMPLETE.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 46,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1.4,
                    height: 0.98,
                  ),
                ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.05, end: 0),
                const SizedBox(height: 8),
                Text(
                  'You showed up. Log the win.',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ).animate(delay: 250.ms).fadeIn(),
                const SizedBox(height: 20),
                Expanded(
                  child: Center(
                    child: RepaintBoundary(
                      key: _cardKey,
                      child: _ShareCard(
                        habitTitle: widget.habitTitle,
                        reps: widget.reps,
                        exerciseName: widget.exerciseName,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                _PrimaryButton(
                  label: 'SHARE THE WIN',
                  icon: LucideIcons.share2,
                  onTap: _share,
                ).animate(delay: 500.ms).fadeIn().slideY(begin: 0.05, end: 0),
                const SizedBox(height: 10),
                _SecondaryButton(
                  label: 'RETURN TO BASE',
                  onTap: widget.onClose,
                ).animate(delay: 600.ms).fadeIn(),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ────────────────────────── Mission badge (top) ─────────────────────

class _MissionBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.emerald.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.emerald.withOpacity(0.55), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle, color: AppColors.emerald, size: 14),
          const SizedBox(width: 6),
          Text(
            'DEBT PAID',
            style: TextStyle(
              color: AppColors.emerald,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 3,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms);
  }
}

// ────────────────────────── The share card ──────────────────────────

class _ShareCard extends StatelessWidget {
  final String habitTitle;
  final int reps;
  final String exerciseName;

  const _ShareCard({
    required this.habitTitle,
    required this.reps,
    required this.exerciseName,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final date = DateFormat('EEE · d MMM').format(now).toUpperCase();
    final time = DateFormat('HH:mm').format(now);

    return Container(
      width: 320,
      padding: const EdgeInsets.fromLTRB(24, 26, 24, 22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF04140C), Color(0xFF010806)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.emerald.withOpacity(0.4), width: 1),
        boxShadow: [
          BoxShadow(
            color: AppColors.emerald.withOpacity(0.28),
            blurRadius: 40,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
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
              const SizedBox(width: 10),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: 'Habit',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                    TextSpan(
                      text: 'Drill',
                      style: TextStyle(
                        color: AppColors.emerald,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                date,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.35),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Text(
            habitTitle.toUpperCase(),
            style: TextStyle(
              color: Colors.white.withOpacity(0.55),
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'WON AT $time',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.w900,
              letterSpacing: -1,
              height: 1,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$reps',
                style: TextStyle(
                  color: AppColors.emerald,
                  fontSize: 76,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -3,
                  height: 1,
                  shadows: [
                    Shadow(color: AppColors.emerald.withOpacity(0.55), blurRadius: 26),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  exerciseName.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                    height: 1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            height: 1,
            color: Colors.white.withOpacity(0.06),
          ),
          const SizedBox(height: 12),
          Text(
            'I start my day by punching\nprocrastination in the tacos.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 15,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            '💪  😡  💀',
            style: TextStyle(fontSize: 22, letterSpacing: 6),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Text(
                'HABITDRILL.APP',
                style: TextStyle(
                  color: AppColors.emerald.withOpacity(0.9),
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 3,
                ),
              ),
              const Spacer(),
              Text(
                'THE DRILL SGT. APP',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.3),
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ────────────────────────── Buttons ─────────────────────────────────

class _PrimaryButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _PrimaryButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          gradient: AppColors.emeraldGradient,
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(
              color: AppColors.emerald.withOpacity(0.5),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.black, size: 18),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(
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

class _SecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _SecondaryButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withOpacity(0.55),
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 2.5,
          ),
        ),
      ),
    );
  }
}
