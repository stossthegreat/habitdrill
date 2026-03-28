import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../design/tokens.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

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
          'Privacy Policy',
          style: AppTextStyles.h2.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Last updated: March 28, 2026',
              style: AppTextStyles.caption.copyWith(color: AppColors.textTertiary),
            ),
            const SizedBox(height: AppSpacing.xl),

            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.emerald.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppBorderRadius.lg),
                border: Border.all(color: AppColors.emerald.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  Icon(LucideIcons.shield, size: 32, color: AppColors.emerald),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Your Privacy Matters',
                    style: AppTextStyles.h3.copyWith(color: AppColors.emerald, fontWeight: FontWeight.w700),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'We are committed to protecting your personal information and your right to privacy.',
                    style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.xl),

            _buildSection(
              '1. Information We Collect',
              'Account Information:\n'
              '• Email address and display name\n'
              '• Account preferences and settings\n\n'
              'Usage Data:\n'
              '• Habits, tasks, and bad habits you create\n'
              '• Completion history and streaks\n'
              '• Exercise session data\n\n'
              'Device Information:\n'
              '• Device type and operating system\n'
              '• App version and crash reports',
            ),

            _buildSection(
              '2. How We Use Your Information',
              'We use your information to:\n\n'
              '• Provide and improve Drillsarj services\n'
              '• Track your habits and exercise progress\n'
              '• Send alarm reminders and notifications\n'
              '• Ensure security and prevent fraud\n'
              '• Improve the app experience',
            ),

            _buildSection(
              '3. Data Storage and Security',
              '• Habit data is stored locally on your device\n'
              '• Authentication is handled securely via Firebase\n'
              '• All data is encrypted in transit\n'
              '• We do not sell your personal information',
            ),

            _buildSection(
              '4. Data Sharing',
              'We do NOT sell your personal data. We may share data only:\n\n'
              '• With service providers that help operate the app (e.g., Firebase)\n'
              '• When required by law\n'
              '• In the event of a business transfer',
            ),

            _buildSection(
              '5. Your Rights',
              'You have the right to:\n\n'
              '• Access your personal data\n'
              '• Correct your information\n'
              '• Delete your account and all data\n'
              '• Opt out of notifications\n\n'
              'Contact support@drillsarj.com to exercise these rights.',
            ),

            _buildSection(
              '6. Children\'s Privacy',
              'Drillsarj is not intended for users under 13 years of age. We do not knowingly collect personal information from children.',
            ),

            _buildSection(
              '7. Changes to Privacy Policy',
              'We may update this policy from time to time. Continued use of the app after changes constitutes acceptance.',
            ),

            _buildSection(
              '8. Contact Us',
              'Questions about this Privacy Policy?\n\n'
              'Email: privacy@drillsarj.com',
            ),

            const SizedBox(height: AppSpacing.xl),

            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.glassBackground,
                borderRadius: BorderRadius.circular(AppBorderRadius.lg),
                border: Border.all(color: AppColors.glassBorder),
              ),
              child: Row(
                children: [
                  const Icon(LucideIcons.lock, color: AppColors.emerald, size: 20),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      'Your data is encrypted and secure. We will never sell your personal information.',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
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

  Widget _buildSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTextStyles.h3.copyWith(fontWeight: FontWeight.w700, color: AppColors.emerald),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            content,
            style: AppTextStyles.body.copyWith(color: AppColors.textSecondary, height: 1.6),
          ),
        ],
      ),
    );
  }
}
