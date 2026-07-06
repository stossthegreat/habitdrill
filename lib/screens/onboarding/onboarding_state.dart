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

  bool get hasSignature => signatureBytes != null && signatureBytes!.isNotEmpty;
}
