import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Plays drill sergeant voice clips at the right moments.
/// 1.mp3 = "1!", 2.mp3 = "2!", etc. Every single rep gets its number called.
class SergeantAudioService {
  static final AudioPlayer _player = AudioPlayer();
  static final AudioPlayer _barkPlayer = AudioPlayer(); // Second player for overlapping barks
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

  // ==================== NAMED BARK CLIPS ====================
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
    try {
      await _player.stop();
      await _player.play(AssetSource(assetPath.replaceFirst('assets/', '')));
    } catch (e) {
      debugPrint('SergeantAudio error: $e');
    }
  }

  /// Play on the bark player (won't cut off the main player)
  static Future<void> _playBark(String assetPath) async {
    try {
      await _barkPlayer.play(AssetSource(assetPath.replaceFirst('assets/', '')));
    } catch (e) {
      debugPrint('SergeantAudio bark error: $e');
    }
  }

  static Future<void> playExerciseStart(String exerciseId) async {
    final clip = _exerciseStartClips[exerciseId];
    if (clip != null) await _play(clip);
  }

  static Future<void> playCountdown() async => await _play(_countdownClip);
  static Future<void> playCircuitComplete() async => await _play(_circuitCompleteClip);

  /// THE MAIN METHOD. Called on every single rep.
  /// Rep 1 = plays 1.mp3. Rep 2 = plays 2.mp3. Always. No exceptions up to 30.
  static Future<void> onRepCounted({
    required int currentRep,
    required int targetReps,
    required String exerciseId,
  }) async {
    // Play the rep number. Always. 1 = 1.mp3, 2 = 2.mp3, etc.
    if (currentRep >= 1 && currentRep <= 30) {
      await _play('assets/audio/sergeant/$currentRep.mp3');
    }

    // AFTER the number, play a milestone bark on the second player
    // so it doesn't cut off the number
    await Future.delayed(const Duration(milliseconds: 800));

    if (currentRep == targetReps) {
      // Exercise done - circuit screen handles transition
      return;
    }

    if (currentRep == targetReps - 1) {
      await _playBark(_lastRepClip);
      return;
    }

    final halfway = (targetReps / 2).round();
    if (currentRep == halfway && targetReps >= 6) {
      await _playBark(_halfwayClip);
      return;
    }

    // Random bark every 5 reps for intensity
    if (currentRep > 0 && currentRep % 5 == 0) {
      int idx;
      do {
        idx = _random.nextInt(_namedBarks.length);
      } while (idx == _lastBarkIndex && _namedBarks.length > 1);
      _lastBarkIndex = idx;
      await _playBark(_namedBarks[idx]);
    }
  }

  static Future<void> stop() async {
    await _player.stop();
    await _barkPlayer.stop();
  }

  static Future<void> dispose() async {
    await _player.dispose();
    await _barkPlayer.dispose();
  }
}
