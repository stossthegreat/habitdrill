import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../../design/tokens.dart';
import '../../services/premium_service.dart';
import '../main_screen.dart';
import 'onboarding_state.dart';

class OnboardingPaywall extends StatefulWidget {
  final OnboardingState state;
  const OnboardingPaywall({super.key, required this.state});

  @override
  State<OnboardingPaywall> createState() => _OnboardingPaywallState();
}

class _OnboardingPaywallState extends State<OnboardingPaywall> {
  int _stage = 0;
  bool _yearly = true;
  bool _oneTimeUnlocked = false;
  bool _loading = false;
  StreamSubscription<List<PurchaseDetails>>? _sub;

  static const String _monthlyId = 'habitdrill_pro_monthly';
  static const String _yearlyId = 'habitdrill_pro_yearly';

  @override
  void initState() {
    super.initState();
    _sub = InAppPurchase.instance.purchaseStream.listen(_onPurchase);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _onPurchase(List<PurchaseDetails> purchases) async {
    for (final p in purchases) {
      if (p.status == PurchaseStatus.purchased || p.status == PurchaseStatus.restored) {
        InAppPurchase.instance.completePurchase(p);
        await PremiumService.setPremium(true);
        _goHome();
      } else if (p.status == PurchaseStatus.error) {
        if (mounted) setState(() => _loading = false);
      }
    }
  }

  void _next() {
    HapticFeedback.selectionClick();
    setState(() => _stage++);
  }

  void _tryClose() {
    HapticFeedback.selectionClick();
    if (_oneTimeUnlocked) {
      _goHome();
      return;
    }
    // Show one-time offer instead of dismissing.
    setState(() {
      _oneTimeUnlocked = true;
      _stage = 3;
    });
  }

  Future<void> _startPurchase() async {
    if (_loading) return;
    HapticFeedback.mediumImpact();
    setState(() => _loading = true);
    try {
      final id = _yearly ? _yearlyId : _monthlyId;
      final response = await InAppPurchase.instance.queryProductDetails({id});
      if (response.productDetails.isEmpty) {
        setState(() => _loading = false);
        return;
      }
      await InAppPurchase.instance.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: response.productDetails.first),
      );
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _restore() async {
    HapticFeedback.selectionClick();
    await InAppPurchase.instance.restorePurchases();
  }

  void _goHome() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MainScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          child: KeyedSubtree(
            key: ValueKey(_stage),
            child: _buildStage(),
          ),
        ),
      ),
    );
  }

  Widget _buildStage() {
    switch (_stage) {
      case 0:
        return _StageUnlock(onNext: _next, onClose: _tryClose);
      case 1:
        return _StageReminder(onNext: _next, onClose: _tryClose);
      case 2:
        return _StageTimeline(
          yearly: _yearly,
          loading: _loading,
          onPickYearly: (v) => setState(() => _yearly = v),
          onPurchase: _startPurchase,
          onRestore: _restore,
          onClose: _tryClose,
        );
      case 3:
        return _OneTimeOffer(
          loading: _loading,
          onPurchase: _startPurchase,
          onDecline: _goHome,
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

// ────────────────────────── Close button (top-right X) ──────────────────

class _CloseX extends StatelessWidget {
  final VoidCallback onTap;
  const _CloseX({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topRight,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Icon(Icons.close, color: Colors.white.withOpacity(0.35), size: 22),
        ),
      ),
    );
  }
}

// ────────────────────────── Primary button (shared) ──────────────────

class _CTA extends StatelessWidget {
  final String label;
  final String? sublabel;
  final bool loading;
  final VoidCallback onTap;
  const _CTA({required this.label, this.sublabel, this.loading = false, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: AppColors.emeraldGradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: AppColors.emerald.withOpacity(0.4), blurRadius: 26, offset: const Offset(0, 8)),
          ],
        ),
        alignment: Alignment.center,
        child: loading
            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 3,
                    ),
                  ),
                  if (sublabel != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      sublabel!,
                      style: TextStyle(
                        color: Colors.black.withOpacity(0.55),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}

// ────────────────────────── STAGE A: Unlock ──────────────────

class _StageUnlock extends StatelessWidget {
  final VoidCallback onNext;
  final VoidCallback onClose;
  const _StageUnlock({required this.onNext, required this.onClose});

  static const List<String> _bullets = [
    'AI verifies every rep',
    'Alarm escalation: +5 reps a minute',
    'Unlimited contracts',
    'Discipline streaks that count',
    'Every future update included',
  ];

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              Text(
                'Everything is ready.',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.55),
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ).animate().fadeIn(),
              const SizedBox(height: 6),
              const Text(
                'UNLOCK HABITDRILL.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                  height: 1.1,
                ),
              ).animate(delay: 100.ms).fadeIn().slideY(begin: 0.05, end: 0),
              const SizedBox(height: 32),
              for (int i = 0; i < _bullets.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: AppColors.emerald.withOpacity(0.15),
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.emerald.withOpacity(0.4), width: 1),
                        ),
                        child: const Icon(Icons.check, color: AppColors.emerald, size: 14),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _bullets[i],
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ).animate(delay: (300 + i * 100).ms).fadeIn(duration: 300.ms).slideX(begin: 0.04, end: 0),
                ),
              const Spacer(),
              _StarStrip().animate(delay: 900.ms).fadeIn(),
              const SizedBox(height: 20),
              _CTA(label: 'START FREE TRIAL', sublabel: '3 DAYS FREE · THEN £24.99/YEAR', onTap: onNext)
                  .animate(delay: 1000.ms).fadeIn().slideY(begin: 0.05, end: 0),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'No payment today.',
                  style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
        _CloseX(onTap: onClose),
      ],
    );
  }
}

