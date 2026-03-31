import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'local_storage.dart';
import 'sergeant_service.dart';

/// Sergeant ranks - promote on consistency, demote on failure
enum SergeantRank {
  private_(0, 'PRIVATE', 0),
  corporal(1, 'CORPORAL', 7),
  sergeant(2, 'SERGEANT', 21),
  lieutenant(3, 'LIEUTENANT', 45),
  captain(4, 'CAPTAIN', 90);

  final int level;
  final String title;
  final int daysRequired;
  const SergeantRank(this.level, this.title, this.daysRequired);
}

class DisciplineService {
  static const String _scoreKey = 'discipline_score';
  static const String _daysControlledKey = 'days_controlled';
  static const String _bestStreakKey = 'best_streak';
  static const String _rankKey = 'sergeant_rank';
  static const String _totalOrdersKey = 'total_orders_completed';
  static const String _totalRulesHeldKey = 'total_rules_held_days';
  static const String _lastCheckDateKey = 'last_discipline_check';
  static const String _briefingSeenKey = 'briefing_seen_date';

  // ==================== DISCIPLINE SCORE (0-100, rolling 30 days) ====================

  static Future<int> getScore() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_scoreKey) ?? 50; // Start at 50
  }

  static Future<void> _setScore(int score) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_scoreKey, score.clamp(0, 100));
  }

  /// Call when user completes an order. Score goes up.
  static Future<void> onOrderCompleted() async {
    final score = await getScore();
    await _setScore(score + 3); // +3 per completion
    await _incrementTotalOrders();
  }

  /// Call when user fails (misses order or breaks rule). Score drops.
  static Future<void> onFailure() async {
    final score = await getScore();
    await _setScore(score - 8); // -8 per failure (loss aversion: losses hurt 2.5x more)
    await _checkDemotion();
  }

  /// Daily decay if no orders completed (at-risk erosion)
  static Future<void> dailyDecay() async {
    final score = await getScore();
    if (score > 30) {
      await _setScore(score - 1); // Slow decay
    }
  }

  // ==================== DAYS CONTROLLED (streak) ====================

  static Future<int> getDaysControlled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_daysControlledKey) ?? 0;
  }

  static Future<int> getBestStreak() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_bestStreakKey) ?? 0;
  }

  static Future<void> incrementDaysControlled() async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(_daysControlledKey) ?? 0;
    final newDays = current + 1;
    await prefs.setInt(_daysControlledKey, newDays);

    // Update best streak
    final best = prefs.getInt(_bestStreakKey) ?? 0;
    if (newDays > best) {
      await prefs.setInt(_bestStreakKey, newDays);
    }

    // Check promotion
    await _checkPromotion(newDays);
  }

  static Future<void> resetDaysControlled() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_daysControlledKey, 0);
  }

  // ==================== SERGEANT RANK ====================

  static Future<SergeantRank> getRank() async {
    final prefs = await SharedPreferences.getInstance();
    final level = prefs.getInt(_rankKey) ?? 0;
    return SergeantRank.values.firstWhere((r) => r.level == level, orElse: () => SergeantRank.private_);
  }

  static Future<void> _setRank(SergeantRank rank) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_rankKey, rank.level);
  }

  static Future<void> _checkPromotion(int daysControlled) async {
    final currentRank = await getRank();
    for (final rank in SergeantRank.values.reversed) {
      if (daysControlled >= rank.daysRequired && rank.level > currentRank.level) {
        await _setRank(rank);
        debugPrint('PROMOTED to ${rank.title}!');
        return;
      }
    }
  }

  static Future<void> _checkDemotion() async {
    final currentRank = await getRank();
    if (currentRank.level > 0) {
      final newRank = SergeantRank.values.firstWhere((r) => r.level == currentRank.level - 1);
      await _setRank(newRank);
      debugPrint('DEMOTED to ${newRank.title}');
    }
  }

  // ==================== STATS ====================

  static Future<int> getTotalOrdersCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_totalOrdersKey) ?? 0;
  }

  static Future<void> _incrementTotalOrders() async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(_totalOrdersKey) ?? 0;
    await prefs.setInt(_totalOrdersKey, current + 1);
  }

  static Future<int> getTotalRulesHeldDays() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_totalRulesHeldKey) ?? 0;
  }

  static Future<void> incrementRulesHeld() async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(_totalRulesHeldKey) ?? 0;
    await prefs.setInt(_totalRulesHeldKey, current + 1);
  }

  // ==================== DAILY CHECK ====================

  /// Run at app open. Checks yesterday's performance.
  static Future<Map<String, dynamic>> runDailyCheck() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now();
    final todayStr = '${today.year}-${today.month}-${today.day}';
    final lastCheck = prefs.getString(_lastCheckDateKey);

    if (lastCheck == todayStr) {
      return {'alreadyChecked': true};
    }

    // Check yesterday
    final yesterday = today.subtract(const Duration(days: 1));
    final habits = LocalStorageService.getAllHabits();
    final yesterdayHabits = habits.where((h) => h.isScheduledForDate(yesterday) && h.type != 'bad_habit').toList();
    final yesterdayRules = habits.where((h) => h.isScheduledForDate(yesterday) && h.type == 'bad_habit').toList();

    bool allOrdersDone = yesterdayHabits.isEmpty || yesterdayHabits.every((h) => h.isDoneOn(yesterday));
    bool noRulesBroken = yesterdayRules.isEmpty || yesterdayRules.every((h) => !h.isDoneOn(yesterday));
    // For rules, isDoneOn means they BROKE it

    bool perfectDay = allOrdersDone && noRulesBroken;

    if (perfectDay) {
      await incrementDaysControlled();
      if (noRulesBroken && yesterdayRules.isNotEmpty) {
        await incrementRulesHeld();
      }
    } else {
      await resetDaysControlled();
      await onFailure();
      // Create violations for missed orders
      for (final habit in yesterdayHabits) {
        if (!habit.isDoneOn(yesterday)) {
          await SergeantService.triggerMissedHabitViolation(habit, yesterday);
        }
      }
    }

    await prefs.setString(_lastCheckDateKey, todayStr);

    return {
      'alreadyChecked': false,
      'perfectDay': perfectDay,
      'allOrdersDone': allOrdersDone,
      'noRulesBroken': noRulesBroken,
    };
  }

  // ==================== DAILY BRIEFING ====================

  static Future<bool> hasSeenBriefingToday() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now();
    final todayStr = '${today.year}-${today.month}-${today.day}';
    return prefs.getString(_briefingSeenKey) == todayStr;
  }

  static Future<void> markBriefingSeen() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now();
    await prefs.setString(_briefingSeenKey, '${today.year}-${today.month}-${today.day}');
  }

  // ==================== SHARE DATA ====================

  static Future<Map<String, dynamic>> getShareData() async {
    return {
      'score': await getScore(),
      'daysControlled': await getDaysControlled(),
      'bestStreak': await getBestStreak(),
      'rank': (await getRank()).title,
      'totalOrders': await getTotalOrdersCompleted(),
      'rulesHeld': await getTotalRulesHeldDays(),
    };
  }
}
