import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../main.dart';
import '../../design/tokens.dart';
import '../../services/premium_service.dart';
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
    // Route to PunishmentGate (not MainScreen). If we drop straight
    // into MainScreen, the wake-alarm gate never runs — meaning a user
    // who finishes onboarding minutes before their alarm fires never
    // sees the punishment screen unless they hard-close and cold-launch
    // the app (which THEN routes through AppRouter → PunishmentGate).
    // That was the "have to close and reopen" bug.
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const PunishmentGate()),
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
    // Post-reveal: a full white-theme paywall page that matches the
    // reference screenshot 1:1. Pre-reveal: keep the dark wheel-of-
    // fortune vibe. Nothing about the wheel changes.
    if (_revealed) {
      return _RescueRevealPage(
        loading: widget.loading,
        onPurchase: widget.onPurchase,
        onDecline: widget.onDecline,
        onRestore: widget.onRestore,
      );
    }
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
                  'Spinning your rescue.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.55),
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Hold on…',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                    height: 1.05,
                  ),
                ),
                const SizedBox(height: 32),
                Center(
                  child: _SlotStrip(onDone: () {
                    if (mounted) setState(() => _revealed = true);
                  }),
                ),
                const SizedBox(height: 22),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ────────────────────────── Circular roulette wheel ─────────────────
//
// A proper wheel of fortune: 12 pie slices around a big circle, 11 with
// question marks, one with the prize. The wheel spins with an easing
// deceleration and lands with the pointer at the top pointing straight
// at the prize slice. On land: heavy haptic, brief hold, then _onDone
// fires and the reveal card takes over.
//
// _SlotStrip kept as the class name so callers don't need to change.

class _SlotStrip extends StatefulWidget {
  final VoidCallback onDone;
  const _SlotStrip({required this.onDone});

  @override
  State<_SlotStrip> createState() => _SlotStripState();
}

class _SlotStripState extends State<_SlotStrip>
    with SingleTickerProviderStateMixin {
  static const int _slices = 8;
  static const int _prizeIndex = 2; // arbitrary — pointer will land here

  late final AnimationController _controller;
  late final Animation<double> _rotation;

  @override
  void initState() {
    super.initState();
    // Wheel spins 4 full turns + settles so the prize slice ends up
    // dead-under the pointer at the top. Slice 0 is centered at 12
    // o'clock; each slice covers 2π/_slices radians.
    final sliceAngle = (2 * pi) / _slices;
    // Rotate so slice _prizeIndex is at the top (which is where the
    // pointer sits). Extra 4 full spins for drama.
    final targetAngle = (4 * 2 * pi) - (_prizeIndex * sliceAngle);
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    );
    _rotation = Tween<double>(begin: 0, end: targetAngle).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _controller.forward();
    _controller.addStatusListener((s) {
      if (s == AnimationStatus.completed) {
        HapticFeedback.heavyImpact();
        Future.delayed(const Duration(milliseconds: 550), () {
          if (mounted) widget.onDone();
        });
      }
    });
    // Rhythmic click as it spins — softens as the wheel decelerates.
    _startTickHaptics();
  }

  Future<void> _startTickHaptics() async {
    for (int i = 0; i < 24; i++) {
      if (!mounted || _controller.isCompleted) return;
      HapticFeedback.selectionClick();
      // Getting slower as we approach the end.
      final t = _controller.value;
      final delayMs = 60 + (t * 220).round();
      await Future.delayed(Duration(milliseconds: delayMs));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Wheel is 300px (up from 240) — with only 8 slices each slice is
    // fatter so a bigger radius reads correctly. The container is a
    // little taller than the wheel to leave room for the pointer above.
    const double wheelSize = 300;
    return SizedBox(
      width: 320,
      height: 360,
      child: Stack(
        alignment: Alignment.topCenter,
        clipBehavior: Clip.none,
        children: [
          // Ambient glow behind the wheel.
          Positioned(
            top: 30,
            child: Container(
              width: wheelSize,
              height: wheelSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.emerald.withOpacity(0.35),
                    AppColors.emerald.withOpacity(0.02),
                  ],
                ),
              ),
            ),
          ),
          // The wheel itself.
          Positioned(
            top: 30,
            child: AnimatedBuilder(
              animation: _rotation,
              builder: (context, _) => Transform.rotate(
                angle: _rotation.value,
                child: CustomPaint(
                  size: const Size(wheelSize, wheelSize),
                  painter: _WheelPainter(
                    slices: _slices,
                    prizeIndex: _prizeIndex,
                  ),
                ),
              ),
            ),
          ),
          // Fixed center hub.
          Positioned(
            top: 30 + wheelSize / 2 - 22,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [Colors.white, Colors.white.withOpacity(0.4)],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: const Text(
                '£',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          // Pointer / needle at the top.
          Positioned(
            top: 8,
            child: SizedBox(
              width: 34,
              height: 42,
              child: CustomPaint(painter: _PointerPainter()),
            ),
          ),
        ],
      ),
    );
  }
}

