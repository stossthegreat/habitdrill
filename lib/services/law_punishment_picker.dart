import 'dart:math';

/// A single punishment that HabitDrill can assign when a Law is broken.
/// Kept minimal — the label is the whole product surface.
class LawPunishment {
  final String id;
  final String label;
  final String emoji;
  final String flavor;
  const LawPunishment({
    required this.id,
    required this.label,
    required this.emoji,
    required this.flavor,
  });
}

/// The pool of punishments HabitDrill can hand a user when they break a
/// Law. The unpredictability is the whole point: the user knows the
/// pool but not which they'll actually get. Uncertainty of consequence
/// is a stronger deterrent than a known cost (behavioural econ 101 —
/// Kahneman's variable-ratio schedule).
///
/// Punishments are deterministic per (law-id, offense-number) so the
/// same offense always resolves the same punishment — no rerolling
/// their way out. But since offense-number is unknown at commit time,
/// the user can't optimise around the reveal.
class LawPunishmentPicker {
  static const List<LawPunishment> pool = [
    LawPunishment(
      id: 'pushups_30',
      label: '30 Push-ups',
      emoji: '💪',
      flavor: 'Chest, arms, and pride. Enjoy.',
    ),
    LawPunishment(
      id: 'burpees_20',
      label: '20 Burpees',
      emoji: '💥',
      flavor: 'The exercise you hate the most.',
    ),
    LawPunishment(
      id: 'wallsit_45',
      label: '45s Wall Sit',
      emoji: '🧱',
      flavor: 'Just you, the wall, and your legs quitting.',
    ),
    LawPunishment(
      id: 'squats_50',
      label: '50 Squats',
      emoji: '🦵',
      flavor: 'Your legs will remember this tomorrow.',
    ),
    LawPunishment(
      id: 'highknees_60',
      label: '60 High Knees',
      emoji: '🏃',
      flavor: 'Cardio you asked for. In a way.',
    ),
    LawPunishment(
      id: 'circuit_ps',
      label: '20 Push-ups + 30 Squats',
      emoji: '🔥',
      flavor: 'A gentle reminder. Or so we tell you.',
    ),
    LawPunishment(
      id: 'circuit_bp',
      label: '15 Burpees + 20 Push-ups',
      emoji: '⚡',
      flavor: 'The full menu. You broke it, you eat it.',
    ),
  ];

  /// Deterministic pick for a real violation. Given a stable seed (the
  /// law's habit id + the offense count), returns the SAME punishment
  /// every time — so a user can't quit and reopen to reroll. But the
  /// seed changes each offense, so consecutive breaks bring different
  /// punishments.
  static LawPunishment pickFor(String lawId, int offenseNumber) {
    final seed = (lawId.hashCode.abs() + offenseNumber * 31).abs();
    return pool[seed % pool.length];
  }

  /// A truly random pick — used ONLY for the onboarding slot-machine
  /// reveal so the user sees ONE example from the pool. Not the same
  /// as what they'll actually get when they break a real Law.
  static LawPunishment sample({int? seed}) {
    final rng = seed == null ? Random() : Random(seed);
    return pool[rng.nextInt(pool.length)];
  }
}
