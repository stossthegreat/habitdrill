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
  static Future<bool> schedule({
    required String id,
    required String title,
    required DateTime fireAt,
  }) async {
    if (!Platform.isIOS) return false;
    try {
      final res = await _channel.invokeMethod<bool>('schedule', {
        'id': id,
        'title': title,
        'fireAtEpochSeconds': fireAt.millisecondsSinceEpoch / 1000.0,
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
}
