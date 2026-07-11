import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../design/tokens.dart';
import '../services/analytics_service.dart';
import 'terms_screen.dart';
import 'privacy_screen.dart';
import 'support_screen.dart';
import 'paywall_screen.dart';

/// Erly-style clean list. This is BOTH the standalone Settings screen
/// (when opened from a link) and the SETTINGS tab in the bottom nav.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    AnalyticsService.logScreenView('settings');
    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
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
                    'SETTINGS',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 4,
                      height: 1,
                    ),
                  ),
                  const Spacer(),
                  // Close X — Settings is now only reached via the
                  // header gear icon (no tab), so it always needs a
                  // way out.
                  GestureDetector(
                    onTap: () => Navigator.of(context).maybePop(),
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Icon(
                        Icons.close_rounded,
                        color: Colors.white.withOpacity(0.55),
                        size: 24,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _SettingsRow(
                icon: LucideIcons.creditCard,
                label: 'Manage Subscription',
                onTap: () => _openManageSubscription(),
              ),
              _SettingsRow(
                icon: LucideIcons.crown,
                label: 'Unlock Pro',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    fullscreenDialog: true,
                    builder: (_) => const PaywallScreen(),
                  ),
                ),
              ),
              _SettingsRow(
                icon: LucideIcons.bell,
                label: 'Notifications',
                onTap: () => _openAppSettings(),
              ),
              _SettingsRow(
                icon: LucideIcons.alarmClock,
                label: 'Alarm Settings',
                onTap: () => _openAppSettings(),
              ),
              _SettingsRow(
                icon: LucideIcons.helpCircle,
                label: 'Support',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SupportScreen()),
                ),
              ),
              _SettingsRow(
                icon: LucideIcons.star,
                label: 'Leave a Review',
                onTap: () => _leaveReview(),
              ),
              _SettingsRow(
                icon: LucideIcons.lock,
                label: 'Privacy Policy',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PrivacyScreen()),
                ),
              ),
              _SettingsRow(
                icon: LucideIcons.fileText,
                label: 'Terms of Service',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const TermsScreen()),
                ),
              ),
              _SettingsRow(
                icon: LucideIcons.info,
                label: 'About',
                onTap: () => _showAbout(context),
              ),
              const SizedBox(height: 32),
              const _Footer(),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openManageSubscription() async {
    // Deep link straight to the App Store subscriptions management page.
    final uri = Uri.parse('https://apps.apple.com/account/subscriptions');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _openAppSettings() async {
    // Deep link to the app's iOS Settings page — Notifications live there,
    // alarm-related settings live under the Notifications section, so one
    // entry point covers both.
    final uri = Uri.parse('app-settings:');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _leaveReview() async {
    // Real App Store URL — id6761660060 is HabitDrill's actual App
    // Store id. `action=write-review` deep-links straight into the
    // write-review sheet on iOS.
    final uri = Uri.parse(
      'https://apps.apple.com/gb/app/habitdrill/id6761660060?action=write-review',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _showAbout(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'HabitDrill',
      applicationVersion: '1.0.2',
      applicationLegalese: 'Discipline enforcement system.',
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SettingsRow({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF0B0B0B),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.05), width: 1),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: Colors.white.withOpacity(0.75), size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
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

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          Text(
            'HABITDRILL',
            style: TextStyle(
              color: Colors.white.withOpacity(0.25),
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'v1.0.2',
            style: TextStyle(
              color: Colors.white.withOpacity(0.2),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
