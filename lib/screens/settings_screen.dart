import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../design/tokens.dart';
import '../widgets/glass_card.dart';
import '../widgets/glass_button.dart';
import '../services/local_storage.dart';
import '../providers/auth_provider.dart';
import 'auth/login_screen.dart';
import 'paywall_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {

  Future<void> _logout() async {
    final confirmed = await _showConfirmationDialog(
      'Logout',
      'Are you sure you want to logout?',
    );

    if (confirmed) {
      try {
        final authService = ref.read(authServiceProvider);
        await authService.signOut();

        await LocalStorageService.clearAllHabits();
        await LocalStorageService.clearAllSettings();
        await Hive.deleteFromDisk();

        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
            (route) => false,
          );
        }
      } catch (e) {
        _showErrorSnackBar('Logout failed: $e');
      }
    }
  }

  Future<void> _deleteAccount() async {
    final confirmed = await _showConfirmationDialog(
      'Delete Account',
      'This will PERMANENTLY delete your account and all associated data. This action CANNOT be undone. Are you absolutely sure?',
      isDestructive: true,
    );

    if (confirmed) {
      try {
        final authService = ref.read(authServiceProvider);
        await authService.deleteAccount();

        await LocalStorageService.clearAllHabits();
        await LocalStorageService.clearAllSettings();
        await Hive.deleteFromDisk();

        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
            (route) => false,
          );
        }
      } catch (e) {
        _showErrorSnackBar('Delete account failed: $e');
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(LucideIcons.alertCircle, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Flexible(child: Text(message)),
          ],
        ),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppBorderRadius.sm),
        ),
      ),
    );
  }

  Future<bool> _showConfirmationDialog(
    String title,
    String content, {
    bool isDestructive = false,
  }) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.baseDark2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppBorderRadius.lg),
          side: BorderSide(
            color: isDestructive ? AppColors.error.withOpacity(0.5) : AppColors.glassBorder,
          ),
        ),
        title: Text(
          title,
          style: AppTextStyles.h3.copyWith(
            color: isDestructive ? AppColors.error : AppColors.textPrimary,
          ),
        ),
        content: Text(
          content,
          style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Cancel',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
          ),
          GlassButton(
            onPressed: () => Navigator.of(context).pop(true),
            backgroundColor: AppColors.error.withOpacity(0.2),
            borderColor: AppColors.error.withOpacity(0.3),
            child: Text(
              isDestructive ? 'Delete' : 'Confirm',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    ) ?? false;
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
          'Settings',
          style: AppTextStyles.h2.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            // Drillsarj Pro
            GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(
                fullscreenDialog: true,
                builder: (_) => const PaywallScreen(),
              )),
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.emerald.withOpacity(0.2),
                      AppColors.emerald.withOpacity(0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(AppBorderRadius.xl),
                  border: Border.all(color: AppColors.emerald.withOpacity(0.4), width: 1.5),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        gradient: AppColors.emeraldGradient,
                        borderRadius: BorderRadius.circular(AppBorderRadius.md),
                      ),
                      child: const Icon(LucideIcons.crown, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Drillsarj Pro', style: AppTextStyles.h3.copyWith(fontWeight: FontWeight.w700, color: AppColors.emerald)),
                          Text('Unlock the full sergeant experience', style: AppTextStyles.captionSmall.copyWith(color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                    const Icon(LucideIcons.chevronRight, color: AppColors.emerald, size: 20),
                  ],
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // Account Management
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(LucideIcons.user, size: 20, color: AppColors.emerald),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        'Account',
                        style: AppTextStyles.h3.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  SizedBox(
                    width: double.infinity,
                    child: GlassButton(
                      onPressed: _logout,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(LucideIcons.logOut, size: 16, color: AppColors.textPrimary),
                          const SizedBox(width: 8),
                          Text('Logout', style: AppTextStyles.bodyMedium),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  SizedBox(
                    width: double.infinity,
                    child: GlassButton(
                      onPressed: _deleteAccount,
                      backgroundColor: AppColors.error.withOpacity(0.1),
                      borderColor: AppColors.error.withOpacity(0.3),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(LucideIcons.userX, size: 16, color: AppColors.error),
                          const SizedBox(width: 8),
                          Text('Delete Account', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.error)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // Legal & Support
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(LucideIcons.fileText, size: 20, color: AppColors.emerald),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        'Legal & Support',
                        style: AppTextStyles.h3.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _buildNavItem('Terms & Conditions', LucideIcons.fileText, () => Navigator.pushNamed(context, '/terms')),
                  const SizedBox(height: AppSpacing.sm),
                  _buildNavItem('Privacy Policy', LucideIcons.shield, () => Navigator.pushNamed(context, '/privacy')),
                  const SizedBox(height: AppSpacing.sm),
                  _buildNavItem('Help & Support', LucideIcons.helpCircle, () => Navigator.pushNamed(context, '/support')),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // About
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.asset('assets/icon/app_icon.png', width: 28, height: 28, fit: BoxFit.cover),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        'Drillsarj',
                        style: AppTextStyles.h3.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Break a habit? Face the sergeant. Build discipline through accountability and exercise. v1.0.0',
                    style: AppTextStyles.caption.copyWith(color: AppColors.textTertiary),
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

  Widget _buildNavItem(String title, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.glassBackground,
          borderRadius: BorderRadius.circular(AppBorderRadius.md),
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.emerald),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(title, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary)),
            ),
            const Icon(LucideIcons.chevronRight, size: 20, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }
}
