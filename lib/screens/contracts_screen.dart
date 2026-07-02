import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../design/tokens.dart';
import '../models/contract.dart';
import '../services/contract_service.dart';
import '../services/analytics_service.dart';
import 'new_contract_screen.dart';

class ContractsScreen extends StatefulWidget {
  const ContractsScreen({super.key});

  @override
  State<ContractsScreen> createState() => _ContractsScreenState();
}

class _ContractsScreenState extends State<ContractsScreen> {
  List<Contract> _contracts = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    AnalyticsService.logScreenView('contracts');
    _load();
  }

  Future<void> _load() async {
    final list = await ContractService.loadAll();
    if (!mounted) return;
    setState(() {
      _contracts = list;
      _loading = false;
    });
  }

  Future<void> _openNewContract() async {
    await Navigator.of(context).push<Contract>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const NewContractScreen(),
      ),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final active = _contracts.where((c) => c.status == ContractStatus.active).toList()
      ..sort((a, b) => b.daysCompleted.compareTo(a.daysCompleted));
    final finished = _contracts.where((c) => c.status != ContractStatus.active).toList()
      ..sort((a, b) => (b.completedAt ?? b.startDate).compareTo(a.completedAt ?? a.startDate));

    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.emerald))
            : CustomScrollView(
                slivers: [
                  const SliverToBoxAdapter(child: _Header()),
                  SliverToBoxAdapter(
                    child: _SectionLabel(
                      label: 'ACTIVE',
                      count: active.length,
                    ),
                  ),
                  if (active.isEmpty)
                    const SliverToBoxAdapter(child: _EmptyState())
                  else
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      sliver: SliverList.builder(
                        itemCount: active.length,
                        itemBuilder: (context, i) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _ContractCard(contract: active[i], index: i),
                        ),
                      ),
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 32)),
                  const SliverToBoxAdapter(
                    child: _SectionLabel(label: 'NEW CONTRACT'),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: SliverToBoxAdapter(
                      child: _NewContractGrid(onTap: _openNewContract),
                    ),
                  ),
                  if (finished.isNotEmpty) ...[
                    const SliverToBoxAdapter(child: SizedBox(height: 32)),
                    SliverToBoxAdapter(
                      child: _SectionLabel(label: 'HISTORY', count: finished.length),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      sliver: SliverList.builder(
                        itemCount: finished.length,
                        itemBuilder: (context, i) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _HistoryRow(contract: finished[i]),
                        ),
                      ),
                    ),
                  ],
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
                  color: AppColors.emerald,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'CONTRACTS',
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
              'Every promise creates accountability.',
              style: TextStyle(
                color: Colors.white.withOpacity(0.35),
                fontSize: 12,
                fontWeight: FontWeight.w500,
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
              color: Colors.white.withOpacity(0.45),
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
          if (count != null) ...[
            const SizedBox(width: 10),
            Text(
              count.toString().padLeft(2, '0'),
              style: TextStyle(
                color: Colors.white.withOpacity(0.35),
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

class _ContractCard extends StatelessWidget {
  final Contract contract;
  final int index;
  const _ContractCard({required this.contract, required this.index});

  @override
  Widget build(BuildContext context) {
    final hasTarget = contract.hasTarget;
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0B0B0B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05), width: 1),
      ),
      padding: const EdgeInsets.fromLTRB(20, 18, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                contract.emoji,
                style: const TextStyle(fontSize: 28, height: 1),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      contract.title.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.4,
                        height: 1.1,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _typeLabel(contract.type),
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.35),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _DayBadge(contract: contract),
            ],
          ),
          if (hasTarget) ...[
            const SizedBox(height: 16),
            _ProgressBar(progress: contract.progress),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${(contract.progress * 100).round()}%',
                  style: TextStyle(
                    color: AppColors.emerald.withOpacity(0.85),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'monospace',
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  '${contract.daysRemaining} DAYS LEFT',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.35),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ],
          if (contract.daysFailed > 0) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: AppColors.error,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${contract.daysFailed} FAILED',
                  style: TextStyle(
                    color: AppColors.error.withOpacity(0.75),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    ).animate(delay: (index * 70).ms).fadeIn(duration: 350.ms).slideY(begin: 0.05, end: 0);
  }

  String _typeLabel(ContractType t) {
    switch (t) {
      case ContractType.quit:
        return 'ABSTAIN';
      case ContractType.build:
        return 'BUILD';
      case ContractType.streak:
        return 'STREAK';
    }
  }
}

