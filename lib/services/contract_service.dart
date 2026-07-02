import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/contract.dart';

class ContractService {
  static const String _key = 'contracts_v1';
  static const Uuid _uuid = Uuid();

  static Future<List<Contract>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? const [];
    return raw.map(Contract.fromRaw).toList();
  }

  static Future<void> saveAll(List<Contract> contracts) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, contracts.map((c) => c.toRaw()).toList());
  }

  static Future<Contract> create({
    required String title,
    required String emoji,
    required int? targetDays,
    required ContractType type,
  }) async {
    final now = DateTime.now();
    final contract = Contract(
      id: _uuid.v4(),
      title: title,
      emoji: emoji,
      startDate: DateTime(now.year, now.month, now.day),
      targetDays: targetDays,
      type: type,
    );
    final list = await loadAll();
    list.add(contract);
    await saveAll(list);
    return contract;
  }

  static Future<void> delete(String id) async {
    final list = await loadAll();
    list.removeWhere((c) => c.id == id);
    await saveAll(list);
  }

  static Future<List<Contract>> activeOnly() async {
    final all = await loadAll();
    return all.where((c) => c.status == ContractStatus.active).toList();
  }

  /// Advance day counters for the new day. Call on app open.
  /// Idempotent: if a contract was already ticked today, it's a no-op.
  /// `hadViolationToday` is true if there is an unpaid punishment / broken
  /// order recorded for today — a signal from SergeantService.
  static Future<void> tickForNewDay({required bool hadViolationToday}) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final list = await loadAll();
    var mutated = false;

    for (final c in list) {
      if (c.status != ContractStatus.active) continue;
      final last = c.lastCheckedDate;
      if (last != null &&
          last.year == today.year &&
          last.month == today.month &&
          last.day == today.day) {
        continue;
      }
      if (hadViolationToday) {
        c.daysFailed++;
      } else {
        c.daysCompleted++;
      }
      c.lastCheckedDate = today;
      if (c.hasTarget && c.daysCompleted >= c.targetDays!) {
        c.status = ContractStatus.completed;
        c.completedAt = today;
      }
      mutated = true;
    }

    if (mutated) await saveAll(list);
  }
}
