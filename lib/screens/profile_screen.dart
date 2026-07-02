import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _Header(),
                    _RankBadge(rank: _snap!.rank),
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
  const _RankBadge({required this.rank});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 28),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0A0F0D), Color(0xFF0B0B0B)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.emerald.withOpacity(0.35), width: 1),
          boxShadow: [
            BoxShadow(
              color: AppColors.emerald.withOpacity(0.12),
              blurRadius: 40,
              spreadRadius: -8,
            ),
          ],
        ),
        child: Column(
          children: [
            Text(
              'RANK',
              style: TextStyle(
                color: Colors.white.withOpacity(0.35),
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 4,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              rank,
              style: const TextStyle(
                color: AppColors.emerald,
                fontSize: 32,
                fontWeight: FontWeight.w900,
                letterSpacing: 5,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    ).animate(delay: 100.ms).fadeIn(duration: 400.ms).slideY(begin: 0.06, end: 0);
  }
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
            _Row(label: 'Honour', value: snap.honour.toString(), valueColor: AppColors.amber),
            _Row(label: 'Discipline Score', value: _fmt(snap.disciplineScore), valueColor: AppColors.emerald),
            _Row(label: 'Current Streak', value: '$currentStreak Days'),
            _Row(label: 'Longest Contract', value: '$longestContract Days'),
            _Row(label: 'Total Debt Paid', value: '${_fmt(snap.totalReps)} Reps', last: true),
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

class _Row extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;
  final bool last;

  const _Row({
    required this.label,
    required this.value,
    this.valueColor = Colors.white,
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
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontSize: 15,
              fontWeight: FontWeight.w900,
              fontFamily: 'monospace',
              letterSpacing: 0.5,
            ),
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
    );
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
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: AppColors.emeraldGradient,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: AppColors.emerald.withOpacity(0.3),
              blurRadius: 18,
              offset: const Offset(0, 6),
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
            letterSpacing: 3,
          ),
        ),
      ),
    );
  }
}
