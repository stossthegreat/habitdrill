import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// The relentless morning shark.
///
/// AlarmKit rings the phone through Silent/Focus for the first 5 minutes
/// but its sound stops after each alert dismisses. Users complained the
/// "shark" went quiet the moment they started the workout.
///
/// This service is the continuous in-app scream that spans from the
/// moment MorningAlarmScreen renders until the user finishes reps. Its
/// AudioPlayer instance is separate from SergeantAudioService's, so the
/// rep-counting barks can play OVER it without stopping the siren.
///
/// - Looping mode on an ~1s bark ("MOVE IT!") means the sergeant is
///   shouting nonstop.
/// - Heavy haptic timer beats every 900 ms in parallel.
/// - Playback survives navigation from MorningAlarmScreen →
///   WakeExerciseScreen because we start it once and only stop it in
///   [stop] which is called from _onWakeComplete().
class WakeSirenService {
  static final AudioPlayer _player = AudioPlayer(playerId: 'wake_siren');
  static Timer? _hapticTimer;
  static bool _running = false;

  /// Start the siren. Safe to call more than once — subsequent calls
  /// are no-ops so navigating from MorningAlarmScreen to
  /// WakeExerciseScreen (both of which call start) doesn't restart the
  /// audio.
  static Future<void> start() async {
    if (_running) return;
    _running = true;
    try {
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.setVolume(1.0);
      await _player.setPlayerMode(PlayerMode.mediaPlayer);
      // move_it.mp3 is the shortest shout in the library — loops as an
      // uninterrupted "MOVE IT MOVE IT MOVE IT" bark.
      await _player.play(AssetSource('audio/sergeant/move_it.mp3'));
      debugPrint('🚨 Wake siren STARTED — loop mode');
    } catch (e) {
      debugPrint('WakeSirenService.start failed: $e');
    }
    // Heavy vibration in parallel with the audio — feels like the phone
    // itself is angry at them.
    _hapticTimer?.cancel();
    _hapticTimer = Timer.periodic(const Duration(milliseconds: 900), (_) {
      HapticFeedback.heavyImpact();
    });
  }

  /// Stop the siren. Called from WakeExerciseScreen._onWakeComplete AFTER
  /// reps are counted. Idempotent.
  static Future<void> stop() async {
    if (!_running) return;
    _running = false;
    _hapticTimer?.cancel();
    _hapticTimer = null;
    try {
      await _player.stop();
      debugPrint('🚨 Wake siren STOPPED');
    } catch (e) {
      debugPrint('WakeSirenService.stop failed: $e');
    }
  }

  static bool get isRunning => _running;
}
