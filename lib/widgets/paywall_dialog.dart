import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../design/tokens.dart';
import '../services/payment_service.dart';
import '../services/premium_service.dart';

/// Paywall dialog shown when non-premium users try to use AI features
class PaywallDialog extends StatefulWidget {
  final String feature; // e.g., "AI Chat", "What If Engine"
  
  const PaywallDialog({
    super.key,
    required this.feature,
  });

  @override
  State<PaywallDialog> createState() => _PaywallDialogState();
}

class _PaywallDialogState extends State<PaywallDialog> {
  bool _isLoading = false;
  bool _isDeveloper = false;
  String _monthlyPrice = '';
  String _annualPrice = '';
  bool _pricesLoaded = false;

  @override
  void initState() {
    super.initState();
    _checkDeveloperStatus();
  }

  Future<void> _checkDeveloperStatus() async {
    final isDev = await PremiumService.isDeveloper();
    if (mounted) {
      setState(() {
        _isDeveloper = isDev;
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadPrices();
  }

  Future<void> _loadPrices() async {
    try {
      final products = await PaymentService.instance.getProducts();
      for (final product in products) {
        if (product.id == PaymentService.monthlySubscriptionId) {
          _monthlyPrice = product.price;
        } else if (product.id == PaymentService.annualSubscriptionId) {
          _annualPrice = product.price;
        }
      }
      if (mounted) {
        setState(() {
          _pricesLoaded = true;
        });
      }
    } catch (e) {
      debugPrint('Failed to load prices: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF18181B),
              const Color(0xFF09090B),
            ],
          ),
          borderRadius: BorderRadius.circular(AppBorderRadius.xl),
          border: Border.all(
            color: AppColors.emerald.withOpacity(0.3),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 40,
              offset: const Offset(0, 20),
            ),
          ],
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: AppColors.emeraldGradient,
                  borderRadius: BorderRadius.circular(AppBorderRadius.full),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.emerald.withOpacity(0.4),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  LucideIcons.sparkles,
                  size: 40,
                  color: Colors.black,
                ),
              ).animate().scale(duration: 500.ms, curve: Curves.elasticOut)
               .then(delay: 500.ms).shimmer(duration: 2000.ms, color: Colors.white.withOpacity(0.3)),
              
              const SizedBox(height: 24),
              
              // Title
              Text(
                'Unlock ${widget.feature}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  height: 1.2,
                ),
              ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.1, end: 0),
              
              const SizedBox(height: 12),
              
              // Subtitle
              Text(
                'Upgrade to AI Companion to access this feature',
                textAlign: TextAlign.center,
                style: AppTextStyles.body.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.6,
                ),
              ).animate().fadeIn(delay: 200.ms),
              
              const SizedBox(height: 24),
              
              // Features
              _buildFeature(
                LucideIcons.messageCircle,
                'Unlimited AI conversations',
                delay: 300,
              ),
              const SizedBox(height: 16),
              _buildFeature(
                LucideIcons.zap,
                'What-If Engine & Planning',
                delay: 350,
              ),
              const SizedBox(height: 16),
              _buildFeature(
                LucideIcons.brain,
                'Memory System (AI remembers you)',
                delay: 400,
              ),
              const SizedBox(height: 16),
              _buildFeature(
                LucideIcons.sunrise,
                'Daily Briefs & Debriefs',
                delay: 450,
              ),
              
              const SizedBox(height: 32),
              
              // Price
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.emerald.withOpacity(0.2),
                      AppColors.cyan.withOpacity(0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(AppBorderRadius.lg),
                  border: Border.all(
                    color: AppColors.emerald.withOpacity(0.3),
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      _pricesLoaded && _monthlyPrice.isNotEmpty
                          ? _monthlyPrice
                          : '\$6.99',
                      style: const TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.w900,
                        color: AppColors.emerald,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '/month',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Billed monthly. Auto-renews until cancelled.',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textTertiary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 500.ms).scale(delay: 500.ms),
              
              const SizedBox(height: 24),
              
              // Monthly Subscription Button
              GestureDetector(
                onTap: _isLoading ? null : () => _purchaseMonthly(),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    gradient: _isLoading ? null : AppColors.emeraldGradient,
                    color: _isLoading ? Colors.grey : null,
                    borderRadius: BorderRadius.circular(AppBorderRadius.xl),
                    boxShadow: _isLoading ? null : [
                      BoxShadow(
                        color: AppColors.emerald.withOpacity(0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          'Get Premium${_pricesLoaded && _monthlyPrice.isNotEmpty ? ' - $_monthlyPrice/mo' : ''}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: Colors.black,
                          ),
                        ),
                ),
              ).animate().fadeIn(delay: 600.ms).slideY(begin: 0.1, end: 0),
              
              const SizedBox(height: 12),
              
              // Annual Subscription Button
              GestureDetector(
                onTap: _isLoading ? null : () => _purchaseAnnual(),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.emerald, width: 2),
                    borderRadius: BorderRadius.circular(AppBorderRadius.xl),
                  ),
                  child: Text(
                    'Annual Plan${_pricesLoaded && _annualPrice.isNotEmpty ? ' - $_annualPrice/year' : ''} (Save 40%)',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.emerald,
                    ),
                  ),
                ),
              ).animate().fadeIn(delay: 650.ms).slideY(begin: 0.1, end: 0),
              
              const SizedBox(height: 12),
              
              // Restore Purchases Button
              TextButton(
                onPressed: _isLoading ? null : _restorePurchases,
                child: Text(
                  'Restore Purchases',
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              
              const SizedBox(height: 12),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Auto-renews until cancelled. Cancel anytime in Google Play > Subscriptions. Subscription is optional.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.captionSmall.copyWith(
                    color: AppColors.textTertiary,
                    fontSize: 10,
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Cancel button
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Maybe Later',
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.textTertiary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildFeature(IconData icon, String text, {required int delay}) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.emerald.withOpacity(0.15),
            borderRadius: BorderRadius.circular(AppBorderRadius.md),
          ),
          child: Icon(
            icon,
            size: 18,
            color: AppColors.emerald,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: AppTextStyles.body.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ).animate().fadeIn(delay: delay.ms).slideX(begin: -0.1, end: 0);
  }

  /// Purchase monthly subscription
  Future<void> _purchaseMonthly() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final success = await PaymentService.instance.purchaseMonthlySubscription();
      
      if (success && mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Welcome to AI Companion! ${widget.feature} is now unlocked.'),
            backgroundColor: AppColors.emerald,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Purchase failed. Please try again.'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Purchase annual subscription
  Future<void> _purchaseAnnual() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final success = await PaymentService.instance.purchaseAnnualSubscription();
      
      if (success && mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Welcome to AI Companion Annual! ${widget.feature} is now unlocked.'),
            backgroundColor: AppColors.emerald,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Purchase failed. Please try again.'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Restore previous purchases
  Future<void> _restorePurchases() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final restored = await PaymentService.instance.restorePurchases();
      
      if (restored && mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Purchases restored successfully!'),
            backgroundColor: AppColors.emerald,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No previous purchases found.'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
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
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}