class _WheelPainter extends CustomPainter {
  final int slices;
  final int prizeIndex;
  _WheelPainter({required this.slices, required this.prizeIndex});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final sliceAngle = (2 * pi) / slices;

    // Slice 0 is centered at the top (12 o'clock), so start at
    // -π/2 - sliceAngle/2 so slice 0's midpoint sits at -π/2.
    final startAngle = -pi / 2 - (sliceAngle / 2);

    for (int i = 0; i < slices; i++) {
      final rect = Rect.fromCircle(center: center, radius: radius);
      final sliceStart = startAngle + (i * sliceAngle);
      final isPrize = i == prizeIndex;
      final fill = Paint()
        ..style = PaintingStyle.fill
        ..shader = SweepGradient(
          startAngle: sliceStart,
          endAngle: sliceStart + sliceAngle,
          colors: isPrize
              ? [
                  const Color(0xFF10B981),
                  const Color(0xFF059669),
                ]
              : (i.isEven
                  ? [const Color(0xFF1A1A1A), const Color(0xFF0D0D0D)]
                  : [const Color(0xFF141414), const Color(0xFF080808)]),
        ).createShader(rect);

      canvas.drawArc(rect, sliceStart, sliceAngle, true, fill);

      // Slice divider hairlines.
      final divider = Paint()
        ..color = Colors.white.withOpacity(0.08)
        ..strokeWidth = 1
        ..style = PaintingStyle.stroke;
      canvas.drawLine(
        center,
        center +
            Offset(cos(sliceStart) * radius, sin(sliceStart) * radius),
        divider,
      );

      // Label — question mark for mystery slices, £ for the prize.
      final midAngle = sliceStart + sliceAngle / 2;
      final labelRadius = radius * 0.65;
      final labelPos = center +
          Offset(cos(midAngle) * labelRadius, sin(midAngle) * labelRadius);
      final label = isPrize ? '£' : '?';
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            color: isPrize ? Colors.white : Colors.white.withOpacity(0.4),
            fontSize: isPrize ? 26 : 22,
            fontWeight: FontWeight.w900,
            shadows: isPrize
                ? [const Shadow(color: Colors.black26, blurRadius: 4)]
                : null,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      canvas.save();
      canvas.translate(labelPos.dx, labelPos.dy);
      canvas.rotate(midAngle + pi / 2);
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();
    }

    // Outer emerald ring.
    final ringOuter = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = AppColors.emerald.withOpacity(0.6);
    canvas.drawCircle(center, radius - 1.5, ringOuter);

    final ringInner = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.white.withOpacity(0.12);
    canvas.drawCircle(center, radius * 0.35, ringInner);
  }

  @override
  bool shouldRepaint(covariant _WheelPainter old) =>
      old.prizeIndex != prizeIndex || old.slices != slices;
}

