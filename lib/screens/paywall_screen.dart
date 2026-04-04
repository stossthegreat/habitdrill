import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../design/tokens.dart';
import '../services/premium_service.dart';

class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  static const String _monthlyId = 'habitdrill_pro_monthly';
  static const String _yearlyId = 'habitdrill_pro_yearly';

  bool _yearly = false;
  bool _loading = false;
  StreamSubscription<List<PurchaseDetails>>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = InAppPurchase.instance.purchaseStream.listen((purchases) async {
      for (final p in purchases) {
        if (p.status == PurchaseStatus.purchased || p.status == PurchaseStatus.restored) {
          InAppPurchase.instance.completePurchase(p);
          await PremiumService.setPremium(true);
          if (mounted) Navigator.pop(context, true);
        } else if (p.status == PurchaseStatus.error) {
          if (mounted) setState(() => _loading = false);
        } else if (p.status == PurchaseStatus.pending) {
          if (mounted) setState(() => _loading = true);
        }
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _purchase() async {
    setState(() => _loading = true);
    try {
      final id = _yearly ? _yearlyId : _monthlyId;
      final response = await InAppPurchase.instance.queryProductDetails({id});
      if (response.productDetails.isEmpty) {
        setState(() => _loading = false);
        return;
      }
      await InAppPurchase.instance.buyNonConsumable(purchaseParam: PurchaseParam(productDetails: response.productDetails.first));
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const SizedBox(height: 16),

              // Close
              Align(
                alignment: Alignment.topRight,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Icon(Icons.close, color: Colors.white.withOpacity(0.3), size: 24),
                ),
              ),

              const Spacer(flex: 2),

              // Icon
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.asset('assets/icon/app_icon.png', width: 72, height: 72),
              ).animate().fadeIn(duration: 400.ms).scale(begin: const Offset(0.8, 0.8), end: const Offset(1, 1)),

              const SizedBox(height: 20),

              const Text(
                'HABITDRILL PRO',
                style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: 3),
              ).animate(delay: 200.ms).fadeIn(),

              const SizedBox(height: 8),

              Text(
                'Full enforcement unlocked.',
                style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 14),
              ).animate(delay: 300.ms).fadeIn(),

              const SizedBox(height: 36),

              // Features
              _feature('Drill sergeant punishment videos', 0),
              _feature('AI exercise tracking with camera', 1),
              _feature('Escalating workout circuits', 2),
              _feature('Sergeant voice during training', 3),
              _feature('Full violation & offense tracking', 4),

              const Spacer(flex: 3),

              // Plan toggle
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    _planOption('MONTHLY', '\$4.99/mo', false),
                    _planOption('YEARLY', '\$29.99/yr', true),
                  ],
                ),
              ),

              if (_yearly)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text('Save 50%', style: TextStyle(color: AppColors.emerald, fontSize: 12, fontWeight: FontWeight.w700)),
                ),

              const SizedBox(height: 20),

              // Subscribe button
              GestureDetector(
                onTap: _loading ? null : _purchase,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    gradient: AppColors.emeraldGradient,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [BoxShadow(color: AppColors.emerald.withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 4))],
                  ),
                  child: _loading
                      ? const Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black)))
                      : const Text(
                          'UNLOCK PRO',
                          style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 2),
                          textAlign: TextAlign.center,
                        ),
                ),
              ),

              const SizedBox(height: 12),

              GestureDetector(
                onTap: () => InAppPurchase.instance.restorePurchases(),
                child: Text('Restore purchases', style: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 12, decoration: TextDecoration.underline, decorationColor: Colors.white24)),
              ),

              const SizedBox(height: 8),

              Text(
                'Auto-renews. Cancel anytime.',
                style: TextStyle(color: Colors.white.withOpacity(0.1), fontSize: 11),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _feature(String text, int index) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Container(
            width: 6, height: 6,
            decoration: BoxDecoration(color: AppColors.emerald, borderRadius: BorderRadius.circular(3)),
          ),
          const SizedBox(width: 14),
          Text(text, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14, fontWeight: FontWeight.w500)),
        ],
      ),
    ).animate(delay: (400 + index * 100).ms).fadeIn(duration: 250.ms).slideX(begin: 0.03, end: 0);
  }

  Widget _planOption(String label, String price, bool isYearly) {
    final selected = _yearly == isYearly;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _yearly = isYearly),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? AppColors.emerald : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              Text(label, style: TextStyle(color: selected ? Colors.black : Colors.white54, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1)),
              Text(price, style: TextStyle(color: selected ? Colors.black : Colors.white30, fontSize: 11, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}
