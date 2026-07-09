import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../design/tokens.dart';
import '../services/analytics_service.dart';
import 'contracts_screen.dart' show PresetParams;
import 'new_contract_screen.dart';

/// Dedicated screen that shows contract templates. Reached by tapping
/// "+ NEW CONTRACT" on the Contracts tab. Splits the old marketplace-inside-
/// dashboard mess into: Popular row of iconic presets, plus a Browse All
/// grid, plus a Build My Own escape hatch.
class NewContractTemplatesScreen extends StatelessWidget {
  const NewContractTemplatesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    AnalyticsService.logScreenView('new_contract_templates');
    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(onClose: () => Navigator.of(context).pop()),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Hero(),
                    const SizedBox(height: 28),
                    _SectionLabel(label: 'POPULAR'),
                    const SizedBox(height: 12),
                    for (int i = 0; i < _templates.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _TemplateRow(
                          template: _templates[i],
                          onTap: () => _openWizard(context, _templates[i]),
                        ).animate(delay: (60 + i * 40).ms).fadeIn(duration: 240.ms).slideX(begin: 0.03, end: 0),
                      ),
                    const SizedBox(height: 24),
                    _SectionLabel(label: 'BROWSE ALL'),
                    const SizedBox(height: 12),
                    _BuildYourOwnCard(onTap: () => _openWizard(context, null)),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openWizard(BuildContext context, _Template? t) async {
    HapticFeedback.selectionClick();
    final params = t == null
        ? null
        : PresetParams(
            title: t.title,
            emoji: t.emoji,
            targetDays: t.days,
            type: t.type,
          );
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => NewContractScreen(preset: params),
      ),
    );
  }
}

// ────────────────────────── Templates ──────────────────────────

class _Template {
  final String title;
  final String subtitle;
  final IconData icon;
  final String emoji; // still passed as fallback for the Habit model
  final int days;
  final String type;
  const _Template({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.emoji,
    required this.days,
    required this.type,
  });
}

// Two Laws + two Contracts. Kept intentionally short so POPULAR reads
// as a menu, not a catalogue.
const List<_Template> _templates = [
  // ── LAWS ──
  _Template(
    title: 'Quit Vape',
    subtitle: 'Clean lungs · 90 days',
    icon: LucideIcons.wind,
    emoji: '🚭',
    days: 90,
    type: 'bad_habit',
  ),
  _Template(
    title: 'Quit Porn',
    subtitle: 'Break the loop · 90 days',
    icon: LucideIcons.eyeOff,
    emoji: '🚫',
    days: 90,
    type: 'bad_habit',
  ),
  // ── CONTRACTS ──
  _Template(
    title: 'Exercise',
    subtitle: 'Move your body · 30 days',
    icon: LucideIcons.dumbbell,
    emoji: '💪',
    days: 30,
    type: 'habit',
  ),
  _Template(
    title: 'Study',
    subtitle: 'Sharpen the mind · 30 days',
    icon: LucideIcons.bookOpen,
    emoji: '📚',
    days: 30,
    type: 'habit',
  ),
];

// ────────────────────────── Widgets ──────────────────────────

class _TopBar extends StatelessWidget {
  final VoidCallback onClose;
  const _TopBar({required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'PICK ONE',
            style: TextStyle(
              color: Colors.white.withOpacity(0.4),
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 3,
            ),
          ),
          IconButton(
            onPressed: onClose,
            icon: Icon(Icons.close, color: Colors.white.withOpacity(0.5), size: 22),
          ),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
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
              'NEW CONTRACT',
              style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w900,
                letterSpacing: 3,
                height: 1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.only(left: 18),
          child: Text(
            'Sign a promise. Live with it.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.4),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
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
          Expanded(child: Container(height: 1, color: Colors.white.withOpacity(0.06))),
        ],
      ),
    );
  }
}

class _TemplateRow extends StatelessWidget {
  final _Template template;
  final VoidCallback onTap;
  const _TemplateRow({required this.template, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
        decoration: BoxDecoration(
          color: const Color(0xFF0B0B0B),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.05), width: 1),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withOpacity(0.08), width: 1),
              ),
              alignment: Alignment.center,
              child: Icon(template.icon, color: Colors.white.withOpacity(0.85), size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    template.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    template.subtitle,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.45),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Icon(
              LucideIcons.chevronRight,
              color: Colors.white.withOpacity(0.35),
              size: 18,
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
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.emerald.withOpacity(0.15), AppColors.emerald.withOpacity(0.05)],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.emerald.withOpacity(0.35), width: 1),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(LucideIcons.plus, color: AppColors.emerald, size: 18),
            SizedBox(width: 10),
            Text(
              'BUILD MY OWN',
              style: TextStyle(
                color: AppColors.emerald,
                fontSize: 12,
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
