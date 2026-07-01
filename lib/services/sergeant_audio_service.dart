import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Plays drill sergeant voice clips. NO number counting.
/// Exercise starts, milestones, random barks only.
class SergeantAudioService {
  static final AudioPlayer _player = AudioPlayer();
  static final Random _random = Random();
  static int _lastBarkIndex = -1;

  static const Map<String, String> _exerciseStartClips = {
    'squats': 'assets/audio/sergeant/squats_now.mp3',
    'burpees': 'assets/audio/sergeant/burpees_now.mp3',
    'high_knees': 'assets/audio/sergeant/high_knees.mp3',
    'push_ups': 'assets/audio/sergeant/pushups_now.mp3',
  };

  static const String _halfwayClip = 'assets/audio/sergeant/halfway.mp3';
  static const String _lastRepClip = 'assets/audio/sergeant/last_rep.mp3';
  static const String _countdownClip = 'assets/audio/sergeant/countdown.mp3';
  static const String _circuitCompleteClip = 'assets/audio/sergeant/curcuits_complete.mp3';

  static const List<String> _barks = [
    'assets/audio/sergeant/move_it.mp3',
    'assets/audio/sergeant/pathetic.mp3',
    'assets/audio/sergeant/not_counting.mp3',
    'assets/audio/sergeant/quit_grandma.mp3',
    'assets/audio/sergeant/fault.mp3',
    'assets/audio/sergeant/keep_going.mp3',
    'assets/audio/sergeant/younever_learn.mp3',
  ];

  static Future<void> _play(String assetPath) async {
    try {
      await _player.stop();
      await _player.play(AssetSource(assetPath.replaceFirst('assets/', '')));
    } catch (e) {
      debugPrint('SergeantAudio error: $e');
    }
  }

  static Future<void> playExerciseStart(String exerciseId) async {
    final clip = _exerciseStartClips[exerciseId];
    if (clip != null) await _play(clip);
  }

  static Future<void> playCountdown() async => await _play(_countdownClip);
  static Future<void> playCircuitComplete() async => await _play(_circuitCompleteClip);

  static Future<void> _playRandomBark() async {
    int idx;
    do {
      idx = _random.nextInt(_barks.length);
    } while (idx == _lastBarkIndex && _barks.length > 1);
    _lastBarkIndex = idx;
    await _play(_barks[idx]);
  }

  /// Called on every rep. Plays milestones and random barks. No numbers.
  static Future<void> onRepCounted({
    required int currentRep,
    required int targetReps,
    required String exerciseId,
  }) async {
    if (currentRep >= targetReps) return;

    if (currentRep == targetReps - 1) {
      await _play(_lastRepClip);
      return;
    }

    final halfway = (targetReps / 2).round();
    if (currentRep == halfway && targetReps >= 6) {
      await _play(_halfwayClip);
      return;
    }

    // Random bark every 3rd rep
    if (currentRep > 0 && currentRep % 3 == 0) {
      await _playRandomBark();
    }
  }

  static Future<void> stop() async => await _player.stop();
  static Future<void> dispose() async => await _player.dispose();
}
