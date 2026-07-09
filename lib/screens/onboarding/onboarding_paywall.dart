import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../design/tokens.dart';
import '../../services/premium_service.dart';
import '../main_screen.dart';
import '../privacy_screen.dart';
import '../terms_screen.dart';
import 'onboarding_state.dart';

/// Product IDs. Yearly rescue is a SEPARATE SKU that must be created in
/// App Store Connect at £19.99/year with a 3-day free trial.
class _Products {
  static const String monthly = 'habitdrill_pro_monthly';
  static const String yearly = 'habitdrill_pro_yearly';
  static const String yearlyRescue = 'habitdrill_pro_yearly_rescue';
}

class OnboardingPaywall extends StatefulWidget {
  final OnboardingState state;
  const OnboardingPaywall({super.key, required this.state});

  @override
  State<OnboardingPaywall> createState() => _OnboardingPaywallState();
}

class _OnboardingPaywallState extends State<OnboardingPaywall> {
  int _stage = 0;
  bool _yearly = true;
  bool _rescueShown = false;
  bool _loading = false;
  // Only route home when the user has actually kicked off a purchase or a
  // restore in THIS paywall session. Without this, a stray .restored event
  // from a prior sandbox test would auto-close the paywall the instant it
  // mounts — showing Stage A for a split second then flipping to home.
  bool _purchaseInitiated = false;
  StreamSubscription<List<PurchaseDetails>>? _sub;

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
        // ONLY route home if the user actually tapped a Buy/Restore button
        // during this session. Otherwise a phantom .restored from the App
        // Store queue would auto-close the paywall on mount.
        if (_purchaseInitiated) {
          _goHome();
        }
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
    if (_rescueShown) {
      _goHome();
      return;
    }
    // Divert to the rescue offer.
    setState(() {
      _rescueShown = true;
      _stage = 3;
    });
  }

  Future<void> _purchase({required String productId}) async {
    if (_loading) return;
    HapticFeedback.mediumImpact();
    _purchaseInitiated = true;
    setState(() => _loading = true);
    try {
      final response = await InAppPurchase.instance.queryProductDetails({productId});
      if (response.productDetails.isEmpty) {
        // Rescue product missing? Fall back to standard yearly so the button
        // still works while the App Store Connect SKU is being created.
        if (productId == _Products.yearlyRescue) {
          return _purchase(productId: _Products.yearly);
        }
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
    _purchaseInitiated = true;
    await InAppPurchase.instance.restorePurchases();
  }

  Future<void> _goHome() async {
    // Only mark onboarding as seen AFTER the user actually exits the
    // paywall — either by purchasing, restoring, or declining the rescue
    // offer. This prevents the paywall from being skipped forever if the
    // app is quit between the summary screen and the paywall.
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('seen_onboarding', true);
    } catch (_) {}
    if (!mounted) return;
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
          duration: const Duration(milliseconds: 380),
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
        return _StageFreeTrial(onNext: _next, onClose: _tryClose, onRestore: _restore);
      case 1:
        return _StageReminder(onNext: _next, onClose: _tryClose, onRestore: _restore);
      case 2:
        return _StageTimeline(
          yearly: _yearly,
          loading: _loading,
          onPickYearly: (v) => setState(() => _yearly = v),
          onPurchase: () => _purchase(productId: _yearly ? _Products.yearly : _Products.monthly),
          onRestore: _restore,
          onClose: _tryClose,
        );
      case 3:
        return _RescueOffer(
          loading: _loading,
          onPurchase: () => _purchase(productId: _Products.yearlyRescue),
          onDecline: _goHome,
          onRestore: _restore,
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

// ────────────────────────── Shared bits ──────────────────────────

class _TopRow extends StatelessWidget {
  final VoidCallback? onClose;
  final VoidCallback? onRestore;
  const _TopRow({this.onClose, this.onRestore});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Row(
        children: [
          if (onClose != null)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onClose,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Icon(Icons.close, color: Colors.white.withOpacity(0.45), size: 22),
              ),
            )
          else
            const SizedBox(width: 38),
          const Spacer(),
          if (onRestore != null)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onRestore,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  'Restore',
                  style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

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
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          gradient: AppColors.emeraldGradient,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(color: AppColors.emerald.withOpacity(0.4), blurRadius: 30, offset: const Offset(0, 10)),
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
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2.5,
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
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}

// ────────────────────────── STAGE A: Free trial hook ──────────────────

class _StageFreeTrial extends StatelessWidget {
  final VoidCallback onNext;
  final VoidCallback onClose;
  final VoidCallback onRestore;
  const _StageFreeTrial({required this.onNext, required this.onClose, required this.onRestore});

  static const List<(String title, String body)> _bullets = [
    ('AI-Verified Reps', 'Our computer vision watches every rep. Fake reps do not count.'),
    ('Quit The Bad Ones', 'Vape, porn, sugar, phone. Sign the contract, pay the debt when you break it.'),
    ('Wake Up Or Pay', 'The only way to dismiss your alarm is to actually move.'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _TopRow(onClose: onClose, onRestore: onRestore),
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                const Text(
                  'Try HabitDrill',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.8,
                    height: 1.05,
                  ),
                ).animate().fadeIn(),
                Text(
                  'for free.',
                  style: TextStyle(
                    color: AppColors.emerald,
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.8,
                    height: 1.05,
                    shadows: [Shadow(color: AppColors.emerald.withOpacity(0.5), blurRadius: 18)],
                  ),
                ).animate(delay: 100.ms).fadeIn().slideY(begin: 0.05, end: 0),
                const SizedBox(height: 36),
                for (int i = 0; i < _bullets.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 22),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            color: AppColors.emerald.withOpacity(0.15),
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.emerald.withOpacity(0.5), width: 1),
                          ),
                          alignment: Alignment.center,
                          child: const Icon(Icons.check, color: AppColors.emerald, size: 15),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _bullets[i].$1,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.2,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _bullets[i].$2,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.55),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ).animate(delay: (300 + i * 120).ms).fadeIn(duration: 350.ms).slideX(begin: 0.04, end: 0),
                  ),
                const SizedBox(height: 24),
                const Center(child: _LaurelStars()),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.check, color: AppColors.emerald, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'No payment due now.',
                      style: TextStyle(color: Colors.white.withOpacity(0.65), fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                  ],
                ).animate(delay: 900.ms).fadeIn(),
                const SizedBox(height: 16),
                _CTA(
                  label: 'TRY FOR £0.00',
                  sublabel: '3 DAYS FREE · THEN £34.99/YR',
                  onTap: onNext,
                ).animate(delay: 1000.ms).fadeIn().slideY(begin: 0.05, end: 0),
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    '3 days free, then £34.99 per year (£2.92/mo)',
                    style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ).animate(delay: 1100.ms).fadeIn(),
                const SizedBox(height: 18),
                _LegalFooter(onRestore: onRestore),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _LaurelStars extends StatelessWidget {
  const _LaurelStars();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('🌿', style: const TextStyle(fontSize: 26)),
        const SizedBox(width: 6),
        Row(
          children: [
            for (int i = 0; i < 5; i++)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 1),
                child: Icon(Icons.star_rounded, color: AppColors.amber, size: 20),
              ),
          ],
        ),
        const SizedBox(width: 6),
        Text('🌿', style: const TextStyle(fontSize: 26)),
      ],
    );
  }
}

