import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import 'local_storage.dart';
import 'normal_reminder_registry.dart';
import 'wake_siren_service.dart';

/// Background-audio keepalive — the Alarmy technique.
///
/// iOS suspends any app in the background after ~30 s unless it's
/// actively playing audio via an `AVAudioSession` with the `.playback`
/// category (declared in `UIBackgroundModes: audio`). Once suspended,
/// the app can't run code, so at wake time it can't spin up the
/// WakeSirenService.
///
/// This service plays a 1-second near-silent WAV on infinite loop
/// while any active wake alarm exists on the schedule. That keeps
/// HabitDrill alive through the night, so when the alarm fires we can
/// take the audio session over at full volume — bypassing the silent
/// switch because `.playback` is *allowed to*.
///
/// It runs alongside the AlarmKit alert (iOS 26+) and the
/// time-sensitive notification cascade (iOS 15+). Belt, braces,
/// parachute.
///
/// The service is a no-op on Android (Android uses AlarmManager/exact
/// alarms, not background audio, for scheduled wake).
class WakeKeepaliveService {
  static final AudioPlayer _player = AudioPlayer(playerId: 'wake_keepalive');
  static bool _running = false;
  static Timer? _watchdog;

  static const String _silenceAsset = 'audio/sergeant/silence.wav';

  /// Start the keepalive loop IF there is at least one active wake
  /// habit. Idempotent — safe to call on every app resume / launch /
  /// habit change.
  static Future<void> startIfNeeded() async {
    if (WakeSirenService.isRunning) {
      // Real siren is playing — it owns the audio session. Never
      // fight it.
      return;
    }
    if (!_hasActiveWakeHabit()) {
      await stop();
      return;
    }
    if (_running) {
      _kickIfDead();
      return;
    }
    _running = true;
    await _playOnce();
    _watchdog?.cancel();
    _watchdog = Timer.periodic(const Duration(seconds: 15), (_) {
      if (!_running) return;
      if (WakeSirenService.isRunning) {
        stop();
        return;
      }
      if (!_hasActiveWakeHabit()) {
        stop();
        return;
      }
      _kickIfDead();
    });
    debugPrint('🔇 WakeKeepalive STARTED');
  }

  static Future<void> _playOnce() async {
    try {
      await _player.setReleaseMode(ReleaseMode.loop);
      // Volume is set very low — the WAV itself is all-zero samples
      // so any volume produces silence anyway. Keeping non-zero volume
      // makes some iOS audio-session heuristics happier about
      // considering us "actively playing".
      await _player.setVolume(0.01);
      await _player.setPlayerMode(PlayerMode.mediaPlayer);
      await _player.play(AssetSource(_silenceAsset), volume: 0.01);
    } catch (e) {
      debugPrint('WakeKeepalive._playOnce failed: $e');
    }
  }

  static Future<void> _kickIfDead() async {
    try {
      final state = _player.state;
      if (state != PlayerState.playing) {
        debugPrint('🔇 WakeKeepalive watchdog: state=$state — restarting');
        await _playOnce();
      }
    } catch (e) {
      debugPrint('WakeKeepalive._kickIfDead error: $e');
    }
  }

  /// Stop the keepalive. Called when the real siren starts, when the
  /// last wake alarm is disabled, or when the app fully exits.
  static Future<void> stop() async {
    if (!_running) return;
    _running = false;
    _watchdog?.cancel();
    _watchdog = null;
    try {
      await _player.stop();
      debugPrint('🔇 WakeKeepalive STOPPED');
    } catch (e) {
      debugPrint('WakeKeepalive.stop failed: $e');
    }
  }

  static bool get isRunning => _running;

  static bool _hasActiveWakeHabit() {
    try {
      final all = LocalStorageService.getAllHabits();
      return all.any((h) =>
          h.type == 'habit' &&
          h.reminderOn &&
          h.time.isNotEmpty &&
          h.repeatDays.isNotEmpty &&
          !NormalReminderRegistry.isNormalReminder(h.id));
    } catch (e) {
      debugPrint('WakeKeepalive._hasActiveWakeHabit failed: $e');
      return false;
    }
  }
}