class _StarStrip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (int i = 0; i < 5; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Icon(Icons.star_rounded, color: AppColors.amber, size: 20),
          ),
        const SizedBox(width: 8),
        Text(
          '4.8 · 1.2K RATINGS',
          style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5),
        ),
      ],
    );
  }
}

// ────────────────────────── STAGE B: Reminder ──────────────────

class _StageReminder extends StatelessWidget {
  final VoidCallback onNext;
  final VoidCallback onClose;
  const _StageReminder({required this.onNext, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 40),
              // Big bell
              Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.emerald.withOpacity(0.2),
                      AppColors.emerald.withOpacity(0.02),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: const Center(
                  child: Icon(Icons.notifications_active_rounded, color: AppColors.emerald, size: 84),
                ),
              ).animate().scale(begin: const Offset(0.7, 0.7), end: const Offset(1, 1), duration: 500.ms, curve: Curves.easeOutBack),
              const SizedBox(height: 32),
              Text(
                "We'll remind you",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                ),
              ).animate(delay: 300.ms).fadeIn(),
              const SizedBox(height: 6),
              const Text(
                'before your trial ends.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                  height: 1.2,
                ),
              ).animate(delay: 400.ms).fadeIn().slideY(begin: 0.05, end: 0),
              const SizedBox(height: 20),
              Text(
                'No surprise charges.\nYou stay in control.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 14, fontWeight: FontWeight.w500, height: 1.5),
              ).animate(delay: 600.ms).fadeIn(),
              const Spacer(),
              _CTA(label: 'CONTINUE', onTap: onNext).animate(delay: 800.ms).fadeIn(),
            ],
          ),
        ),
        _CloseX(onTap: onClose),
      ],
    );
  }
}

// ────────────────────────── STAGE C: Timeline + pricing ──────────

class _StageTimeline extends StatelessWidget {
  final bool yearly;
  final bool loading;
  final ValueChanged<bool> onPickYearly;
  final VoidCallback onPurchase;
  final VoidCallback onRestore;
  final VoidCallback onClose;
  const _StageTimeline({
    required this.yearly,
    required this.loading,
    required this.onPickYearly,
    required this.onPurchase,
    required this.onRestore,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              const Text(
                'HERE IS HOW\nIT WORKS.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                  height: 1.1,
                ),
              ).animate().fadeIn().slideY(begin: 0.05, end: 0),
              const SizedBox(height: 28),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _TimelineRow(label: 'TODAY', title: 'Unlock everything', dotColor: AppColors.emerald)
                          .animate(delay: 200.ms).fadeIn().slideX(begin: 0.04, end: 0),
                      const _TimelineLine(),
                      _TimelineRow(label: 'IN 2 DAYS', title: 'Reminder notification', dotColor: Colors.white.withOpacity(0.4))
                          .animate(delay: 400.ms).fadeIn().slideX(begin: 0.04, end: 0),
                      const _TimelineLine(),
                      _TimelineRow(label: 'IN 3 DAYS', title: 'Billing begins', dotColor: Colors.white.withOpacity(0.4))
                          .animate(delay: 600.ms).fadeIn().slideX(begin: 0.04, end: 0),
                      const SizedBox(height: 26),
                      _PlanCard(
                        title: 'MONTHLY',
                        price: '£7.99',
                        sub: 'billed monthly',
                        selected: !yearly,
                        onTap: () => onPickYearly(false),
                      ).animate(delay: 700.ms).fadeIn(),
                      const SizedBox(height: 10),
                      _PlanCard(
                        title: 'YEARLY',
                        price: '£24.99',
                        sub: '3-DAY FREE TRIAL · Save 74%',
                        selected: yearly,
                        badge: 'BEST VALUE',
                        onTap: () => onPickYearly(true),
                      ).animate(delay: 800.ms).fadeIn(),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _CTA(
                label: yearly ? 'START MY FREE TRIAL' : 'START SUBSCRIPTION',
                sublabel: yearly ? '3 DAYS FREE · CANCEL ANYTIME' : 'CANCEL ANYTIME',
                loading: loading,
                onTap: onPurchase,
              ),
              const SizedBox(height: 10),
              Center(
                child: GestureDetector(
                  onTap: onRestore,
                  child: Text(
                    'Restore purchases',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.4),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.underline,
                      decorationColor: Colors.white24,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        _CloseX(onTap: onClose),
      ],
    );
  }
}

