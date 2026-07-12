import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'wake_keepalive_service.dart';

/// The relentless morning shark — INSIDE the app.
///
/// AlarmKit rings the phone through Silent/Focus BEFORE the user opens
/// the app. The moment they tap OPEN, iOS foregrounds HabitDrill and
/// suppresses further AlarmKit alert sounds — which is what the user
/// experienced as "alarm stops the second I tap the notification."
///
/// This service is the in-app scream that fills that gap. It's owned
/// by MorningAlarmScreen (start) and released by WakeCompleteScreen
/// (stop) — meaning it plays right through the workout screens.
///
/// AVAudioSession is configured `.playback + mixWithOthers` in
/// main.dart, NOT `duckOthers`, so this player can coexist with any
/// AlarmKit alarms that still fire during the cascade. We don't fight
/// AlarmKit — we back it up.
///
/// Bulletproofing:
/// - Looping mode on ~1s bark ("MOVE IT!"): even if the OS pauses us
///   briefly (call, focus loss), the watchdog restarts.
/// - Watchdog polls every 3s and force-restarts on `PlayerState !=
///   playing`.
/// - Retry-with-backoff around initial start so a first-call failure
///   never leaves us silent.
class WakeSirenService {
  static final AudioPlayer _player = AudioPlayer(playerId: 'wake_siren');
  static Timer? _hapticTimer;
  static Timer? _watchdog;
  static bool _running = false;
  static int _startAttempts = 0;

  static const String _sirenAsset = 'audio/sergeant/move_it.mp3';

  /// Start the siren. Safe to call multiple times — subsequent calls
  /// while already running are no-ops (but kick the watchdog).
  static Future<void> start() async {
    if (_running) {
      _kickIfDead();
      return;
    }
    // Hand the audio session over from the silent keepalive to the
    // loud siren. Never let them play simultaneously — same
    // AVAudioSession, different players.
    await WakeKeepaliveService.stop();
    _running = true;
    _startAttempts = 0;
    await _playOnce();
    _hapticTimer?.cancel();
    _hapticTimer = Timer.periodic(const Duration(milliseconds: 900), (_) {
      HapticFeedback.heavyImpact();
    });
    _watchdog?.cancel();
    _watchdog = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!_running) return;
      _kickIfDead();
    });
  }

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
      if (_running && _startAttempts < 20) {
        final delayMs = (300 * _startAttempts).clamp(300, 2000);
        Future.delayed(Duration(milliseconds: delayMs), () {
          if (_running) _playOnce();
        });
      }
    }
  }

  static Future<void> _kickIfDead() async {
    try {
      final state = _player.state;
      if (state != PlayerState.playing) {
        debugPrint('🚨 Wake siren watchdog: state=$state — restarting');
        await _playOnce();
      }
    } catch (e) {
      debugPrint('WakeSirenService._kickIfDead error: $e');
      await _playOnce();
    }
  }

  /// Stop the siren. Called from WakeCompleteScreen.initState AFTER
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
    // Reactivate the keepalive so tomorrow's alarm has an already-
    // alive audio session to fall back on if the user leaves the app
    // in the background.
    await WakeKeepaliveService.startIfNeeded();
  }

  static bool get isRunning => _running;
}