class _DayBadge extends StatelessWidget {
  final Contract contract;
  const _DayBadge({required this.contract});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.emerald.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.emerald.withOpacity(0.25), width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            contract.progressLabel,
            style: const TextStyle(
              color: AppColors.emerald,
              fontSize: 14,
              fontWeight: FontWeight.w900,
              fontFamily: 'monospace',
              letterSpacing: 0.5,
              height: 1,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            contract.hasTarget ? 'DAYS' : 'DAY STREAK',
            style: TextStyle(
              color: AppColors.emerald.withOpacity(0.6),
              fontSize: 8,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final double progress;
  const _ProgressBar({required this.progress});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) => Container(
        height: 3,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(2),
        ),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Container(
            width: c.maxWidth * progress,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.emeraldDark, AppColors.emerald, AppColors.emeraldLight],
              ),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ),
    );
  }
}

class _NewContractGrid extends StatelessWidget {
  final VoidCallback onTap;
  const _NewContractGrid({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final presets = ContractTemplate.presets;
    return Column(
      children: [
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 2.4,
          ),
          itemCount: presets.length,
          itemBuilder: (context, i) => _TemplateChip(
            emoji: presets[i].emoji,
            title: presets[i].title,
            onTap: onTap,
          ).animate(delay: (i * 40).ms).fadeIn(duration: 250.ms),
        ),
        const SizedBox(height: 10),
        _BuildYourOwnCard(onTap: onTap)
            .animate(delay: 300.ms)
            .fadeIn(duration: 250.ms),
      ],
    );
  }
}

class _TemplateChip extends StatelessWidget {
  final String emoji;
  final String title;
  final VoidCallback onTap;
  const _TemplateChip({required this.emoji, required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF0B0B0B),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.05), width: 1),
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 20, height: 1)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BuildYourOwnCard extends StatelessWidget {
  final VoidCallback onTap;
  const _BuildYourOwnCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.emerald.withOpacity(0.15),
              AppColors.emerald.withOpacity(0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.emerald.withOpacity(0.35), width: 1),
        ),
        child: const Center(
          child: Text(
            '+  BUILD MY OWN',
            style: TextStyle(
              color: AppColors.emerald,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 3,
            ),
          ),
        ),
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  final Contract contract;
  const _HistoryRow({required this.contract});

  @override
  Widget build(BuildContext context) {
    final completed = contract.status == ContractStatus.completed;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF080808),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.03), width: 1),
      ),
      child: Row(
        children: [
          Text(contract.emoji, style: const TextStyle(fontSize: 18, height: 1)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              contract.title.toUpperCase(),
              style: TextStyle(
                color: Colors.white.withOpacity(0.55),
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            completed ? 'VERIFIED' : 'BROKEN',
            style: TextStyle(
              color: (completed ? AppColors.emerald : AppColors.error).withOpacity(0.75),
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 28),
        decoration: BoxDecoration(
          color: const Color(0xFF080808),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.04), width: 1),
        ),
        child: Column(
          children: [
            Text(
              'NO ACTIVE CONTRACTS',
              style: TextStyle(
                color: Colors.white.withOpacity(0.35),
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 3,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Pick one below to make your first promise.',
              style: TextStyle(
                color: Colors.white.withOpacity(0.25),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
