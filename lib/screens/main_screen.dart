import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../design/tokens.dart';
import 'home_screen.dart';
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

  void _selectTab(int i) {
    if (i == _tab) return;
    HapticFeedback.selectionClick();
    setState(() => _tab = i);
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
      bottomNavigationBar: _NavBar(current: _tab, onSelect: _selectTab),
    );
  }
}

class _NavBar extends StatelessWidget {
  final int current;
  final ValueChanged<int> onSelect;

  const _NavBar({required this.current, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    const items = <_NavItemData>[
      _NavItemData(icon: LucideIcons.target, label: 'TODAY'),
      _NavItemData(icon: LucideIcons.scroll, label: 'CONTRACTS'),
      _NavItemData(icon: LucideIcons.skull, label: 'DEBT'),
      _NavItemData(icon: LucideIcons.bookOpen, label: 'LEDGER'),
      _NavItemData(icon: LucideIcons.user, label: 'PROFILE'),
    ];
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF040404),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05), width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 66,
          child: Stack(
            children: [
              AnimatedAlign(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                alignment: Alignment(-1 + (current * 2 / (items.length - 1)), -1),
                child: FractionallySizedBox(
                  widthFactor: 1 / items.length,
                  child: Center(
                    child: Container(
                      width: 26,
                      height: 2,
                      decoration: BoxDecoration(
                        color: AppColors.emerald,
                        borderRadius: BorderRadius.circular(1),
                        boxShadow: [
                          BoxShadow(color: AppColors.emerald.withOpacity(0.7), blurRadius: 8),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Row(
                children: [
                  for (int i = 0; i < items.length; i++)
                    _NavItem(
                      icon: items[i].icon,
                      label: items[i].label,
                      selected: current == i,
                      onTap: () => onSelect(i),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItemData {
  final IconData icon;
  final String label;
  const _NavItemData({required this.icon, required this.label});
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
    final color = selected ? AppColors.emerald : Colors.white.withOpacity(0.32);
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 6),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: selected ? AppColors.emerald.withOpacity(0.1) : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(height: 3),
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
