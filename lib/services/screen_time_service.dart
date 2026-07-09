import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Dart-side wrapper for the native `ScreenTimeBridge`.
///
/// Same shape as `AlarmKitService`: iOS-only, safe no-ops elsewhere.
/// Every method is currently a STUB on the Swift side (see the
/// `ScreenTimeBridge` header) so the whole feature can be built and
/// shipped today — the numbers are simulated to look live. The moment
/// Apple approves the `com.apple.developer.family-controls`
/// entitlement, flipping `entitlementAvailable` in Swift makes every
/// call pass through to real Family Controls with zero Dart changes.
class ScreenTimeService {
  static const _channel = MethodChannel('habitdrill/screentime');

  static Future<bool> isAvailable() async {
    if (!Platform.isIOS) return false;
    try {
      final res = await _channel.invokeMethod<bool>('isAvailable');
      return res == true;
    } catch (_) {
      return false;
    }
  }

  /// Returns one of: notDetermined, authorized, denied, unsupported.
  static Future<String> authorizationStatus() async {
    if (!Platform.isIOS) return 'unsupported';
    try {
      final res =
          await _channel.invokeMethod<String>('authorizationStatus');
      return res ?? 'unknown';
    } catch (e) {
      debugPrint('ScreenTime authorizationStatus error: $e');
      return 'unknown';
    }
  }

  /// Prompts the user for the Family Controls authorization sheet.
  /// Returns the resulting status.
  static Future<String> requestAuthorization() async {
    if (!Platform.isIOS) return 'unsupported';
    try {
      final res =
          await _channel.invokeMethod<String>('requestAuthorization');
      return res ?? 'unknown';
    } catch (e) {
      debugPrint('ScreenTime requestAuthorization error: $e');
      return 'unknown';
    }
  }

  /// How many minutes of the given category the user has spent today.
  /// [category] is one of [ScreenTimeCategory.id] values.
  static Future<int> minutesUsedToday(String category) async {
    if (!Platform.isIOS) return 0;
    try {
      final res = await _channel.invokeMethod<int>(
        'minutesUsedToday',
        {'category': category},
      );
      return res ?? 0;
    } catch (e) {
      debugPrint('ScreenTime minutesUsedToday error: $e');
      return 0;
    }
  }

  /// Turn on ManagedSettings shielding of the given category. Stubbed;
  /// callers can safely await today and the same shape works when the
  /// entitlement lands.
  static Future<bool> startShield(String category) async {
    if (!Platform.isIOS) return false;
    try {
      final res = await _channel.invokeMethod<bool>(
        'startShield',
        {'category': category},
      );
      return res == true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> stopShield(String category) async {
    if (!Platform.isIOS) return false;
    try {
      final res = await _channel.invokeMethod<bool>(
        'stopShield',
        {'category': category},
      );
      return res == true;
    } catch (_) {
      return false;
    }
  }
}

/// The Screen Time app categories we let users verify a Law against.
/// Deliberately narrow — matches what Apple exposes as `.category` on
/// FamilyActivitySelection so the day-one → real-day migration is clean.
class ScreenTimeCategory {
  final String id;
  final String label;
  final String emoji;
  final String description;
  const ScreenTimeCategory({
    required this.id,
    required this.label,
    required this.emoji,
    required this.description,
  });

  static const social = ScreenTimeCategory(
    id: 'social',
    label: 'Social apps',
    emoji: '📱',
    description: 'TikTok, Instagram, X, Reddit, Snapchat',
  );
  static const entertainment = ScreenTimeCategory(
    id: 'entertainment',
    label: 'Entertainment',
    emoji: '📺',
    description: 'YouTube, Netflix, Twitch, streaming',
  );
  static const games = ScreenTimeCategory(
    id: 'games',
    label: 'Games',
    emoji: '🎮',
    description: 'Every game category',
  );
  static const all = ScreenTimeCategory(
    id: 'all',
    label: 'Phone total',
    emoji: '📵',
    description: 'Every app combined',
  );

  static const List<ScreenTimeCategory> all_ = [
    social,
    entertainment,
    games,
    all,
  ];

  static ScreenTimeCategory byId(String id) => all_.firstWhere(
        (c) => c.id == id,
        orElse: () => social,
      );
}