// ────────────────────────── STAGE B: Reminder ──────────────────

class _StageReminder extends StatelessWidget {
  final VoidCallback onNext;
  final VoidCallback onClose;
  final VoidCallback onRestore;
  const _StageReminder({
    required this.onNext,
    required this.onClose,
    required this.onRestore,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _TopRow(onClose: onClose, onRestore: onRestore),
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const SizedBox(height: 40),
                Text(
                  "We'll send you",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 24, fontWeight: FontWeight.w700),
                ).animate().fadeIn(),
                const SizedBox(height: 4),
                const Text(
                  'a reminder before',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900, letterSpacing: -0.5, height: 1.1),
                ).animate(delay: 100.ms).fadeIn().slideY(begin: 0.05, end: 0),
                Text(
                  'your free trial ends.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.emerald,
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                    height: 1.1,
                    shadows: [Shadow(color: AppColors.emerald.withOpacity(0.5), blurRadius: 18)],
                  ),
                ).animate(delay: 200.ms).fadeIn().slideY(begin: 0.05, end: 0),
                const SizedBox(height: 40),
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            AppColors.emerald.withOpacity(0.15),
                            AppColors.emerald.withOpacity(0.02),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                    const Icon(Icons.notifications_active_rounded, color: AppColors.emerald, size: 130),
                    Positioned(
                      top: 10,
                      right: 30,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: AppColors.error,
                          shape: BoxShape.circle,
                        ),
                        child: const Text(
                          '1',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ).animate(onPlay: (c) => c.repeat(reverse: true))
                          .scaleXY(begin: 1, end: 1.15, duration: 900.ms, curve: Curves.easeInOut),
                    ),
                  ],
                ).animate(delay: 400.ms).scale(begin: const Offset(0.85, 0.85), end: const Offset(1, 1), duration: 500.ms, curve: Curves.easeOutBack),
                const SizedBox(height: 40),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.check, color: AppColors.emerald, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'No payment due now.',
                      style: TextStyle(color: Colors.white.withOpacity(0.65), fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _CTA(label: 'CONTINUE FOR FREE', onTap: onNext).animate(delay: 800.ms).fadeIn(),
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    '3 days free, then £34.99 per year (£2.92/mo)',
                    style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ),
                const SizedBox(height: 18),
                _LegalFooter(onRestore: onRestore),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
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
    return Column(
      children: [
        _TopRow(onClose: onClose, onRestore: onRestore),
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                const Text(
                  'Start your',
                  style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900, letterSpacing: -0.5, height: 1.1),
                ).animate().fadeIn(),
                Text(
                  '3-day FREE trial',
                  style: TextStyle(
                    color: AppColors.emerald,
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                    height: 1.1,
                    shadows: [Shadow(color: AppColors.emerald.withOpacity(0.5), blurRadius: 18)],
                  ),
                ).animate(delay: 100.ms).fadeIn().slideY(begin: 0.05, end: 0),
                const Text(
                  'to continue.',
                  style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900, letterSpacing: -0.5, height: 1.1),
                ).animate(delay: 200.ms).fadeIn(),
                const SizedBox(height: 28),
                _TimelineRow(
                  icon: Icons.lock_open_rounded,
                  iconColor: AppColors.emerald,
                  title: 'Today',
                  body: 'Unlock AI verification, escalating punishments, and the quitting system that kills bad habits for good.',
                  active: true,
                ).animate(delay: 300.ms).fadeIn().slideX(begin: 0.04, end: 0),
                _TimelineConnector(),
                _TimelineRow(
                  icon: Icons.notifications_active_rounded,
                  iconColor: AppColors.emerald,
                  title: 'In 2 Days — Reminder',
                  body: "We'll send you a reminder that your trial is ending soon.",
                  active: true,
                ).animate(delay: 500.ms).fadeIn().slideX(begin: 0.04, end: 0),
                _TimelineConnector(),
                _TimelineRow(
                  icon: Icons.diamond_rounded,
                  iconColor: Colors.white.withOpacity(0.55),
                  title: 'In 3 Days — Billing Starts',
                  body: "You'll be charged £34.99 unless you cancel anytime before.",
                  active: false,
                ).animate(delay: 700.ms).fadeIn().slideX(begin: 0.04, end: 0),
                const SizedBox(height: 22),
                _PricePair(
                  yearly: yearly,
                  onPickYearly: onPickYearly,
                ).animate(delay: 850.ms).fadeIn().slideY(begin: 0.03, end: 0),
                const SizedBox(height: 14),
                Center(
                  child: Text(
                    'Less than a coffee a month.',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.55),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ).animate(delay: 1000.ms).fadeIn(),
                const SizedBox(height: 22),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.check, color: AppColors.emerald, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'No payment due now.',
                      style: TextStyle(color: Colors.white.withOpacity(0.65), fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _CTA(
                  label: yearly ? 'START MY 3-DAY FREE TRIAL' : 'START SUBSCRIPTION',
                  sublabel: yearly ? 'CANCEL ANYTIME · 63% OFF' : 'CANCEL ANYTIME',
                  loading: loading,
                  onTap: onPurchase,
                ),
                const SizedBox(height: 10),
                Center(
                  child: Text(
                    yearly
                        ? '3 days free, then £34.99 per year (£2.92/mo)'
                        : '£7.99 per month · billed monthly',
                    style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ),
                const SizedBox(height: 18),
                _LegalFooter(onRestore: onRestore),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TimelineRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String body;
  final bool active;

  const _TimelineRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.body,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: active ? iconColor.withOpacity(0.15) : Colors.white.withOpacity(0.06),
            shape: BoxShape.circle,
            border: Border.all(color: active ? iconColor.withOpacity(0.5) : Colors.white.withOpacity(0.1), width: 1),
            boxShadow: active ? [BoxShadow(color: iconColor.withOpacity(0.35), blurRadius: 16)] : null,
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.white.withOpacity(active ? 0.95 : 0.55),
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.45),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TimelineConnector extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 20),
      child: Container(
        width: 2,
        height: 22,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.emerald.withOpacity(0.6), AppColors.emerald.withOpacity(0.15)],
          ),
        ),
      ),
    );
  }
}

