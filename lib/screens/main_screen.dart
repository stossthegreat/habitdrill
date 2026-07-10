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

// ────────────────────────── Opal-style floating tab bar ──────────────
//
// Floating dark pill capsule. Three FIXED-WIDTH tabs, each showing icon
// on top and label underneath — ALL labels visible at ALL times, no
// expanding pill, no size-change animation. Selection state is just an
// emerald tint on the active tab's icon (and slightly brighter label);
// inactive tabs are grey. This is Opal's tab bar, one-for-one.

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
        24,
        0,
        24,
        MediaQuery.of(context).padding.bottom + 12,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF111111),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withOpacity(0.05), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.45),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            for (int i = 0; i < _items.length; i++)
              Expanded(
                child: _NavTab(
                  icon: _items[i].icon,
                  label: _items[i].label,
                  selected: current == i,
                  onTap: () => onSelect(i),
                ),
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

class _NavTab extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavTab({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Colors are the only thing that changes between states. No padding
    // shift, no size shift, no re-flow — the layout is IDENTICAL for
    // every tab, active or not.
    final Color iconColor = selected ? AppColors.emerald : const Color(0xFF8A8A8A);
    final Color labelColor = selected ? AppColors.emerald : const Color(0xFF8A8A8A);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22, color: iconColor),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: labelColor,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
