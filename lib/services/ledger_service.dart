import 'package:shared_preferences/shared_preferences.dart';

/// Persistent reputation ledger. Never resets.
/// Powers the Ledger and Profile tabs, plus share cards.
class LedgerService {
  static const String _kDisciplineSince = 'ledger_discipline_since';
  static const String _kPromisesMade = 'ledger_promises_made';
  static const String _kPromisesKept = 'ledger_promises_kept';
  static const String _kPromisesBroken = 'ledger_promises_broken';
  static const String _kPunishmentsCompleted = 'ledger_punishments_completed';
  static const String _kRepsPrefix = 'ledger_reps_';
  static const String _kLongestContract = 'ledger_longest_contract';

  static Future<LedgerSnapshot> read() async {
    final prefs = await SharedPreferences.getInstance();
    final sinceIso = prefs.getString(_kDisciplineSince);
    DateTime since;
    if (sinceIso == null) {
      since = DateTime.now();
      await prefs.setString(_kDisciplineSince, since.toIso8601String());
    } else {
      since = DateTime.parse(sinceIso);
    }

    final repKeys = prefs.getKeys().where((k) => k.startsWith(_kRepsPrefix));
    final reps = <String, int>{};
    for (final k in repKeys) {
      reps[k.substring(_kRepsPrefix.length)] = prefs.getInt(k) ?? 0;
    }

    return LedgerSnapshot(
      disciplineSince: since,
      promisesMade: prefs.getInt(_kPromisesMade) ?? 0,
      promisesKept: prefs.getInt(_kPromisesKept) ?? 0,
      promisesBroken: prefs.getInt(_kPromisesBroken) ?? 0,
      punishmentsCompleted: prefs.getInt(_kPunishmentsCompleted) ?? 0,
      reps: reps,
      longestContract: prefs.getInt(_kLongestContract) ?? 0,
    );
  }

  static Future<void> recordPromiseMade() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kPromisesMade, (prefs.getInt(_kPromisesMade) ?? 0) + 1);
  }

  static Future<void> recordPromiseKept() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kPromisesKept, (prefs.getInt(_kPromisesKept) ?? 0) + 1);
  }

  static Future<void> recordPromiseBroken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kPromisesBroken, (prefs.getInt(_kPromisesBroken) ?? 0) + 1);
  }

  static Future<void> recordPunishmentCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      _kPunishmentsCompleted,
      (prefs.getInt(_kPunishmentsCompleted) ?? 0) + 1,
    );
  }

  static Future<void> addReps(String exerciseId, int reps) async {
    if (reps <= 0) return;
    final prefs = await SharedPreferences.getInstance();
    final key = _kRepsPrefix + exerciseId;
    await prefs.setInt(key, (prefs.getInt(key) ?? 0) + reps);
  }

  static Future<void> updateLongestContract(int days) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(_kLongestContract) ?? 0;
    if (days > current) await prefs.setInt(_kLongestContract, days);
  }
}

class LedgerSnapshot {
  final DateTime disciplineSince;
  final int promisesMade;
  final int promisesKept;
  final int promisesBroken;
  final int punishmentsCompleted;
  final Map<String, int> reps;
  final int longestContract;

  const LedgerSnapshot({
    required this.disciplineSince,
    required this.promisesMade,
    required this.promisesKept,
    required this.promisesBroken,
    required this.punishmentsCompleted,
    required this.reps,
    required this.longestContract,
  });

  int get totalReps => reps.values.fold(0, (sum, v) => sum + v);
  int get daysSinceStart => DateTime.now().difference(disciplineSince).inDays;

  int repsFor(String id) => reps[id] ?? 0;
}
