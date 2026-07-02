import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../design/tokens.dart';
import '../services/sergeant_service.dart';
import '../services/contract_service.dart';
import 'home_screen.dart';
import 'planner_screen.dart';
import 'contracts_screen.dart';
import 'enforcement_screen.dart';
import 'ledger_screen.dart';
import 'profile_screen.dart';

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    _tickContracts();
  }

  Future<void> _tickContracts() async {
    try {
      await ContractService.tickForNewDay(
        hadViolationToday: SergeantService.hasPendingPunishment(),
      );
    } catch (_) {}
  }

  void _openPlanner() {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => const PlannerScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      resizeToAvoidBottomInset: false,
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SafeArea(
          bottom: false,
          child: IndexedStack(
            index: _tab,
            children: const [
              HomeScreen(),
              ContractsScreen(),
              EnforcementScreen(),
              LedgerScreen(),
              ProfileScreen(),
            ],
          ),
        ),
      ),
      floatingActionButton: _tab == 0 ? _buildFAB() : null,
      bottomNavigationBar: _NavBar(
        current: _tab,
        onSelect: (i) => setState(() => _tab = i),
      ),
    );
  }

  Widget _buildFAB() {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: FloatingActionButton(
        onPressed: _openPlanner,
        backgroundColor: AppColors.emerald,
        elevation: 8,
        child: const Icon(LucideIcons.plus, color: Colors.black, size: 26),
      ),
    );
  }
}

class _NavBar extends StatelessWidget {
  final int current;
  final ValueChanged<int> onSelect;

  const _NavBar({required this.current, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF050505),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05), width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: Row(
            children: [
              _NavItem(icon: LucideIcons.target, label: 'TODAY', selected: current == 0, onTap: () => onSelect(0)),
              _NavItem(icon: LucideIcons.scroll, label: 'CONTRACTS', selected: current == 1, onTap: () => onSelect(1)),
              _NavItem(icon: LucideIcons.skull, label: 'DEBT', selected: current == 2, onTap: () => onSelect(2)),
              _NavItem(icon: LucideIcons.bookOpen, label: 'LEDGER', selected: current == 3, onTap: () => onSelect(3)),
              _NavItem(icon: LucideIcons.user, label: 'PROFILE', selected: current == 4, onTap: () => onSelect(4)),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.emerald : Colors.white.withOpacity(0.35);
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 8,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
