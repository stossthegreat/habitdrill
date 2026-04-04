import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../design/tokens.dart';
import '../services/analytics_service.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    AnalyticsService.logScreenView('terms');
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
          'Terms & Conditions',
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

            _buildSection(
              '1. Acceptance of Terms',
              'By accessing and using HabitDrill, you accept and agree to be bound by these terms. If you do not agree, please do not use this application.',
            ),

            _buildSection(
              '2. Description of Service',
              'HabitDrill is a habit accountability app that uses exercise-based consequences to reinforce discipline. The service includes:\n\n'
              '• Habit tracking and scheduling\n'
              '• Task and bad habit management\n'
              '• Exercise-based accountability (drill sergeant mode)\n'
              '• Alarm reminders and notifications\n'
              '• Progress tracking with streaks',
            ),

            _buildSection(
              '3. Health Disclaimer',
              'HabitDrill includes physical exercise components. By using this app, you acknowledge:\n\n'
              '• You are physically capable of performing the exercises shown\n'
              '• You should consult a doctor before starting any exercise program\n'
              '• HabitDrill is not a substitute for professional medical or fitness advice\n'
              '• You exercise at your own risk and responsibility',
            ),

            _buildSection(
              '4. User Accounts',
              'You are responsible for maintaining the confidentiality of your account and password. You agree to accept responsibility for all activities under your account.',
            ),

            _buildSection(
              '5. User Conduct',
              'You agree not to:\n\n'
              '• Use the service for any illegal purpose\n'
              '• Attempt to gain unauthorized access to the system\n'
              '• Interfere with or disrupt the service\n'
              '• Reverse engineer or extract source code',
            ),

            _buildSection(
              '6. Intellectual Property',
              'All content, features, and functionality of HabitDrill, including text, graphics, logos, videos, audio, and software, are the exclusive property of HabitDrill and are protected by intellectual property laws.',
            ),

            _buildSection(
              '7. Limitation of Liability',
              'HabitDrill is provided "as is" without warranties of any kind. We are not liable for any injuries, damages, or losses resulting from exercise activities performed through the app. Use all features at your own risk.',
            ),

            _buildSection(
              '8. Termination',
              'We reserve the right to terminate or suspend your account at any time for violation of these terms.',
            ),

            _buildSection(
              '9. Changes to Terms',
              'We may modify these terms at any time. Continued use of the service after changes constitutes acceptance of the new terms.',
            ),

            _buildSection(
              '10. Contact',
              'For questions about these terms, contact us at:\n\n'
              'Email: support@habitdrill.com',
            ),

            const SizedBox(height: AppSpacing.xl),

            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.emerald.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppBorderRadius.lg),
                border: Border.all(color: AppColors.emerald.withOpacity(0.3)),
              ),
              child: Text(
                'By using HabitDrill, you acknowledge that you have read, understood, and agree to these Terms and Conditions.',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.emerald,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
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
