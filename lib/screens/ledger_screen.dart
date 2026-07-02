import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../design/tokens.dart';
import '../services/ledger_service.dart';
import '../services/analytics_service.dart';

class LedgerScreen extends StatefulWidget {
  const LedgerScreen({super.key});

  @override
  State<LedgerScreen> createState() => _LedgerScreenState();
}

class _LedgerScreenState extends State<LedgerScreen> {
  LedgerSnapshot? _snap;

  @override
  void initState() {
    super.initState();
    AnalyticsService.logScreenView('ledger');
    _load();
  }

  Future<void> _load() async {
    final s = await LedgerService.read();
    if (!mounted) return;
    setState(() => _snap = s);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      body: SafeArea(
        child: _snap == null
            ? const Center(child: CircularProgressIndicator(color: AppColors.emerald))
            : CustomScrollView(
                slivers: [
                  const SliverToBoxAdapter(child: _Header()),
                  SliverToBoxAdapter(child: _PromiseBlock(snap: _snap!)),
                  const SliverToBoxAdapter(child: SizedBox(height: 28)),
                  SliverToBoxAdapter(child: _PunishmentBlock(snap: _snap!)),
                  const SliverToBoxAdapter(child: SizedBox(height: 28)),
                  SliverToBoxAdapter(child: _RepsBlock(snap: _snap!)),
                  const SliverToBoxAdapter(child: SizedBox(height: 28)),
                  SliverToBoxAdapter(child: _Footer(snap: _snap!)),
                  const SliverToBoxAdapter(child: SizedBox(height: 40)),
                ],
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
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 6,
                height: 22,
                decoration: BoxDecoration(
                  color: AppColors.amber,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'LEDGER',
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
              'This never resets. Ever.',
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

class _SectionLabel extends StatelessWidget {
  final String label;
  final Color color;
  const _SectionLabel({required this.label, this.color = const Color(0x99FFFFFF)});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 4,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              height: 1,
              color: Colors.white.withOpacity(0.06),
            ),
          ),
        ],
      ),
    );
  }
}

class _PromiseBlock extends StatelessWidget {
  final LedgerSnapshot snap;
  const _PromiseBlock({required this.snap});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(label: 'PROMISES', color: Colors.white.withOpacity(0.45)),
        Padding(
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
                _LedgerRow(label: 'Promises Made', value: snap.promisesMade, valueColor: Colors.white),
                _LedgerRow(label: 'Promises Kept', value: snap.promisesKept, valueColor: AppColors.emerald),
                _LedgerRow(label: 'Promises Broken', value: snap.promisesBroken, valueColor: AppColors.error, last: true),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PunishmentBlock extends StatelessWidget {
  final LedgerSnapshot snap;
  const _PunishmentBlock({required this.snap});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(label: 'PUNISHMENTS', color: Colors.white.withOpacity(0.45)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF0B0B0B),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.05), width: 1),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: _LedgerRow(
              label: 'Punishments Completed',
              value: snap.punishmentsCompleted,
              valueColor: AppColors.amber,
              last: true,
            ),
          ),
        ),
      ],
    );
  }
}

class _RepsBlock extends StatelessWidget {
  final LedgerSnapshot snap;
  const _RepsBlock({required this.snap});

  @override
  Widget build(BuildContext context) {
    final entries = _exerciseOrder(snap);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(label: 'VERIFIED REPS', color: Colors.white.withOpacity(0.45)),
        Padding(
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
                for (int i = 0; i < entries.length; i++)
                  _LedgerRow(
                    label: entries[i].$1,
                    value: entries[i].$2,
                    valueColor: Colors.white,
                    last: i == entries.length - 1 && snap.totalReps == 0,
                  ),
                if (snap.totalReps > 0)
                  _LedgerRow(
                    label: 'TOTAL',
                    value: snap.totalReps,
                    valueColor: AppColors.emerald,
                    labelColor: Colors.white.withOpacity(0.85),
                    bold: true,
                    last: true,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  List<(String, int)> _exerciseOrder(LedgerSnapshot snap) {
    const order = [
      ('Squats', 'squats'),
      ('Burpees', 'burpees'),
      ('High Knees', 'high_knees'),
      ('Push-ups', 'push_ups'),
    ];
    final out = <(String, int)>[];
    for (final (name, id) in order) {
      out.add((name, snap.repsFor(id)));
    }
    return out;
  }
}

class _Footer extends StatelessWidget {
  final LedgerSnapshot snap;
  const _Footer({required this.snap});

  @override
  Widget build(BuildContext context) {
    final since = DateFormat('d MMM yyyy').format(snap.disciplineSince);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 40,
            height: 1,
            color: Colors.white.withOpacity(0.15),
          ),
          const SizedBox(height: 18),
          Text(
            'DISCIPLINE SINCE',
            style: TextStyle(
              color: Colors.white.withOpacity(0.35),
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 3.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            since.toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              fontFamily: 'monospace',
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${snap.daysSinceStart} DAYS',
            style: TextStyle(
              color: AppColors.amber.withOpacity(0.75),
              fontSize: 11,
              fontWeight: FontWeight.w900,
              fontFamily: 'monospace',
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }
}

class _LedgerRow extends StatelessWidget {
  final String label;
  final int value;
  final Color valueColor;
  final Color? labelColor;
  final bool last;
  final bool bold;

  const _LedgerRow({
    required this.label,
    required this.value,
    required this.valueColor,
    this.labelColor,
    this.last = false,
    this.bold = false,
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
                color: labelColor ?? Colors.white.withOpacity(0.6),
                fontSize: 13,
                fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
                letterSpacing: bold ? 2 : 0.2,
              ),
            ),
          ),
          Text(
            _formatNumber(value),
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

  static String _formatNumber(int n) {
    final s = n.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buffer.write(',');
      buffer.write(s[i]);
    }
    return buffer.toString();
  }
}
