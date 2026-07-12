import 'dart:async';

import 'package:flutter/foundation.dart';

/// In-memory ring buffer of every debugPrint the app has emitted.
///
/// Wired up in main() by wrapping the platform's debugPrint hook —
/// every log line still goes to the console for developer machines,
/// AND is captured here so the Debug Log overlay can render it.
///
/// Throttled notifier: raw log writes go into a plain `_buffer`
/// synchronously (no allocations for observers), and the
/// ValueNotifier ticks at most every 200 ms with a fresh snapshot.
/// A previous unthrottled variant caused perceptible jank when the
/// app was chatty at startup (Firebase / timezone / alarm init all
/// pumping dozens of lines within a couple frames), which the user
/// experienced as "the app is frozen, I can't press anything."
class DebugLogService {
  static final DebugLogService _i = DebugLogService._();
  factory DebugLogService() => _i;
  DebugLogService._();

  static const int _maxLines = 500;
  static const Duration _flushInterval = Duration(milliseconds: 200);

  final List<String> _buffer = <String>[];
  Timer? _flushTimer;

  final ValueNotifier<List<String>> lines = ValueNotifier<List<String>>(const []);

  /// Install the debugPrint interception. Safe to call multiple times.
  static bool _installed = false;
  static void install() {
    if (_installed) return;
    _installed = true;
    final defaultPrint = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      // Always keep going to the console so real dev tools still work.
      defaultPrint(message, wrapWidth: wrapWidth);
      _i.add(message ?? '');
    };
  }

  void add(String msg) {
    if (msg.isEmpty) return;
    final ts = _timestamp();
    _buffer.add('[$ts] $msg');
    if (_buffer.length > _maxLines) {
      _buffer.removeRange(0, _buffer.length - _maxLines);
    }
    _scheduleFlush();
  }

  void _scheduleFlush() {
    if (_flushTimer != null) return;
    _flushTimer = Timer(_flushInterval, () {
      _flushTimer = null;
      lines.value = List<String>.unmodifiable(_buffer);
    });
  }

  void clear() {
    _buffer.clear();
    lines.value = const [];
  }

  String snapshot() => _buffer.join('\n');

  static String _timestamp() {
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    String three(int n) => n.toString().padLeft(3, '0');
    return '${two(now.hour)}:${two(now.minute)}:${two(now.second)}.${three(now.millisecond)}';
  }
}