class _PointerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width / 2, size.height) // bottom tip
      ..lineTo(0, 0)
      ..lineTo(size.width, 0)
      ..close();
    final fill = Paint()
      ..style = PaintingStyle.fill
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: const [Colors.white, Color(0xFFB0B0B0)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(path, fill);
    // Outline.
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = Colors.black.withOpacity(0.5);
    canvas.drawPath(path, stroke);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ────────────────────────── Reveal page (white theme) ─────────────
//
// Full-page rescue reveal. Runs after the wheel finishes. White
// background, gold "SPECIAL OFFER" card, "Pay 83% less", plan card
// with a 3-DAY FREE TRIAL header, black Start Free Trial CTA, plus the
// legal-disclosure footer required by Apple 3.1.2.

class _RescueRevealPage extends StatelessWidget {
  final bool loading;
  final VoidCallback onPurchase;
  final VoidCallback onDecline;
  final VoidCallback onRestore;

  const _RescueRevealPage({
    required this.loading,
    required this.onPurchase,
    required this.onDecline,
    required this.onRestore,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      key: const ValueKey('reveal_page'),
      color: Colors.white,
      child: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 76, 24, 32),
              child: Column(
                children: [
                  const _SpecialOfferCard(),
                  const SizedBox(height: 30),
                  // Rescue price £19.99 vs monthly £7.99 × 12 = £95.88
                  // → 79.14% less. Rounded down = 79%.
                  const Text(
                    'Pay 79% less',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF0A0A0A),
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1,
                      height: 1.05,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'than monthly subscribers',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF757575),
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 34),
                  const _RescuePlanCard(),
                  const SizedBox(height: 18),
                  _StartTrialButton(loading: loading, onTap: onPurchase),
                  const SizedBox(height: 14),
                  const _NoCommitmentRow(),
                  const SizedBox(height: 14),
                  const Text(
                    '3 days free, then £19.99 per year.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF9A9A9A),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Billed annually and renews automatically unless\n'
                    'canceled in the App Store.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF9A9A9A),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 18),
                  _LightLegalRow(onRestore: onRestore),
                  const SizedBox(height: 10),
                  // Full Apple 3.1.2 auto-renew disclosure — required
                  // even though the summary is above; keep tiny and
                  // low-contrast so it doesn't fight the CTA.
                  Text(
                    'Payment will be charged to your Apple ID at confirmation '
                    'of purchase. Subscription automatically renews unless '
                    'auto-renew is turned off at least 24 hours before the '
                    'end of the current period. Manage or cancel in your App '
                    'Store account settings.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.black.withOpacity(0.35),
                      fontSize: 9.5,
                      height: 1.4,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: onDecline,
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        'No thanks',
                        style: TextStyle(
                          color: Colors.black.withOpacity(0.4),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Top-left close X in a circle — matches the reference.
            Positioned(
              top: 12,
              left: 20,
              child: GestureDetector(
                onTap: onDecline,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.10),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.close, color: Color(0xFF0A0A0A), size: 20),
                ),
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 380.ms);
  }
}

class _SpecialOfferCard extends StatelessWidget {
  const _SpecialOfferCard();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 240,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // Six sparkles arranged around the card — mixture of gold and
          // black, matched to the cal.ai reference. Sizes vary for
          // visual rhythm. Positioned by absolute coordinates from the
          // sides of the row so they hang off the sides of the card.
          const Positioned(left: 8, top: 12, child: _Sparkle(size: 18)),
          const Positioned(left: 46, top: 84, child: _Sparkle(size: 14, color: _kGold)),
          const Positioned(left: 4, top: 148, child: _Sparkle(size: 26, color: _kGold)),
          const Positioned(right: 12, top: 20, child: _Sparkle(size: 22)),
          const Positioned(right: 44, top: 88, child: _Sparkle(size: 14, color: _kGold)),
          const Positioned(right: 6, top: 168, child: _Sparkle(size: 20)),
          // Slight tilt on the card + soft shadow underneath = the
          // floating "sticker" look the reference has.
          Transform.rotate(
            angle: -0.03,
            child: Container(
              width: 300,
              height: 200,
              decoration: BoxDecoration(
                color: const Color(0xFF0A0A0A),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.18),
                    blurRadius: 30,
                    offset: const Offset(4, 14),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Column(
                  children: [
                    // Gold header stripe.
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [Color(0xFFE8B84E), Color(0xFFF4D07A)],
                        ),
                      ),
                      child: const Center(
                        child: Text(
                          'SPECIAL OFFER',
                          style: TextStyle(
                            color: Color(0xFF0A0A0A),
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 3,
                          ),
                        ),
                      ),
                    ),
                    // Body — gradient from warm dark-gold to black,
                    // strikethrough regular yearly then bold rescue.
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFF241A0A), Color(0xFF0A0A0A)],
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Standard yearly £34.99 struck through.
                            Text(
                              '£34.99',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.42),
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                decoration: TextDecoration.lineThrough,
                                decorationColor: Colors.white54,
                                decorationThickness: 2,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                '£19.99/year',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 40,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

const Color _kGold = Color(0xFFE8B84E);

class _Sparkle extends StatelessWidget {
  final double size;
  final Color color;
  const _Sparkle({required this.size, this.color = const Color(0xFF0A0A0A)});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _SparklePainter(color: color)),
    );
  }
}

