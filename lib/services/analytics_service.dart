import 'package:firebase_analytics/firebase_analytics.dart';

class AnalyticsService {
  static final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  static FirebaseAnalyticsObserver get observer => FirebaseAnalyticsObserver(analytics: _analytics);

  // Screen views
  static Future<void> logScreenView(String screenName) async {
    await _analytics.logScreenView(screenName: screenName, screenClass: screenName);
  }

  // Core actions
  static Future<void> logOrderCompleted(String title) async {
    await _analytics.logEvent(name: 'order_completed', parameters: {'title': title});
  }

  static Future<void> logRuleBroken(String title) async {
    await _analytics.logEvent(name: 'rule_broken', parameters: {'title': title});
  }

  static Future<void> logOrderCreated(String type, String title) async {
    await _analytics.logEvent(name: 'order_created', parameters: {'type': type, 'title': title});
  }

  // Punishment
  static Future<void> logPunishmentStarted(int offenseNumber) async {
    await _analytics.logEvent(name: 'punishment_started', parameters: {'offense': offenseNumber});
  }

  static Future<void> logPunishmentCompleted(int offenseNumber) async {
    await _analytics.logEvent(name: 'punishment_completed', parameters: {'offense': offenseNumber});
  }

  static Future<void> logKillUrge() async {
    await _analytics.logEvent(name: 'kill_urge');
  }

  // Retention
  static Future<void> logDisciplineScore(int score) async {
    await _analytics.logEvent(name: 'discipline_score', parameters: {'score': score});
  }

  static Future<void> logShare() async {
    await _analytics.logEvent(name: 'share_card');
  }

  // Paywall
  static Future<void> logPaywallViewed() async {
    await _analytics.logEvent(name: 'paywall_viewed');
  }

  static Future<void> logPurchaseStarted(String productId) async {
    await _analytics.logEvent(name: 'purchase_started', parameters: {'product': productId});
  }

  // Auth
  static Future<void> logSignIn(String method) async {
    await _analytics.logLogin(loginMethod: method);
  }

  static Future<void> logSignUp(String method) async {
    await _analytics.logSignUp(signUpMethod: method);
  }

  static Future<void> logSkipAuth() async {
    await _analytics.logEvent(name: 'skip_auth');
  }
}
