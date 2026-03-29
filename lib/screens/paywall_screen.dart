import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../design/tokens.dart';

class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  static const String _monthlyId = 'drillsarj_pro_monthly';
  static const String _yearlyId = 'drillsarj_pro_yearly';

  bool _isMonthly = true;
  bool _loading = false;
  String? _monthlyPrice;
  String? _yearlyPrice;
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  @override
  void initState() {
    super.initState();
    _loadProducts();
    _listenToPurchases();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    if (!await InAppPurchase.instance.isAvailable()) return;

    final response = await InAppPurchase.instance.queryProductDetails({_monthlyId, _yearlyId});
    for (final product in response.productDetails) {
      if (product.id == _monthlyId) {
        _monthlyPrice = product.price;
      } else if (product.id == _yearlyId) {
        _yearlyPrice = product.price;
      }
    }
    if (mounted) setState(() {});
  }

  void _listenToPurchases() {
    _subscription = InAppPurchase.instance.purchaseStream.listen((purchases) {
      for (final purchase in purchases) {
        if (purchase.status == PurchaseStatus.purchased ||
            purchase.status == PurchaseStatus.restored) {
          // Complete the purchase
          InAppPurchase.instance.completePurchase(purchase);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Welcome to Drillsarj Pro!'),
                backgroundColor: AppColors.emerald,
              ),
            );
            Navigator.of(context).pop(true);
          }
        } else if (purchase.status == PurchaseStatus.error) {
          setState(() => _loading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Purchase failed: ${purchase.error?.message ?? "Unknown error"}'),
              backgroundColor: AppColors.error,
            ),
          );
        } else if (purchase.status == PurchaseStatus.pending) {
          setState(() => _loading = true);
        }
      }
    });
  }

  Future<void> _purchase() async {
    setState(() => _loading = true);

    try {
      final productId = _isMonthly ? _monthlyId : _yearlyId;
      final response = await InAppPurchase.instance.queryProductDetails({productId});

      if (response.productDetails.isEmpty) {
        setState(() => _loading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Product not available'), backgroundColor: AppColors.error),
          );
        }
        return;
      }

      final purchaseParam = PurchaseParam(productDetails: response.productDetails.first);
      await InAppPurchase.instance.buyNonConsumable(purchaseParam: purchaseParam);
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _restore() async {
    await InAppPurchase.instance.restorePurchases();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Checking for previous purchases...'), backgroundColor: AppColors.emerald),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.baseDark1,
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            child: Column(
              children: [
                const SizedBox(height: AppSpacing.lg),

                // Close button
                Align(
                  alignment: Alignment.topRight,
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close, color: Colors.white54, size: 20),
                    ),
                  ),
                ),

                const SizedBox(height: AppSpacing.md),

                // App icon
                ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Image.asset('assets/icon/app_icon.png', width: 80, height: 80, fit: BoxFit.cover),
                ).animate().fadeIn(duration: 400.ms).scale(
                  begin: const Offset(0.8, 0.8),
                  end: const Offset(1, 1),
                  duration: 400.ms,
                ),

                const SizedBox(height: AppSpacing.lg),

                // Title
                ShaderMask(
                  shaderCallback: (bounds) => AppColors.emeraldGradient.createShader(bounds),
                  child: const Text(
                    'DRILLSARJ PRO',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 2),
                  ),
                ).animate(delay: 200.ms).fadeIn(),

                const SizedBox(height: AppSpacing.sm),

                Text(
                  'Unlock the full drill sergeant experience',
                  style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
                  textAlign: TextAlign.center,
                ).animate(delay: 300.ms).fadeIn(),

                const SizedBox(height: AppSpacing.xxl),

                // Feature list
                _buildFeature(LucideIcons.swords, 'Drill Sergeant Mode', 'Videos, voice, and punishments when you break habits', 0),
                _buildFeature(LucideIcons.dumbbell, 'Exercise Circuits', 'Escalating workouts that get harder each offense', 1),
                _buildFeature(LucideIcons.mic, 'AI Voice Messages', 'Personalized sergeant messages powered by AI', 2),
                _buildFeature(LucideIcons.bell, 'Sergeant Notifications', 'Escalating alerts that won\'t let you hide', 3),
                _buildFeature(LucideIcons.flame, 'Offense Tracking', 'Per-habit violation history and escalation', 4),

                const SizedBox(height: AppSpacing.xxl),

                // Plan toggle
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(AppBorderRadius.lg),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: Row(
                    children: [
                      Expanded(child: _planTab('Monthly', _monthlyPrice ?? '\$4.99', true)),
                      Expanded(child: _planTab('Yearly', _yearlyPrice ?? '\$29.99', false)),
                    ],
                  ),
                ),

                const SizedBox(height: AppSpacing.sm),

                if (!_isMonthly)
                  Text(
                    'Save 50% with annual',
                    style: AppTextStyles.caption.copyWith(color: AppColors.emerald, fontWeight: FontWeight.w600),
                  ).animate().fadeIn(),

                const SizedBox(height: AppSpacing.xl),

                // Subscribe button
                SizedBox(
                  width: double.infinity,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: AppColors.emeraldGradient,
                      borderRadius: BorderRadius.circular(AppBorderRadius.lg),
                      boxShadow: [
                        BoxShadow(color: AppColors.emerald.withOpacity(0.4), blurRadius: 16, offset: const Offset(0, 6)),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _loading ? null : _purchase,
                        borderRadius: BorderRadius.circular(AppBorderRadius.lg),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                          child: _loading
                              ? const Center(child: SizedBox(
                                  width: 24, height: 24,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                                ))
                              : const Text(
                                  'UNLOCK DRILLSARJ PRO',
                                  style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 1),
                                  textAlign: TextAlign.center,
                                ),
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: AppSpacing.md),

                // Restore
                TextButton(
                  onPressed: _restore,
                  child: Text(
                    'Restore Purchases',
                    style: AppTextStyles.caption.copyWith(color: AppColors.textTertiary, decoration: TextDecoration.underline),
                  ),
                ),

                const SizedBox(height: AppSpacing.sm),

                // Legal
                Text(
                  'Subscription auto-renews. Cancel anytime in your device settings.',
                  style: AppTextStyles.captionSmall.copyWith(color: AppColors.textQuaternary, fontSize: 11),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: AppSpacing.xxl),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeature(IconData icon, String title, String desc, int index) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.emerald.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.emerald.withOpacity(0.3)),
            ),
            child: Icon(icon, color: AppColors.emerald, size: 22),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w700, color: Colors.white)),
                const SizedBox(height: 2),
                Text(desc, style: AppTextStyles.caption.copyWith(color: AppColors.textTertiary)),
              ],
            ),
          ),
        ],
      ),
    ).animate(delay: (400 + index * 120).ms).fadeIn(duration: 300.ms).slideX(begin: 0.05, end: 0);
  }

  Widget _planTab(String label, String price, bool isMonthlyOption) {
    final selected = _isMonthly == isMonthlyOption;
    return GestureDetector(
      onTap: () => setState(() => _isMonthly = isMonthlyOption),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected ? AppColors.emerald : Colors.transparent,
          borderRadius: BorderRadius.circular(AppBorderRadius.md),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.black : AppColors.textSecondary,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              price,
              style: TextStyle(
                color: selected ? Colors.black : AppColors.textTertiary,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
