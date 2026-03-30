import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Plays drill sergeant voice clips at exactly the right moments.
/// All clips are pre-recorded in assets/audio/sergeant/.
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

  // ==================== NUMBERED CLIPS (1-30) ====================
  // Random barks to play between reps
  static String _numberedClip(int n) => 'assets/audio/sergeant/${n.clamp(1, 30)}.mp3';

  // All random clips combined (named + numbered)
  static List<String> get _allRandomBarks {
    final list = <String>[..._namedBarks];
    for (int i = 1; i <= 30; i++) {
      list.add(_numberedClip(i));
    }
    return list;
  }

  // Track what we've played to avoid repeats
  static int _lastBarkIndex = -1;

  // ==================== PLAY METHODS ====================

  /// Play a clip from assets. Non-blocking, skips if already playing.
  static Future<void> _play(String assetPath) async {
    if (_isPlaying) return; // Don't overlap
    try {
      _isPlaying = true;
      await _player.play(AssetSource(assetPath.replaceFirst('assets/', '')));
      _player.onPlayerComplete.listen((_) {
        _isPlaying = false;
      });
      // Safety timeout - mark not playing after 4s max
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
    if (clip != null) {
      await _play(clip);
    }
  }

  /// Play countdown (5-4-3-2-1-GO)
  static Future<void> playCountdown() async {
    await _play(_countdownClip);
  }

  /// Play halfway milestone
  static Future<void> playHalfway() async {
    await _play(_halfwayClip);
  }

  /// Play last rep milestone
  static Future<void> playLastRep() async {
    await _play(_lastRepClip);
  }

  /// Play circuit complete
  static Future<void> playCircuitComplete() async {
    await _play(_circuitCompleteClip);
  }

  /// Play a random bark (during reps). Never repeats the same one twice in a row.
  static Future<void> playRandomBark() async {
    final barks = _allRandomBarks;
    int idx;
    do {
      idx = _random.nextInt(barks.length);
    } while (idx == _lastBarkIndex && barks.length > 1);
    _lastBarkIndex = idx;
    await _play(barks[idx]);
  }

  /// Called every rep to decide what to play
  static Future<void> onRepCounted({
    required int currentRep,
    required int targetReps,
    required String exerciseId,
  }) async {
    // Last rep
    if (currentRep == targetReps) {
      // Don't play anything - exercise is done, start clip for next will play
      return;
    }

    // Last rep coming
    if (currentRep == targetReps - 1) {
      await playLastRep();
      return;
    }

    // Halfway
    if (currentRep == (targetReps / 2).round() && targetReps >= 6) {
      await playHalfway();
      return;
    }

    // Random bark every 3rd rep (keeps intensity without overwhelming)
    if (currentRep > 0 && currentRep % 3 == 0) {
      await playRandomBark();
      return;
    }
  }

  /// Stop everything
  static Future<void> stop() async {
    await _player.stop();
    _isPlaying = false;
  }

  /// Dispose
  static Future<void> dispose() async {
    await _player.dispose();
  }
}