class _SparklePainter extends CustomPainter {
  final Color color;
  _SparklePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    // A 4-point star with sharp tips and concave sides — same silhouette
    // as the cal.ai reference. Built from 8 anchored points; the inner
    // waist (at 22% of the max radius) creates the pinch between arms.
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final cy = h / 2;
    final ax = w / 2; // outer arm length x
    final ay = h / 2; // outer arm length y
    final ix = ax * 0.22; // inner waist x
    final iy = ay * 0.22; // inner waist y
    final path = Path()
      ..moveTo(cx, cy - ay) // top point
      ..lineTo(cx + ix, cy - iy)
      ..lineTo(cx + ax, cy) // right point
      ..lineTo(cx + ix, cy + iy)
      ..lineTo(cx, cy + ay) // bottom point
      ..lineTo(cx - ix, cy + iy)
      ..lineTo(cx - ax, cy) // left point
      ..lineTo(cx - ix, cy - iy)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SparklePainter old) => old.color != color;
}

class _RescuePlanCard extends StatelessWidget {
  const _RescuePlanCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF0A0A0A), width: 2),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Black chip on top.
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10),
            color: const Color(0xFF0A0A0A),
            child: const Center(
              child: Text(
                '3-DAY FREE TRIAL',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2.5,
                ),
              ),
            ),
          ),
          // Body.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Yearly Plan',
                      style: TextStyle(
                        color: Color(0xFF0A0A0A),
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      '£19.99 billed yearly',
                      style: TextStyle(
                        color: Color(0xFF808080),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                const Text(
                  'only £1.66/mo',
                  style: TextStyle(
                    color: Color(0xFF808080),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StartTrialButton extends StatelessWidget {
  final bool loading;
  final VoidCallback onTap;
  const _StartTrialButton({required this.loading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: const Color(0xFF0A0A0A),
          borderRadius: BorderRadius.circular(999),
        ),
        alignment: Alignment.center,
        child: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Text(
                'Start Free Trial',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                ),
              ),
      ),
    );
  }
}

class _NoCommitmentRow extends StatelessWidget {
  const _NoCommitmentRow();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.check_rounded, color: Color(0xFF0A0A0A), size: 18),
        SizedBox(width: 8),
        Text(
          'No commitment  •  Cancel anytime',
          style: TextStyle(
            color: Color(0xFF0A0A0A),
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _LightLegalRow extends StatelessWidget {
  final VoidCallback onRestore;
  const _LightLegalRow({required this.onRestore});

  @override
  Widget build(BuildContext context) {
    Widget link(String label, VoidCallback onTap) => GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF808080),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
    Widget dot() => const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Text('·', style: TextStyle(color: Color(0xFFBDBDBD), fontSize: 14)),
        );
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        link('Terms', () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const TermsScreen()),
            )),
        dot(),
        link('Privacy', () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PrivacyScreen()),
            )),
        dot(),
        link('Restore', onRestore),
      ],
    );
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

