import 'package:flutter/foundation.dart';

import 'local_storage.dart';

/// Marks habit IDs whose alarm should be a SINGLE reminder ping rather
/// than the drill-sergeant wake cascade + punishment gate.
///
/// Contracts and laws want a normal alarm — one notification at the set
/// time, done. Wake habits (created via NewWakeAlarmScreen) do NOT go
/// into this registry: they keep the AlarmKit cascade and the whole
/// PunishmentGate → MorningAlarmScreen flow.
///
/// Backing store is the Hive settings box so lookups stay synchronous
/// (needed inside PunishmentGate.build() and WakeDebtService).
class NormalReminderRegistry {
  static const String _key = 'normal_reminder_ids';

  static Set<String> _read() {
    final raw = LocalStorageService.getSetting<List<dynamic>>(
      _key,
      defaultValue: <String>[],
    );
    if (raw == null) return <String>{};
    return raw.map((e) => e.toString()).toSet();
  }

  static Future<void> _write(Set<String> ids) async {
    await LocalStorageService.saveSetting(_key, ids.toList());
  }

  /// Whether the given habit is a plain single-shot reminder (contract
  /// alarm) — NOT a wake alarm. Synchronous.
  static bool isNormalReminder(String habitId) {
    return _read().contains(habitId);
  }

  static Future<void> mark(String habitId) async {
    final ids = _read();
    if (ids.add(habitId)) {
      await _write(ids);
      debugPrint('NormalReminderRegistry: marked $habitId');
    }
  }

  static Future<void> unmark(String habitId) async {
    final ids = _read();
    if (ids.remove(habitId)) {
      await _write(ids);
      debugPrint('NormalReminderRegistry: unmarked $habitId');
    }
  }
}
