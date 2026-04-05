import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Plays drill sergeant voice clips at exactly the right moments.
/// Numbered clips 1-30 = rep count announcements. Played IN ORDER.
class SergeantAudioService {
  static final AudioPlayer _player = AudioPlayer();
  static final Random _random = Random();
  static bool _isPlaying = false;

  // ==================== EXERCISE START CLIPS ====================
  static const Map<String, String> _exerciseStartClips = {
    'squats': 'assets/audio/sergeant/squats_now.mp3',
    'burpees': 'assets/audio/sergeant/burpees_now.mp3',
    'high_knees': 'assets/audio/sergeant/high_knees.mp3',
    'push_ups': 'assets/audio/sergeant/pushups_now.mp3',
    'jumping_jacks': 'assets/audio/sergeant/jumpingjacks_now.mp3',
  };

  // ==================== MILESTONE CLIPS ====================
  static const String _halfwayClip = 'assets/audio/sergeant/halfway.mp3';
  static const String _lastRepClip = 'assets/audio/sergeant/last_rep.mp3';
  static const String _countdownClip = 'assets/audio/sergeant/countdown.mp3';
  static const String _circuitCompleteClip = 'assets/audio/sergeant/curcuits_complete.mp3';

  // ==================== NAMED BARK CLIPS (random between reps) ====================
  static const List<String> _namedBarks = [
    'assets/audio/sergeant/move_it.mp3',
    'assets/audio/sergeant/pathetic.mp3',
    'assets/audio/sergeant/not_counting.mp3',
    'assets/audio/sergeant/quit_grandma.mp3',
    'assets/audio/sergeant/fault.mp3',
    'assets/audio/sergeant/keep_going.mp3',
    'assets/audio/sergeant/younever_learn.mp3',
  ];

  static int _lastBarkIndex = -1;

  // ==================== PLAY ====================

  static Future<void> _play(String assetPath) async {
    if (_isPlaying) return;
    try {
      _isPlaying = true;
      await _player.play(AssetSource(assetPath.replaceFirst('assets/', '')));
      _player.onPlayerComplete.listen((_) {
        _isPlaying = false;
      });
      Future.delayed(const Duration(seconds: 4), () {
        _isPlaying = false;
      });
    } catch (e) {
      _isPlaying = false;
      debugPrint('SergeantAudio error: $e');
    }
  }

  /// Play exercise start announcement
  static Future<void> playExerciseStart(String exerciseId) async {
    final clip = _exerciseStartClips[exerciseId];
    if (clip != null) await _play(clip);
  }

  /// Play the rep count number: 1.mp3 for rep 1, 2.mp3 for rep 2, etc.
  /// Only works for reps 1-30. Above 30 plays a random bark instead.
  static Future<void> playRepNumber(int repNumber) async {
    if (repNumber >= 1 && repNumber <= 30) {
      await _play('assets/audio/sergeant/$repNumber.mp3');
    } else {
      await _playRandomBark();
    }
  }

  /// Play a random named bark (not a number)
  static Future<void> _playRandomBark() async {
    int idx;
    do {
      idx = _random.nextInt(_namedBarks.length);
    } while (idx == _lastBarkIndex && _namedBarks.length > 1);
    _lastBarkIndex = idx;
    await _play(_namedBarks[idx]);
  }

  static Future<void> playHalfway() async => await _play(_halfwayClip);
  static Future<void> playLastRep() async => await _play(_lastRepClip);
  static Future<void> playCountdown() async => await _play(_countdownClip);
  static Future<void> playCircuitComplete() async => await _play(_circuitCompleteClip);

  /// Called every rep. Plays the right audio at the right time.
  /// Rep 1 = "1!", Rep 2 = "2!", etc.
  /// Halfway = halfway clip. Last rep = last rep clip.
  /// Every few reps a random bark for intensity.
  static Future<void> onRepCounted({
    required int currentRep,
    required int targetReps,
    required String exerciseId,
  }) async {
    // Exercise complete - don't play, next exercise start clip will play
    if (currentRep >= targetReps) return;

    // Second to last rep
    if (currentRep == targetReps - 1) {
      await playLastRep();
      return;
    }

    // Halfway point
    if (currentRep == (targetReps / 2).round() && targetReps >= 6) {
      await playHalfway();
      return;
    }

    // Every rep: play the rep number (1.mp3, 2.mp3, 3.mp3...)
    // But every 5th rep, play a random bark instead for variety
    if (currentRep > 0 && currentRep % 5 == 0) {
      await _playRandomBark();
    } else {
      await playRepNumber(currentRep);
    }
  }

  static Future<void> stop() async {
    await _player.stop();
    _isPlaying = false;
  }

  static Future<void> dispose() async {
    await _player.dispose();
  }
}
