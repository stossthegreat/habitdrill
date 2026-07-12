import 'package:flutter/foundation.dart';

/// In-memory ring buffer of every debugPrint the app has emitted.
///
/// Wired up in main() by wrapping the platform's debugPrint hook —
/// every log line still goes to the console for developer machines,
/// AND is captured here so the Debug Log overlay can render it.
/// This is the "constant debug log in the app" the user asked for.
class DebugLogService {
  static final DebugLogService _i = DebugLogService._();
  factory DebugLogService() => _i;
  DebugLogService._();

  static const int _maxLines = 500;

  final ValueNotifier<List<String>> lines = ValueNotifier<List<String>>([]);

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
    final line = '[$ts] $msg';
    final next = List<String>.from(lines.value);
    next.add(line);
    if (next.length > _maxLines) {
      next.removeRange(0, next.length - _maxLines);
    }
    lines.value = next;
  }

  void clear() {
    lines.value = const [];
  }

  String snapshot() => lines.value.join('\n');

  static String _timestamp() {
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    String three(int n) => n.toString().padLeft(3, '0');
    return '${two(now.hour)}:${two(now.minute)}:${two(now.second)}.${three(now.millisecond)}';
  }
}
