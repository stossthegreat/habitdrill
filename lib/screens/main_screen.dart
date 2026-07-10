import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../design/tokens.dart';
import 'home_screen.dart';
import 'contracts_screen.dart';
import 'profile_screen.dart';
// Settings still reachable via the gear icon on Home's top row.

/// Global handle so save-flows (New Contract, New Wake Alarm) can drop
/// the user back on a specific tab. Tab index is 0=Today, 1=Contracts,
/// 2=Profile. Setting to -1 clears.
class MainNav {
  static final ValueNotifier<int> targetTab = ValueNotifier(-1);
  static void goToContracts() => targetTab.value = 1;
  static void goToToday() => targetTab.value = 0;
  static void goToProfile() => targetTab.value = 2;
}

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
    MainNav.targetTab.addListener(_onTargetTab);
  }

  @override
  void dispose() {
    MainNav.targetTab.removeListener(_onTargetTab);
    super.dispose();
  }

  void _onTargetTab() {
    final t = MainNav.targetTab.value;
    if (t < 0) return;
    if (mounted && t != _tab) {
      setState(() => _tab = t);
    }
    // Reset so the next set-and-notify fires even for the same tab.
    MainNav.targetTab.value = -1;
  }

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
      backgroundColor: const Color(0xFF050505),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SafeArea(
          bottom: false,
          child: IndexedStack(
            index: _tab,
            children: const [
              HomeScreen(),
              ContractsScreen(),
              ProfileScreen(),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _NavBar(current: _tab, onSelect: _selectTab),
    );
  }
}

// ────────────────────────── Opal-style pill nav bar ──────────────────
//
// Floating pill on a dark background. Selected tab renders as an
// emerald pill with black icon+label; unselected tabs are outlined
// icons only, no label — the label expands with a spring only for the
// active tab. Sits inside the safe area with a bottom margin so it
// reads as its own object, not a system component.

class _NavBar extends StatelessWidget {
  final int current;
  final ValueChanged<int> onSelect;
  const _NavBar({required this.current, required this.onSelect});

  static const _items = <_NavItemData>[
    _NavItemData(icon: LucideIcons.target, label: 'Today'),
    _NavItemData(icon: LucideIcons.scroll, label: 'Contracts'),
    _NavItemData(icon: LucideIcons.user, label: 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        MediaQuery.of(context).padding.bottom + 12,
      ),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: const Color(0xFF0B0B0B),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withOpacity(0.06), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.45),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            for (int i = 0; i < _items.length; i++)
              _NavPill(
                icon: _items[i].icon,
                label: _items[i].label,
                selected: current == i,
                onTap: () => onSelect(i),
              ),
          ],
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

class _NavPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavPill({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(
          horizontal: selected ? 18 : 14,
          vertical: 11,
        ),
        decoration: BoxDecoration(
          color: selected ? AppColors.emerald : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppColors.emerald.withOpacity(0.45),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: selected
                  ? Colors.black
                  : Colors.white.withOpacity(0.55),
            ),
            // Label only on the active pill — same as Opal's bar.
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              child: selected
                  ? Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Text(
                        label,
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.2,
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}
