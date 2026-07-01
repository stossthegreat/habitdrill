import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../design/tokens.dart';
import '../widgets/glass_card.dart';
import '../widgets/glass_button.dart';
import '../services/local_storage.dart';
import '../services/analytics_service.dart';
import 'paywall_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  void initState() {
    super.initState();
    AnalyticsService.logScreenView('settings');
  }

  Future<void> _resetAllData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.baseDark2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppBorderRadius.lg),
          side: BorderSide(color: AppColors.error.withOpacity(0.5)),
        ),
        title: Text('Reset All Data', style: AppTextStyles.h3.copyWith(color: AppColors.error)),
        content: Text('This will delete ALL orders, rules, and progress. Cannot be undone.', style: AppTextStyles.body.copyWith(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textTertiary)),
          ),
          GlassButton(
            onPressed: () => Navigator.of(context).pop(true),
            backgroundColor: AppColors.error.withOpacity(0.2),
            borderColor: AppColors.error.withOpacity(0.3),
            child: Text('Reset', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.error, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    ) ?? false;

    if (confirmed) {
      await LocalStorageService.clearAllHabits();
      await LocalStorageService.clearAllSettings();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All data reset.'), backgroundColor: AppColors.error),
        );
      }
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
        title: Text('Settings', style: AppTextStyles.h2.copyWith(fontWeight: FontWeight.w700)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            // HabitDrill Pro
            GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(fullscreenDialog: true, builder: (_) => const PaywallScreen())),
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.emerald.withOpacity(0.2), AppColors.emerald.withOpacity(0.05)],
                  ),
                  borderRadius: BorderRadius.circular(AppBorderRadius.xl),
                  border: Border.all(color: AppColors.emerald.withOpacity(0.4), width: 1.5),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(gradient: AppColors.emeraldGradient, borderRadius: BorderRadius.circular(AppBorderRadius.md)),
                      child: const Icon(LucideIcons.crown, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('HABITDRILL PRO', style: AppTextStyles.h3.copyWith(fontWeight: FontWeight.w700, color: AppColors.emerald, letterSpacing: 1)),
                          Text('Unlock full enforcement', style: AppTextStyles.captionSmall.copyWith(color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                    const Icon(LucideIcons.chevronRight, color: AppColors.emerald, size: 20),
                  ],
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // Data
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(LucideIcons.database, size: 20, color: AppColors.emerald),
                      const SizedBox(width: AppSpacing.sm),
                      Text('Data', style: AppTextStyles.h3.copyWith(fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  SizedBox(
                    width: double.infinity,
                    child: GlassButton(
                      onPressed: _resetAllData,
                      backgroundColor: AppColors.error.withOpacity(0.1),
                      borderColor: AppColors.error.withOpacity(0.3),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(LucideIcons.trash2, size: 16, color: AppColors.error),
                          const SizedBox(width: 8),
                          Text('Reset All Data', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.error)),
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
                      Text('Legal & Support', style: AppTextStyles.h3.copyWith(fontWeight: FontWeight.w600)),
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
                      ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.asset('assets/icon/app_icon.png', width: 28, height: 28, fit: BoxFit.cover)),
                      const SizedBox(width: AppSpacing.sm),
                      Text('HabitDrill', style: AppTextStyles.h3.copyWith(fontWeight: FontWeight.w700)),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text('Discipline enforcement system. v1.0.0', style: AppTextStyles.caption.copyWith(color: AppColors.textTertiary)),
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
            Expanded(child: Text(title, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary))),
            const Icon(LucideIcons.chevronRight, size: 20, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }
}
