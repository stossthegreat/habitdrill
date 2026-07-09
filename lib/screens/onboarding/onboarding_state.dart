import 'dart:typed_data';
import 'package:flutter/material.dart';

/// Mutable state carried through the onboarding flow.
/// Not persisted — if the user quits mid-flow, they restart. Cheap.
class OnboardingState {
  String? gender;
  int? age;
  String? source;
  String? habitToFix;
  String? struggleDuration;
  String? failCause;
  String? breakFrequency;
  double frustration = 0.5;
  double importance = 0.5;
  TimeOfDay wakeTime = const TimeOfDay(hour: 6, minute: 30);
  String exerciseId = 'push_ups';
  String exerciseName = 'Push Ups';
  int reps = 15;
  Uint8List? signatureBytes;

  /// Which Laws (bad-habit rules) the user signed. Empty is fine —
  /// Act 4 offers "Not now" and the paywall still lands.
  final Set<String> lawsPicked = {};

  /// The one-off punishment the slot-machine reveal locked onto during
  /// onboarding. Kept only so the Signature and Summary screens can
  /// reference the SAME punishment the user just saw, for continuity.
  String? revealedPunishmentId;

  bool get hasSignature => signatureBytes != null && signatureBytes!.isNotEmpty;
}
