import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import '../design/tokens.dart';
import '../widgets/glass_card.dart';

class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  void _launchEmail() async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: 'support@habitdrill.com',
      query: 'subject=HabitDrill Support Request',
    );
    if (await canLaunchUrl(emailUri)) {
      await launchUrl(emailUri);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.baseDark1,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Help & Support',
          style: AppTextStyles.h2.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GlassCard(
              child: Column(
                children: [
                  const Icon(LucideIcons.messageCircle, size: 48, color: AppColors.emerald),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Need Help, Soldier?',
                    style: AppTextStyles.h3.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Get answers to common questions or reach out to our support team.',
                    style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.xl),

            _buildContactCard(
              'Email Support',
              'Get help via email',
              LucideIcons.mail,
              'support@habitdrill.com',
              _launchEmail,
            ),

            const SizedBox(height: AppSpacing.lg),

            Text(
              'Frequently Asked Questions',
              style: AppTextStyles.h3.copyWith(fontWeight: FontWeight.w700),
            ),

            const SizedBox(height: AppSpacing.lg),

            _buildFAQ(
              'How do I create a habit?',
              'Tap the Planner button on the home screen, then tap "Add New". Fill in the title, time, and repeat days, then tap "Create".',
            ),

            _buildFAQ(
              'How do I mark a habit as done?',
              'On the home screen, tap any habit card to toggle it between "planned" and "done". Your streak updates automatically.',
            ),

            _buildFAQ(
              'What happens when I break a habit?',
              'The drill sergeant kicks in. You\'ll face a video of the sergeant going off, then you\'ll be forced to complete exercises like burpees, push-ups, and high knees. The exercises get harder the more you slip.',
            ),

            _buildFAQ(
              'Can I edit or delete a habit?',
              'Tap the Planner button, switch to the "Manage" tab, and you can delete any habit from there.',
            ),

            _buildFAQ(
              'How do alarms work?',
              'When creating a habit, set a time and toggle the alarm on. You\'ll get a notification reminder at that time every day the habit is scheduled.',
            ),

            _buildFAQ(
              'Can I use HabitDrill offline?',
              'Yes. All habit tracking works offline. Your data is stored locally on your device.',
            ),

            _buildFAQ(
              'The app crashed or has a bug. What should I do?',
              'Email us at support@habitdrill.com with your device model, OS version, and steps to reproduce the issue.',
            ),

            const SizedBox(height: AppSpacing.xl),

            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.emerald.withOpacity(0.3),
                    AppColors.cyan.withOpacity(0.2),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(AppBorderRadius.lg),
                border: Border.all(color: AppColors.emerald.withOpacity(0.4)),
              ),
              child: Column(
                children: [
                  const Icon(LucideIcons.heart, size: 32, color: Colors.black),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Still need help?',
                    style: AppTextStyles.h3.copyWith(fontWeight: FontWeight.w700, color: Colors.black),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Email us at support@habitdrill.com\nWe typically respond within 24 hours.',
                    style: AppTextStyles.body.copyWith(color: Colors.black87),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildContactCard(String title, String subtitle, IconData icon, String value, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: GlassCard(
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: AppColors.emeraldGradient,
                borderRadius: BorderRadius.circular(AppBorderRadius.lg),
              ),
              child: Icon(icon, color: Colors.black, size: 28),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: AppTextStyles.caption.copyWith(color: AppColors.textTertiary)),
                  const SizedBox(height: 4),
                  Text(value, style: AppTextStyles.caption.copyWith(color: AppColors.emerald, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            const Icon(LucideIcons.externalLink, size: 20, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }

  Widget _buildFAQ(String question, String answer) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 2),
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.emerald.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(AppBorderRadius.sm),
                  ),
                  child: const Icon(LucideIcons.helpCircle, size: 16, color: AppColors.emerald),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    question,
                    style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Padding(
              padding: const EdgeInsets.only(left: 34),
              child: Text(
                answer,
                style: AppTextStyles.body.copyWith(color: AppColors.textSecondary, height: 1.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
