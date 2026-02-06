import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../design/tokens.dart';
import '../services/payment_service.dart';
import '../services/premium_service.dart';

/// 💎 PREMIUM PAYWALL - Full-screen, stunning, professional
/// Inspired by Calm, Headspace, Duolingo Super
class PremiumPaywallScreen extends StatefulWidget {
  final String feature; // What they tried to access

  const PremiumPaywallScreen({
    super.key,
    required this.feature,
  });

  @override
  State<PremiumPaywallScreen> createState() => _PremiumPaywallScreenState();
}

class _PremiumPaywallScreenState extends State<PremiumPaywallScreen> {
  bool _isLoading = false;
  bool _isDeveloper = false;
  int _selectedPlanIndex = 1; // 0 = monthly, 1 = annual (default annual)
  String _monthlyPrice = ''; // Loaded from store
  String _annualPrice = '';  // Loaded from store
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
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Animated gradient background
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF0A0A0A),
                    AppColors.emerald.withOpacity(0.05),
                    const Color(0xFF0A0A0A),
                  ],
                ),
              ),
            ),
          ),

          // Floating gradient orbs
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.emerald.withOpacity(0.15),
                    Colors.transparent,
                  ],
                ),
              ),
            )
                .animate(onPlay: (controller) => controller.repeat(reverse: true))
                .scale(duration: 4000.ms, begin: const Offset(1, 1), end: const Offset(1.2, 1.2))
                .then()
                .scale(duration: 4000.ms, begin: const Offset(1.2, 1.2), end: const Offset(1, 1)),
          ),

          Positioned(
            bottom: -150,
            left: -100,
            child: Container(
              width: 350,
              height: 350,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.emerald.withOpacity(0.1),
                    Colors.transparent,
                  ],
                ),
              ),
            )
                .animate(onPlay: (controller) => controller.repeat(reverse: true))
                .scale(duration: 5000.ms, begin: const Offset(1, 1), end: const Offset(1.3, 1.3))
                .then()
                .scale(duration: 5000.ms, begin: const Offset(1.3, 1.3), end: const Offset(1, 1)),
          ),

          // Content
          SafeArea(
            child: Column(
              children: [
                // Close button
                Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(LucideIcons.x, color: Colors.white70, size: 20),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(0.1),
                        padding: const EdgeInsets.all(8),
                      ),
                    ),
                  ),
                ),

                // All content in one Column (no scroll)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Top section: Icon + Title
                        Column(
                          children: [
                            const SizedBox(height: 8),
                            _buildHeader(),
                          ],
                        ),

                        // Middle section: Features (compact)
                        Expanded(
                          child: Center(
                            child: _buildFeatures(),
                          ),
                        ),

                        // Bottom section: Plans + CTA
                        Column(
                          children: [
                            _buildPlanSelector(),
                            const SizedBox(height: 16),
                            _buildCTAButton(),
                            const SizedBox(height: 12),
                            
                            // Restore purchases + Terms (compact)
                            TextButton(
                              onPressed: _restorePurchases,
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                'Restore Purchases',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.6),
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            
                            Text(
                              'Payment charged to your Google Play account. Auto-renews unless cancelled at least 24 hours before the end of the current period. Manage in Google Play > Subscriptions.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.4),
                                fontSize: 10,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Loading overlay
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.7),
              child: const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.emerald),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        // Animated crown icon (smaller)
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: AppColors.emeraldGradient,
            boxShadow: [
              BoxShadow(
                color: AppColors.emerald.withOpacity(0.4),
                blurRadius: 24,
                spreadRadius: 4,
              ),
            ],
          ),
          child: const Icon(
            LucideIcons.crown,
            color: Colors.black,
            size: 32,
          ),
        )
            .animate(onPlay: (controller) => controller.repeat(reverse: true))
            .shimmer(duration: 2000.ms, color: Colors.white.withOpacity(0.3))
            .then()
            .scale(duration: 1000.ms, begin: const Offset(1, 1), end: const Offset(1.05, 1.05))
            .then()
            .scale(duration: 1000.ms, begin: const Offset(1.05, 1.05), end: const Offset(1, 1)),

        const SizedBox(height: 16),

        // Title (more compact)
        ShaderMask(
          shaderCallback: (bounds) => AppColors.emeraldGradient.createShader(bounds),
          child: const Text(
            'Upgrade to Premium',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
            textAlign: TextAlign.center,
          ),
        ),

        const SizedBox(height: 8),

        Text(
          'Unlock ${widget.feature} and all features',
          style: TextStyle(
            fontSize: 14,
            color: Colors.white.withOpacity(0.7),
          ),
          textAlign: TextAlign.center,
        ),

        // Developer badge (compact)
        if (_isDeveloper) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.emerald.withOpacity(0.2),
                  AppColors.emerald.withOpacity(0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.emerald.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(LucideIcons.code, color: AppColors.emerald, size: 14),
                const SizedBox(width: 6),
                Text(
                  'Developer - Free Access',
                  style: TextStyle(
                    color: AppColors.emerald,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFeatures() {
    final features = [
      {
        'icon': LucideIcons.messageCircle,
        'title': 'Unlimited AI Conversations',
        'description': 'Chat with your AI OS anytime',
      },
      {
        'icon': LucideIcons.zap,
        'title': 'What-If Simulator & Habit Plans',
        'description': 'Scientific plans backed by research',
      },
      {
        'icon': LucideIcons.brain,
        'title': 'Daily Coaching & Smart Nudges',
        'description': 'Personalized briefs, debriefs & interventions',
      },
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: features.asMap().entries.map((entry) {
        final index = entry.key;
        final feature = entry.value;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _buildFeatureCard(
            feature['icon'] as IconData,
            feature['title'] as String,
            feature['description'] as String,
          ),
        )
            .animate()
            .fadeIn(delay: (index * 100).ms, duration: 400.ms)
            .slideX(begin: -0.2, end: 0, delay: (index * 100).ms, duration: 400.ms);
      }).toList(),
    );
  }

  Widget _buildFeatureCard(IconData icon, String title, String description) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: AppColors.emeraldGradient.scale(0.3),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.emerald, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            LucideIcons.check,
            color: AppColors.emerald,
            size: 18,
          ),
        ],
      ),
    );
  }

  Widget _buildPlanSelector() {
    final monthlyDisplay = _pricesLoaded && _monthlyPrice.isNotEmpty
        ? _monthlyPrice
        : '\$6.99';
    final annualDisplay = _pricesLoaded && _annualPrice.isNotEmpty
        ? _annualPrice
        : '\$49.99';

    return Column(
      children: [
        Text(
          'Choose Your Plan',
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildPlanOption(
                index: 0,
                title: 'Monthly',
                price: monthlyDisplay,
                period: '/mo',
                badge: null,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildPlanOption(
                index: 1,
                title: 'Annual',
                price: annualDisplay,
                period: '/yr',
                badge: 'SAVE 40%',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          _selectedPlanIndex == 0
              ? '$monthlyDisplay billed monthly. Auto-renews until cancelled.'
              : '$annualDisplay billed annually. Auto-renews until cancelled.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withOpacity(0.5),
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Subscription is optional. Free features available without purchase.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withOpacity(0.4),
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  Widget _buildPlanOption({
    required int index,
    required String title,
    required String price,
    required String period,
    String? badge,
  }) {
    final isSelected = _selectedPlanIndex == index;

    return GestureDetector(
      onTap: () => setState(() => _selectedPlanIndex = index),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  colors: [
                    AppColors.emerald.withOpacity(0.2),
                    AppColors.emerald.withOpacity(0.1),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isSelected ? null : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.emerald : Colors.white.withOpacity(0.1),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      price,
                      style: TextStyle(
                        color: isSelected ? AppColors.emerald : Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      period,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (badge != null)
              Positioned(
                top: -6,
                right: -6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    gradient: AppColors.emeraldGradient,
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.emerald.withOpacity(0.4),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Text(
                    badge,
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    ).animate(target: isSelected ? 1 : 0).scale(
          begin: const Offset(1, 1),
          end: const Offset(1.02, 1.02),
          duration: 200.ms,
        );
  }

  Widget _buildCTAButton() {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: AppColors.emeraldGradient,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppColors.emerald.withOpacity(0.4),
            blurRadius: 16,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isLoading ? null : _purchase,
          borderRadius: BorderRadius.circular(14),
          child: Center(
            child: _isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(LucideIcons.sparkles, color: Colors.black, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        _selectedPlanIndex == 0 ? 'Start 7-Day Free Trial' : 'Subscribe Now',
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    )
        .animate(onPlay: (controller) => controller.repeat(reverse: true))
        .shimmer(duration: 2000.ms, color: Colors.white.withOpacity(0.2))
        .then()
        .scale(duration: 1000.ms, begin: const Offset(1, 1), end: const Offset(1.01, 1.01))
        .then()
        .scale(duration: 1000.ms, begin: const Offset(1.01, 1.01), end: const Offset(1, 1));
  }

  Future<void> _purchase() async {
    setState(() => _isLoading = true);

    try {
      final success = _selectedPlanIndex == 0
          ? await PaymentService.instance.purchaseMonthlySubscription()
          : await PaymentService.instance.purchaseAnnualSubscription();

      if (success && mounted) {
        Navigator.pop(context, true); // Return success
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(LucideIcons.checkCircle, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Welcome to AI Companion! ${widget.feature} is now unlocked.',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.emerald,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.all(16),
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
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _restorePurchases() async {
    setState(() => _isLoading = true);

    try {
      final restored = await PaymentService.instance.restorePurchases();

      if (mounted) {
        if (restored) {
          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Purchases restored successfully!'),
              backgroundColor: AppColors.emerald,
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No previous purchases found.'),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
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
        setState(() => _isLoading = false);
      }
    }
  }
}

