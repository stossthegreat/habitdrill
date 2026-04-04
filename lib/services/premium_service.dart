import 'package:shared_preferences/shared_preferences.dart';

/// Simple premium check. Free = habits/tasks only. Pro = punishment system.
class PremiumService {
  static const String _key = 'is_premium';

  static Future<bool> isPremium() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key) ?? false;
  }

  static Future<void> setPremium(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, value);
  }
}
