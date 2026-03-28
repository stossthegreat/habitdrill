import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../design/tokens.dart';
import '../widgets/glass_card.dart';
import '../widgets/glass_button.dart';
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
          
          const SizedBox(height: 100),
        ],
      ),
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

}
