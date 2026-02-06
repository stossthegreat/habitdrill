import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../design/tokens.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

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
          'Terms & Conditions',
          style: AppTextStyles.h2.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Last updated: November 5, 2025',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            
            _buildSection(
              '1. Acceptance of Terms',
              'By accessing and using Future-You OS, you accept and agree to be bound by the terms and provisions of this agreement. If you do not agree to these terms, please do not use this application.',
            ),
            
            _buildSection(
              '2. Description of Service',
              'Future-You OS is an AI-powered habit tracking and personal development system that helps users discover their life\'s purpose and build sustainable habits. The service includes:\n\n'
              '• AI-driven goal discovery and planning\n'
              '• Science-backed habit recommendations\n'
              '• Daily motivation and accountability messages\n'
              '• Progress tracking and analytics\n'
              '• Personalized coaching through AI conversations',
            ),
            
            _buildSection(
              '3. User Accounts',
              'You are responsible for maintaining the confidentiality of your account and password. You agree to accept responsibility for all activities that occur under your account. You must immediately notify us of any unauthorized use of your account.',
            ),
            
            _buildSection(
              '4. AI-Generated Content',
              'Future-You OS uses artificial intelligence to generate personalized content, including messages, recommendations, and guidance. While we strive for accuracy and relevance:\n\n'
              '• AI-generated content is for informational purposes only\n'
              '• It should not replace professional medical, psychological, or financial advice\n'
              '• We do not guarantee the accuracy of all AI-generated recommendations\n'
              '• You should use your own judgment when following any advice',
            ),
            
            _buildSection(
              '5. Subscription and Payment',
              'Free Tier: Basic habit tracking and task management\n'
              'Premium Tier: Full access to AI features, unlimited What-If planning, and personalized coaching. Pricing varies by region and is displayed at the time of purchase.\n\n'
              'Subscriptions auto-renew unless cancelled at least 24 hours before the end of the current billing period. You can manage or cancel your subscription in Google Play Store > Subscriptions (Android) or Settings > Apple ID > Subscriptions (iOS). Cancellations take effect at the end of the current billing cycle. No refunds for partial periods.',
            ),
            
            _buildSection(
              '6. User Conduct',
              'You agree not to:\n\n'
              '• Use the service for any illegal purpose\n'
              '• Attempt to gain unauthorized access to the system\n'
              '• Interfere with or disrupt the service\n'
              '• Share your account credentials with others\n'
              '• Reverse engineer or attempt to extract source code',
            ),
            
            _buildSection(
              '7. Intellectual Property',
              'All content, features, and functionality of Future-You OS, including but not limited to text, graphics, logos, icons, images, audio clips, and software, are the exclusive property of Future-You OS and are protected by copyright, trademark, and other intellectual property laws.',
            ),
            
            _buildSection(
              '8. Data and Privacy',
              'Your privacy is important to us. Please review our Privacy Policy to understand how we collect, use, and protect your personal information. By using Future-You OS, you consent to our data practices as described in the Privacy Policy.',
            ),
            
            _buildSection(
              '9. Limitation of Liability',
              'Future-You OS is provided "as is" without warranties of any kind. We shall not be liable for any indirect, incidental, special, consequential, or punitive damages resulting from your use of or inability to use the service. Our total liability shall not exceed the amount you paid for the service in the past 12 months.',
            ),
            
            _buildSection(
              '10. Termination',
              'We reserve the right to terminate or suspend your account at any time for violation of these terms. Upon termination, your right to use the service will immediately cease, though certain provisions of these terms will survive termination.',
            ),
            
            _buildSection(
              '11. Changes to Terms',
              'We reserve the right to modify these terms at any time. We will notify users of any material changes via email or in-app notification. Continued use of the service after changes constitutes acceptance of the new terms.',
            ),
            
            _buildSection(
              '12. Contact Information',
              'For questions about these terms, please contact us at:\n\n'
              'Email: support@futureyou-os.com\n'
              'Website: www.futureyou-os.com',
            ),
            
            const SizedBox(height: AppSpacing.xl),
            
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.emerald.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppBorderRadius.lg),
                border: Border.all(
                  color: AppColors.emerald.withOpacity(0.3),
                ),
              ),
              child: Text(
                'By using Future-You OS, you acknowledge that you have read, understood, and agree to be bound by these Terms and Conditions.',
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
            style: AppTextStyles.h3.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.emerald,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            content,
            style: AppTextStyles.body.copyWith(
              color: AppColors.textSecondary,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

