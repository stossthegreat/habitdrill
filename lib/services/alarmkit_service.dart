import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Dart-side wrapper for the native AlarmKit bridge (iOS 26+ only).
/// Everything is null-safe on other platforms / older iOS — calls return
/// `false` / `"unsupported"` so the caller can fall back to notifications.
class AlarmKitService {
  static const _channel = MethodChannel('habitdrill/alarmkit');

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
      final res = await _channel.invokeMethod<String>('authorizationStatus');
      return res ?? 'unknown';
    } catch (e) {
      debugPrint('AlarmKit authorizationStatus error: $e');
      return 'unknown';
    }
  }

  /// Prompts the user for permission. Returns the resulting status.
  static Future<String> requestAuthorization() async {
    if (!Platform.isIOS) return 'unsupported';
    try {
      final res = await _channel.invokeMethod<String>('requestAuthorization');
      return res ?? 'unknown';
    } catch (e) {
      debugPrint('AlarmKit requestAuthorization error: $e');
      return 'unknown';
    }
  }

  /// Schedules a one-shot alarm at `fireAt`. Returns true on success.
  /// `id` MUST be a UUID string (native side parses it as UUID).
  /// `habitId` is the Habit.id — carried through the AppIntent so that
  /// tapping the alarm routes into the correct wake screen on resume.
  static Future<bool> schedule({
    required String id,
    required String title,
    required DateTime fireAt,
    String habitId = '',
  }) async {
    if (!Platform.isIOS) return false;
    try {
      final res = await _channel.invokeMethod<bool>('schedule', {
        'id': id,
        'title': title,
        'fireAtMs': fireAt.millisecondsSinceEpoch,
        'habitId': habitId,
      });
      return res == true;
    } catch (e) {
      debugPrint('AlarmKit schedule error: $e');
      return false;
    }
  }

  static Future<bool> cancel(String id) async {
    if (!Platform.isIOS) return false;
    try {
      final res = await _channel.invokeMethod<bool>('cancel', {'id': id});
      return res == true;
    } catch (e) {
      debugPrint('AlarmKit cancel error: $e');
      return false;
    }
  }

  /// Stops EVERY AlarmKit alarm this app has scheduled — including
  /// orphans left behind by any historical ID scheme — in a single
  /// method-channel round trip. Returns how many were stopped.
  static Future<int> cancelAll() async {
    if (!Platform.isIOS) return 0;
    try {
      final res = await _channel.invokeMethod<int>('cancelAll');
      return res ?? 0;
    } catch (e) {
      debugPrint('AlarmKit cancelAll error: $e');
      return 0;
    }
  }
}
