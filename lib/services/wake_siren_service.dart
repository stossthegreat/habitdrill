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
/// Bulletproofing:
/// - Looping mode on an ~1s bark ("MOVE IT!"): if the OS ever stops the
///   loop early, the watchdog restarts it.
/// - Watchdog timer polls playback state every 3s while running and
///   force-restarts the audio if the player has gone silent for any
///   reason (interruptions, focus loss, phone call, buggy release).
/// - Retry-with-backoff around initial start so a first-call failure
///   never leaves us silent.
/// - Heavy haptic timer beats every 900ms in parallel.
class WakeSirenService {
  static final AudioPlayer _player = AudioPlayer(playerId: 'wake_siren');
  static Timer? _hapticTimer;
  static Timer? _watchdog;
  static bool _running = false;
  static int _startAttempts = 0;

  /// The clip we loop. Short + clearly aggressive — a longer track
  /// would give the user "silence" between loops if playback stutters.
  static const String _sirenAsset = 'audio/sergeant/move_it.mp3';

  /// Start the siren. Safe to call more than once — subsequent calls
  /// while already running are no-ops. Idempotent per session.
  static Future<void> start() async {
    if (_running) {
      // Even if we think we're running, force a state check — a
      // background OS interruption could have paused us silently.
      _kickIfDead();
      return;
    }
    _running = true;
    _startAttempts = 0;
    await _playOnce();
    _hapticTimer?.cancel();
    _hapticTimer = Timer.periodic(const Duration(milliseconds: 900), (_) {
      HapticFeedback.heavyImpact();
    });
    // Watchdog: every 3 s while running, verify the player is still
    // playing. If not — restart. This is what makes the alarm truly
    // NEVER stop until reps done.
    _watchdog?.cancel();
    _watchdog = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!_running) return;
      _kickIfDead();
    });
  }

  /// Fire-and-forget play with retry-on-failure. Called from start()
  /// and by the watchdog when it detects silence.
  static Future<void> _playOnce() async {
    try {
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.setVolume(1.0);
      await _player.setPlayerMode(PlayerMode.mediaPlayer);
      await _player.play(AssetSource(_sirenAsset), volume: 1.0);
      debugPrint('🚨 Wake siren STARTED (attempt ${_startAttempts + 1})');
      _startAttempts = 0;
    } catch (e) {
      _startAttempts++;
      debugPrint('WakeSirenService._playOnce failed (attempt $_startAttempts): $e');
      // Exponential-ish backoff, capped: 300ms, 600ms, 1.2s, 2s, 2s…
      if (_running && _startAttempts < 20) {
        final delayMs = (300 * _startAttempts).clamp(300, 2000);
        Future.delayed(Duration(milliseconds: delayMs), () {
          if (_running) _playOnce();
        });
      }
    }
  }

  /// Check the player's state. If it's not actively playing, restart.
  static Future<void> _kickIfDead() async {
    try {
      final state = _player.state;
      if (state != PlayerState.playing) {
        debugPrint('🚨 Wake siren watchdog: state=$state — restarting');
        await _playOnce();
      }
    } catch (e) {
      debugPrint('WakeSirenService._kickIfDead error: $e');
      // Best effort: try to restart anyway.
      await _playOnce();
    }
  }

  /// Stop the siren. Called from WakeExerciseScreen._onWakeComplete AFTER
  /// reps are counted. Idempotent.
  static Future<void> stop() async {
    if (!_running) return;
    _running = false;
    _hapticTimer?.cancel();
    _hapticTimer = null;
    _watchdog?.cancel();
    _watchdog = null;
    try {
      await _player.stop();
      debugPrint('🚨 Wake siren STOPPED');
    } catch (e) {
      debugPrint('WakeSirenService.stop failed: $e');
    }
  }

  static bool get isRunning => _running;
}