class _TimelineRow extends StatelessWidget {
  final String label;
  final String title;
  final Color dotColor;
  const _TimelineRow({required this.label, required this.title, required this.dotColor});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: dotColor,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: dotColor.withOpacity(0.6), blurRadius: 8)],
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.4),
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TimelineLine extends StatelessWidget {
  const _TimelineLine();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 5),
      child: Container(
        width: 2,
        height: 22,
        color: Colors.white.withOpacity(0.15),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final String title;
  final String price;
  final String sub;
  final bool selected;
  final String? badge;
  final VoidCallback onTap;
  const _PlanCard({
    required this.title,
    required this.price,
    required this.sub,
    required this.selected,
    this.badge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        decoration: BoxDecoration(
          color: selected ? AppColors.emerald.withOpacity(0.12) : const Color(0xFF0B0B0B),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.emerald : Colors.white.withOpacity(0.06),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: selected ? AppColors.emerald : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? AppColors.emerald : Colors.white.withOpacity(0.25),
                  width: 1.5,
                ),
              ),
              child: selected ? const Icon(Icons.check, color: Colors.black, size: 14) : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                        ),
                      ),
                      if (badge != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.emerald,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            badge!,
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 8,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    sub,
                    style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              price,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ────────────────────────── One-time offer ──────────────────

class _OneTimeOffer extends StatelessWidget {
  final bool loading;
  final VoidCallback onPurchase;
  final VoidCallback onDecline;
  const _OneTimeOffer({required this.loading, required this.onPurchase, required this.onDecline});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 30),
          const Text(
            'Wait.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 44,
              fontWeight: FontWeight.w900,
              letterSpacing: -1,
              height: 1,
            ),
          ).animate().fadeIn().slideY(begin: 0.1, end: 0),
          const SizedBox(height: 8),
          Text(
            'One last offer.',
            style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 20, fontWeight: FontWeight.w600),
          ).animate(delay: 150.ms).fadeIn(),
          const SizedBox(height: 32),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.emerald.withOpacity(0.2), AppColors.emerald.withOpacity(0.05)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.emerald, width: 1.5),
              boxShadow: [
                BoxShadow(color: AppColors.emerald.withOpacity(0.25), blurRadius: 30, spreadRadius: -6),
              ],
            ),
            child: Column(
              children: [
                Text(
                  'ONE-TIME OFFER',
                  style: TextStyle(
                    color: AppColors.emerald,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 4,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  '33% OFF',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 44,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 3,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'FOREVER',
                  style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 3),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '£24.99',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.4),
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        decoration: TextDecoration.lineThrough,
                        decorationColor: Colors.white38,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Text(
                      '£17.99',
                      style: TextStyle(
                        color: AppColors.emerald,
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                        shadows: [Shadow(color: AppColors.emerald.withOpacity(0.5), blurRadius: 18)],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4, left: 4),
                      child: Text(
                        '/year',
                        style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ).animate(delay: 300.ms).scale(
                begin: const Offset(0.92, 0.92),
                end: const Offset(1, 1),
                duration: 400.ms,
                curve: Curves.easeOutBack,
              ),
          const SizedBox(height: 20),
          Text(
            'This offer disappears forever\nonce you close this screen.',
            style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13, fontWeight: FontWeight.w600, height: 1.5),
          ).animate(delay: 600.ms).fadeIn(),
          const Spacer(),
          _CTA(label: 'CLAIM MY DISCOUNT', loading: loading, onTap: onPurchase)
              .animate(delay: 800.ms).fadeIn(),
          const SizedBox(height: 10),
          Center(
            child: GestureDetector(
              onTap: onDecline,
              child: Text(
                'No thanks',
                style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
