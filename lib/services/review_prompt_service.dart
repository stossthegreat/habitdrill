import 'package:flutter/foundation.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Fires the native "Enjoying HabitDrill?" 5-star review popup
/// (SKStoreReviewController on iOS) at aha moments.
///
/// iOS handles the actual rendering and enforces its own throttle
/// (max 3 prompts per rolling 365 days per app), so we call
/// `requestReview()` liberally at moments where the user is likely
/// to feel good about the app. iOS decides when to actually show it.
///
/// On our side we also gate on:
/// - `_kMinAhaMoments` — don't ask before the user has actually done
///   the thing once. First-time users spam-tapping through onboarding
///   shouldn't see the popup.
/// - `_kMinDaysBetween` — even if iOS would show it, don't burn our
///   attempts more than once per week.
class ReviewPromptService {
  static final InAppReview _inAppReview = InAppReview.instance;

  static const String _kAhaCount = 'review_aha_moments';
  static const String _kLastPromptAt = 'review_last_prompt_ms';

  /// The user must have crossed this many aha moments before we
  /// pester them. Set to 1 so the first battle-won or contract
  /// completion is enough — the app is short-loop, don't hold back.
  static const int _kMinAhaMoments = 1;

  /// Minimum spacing between our prompt attempts (regardless of what
  /// iOS decides). iOS's own throttle is longer than this, so this is
  /// just a floor.
  static const Duration _kMinDaysBetween = Duration(days: 7);

  /// Register an aha moment. Persisted so we don't double-count
  /// across app launches.
  static Future<void> registerAha() async {
    final prefs = await SharedPreferences.getInstance();
    final n = (prefs.getInt(_kAhaCount) ?? 0) + 1;
    await prefs.setInt(_kAhaCount, n);
    debugPrint('ReviewPromptService: aha moment count = $n');
  }

  /// Try to show the native review popup. Safe to call anywhere —
  /// silently no-ops when unavailable or throttled.
  ///
  /// Set `alsoRegisterAha: true` to bump the aha counter as part of
  /// the same call (typical use: pass true from a screen that's ONLY
  /// reached after a real win).
  static Future<void> maybeAsk({bool alsoRegisterAha = false}) async {
    try {
      if (alsoRegisterAha) await registerAha();
      final prefs = await SharedPreferences.getInstance();
      final ahaCount = prefs.getInt(_kAhaCount) ?? 0;
      if (ahaCount < _kMinAhaMoments) {
        debugPrint('ReviewPromptService: ahaCount=$ahaCount < min, skip');
        return;
      }
      final lastAt = prefs.getInt(_kLastPromptAt);
      if (lastAt != null) {
        final since = DateTime.now().millisecondsSinceEpoch - lastAt;
        if (since < _kMinDaysBetween.inMilliseconds) {
          debugPrint('ReviewPromptService: last prompt too recent, skip');
          return;
        }
      }
      if (!await _inAppReview.isAvailable()) {
        debugPrint('ReviewPromptService: not available on this device');
        return;
      }
      await _inAppReview.requestReview();
      await prefs.setInt(_kLastPromptAt, DateTime.now().millisecondsSinceEpoch);
      debugPrint('✅ ReviewPromptService: requestReview() dispatched');
    } catch (e) {
      debugPrint('ReviewPromptService error: $e');
    }
  }

  /// For the Settings "Leave a Review" row — always tries the App
  /// Store URL (no throttling), letting the user actively rate.
  static Future<void> openStoreListing() async {
    try {
      await _inAppReview.openStoreListing(
        appStoreId: '6761660060',
      );
    } catch (e) {
      debugPrint('ReviewPromptService.openStoreListing error: $e');
    }
  }
}