class _PricePair extends StatelessWidget {
  final bool yearly;
  final ValueChanged<bool> onPickYearly;
  const _PricePair({required this.yearly, required this.onPickYearly});

  @override
  Widget build(BuildContext context) {
    // Reserved height so both cards start at the same Y. The 3-DAYS FREE
    // badge on yearly and the STANDARD badge on monthly both live in this
    // strip — cards below stay the same size, always.
    return Column(
      children: [
        Row(
          children: const [
            Expanded(child: Center(child: _StandardBadge())),
            SizedBox(width: 10),
            Expanded(child: Center(child: _FreeTrialBadge())),
          ],
        ),
        const SizedBox(height: 8),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _PlanCard(
                  title: 'Monthly',
                  price: '£7.99',
                  per: '/mo',
                  note: 'billed monthly',
                  selected: !yearly,
                  onTap: () => onPickYearly(false),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _PlanCard(
                  title: 'Yearly',
                  price: '£34.99',
                  per: '/yr',
                  note: 'just £2.92/mo · save 63%',
                  selected: yearly,
                  accent: true,
                  onTap: () => onPickYearly(true),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StandardBadge extends StatelessWidget {
  const _StandardBadge();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
      ),
      child: Text(
        'STANDARD',
        style: TextStyle(
          color: Colors.white.withOpacity(0.55),
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}

class _FreeTrialBadge extends StatelessWidget {
  const _FreeTrialBadge();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.emerald,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [BoxShadow(color: AppColors.emerald.withOpacity(0.4), blurRadius: 12)],
      ),
      child: const Text(
        '3-DAYS FREE',
        style: TextStyle(
          color: Colors.black,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final String title;
  final String price;
  final String per;
  final String note;
  final bool selected;
  final bool accent;
  final VoidCallback onTap;

  const _PlanCard({
    required this.title,
    required this.price,
    required this.per,
    required this.note,
    required this.selected,
    this.accent = false,
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
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
        decoration: BoxDecoration(
          color: selected ? AppColors.emerald.withOpacity(0.12) : const Color(0xFF0B0B0B),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.emerald : Colors.white.withOpacity(0.08),
            width: selected ? 1.8 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: Colors.white.withOpacity(selected ? 0.95 : 0.7),
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: selected ? AppColors.emerald : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected ? AppColors.emerald : Colors.white.withOpacity(0.3),
                      width: 1.5,
                    ),
                  ),
                  child: selected ? const Icon(Icons.check, color: Colors.black, size: 12) : null,
                ),
              ],
            ),
            const SizedBox(height: 10),
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: price,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                  TextSpan(
                    text: per,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              note,
              style: TextStyle(
                color: accent ? AppColors.emerald.withOpacity(0.85) : Colors.white.withOpacity(0.5),
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ────────────────────────── STAGE D: Rescue offer ──────────────────

/// Slot-machine rescue reveal. Three reels spin garbled characters for
/// ~2.5s and then lock — one at a time, with haptics — onto "£", "19",
/// "99". Then the reveal card fades in with the clean price and the CTA.
///
/// Design ethos: the price is FIXED at £19.99/yr; the slots don't gamble.
/// They're theatre. The user WON — that's the point. Cancel / restore /
/// terms / privacy links sit at the bottom for App Store compliance.
class _RescueOffer extends StatefulWidget {
  final bool loading;
  final VoidCallback onPurchase;
  final VoidCallback onDecline;
  final VoidCallback onRestore;
  const _RescueOffer({
    required this.loading,
    required this.onPurchase,
    required this.onDecline,
    required this.onRestore,
  });

  @override
  State<_RescueOffer> createState() => _RescueOfferState();
}

class _RescueOfferState extends State<_RescueOffer> {
  bool _revealed = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _TopRow(onClose: widget.onDecline, onRestore: widget.onRestore),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),
                Text(
                  _revealed ? 'Locked in.' : 'Spinning your rescue.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.55),
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _revealed ? 'You got the deal.' : 'Hold on…',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                    height: 1.05,
                  ),
                ),
                const SizedBox(height: 32),
                AnimatedSize(
                  duration: const Duration(milliseconds: 380),
                  curve: Curves.easeOutCubic,
                  child: _revealed
                      ? _RevealCard(
                          loading: widget.loading,
                          onPurchase: widget.onPurchase,
                        )
                      : _SlotStrip(onDone: () {
                          if (mounted) setState(() => _revealed = true);
                        }),
                ),
                const SizedBox(height: 22),
                if (_revealed) ...[
                  Center(
                    child: GestureDetector(
                      onTap: widget.onDecline,
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Text(
                          'No thanks',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.35),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _LegalFooter(onRestore: widget.onRestore),
                ],
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ────────────────────────── Slot machine strip ─────────────────────

class _SlotStrip extends StatefulWidget {
  final VoidCallback onDone;
  const _SlotStrip({required this.onDone});

  @override
  State<_SlotStrip> createState() => _SlotStripState();
}

class _SlotStripState extends State<_SlotStrip> {
  static const _targets = ['£', '19', '99'];

  /// Garbled pool — shown while the reels spin. Deliberately meaningless
  /// so the user's eye can't pre-read the reveal.
  static const _pool = <String>[
    '??', '★', '¥7', '₿', '§', '99', '01', '77', '£!', '¥%',
    r'$$', '02', '05', '13', '20', '33', '44', '™', '№', '¤',
  ];

  final _rng = Random();
  final List<String> _current = List.filled(3, '★');
  final List<bool> _locked = List.filled(3, false);
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(milliseconds: 65), (_) {
      if (!mounted) return;
      setState(() {
        for (int i = 0; i < 3; i++) {
          if (!_locked[i]) _current[i] = _pool[_rng.nextInt(_pool.length)];
        }
      });
    });
    _lockAt(0, const Duration(milliseconds: 1500));
    _lockAt(1, const Duration(milliseconds: 2100));
    _lockAt(2, const Duration(milliseconds: 2750));
    Future.delayed(const Duration(milliseconds: 3350), () {
      if (mounted) widget.onDone();
    });
  }

  void _lockAt(int reel, Duration delay) {
    Future.delayed(delay, () {
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      setState(() {
        _current[reel] = _targets[reel];
        _locked[reel] = true;
      });
      if (reel == 2) _tick?.cancel();
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (int i = 0; i < 3; i++) ...[
          _SlotReel(
            key: ValueKey('reel_$i'),
            character: _current[i],
            locked: _locked[i],
          ),
          if (i < 2) const SizedBox(width: 10),
        ],
      ],
    );
  }
}

class _SlotReel extends StatelessWidget {
  final String character;
  final bool locked;
  const _SlotReel({super.key, required this.character, required this.locked});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      width: 92,
      height: 116,
      decoration: BoxDecoration(
        color: const Color(0xFF0B0B0B),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: locked
              ? AppColors.emerald.withOpacity(0.75)
              : Colors.white.withOpacity(0.06),
          width: locked ? 2 : 1,
        ),
        boxShadow: locked
            ? [
                BoxShadow(
                  color: AppColors.emerald.withOpacity(0.35),
                  blurRadius: 22,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      alignment: Alignment.center,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 90),
        transitionBuilder: (child, anim) => FadeTransition(
          opacity: anim,
          child: SlideTransition(
            position: Tween(begin: const Offset(0, 0.6), end: Offset.zero).animate(anim),
            child: child,
          ),
        ),
        child: Text(
          character,
          key: ValueKey('${character}_$locked'),
          style: TextStyle(
            color: locked ? AppColors.emerald : Colors.white,
            fontSize: 44,
            fontWeight: FontWeight.w900,
            letterSpacing: -1,
            height: 1,
            shadows: locked
                ? [Shadow(color: AppColors.emerald.withOpacity(0.4), blurRadius: 12)]
                : null,
          ),
        ),
      ),
    );
  }
}

// ────────────────────────── Reveal card ────────────────────────────

class _RevealCard extends StatelessWidget {
  final bool loading;
  final VoidCallback onPurchase;
  const _RevealCard({required this.loading, required this.onPurchase});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('reveal_card'),
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.emerald.withOpacity(0.18),
            AppColors.emerald.withOpacity(0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.emerald.withOpacity(0.5), width: 1),
        boxShadow: [
          BoxShadow(
            color: AppColors.emerald.withOpacity(0.28),
            blurRadius: 40,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.emerald,
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Text(
              'RESCUE UNLOCKED',
              style: TextStyle(
                color: Colors.black,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 2.5,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            '£34.99',
            style: TextStyle(
              color: Colors.white.withOpacity(0.35),
              fontSize: 18,
              fontWeight: FontWeight.w700,
              decoration: TextDecoration.lineThrough,
              decorationColor: Colors.white38,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '£19',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 92,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -4,
                  height: 1,
                  shadows: [Shadow(color: AppColors.emerald.withOpacity(0.55), blurRadius: 22)],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  '.99',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 40,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1,
                    shadows: [Shadow(color: AppColors.emerald.withOpacity(0.55), blurRadius: 22)],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            'PER YEAR · LOCKED FOREVER',
            style: TextStyle(
              color: AppColors.emerald.withOpacity(0.9),
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 3,
            ),
          ),
          const SizedBox(height: 18),
          Container(
            height: 1,
            color: Colors.white.withOpacity(0.06),
          ),
          const SizedBox(height: 14),
          Text(
            'Cancel anytime. Never renews at full price.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.55),
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 18),
          _CTA(
            label: 'CLAIM RESCUE',
            sublabel: '£19.99 charged today',
            loading: loading,
            onTap: onPurchase,
          ),
        ],
      ),
    ).animate().fadeIn(duration: 380.ms).slideY(begin: 0.05, end: 0);
  }
}

// ────────────────────────── Legal footer ───────────────────────────

/// Full paywall footer used on every stage. Restore · Terms · Privacy
/// links plus the Apple-required auto-renew disclosure (Guideline 3.1.2).
class _LegalFooter extends StatelessWidget {
  final VoidCallback onRestore;
  final bool showAutoRenewDisclosure;
  const _LegalFooter({
    required this.onRestore,
    this.showAutoRenewDisclosure = true,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _LegalLink(label: 'Restore', onTap: onRestore),
              _LegalDot(),
              _LegalLink(
                label: 'Terms',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const TermsScreen()),
                ),
              ),
              _LegalDot(),
              _LegalLink(
                label: 'Privacy',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PrivacyScreen()),
                ),
              ),
            ],
          ),
          if (showAutoRenewDisclosure) ...[
            const SizedBox(height: 10),
            Text(
              'Payment will be charged to your Apple ID at confirmation of '
              'purchase. Subscription automatically renews unless auto-renew '
              'is turned off at least 24 hours before the end of the current '
              'period. Your account will be charged for renewal within 24 '
              'hours prior to the end. You can manage and cancel subscriptions '
              'in your App Store account settings.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.35),
                fontSize: 9.5,
                height: 1.4,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LegalLink extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _LegalLink({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.35),
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            decoration: TextDecoration.underline,
            decorationColor: Colors.white24,
          ),
        ),
      ),
    );
  }
}

class _LegalDot extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        '·',
        style: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 12),
      ),
    );
  }
}

