import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../design/tokens.dart';
import '../widgets/glass_card.dart';
import '../widgets/glass_button.dart';
import '../widgets/premium_paywall_screen.dart';
import '../services/payment_service.dart';
import '../services/premium_service.dart';
import '../services/local_storage.dart';
import '../services/auth_service.dart';
import '../providers/auth_provider.dart';
import 'auth/login_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  
  String _selectedVoice = 'marcus';
  
  // Available voices
  final List<Map<String, String>> _voices = [
    {'id': 'marcus', 'name': 'Marcus', 'gender': 'Male'},
    {'id': 'atlas', 'name': 'Atlas', 'gender': 'Male'},
    {'id': 'orion', 'name': 'Orion', 'gender': 'Male'},
    {'id': 'nova', 'name': 'Nova', 'gender': 'Female'},
    {'id': 'luna', 'name': 'Luna', 'gender': 'Female'},
    {'id': 'aurora', 'name': 'Aurora', 'gender': 'Female'},
  ];
  
  @override
  void initState() {
    super.initState();
    _loadSettings();
  }
  
  @override
  void dispose() {
    super.dispose();
  }
  
  void _loadSettings() {
    _selectedVoice = LocalStorageService.getSelectedVoice();
  }
  
  Future<void> _saveSettings() async {
    await LocalStorageService.setSelectedVoice(_selectedVoice);
    
    _showSuccessSnackBar('Settings saved successfully');
  }
  

  Future<void> _logout() async {
    final confirmed = await _showConfirmationDialog(
      'Logout',
      'Are you sure you want to logout?',
    );
    
    if (confirmed) {
      try {
        final authService = ref.read(authServiceProvider);
        await authService.signOut();
        
        // Clear all local data
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
        
        // Clear all local data
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
  
  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(LucideIcons.check, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Text(message),
          ],
        ),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppBorderRadius.sm),
        ),
      ),
    );
  }
  
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(LucideIcons.alertCircle, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Text(message),
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
            // 💎 SUBSCRIPTION SECTION
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.emerald.withOpacity(0.2),
                    AppColors.cyan.withOpacity(0.1),
                    AppColors.emerald.withOpacity(0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(AppBorderRadius.xl),
                border: Border.all(
                  color: AppColors.emerald.withOpacity(0.4),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.emerald.withOpacity(0.15),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        decoration: BoxDecoration(
                          gradient: AppColors.emeraldGradient,
                          borderRadius: BorderRadius.circular(AppBorderRadius.md),
                        ),
                        child: const Icon(
                          LucideIcons.crown,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Future You Premium',
                              style: AppTextStyles.h3.copyWith(
                                fontWeight: FontWeight.w700,
                                color: AppColors.emerald,
                              ),
                            ),
                            Text(
                              'Unlock your full potential',
                              style: AppTextStyles.captionSmall.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: AppSpacing.lg),
                  
                  // Premium Features
                  Column(
                    children: [
                      _buildPremiumFeature(
                        LucideIcons.brain,
                        'AI Operating System',
                        'Full access to your personal AI OS',
                      ),
                      _buildPremiumFeature(
                        LucideIcons.messageCircle,
                        'Unlimited AI Chat',
                        'Chat with Future You, What-If Engine, and more',
                      ),
                      _buildPremiumFeature(
                        LucideIcons.volume2,
                        'Voice Messages',
                        'Text-to-speech for all briefs and nudges',
                      ),
                      _buildPremiumFeature(
                        LucideIcons.zap,
                        'Smart Nudges',
                        'Contextual reminders powered by AI',
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: AppSpacing.xl),
                  
                  // Subscription Button
                  SizedBox(
                    width: double.infinity,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: AppColors.emeraldGradient,
                        borderRadius: BorderRadius.circular(AppBorderRadius.lg),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.emerald.withOpacity(0.5),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _showSubscriptionOptions,
                          borderRadius: BorderRadius.circular(AppBorderRadius.lg),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: AppSpacing.lg,
                              horizontal: AppSpacing.xl,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  LucideIcons.sparkles,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Text(
                                  'Upgrade to Premium',
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: AppSpacing.xl),
          
          // Voice Settings section
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(LucideIcons.mic, size: 20, color: AppColors.emerald),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      'Voice Settings',
                      style: AppTextStyles.h3.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Choose the voice for briefs, nudges, and debriefs',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                
                // Voice options
                ..._voices.map((voice) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedVoice = voice['id']!;
                      });
                      _saveSettings();
                    },
                    child: Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: _selectedVoice == voice['id']
                            ? AppColors.emerald.withOpacity(0.1)
                            : AppColors.glassBackground,
                        borderRadius: BorderRadius.circular(AppBorderRadius.md),
                        border: Border.all(
                          color: _selectedVoice == voice['id']
                              ? AppColors.emerald
                              : AppColors.glassBorder,
                          width: _selectedVoice == voice['id'] ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _selectedVoice == voice['id']
                                ? Icons.radio_button_checked
                                : Icons.radio_button_unchecked,
                            color: _selectedVoice == voice['id']
                                ? AppColors.emerald
                                : AppColors.textTertiary,
                            size: 20,
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  voice['name']!,
                                  style: AppTextStyles.body.copyWith(
                                    fontWeight: _selectedVoice == voice['id']
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                    color: _selectedVoice == voice['id']
                                        ? AppColors.emerald
                                        : AppColors.textPrimary,
                                  ),
                                ),
                                Text(
                                  voice['gender']!,
                                  style: AppTextStyles.caption.copyWith(
                                    color: AppColors.textTertiary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            LucideIcons.volume2,
                            size: 18,
                            color: _selectedVoice == voice['id']
                                ? AppColors.emerald
                                : AppColors.textTertiary,
                          ),
                        ],
                      ),
                    ),
                  ),
                )).toList(),
              ],
            ),
          ),
          
          const SizedBox(height: AppSpacing.lg),
          
          // Account Management section
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Account Management',
                  style: AppTextStyles.h3.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Manage your authentication and account settings',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                
                Column(
                  children: [
                    // Logout button
                    SizedBox(
                      width: double.infinity,
                      child: GlassButton(
                        onPressed: _logout,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              LucideIcons.logOut,
                              size: 16,
                              color: AppColors.textPrimary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Logout',
                              style: AppTextStyles.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    // Delete account button
                    SizedBox(
                      width: double.infinity,
                      child: GlassButton(
                        onPressed: _deleteAccount,
                        backgroundColor: AppColors.error.withOpacity(0.1),
                        borderColor: AppColors.error.withOpacity(0.3),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              LucideIcons.userX,
                              size: 16,
                              color: AppColors.error,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Delete Account',
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: AppColors.error,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          const SizedBox(height: AppSpacing.lg),
          
          // Legal & Support section
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Legal & Support',
                  style: AppTextStyles.h3.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                _buildNavigationItem(
                  'Terms & Conditions',
                  LucideIcons.fileText,
                  () => Navigator.pushNamed(context, '/terms'),
                ),
                const SizedBox(height: AppSpacing.sm),
                _buildNavigationItem(
                  'Privacy Policy',
                  LucideIcons.shield,
                  () => Navigator.pushNamed(context, '/privacy'),
                ),
                const SizedBox(height: AppSpacing.sm),
                _buildNavigationItem(
                  'Help & Support',
                  LucideIcons.helpCircle,
                  () => Navigator.pushNamed(context, '/support'),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: AppSpacing.lg),
          
          // About section
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'About',
                  style: AppTextStyles.h3.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Future-You OS — AI-powered system to discover your life\'s purpose and build the habits that get you there. v1.0.0',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: AppSpacing.lg),
          
          // 💎 SUBSCRIPTION MANAGEMENT
          FutureBuilder<bool>(
            future: PremiumService.isPremium(),
            builder: (context, snapshot) {
              final isPremium = snapshot.data ?? false;
              return GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isPremium ? LucideIcons.crown : LucideIcons.sparkles,
                          color: isPremium ? AppColors.emerald : AppColors.textSecondary,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isPremium ? 'AI Companion Active' : 'Upgrade to AI Companion',
                          style: AppTextStyles.h3.copyWith(
                            fontWeight: FontWeight.w600,
                            color: isPremium ? AppColors.emerald : AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      isPremium 
                          ? 'You have full access to all AI features'
                          : 'Unlock unlimited AI conversations, What-If Engine, and more',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    if (isPremium) ...[
                      // Subscription info for premium users
                      FutureBuilder<Map<String, dynamic>?>(
                        future: PaymentService.instance.getSubscriptionInfo(),
                        builder: (context, subSnapshot) {
                          final subInfo = subSnapshot.data;
                          return Column(
                            children: [
                              _buildInfoRow('Status', 'Active', AppColors.emerald),
                              if (subInfo != null) ...[
                                _buildInfoRow('Plan', subInfo['productId']?.toString().contains('annual') == true ? 'Annual' : 'Monthly', AppColors.textPrimary),
                                if (subInfo['expirationDate'] != null)
                                  _buildInfoRow('Renews', _formatDate(subInfo['expirationDate']), AppColors.textSecondary),
                              ],
                              const SizedBox(height: AppSpacing.md),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildActionButton(
                                      'Restore Purchases',
                                      LucideIcons.refreshCw,
                                      () => _restorePurchases(),
                                      isSecondary: true,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _buildActionButton(
                                      'Manage',
                                      LucideIcons.externalLink,
                                      () => _manageSubscription(),
                                      isSecondary: true,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          );
                        },
                      ),
                    ] else ...[
                      // Upgrade options for free users
                      _buildActionButton(
                        'Upgrade to AI Companion',
                        LucideIcons.sparkles,
                        () => _showUpgradeDialog(),
                        isSecondary: false,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _buildActionButton(
                        'Restore Purchases',
                        LucideIcons.refreshCw,
                        () => _restorePurchases(),
                        isSecondary: true,
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
          
          const SizedBox(height: AppSpacing.lg),
          
          // 🔧 DEBUG: Premium Toggle (for testing paywall)
          // Bottom padding for navigation
          const SizedBox(height: 100),
        ],
      ),
      ),
    );
  }
  
  
  Widget _buildToggleSetting(String title, String subtitle, bool value, Function(bool) onChanged) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                subtitle,
                style: AppTextStyles.captionSmall.copyWith(
                  color: AppColors.textQuaternary,
                ),
              ),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
        ),
      ],
    );
  }
  
  Widget _buildPremiumFeature(IconData icon, String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.xs),
            decoration: BoxDecoration(
              color: AppColors.emerald.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppBorderRadius.sm),
            ),
            child: Icon(
              icon,
              color: AppColors.emerald,
              size: 16,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  description,
                  style: AppTextStyles.captionSmall.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showSubscriptionOptions() {
    // Use the WORKING premium paywall screen (same as bottom button)
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => const PremiumPaywallScreen(feature: 'Premium Features'),
      ),
    );
  }

  Widget _buildSubscriptionOption(
    String title,
    String price,
    String description,
    VoidCallback onTap, {
    bool isPopular = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.glassBackground,
        borderRadius: BorderRadius.circular(AppBorderRadius.lg),
        border: Border.all(
          color: isPopular ? AppColors.emerald : AppColors.emerald.withOpacity(0.2),
          width: isPopular ? 2 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppBorderRadius.lg),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (isPopular) ...[
                      const SizedBox(width: AppSpacing.sm),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          gradient: AppColors.emeraldGradient,
                          borderRadius: BorderRadius.circular(AppBorderRadius.sm),
                        ),
                        child: Text(
                          'POPULAR',
                          style: AppTextStyles.captionSmall.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  price,
                  style: AppTextStyles.h3.copyWith(
                    color: AppColors.emerald,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  description,
                  style: AppTextStyles.captionSmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _handleSubscription(String plan) {
    Navigator.pop(context);
    // TODO: Implement actual subscription logic
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$plan subscription selected - implement payment flow'),
        backgroundColor: AppColors.emerald,
      ),
    );
  }

  Widget _buildNavigationItem(String title, IconData icon, VoidCallback onTap) {
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
              child: Text(
                title,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const Icon(
              LucideIcons.chevronRight,
              size: 20,
              color: AppColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }

  /// Show upgrade dialog with payment options
  void _showUpgradeDialog() {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => const PremiumPaywallScreen(feature: 'Premium Features'),
      ),
    );
  }

  /// Restore previous purchases
  Future<void> _restorePurchases() async {
    try {
      final restored = await PaymentService.instance.restorePurchases();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(restored 
                ? 'Purchases restored successfully!' 
                : 'No previous purchases found.'),
            backgroundColor: restored ? AppColors.emerald : Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
        
        // Refresh the UI
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Restore failed: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  /// Manage subscription (redirect to platform store)
  void _manageSubscription() {
    PaymentService.instance.cancelSubscription();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Redirecting to subscription management...'),
        backgroundColor: AppColors.emerald,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Build info row for subscription details
  Widget _buildInfoRow(String label, String value, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            value,
            style: AppTextStyles.caption.copyWith(
              color: valueColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  /// Build action button for subscription actions
  Widget _buildActionButton(String text, IconData icon, VoidCallback onTap, {required bool isSecondary}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          gradient: isSecondary ? null : AppColors.emeraldGradient,
          color: isSecondary ? Colors.transparent : null,
          border: isSecondary ? Border.all(color: AppColors.glassBorder) : null,
          borderRadius: BorderRadius.circular(AppBorderRadius.md),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSecondary ? AppColors.textSecondary : Colors.black,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                text,
                style: AppTextStyles.caption.copyWith(
                  color: isSecondary ? AppColors.textSecondary : Colors.black,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Format date for display
  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
