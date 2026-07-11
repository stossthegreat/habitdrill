import 'package:flutter/foundation.dart';

import 'local_storage.dart';

/// Per-day counters for how many times each rule has been broken today
/// and what streak the user lost on the FIRST break.
///
/// Design:
///   * First break of the day fires the full punishment workout, zeroes
///     the streak, and records `streakLost = habit.streak` so we can
///     shame them ("you lost 12 days") on the card.
///   * Every subsequent break the same day increments `count` but does
///     NOT fire another workout. The shame card still updates (OFFENSE
///     #N TODAY).
///   * Everything is keyed on YYYY-MM-DD in the local timezone. Rolls
///     over automatically at midnight (a new day yields a different key
///     and lookups return the defaults).
///
/// Backing store: Hive settings box via LocalStorageService, so lookups
/// are synchronous (needed inside build()).
class RuleBreakLedger {
  static const String _keyPrefix = 'rule_break_ledger.';

  static String _dayKey(String habitId, [DateTime? at]) {
    final now = at ?? DateTime.now();
    final y = now.year.toString().padLeft(4, '0');
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '$_keyPrefix${habitId}_$y-$m-$d';
  }

  static Map<String, dynamic> _read(String habitId, [DateTime? at]) {
    final raw = LocalStorageService.getSetting<dynamic>(_dayKey(habitId, at));
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    return const {'count': 0, 'streakLost': 0};
  }

  /// Whether this rule has been broken at least once today. Synchronous.
  static bool isBrokenToday(String habitId) => offensesToday(habitId) > 0;

  /// How many times this rule was broken today (0..N).
  static int offensesToday(String habitId) {
    final r = _read(habitId);
    return (r['count'] as int?) ?? 0;
  }

  /// The streak that was zeroed by TODAY'S first break. 0 if there
  /// hasn't been a break today (or the streak was already 0).
  static int streakLostToday(String habitId) {
    final r = _read(habitId);
    return (r['streakLost'] as int?) ?? 0;
  }

  /// Record a break. Pass the habit's streak value BEFORE it gets
  /// zeroed — only the first break of the day locks in that number.
  /// Returns true if this is the first break of the day (caller should
  /// fire the physical punishment), false otherwise.
  static Future<bool> recordBreak(String habitId, {required int streakAtTime}) async {
    final current = _read(habitId);
    final wasFirst = ((current['count'] as int?) ?? 0) == 0;
    final nextCount = ((current['count'] as int?) ?? 0) + 1;
    final lockedStreakLost = wasFirst
        ? streakAtTime
        : ((current['streakLost'] as int?) ?? 0);
    await LocalStorageService.saveSetting(
      _dayKey(habitId),
      {'count': nextCount, 'streakLost': lockedStreakLost},
    );
    debugPrint(
      'RuleBreakLedger: $habitId today count=$nextCount '
      'streakLost=$lockedStreakLost first=$wasFirst',
    );
    return wasFirst;
  }
}
