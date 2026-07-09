import 'package:shared_preferences/shared_preferences.dart';

/// Per-Law Screen Time verification config. Kept in SharedPreferences
/// keyed by habit.id so we don't need a Hive adapter regen.
///
/// A Law is a Habit with `type == 'bad_habit'`. When
/// `ScreenTimePrefs.isVerified(id) == true`, the Law is checked against
/// real (stubbed today) usage numbers instead of relying on the user to
/// tap "I broke it."
class ScreenTimePrefs {
  static String _verifyKey(String habitId) => 'stv.verify.$habitId';
  static String _categoryKey(String habitId) => 'stv.category.$habitId';
  static String _budgetKey(String habitId) => 'stv.budget.$habitId';
  static String _shieldKey(String habitId) => 'stv.shield.$habitId';

  static Future<void> setVerified(String habitId, {
    required bool verified,
    required String categoryId,
    required int budgetMinutes,
    required bool shield,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_verifyKey(habitId), verified);
    await prefs.setString(_categoryKey(habitId), categoryId);
    await prefs.setInt(_budgetKey(habitId), budgetMinutes);
    await prefs.setBool(_shieldKey(habitId), shield);
  }

  static Future<bool> isVerified(String habitId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_verifyKey(habitId)) ?? false;
  }

  static Future<String> getCategory(String habitId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_categoryKey(habitId)) ?? 'social';
  }

  static Future<int> getBudget(String habitId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_budgetKey(habitId)) ?? 30;
  }

  static Future<bool> getShield(String habitId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_shieldKey(habitId)) ?? false;
  }

  static Future<void> clear(String habitId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_verifyKey(habitId));
    await prefs.remove(_categoryKey(habitId));
    await prefs.remove(_budgetKey(habitId));
    await prefs.remove(_shieldKey(habitId));
  }
}
