import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../design/tokens.dart';
import '../models/violation.dart';
import '../models/exercise_set.dart';
import '../services/sergeant_service.dart';
import '../services/analytics_service.dart';
import 'sergeant/punishment_screen.dart';

class EnforcementScreen extends StatefulWidget {
  const EnforcementScreen({super.key});

  @override
  State<EnforcementScreen> createState() => _EnforcementScreenState();
}

class _EnforcementScreenState extends State<EnforcementScreen> with WidgetsBindingObserver {
  List<Violation> _pending = const [];

  @override
  void initState() {
    super.initState();
    AnalyticsService.logScreenView('enforcement');
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  void _refresh() {
    setState(() {
      _pending = SergeantService.getPendingViolations();
    });
  }

  Future<void> _startPunishment(Violation v) async {
    HapticFeedback.heavyImpact();
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PunishmentScreen(
          violation: v,
          onComplete: () => Navigator.of(context).pop(),
        ),
      ),
    );
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final total = _pending.length;
    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.emerald,
          backgroundColor: const Color(0xFF0B0B0B),
          onRefresh: () async => _refresh(),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _Header(hasDebt: total > 0)),
              if (total == 0)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: _CleanState(),
                )
              else ...[
                SliverToBoxAdapter(child: _SectionLabel(label: 'OUTSTANDING DEBT', count: total)),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList.builder(
                    itemCount: _pending.length,
                    itemBuilder: (context, i) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _DebtCard(
                        violation: _pending[i],
                        index: i,
                        onStart: () => _startPunishment(_pending[i]),
                      ),
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 32)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final bool hasDebt;
  const _Header({required this.hasDebt});

  @override
  Widget build(BuildContext context) {
    final accent = hasDebt ? AppColors.error : AppColors.emerald;
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
                  color: accent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'ENFORCEMENT',
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
              hasDebt ? 'Every debt must be paid.' : 'No debt outstanding.',
              style: TextStyle(
                color: accent.withOpacity(0.55),
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
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
  final int? count;
  const _SectionLabel({required this.label, this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              color: AppColors.error.withOpacity(0.7),
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 4,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              height: 1,
              color: AppColors.error.withOpacity(0.15),
            ),
          ),
          if (count != null) ...[
            const SizedBox(width: 10),
            Text(
              count.toString().padLeft(2, '0'),
              style: const TextStyle(
                color: AppColors.error,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                fontFamily: 'monospace',
                letterSpacing: 1,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DebtCard extends StatelessWidget {
  final Violation violation;
  final int index;
  final VoidCallback onStart;

  const _DebtCard({required this.violation, required this.index, required this.onStart});

  @override
  Widget build(BuildContext context) {
    final set = ExerciseSet.forOffense(violation.offenseNumber);
    final totalReps = set.exercises.fold<int>(0, (sum, e) => sum + e.reps);
    final dateStr = DateFormat('d MMM').format(violation.occurredAt);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.error.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.error.withOpacity(0.28), width: 1),
      ),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  violation.violationType == 'indulged' ? 'RULE BROKEN' : 'ORDER FAILED',
                  style: const TextStyle(
                    color: AppColors.error,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                dateStr.toUpperCase(),
                style: TextStyle(
                  color: Colors.white.withOpacity(0.35),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'monospace',
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            violation.habitTitle.toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.6,
              height: 1.15,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.35),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withOpacity(0.04), width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CONSEQUENCE',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.35),
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2.5,
                  ),
                ),
                const SizedBox(height: 8),
                ...set.exercises.map(
                  (e) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        Container(
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            color: AppColors.error,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            e.name,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.75),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Text(
                          '${e.reps}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Divider(color: Colors.white.withOpacity(0.05), height: 1),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      'TOTAL REPS',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.35),
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '$totalReps',
                      style: const TextStyle(
                        color: AppColors.error,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.videocam_outlined, size: 12, color: Colors.white.withOpacity(0.35)),
                    const SizedBox(width: 6),
                    Text(
                      'CAMERA VERIFICATION REQUIRED',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.35),
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: onStart,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: AppColors.error,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.error.withOpacity(0.35),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: const Text(
                'START NOW',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 3,
                ),
              ),
            ),
          ),
        ],
      ),
    ).animate(delay: (index * 80).ms).fadeIn(duration: 350.ms).slideY(begin: 0.05, end: 0);
  }
}

class _CleanState extends StatelessWidget {
  const _CleanState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 92,
            height: 92,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.emerald.withOpacity(0.4), width: 2),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.check, size: 44, color: AppColors.emerald),
          ).animate().scale(begin: const Offset(0.7, 0.7), end: const Offset(1, 1), duration: 400.ms),
          const SizedBox(height: 24),
          const Text(
            'HONOUR INTACT',
            style: TextStyle(
              color: AppColors.emerald,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: 4,
            ),
          ).animate(delay: 200.ms).fadeIn(),
          const SizedBox(height: 8),
          Text(
            'You owe no debt.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.35),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ).animate(delay: 350.ms).fadeIn(),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
