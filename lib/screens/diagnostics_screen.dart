import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';

import '../design/tokens.dart';
import '../models/habit.dart';
import '../services/alarm_service.dart';
import '../services/alarmkit_service.dart';
import '../services/local_storage.dart';
import '../services/normal_reminder_registry.dart';
import '../services/wake_debt_service.dart';
import '../services/wake_mission_prefs.dart';

/// Everything-you-need diagnostics for alarms + notifications.
///
/// Opened from Settings → Diagnostics. Shows:
///   * OS-level permission states (notification, camera, AlarmKit)
///   * Every habit's alarm-relevant fields + whether it's a
///     wake-alarm or a normal-reminder (registry lookup)
///   * Every notification currently sitting in iOS's pending queue —
///     id, title, body, fire time
///   * Buttons to fire a test notification NOW, schedule a probe
///     alarm 30 s out, reschedule every wake alarm, and cancel
///     everything.
///
/// Pull-to-refresh reloads the whole snapshot.
class DiagnosticsScreen extends StatefulWidget {
  const DiagnosticsScreen({super.key});

  @override
  State<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends State<DiagnosticsScreen> {
  bool _loading = true;

  PermissionStatus? _notif;
  PermissionStatus? _cam;
  bool _alarmKitAvailable = false;
  String _alarmKitStatus = 'unknown';
  List<Habit> _habits = const [];
  List<PendingNotificationRequest> _pending = const [];
  final List<String> _actionLog = <String>[];

  Timer? _autoRefresh;

  @override
  void initState() {
    super.initState();
    _refresh();
    // Refresh every 5 seconds so users can watch the queue drain
    // after firing a probe.
    _autoRefresh = Timer.periodic(const Duration(seconds: 5), (_) => _refresh(silent: true));
  }

  @override
  void dispose() {
    _autoRefresh?.cancel();
    super.dispose();
  }

  void _log(String line) {
    final ts = DateFormat('HH:mm:ss').format(DateTime.now());
    setState(() {
      _actionLog.insert(0, '[$ts] $line');
      if (_actionLog.length > 40) _actionLog.removeLast();
    });
    debugPrint('DIAG: $line');
  }

  Future<void> _refresh({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      _notif = await Permission.notification.status;
    } catch (_) {}
    try {
      _cam = await Permission.camera.status;
    } catch (_) {}
    try {
      _alarmKitAvailable = await AlarmKitService.isAvailable();
    } catch (_) {}
    try {
      _alarmKitStatus = await AlarmKitService.authorizationStatus();
    } catch (_) {}
    try {
      _habits = LocalStorageService.getAllHabits();
    } catch (_) {}
    try {
      _pending = await AlarmService.pendingNotifications();
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _fireTestNow() async {
    _log('Firing test notification NOW…');
    final ok = await AlarmService.fireTestNotificationNow();
    _log(ok
        ? '✅ show() returned OK — check your notification tray.'
        : '❌ show() threw — see debugPrint logs.');
    await _refresh(silent: true);
  }

  Future<void> _fireTestIn30s() async {
    _log('Scheduling probe alarm 30 s from now…');
    final at = await AlarmService.scheduleTestAlarmIn30Seconds();
    _log('⏰ Probe scheduled for ${DateFormat('HH:mm:ss').format(at)}.');
    _log('Keep this screen open — it should appear in Pending below.');
    await _refresh(silent: true);
  }

  Future<void> _rescheduleAll() async {
    _log('Rescheduling every wake alarm on the box…');
    try {
      await AlarmService.rescheduleWakeAlarms(_habits);
      _log('✅ rescheduleWakeAlarms completed.');
    } catch (e) {
      _log('❌ rescheduleWakeAlarms threw: $e');
    }
    await _refresh(silent: true);
  }

  Future<void> _cancelEverything() async {
    _log('Cancelling ALL notifications…');
    await AlarmService.cancelEverything();
    _log('✅ cancelAll dispatched.');
    await _refresh(silent: true);
  }

  Future<void> _requestNotifPerm() async {
    _log('Requesting notification permission…');
    final r = await Permission.notification.request();
    _log('Result: $r');
    await _refresh(silent: true);
  }

  Future<void> _requestAlarmKit() async {
    _log('Requesting AlarmKit authorization…');
    final r = await AlarmKitService.requestAuthorization();
    _log('Result: $r');
    await _refresh(silent: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      appBar: AppBar(
        backgroundColor: const Color(0xFF050505),
        elevation: 0,
        title: const Text(
          'DIAGNOSTICS',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w900,
            letterSpacing: 3,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _refresh(),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.emerald,
        backgroundColor: const Color(0xFF0B0B0B),
        onRefresh: _refresh,
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: Colors.white))
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                children: [
                  _section('ENVIRONMENT'),
                  _kv('Platform', Platform.operatingSystem),
                  _kv('Timezone', DateTime.now().timeZoneName),
                  _kv('Now', DateFormat('EEE HH:mm:ss').format(DateTime.now())),
                  const SizedBox(height: 20),
                  _section('PERMISSIONS'),
                  _permRow('Notifications', _notif, _requestNotifPerm),
                  _permRow('Camera', _cam, null),
                  _kv('AlarmKit available', _alarmKitAvailable ? 'YES' : 'NO'),
                  _kv('AlarmKit auth', _alarmKitStatus),
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 4),
                    child: _button(
                      icon: Icons.notification_add,
                      label: 'REQUEST ALARMKIT AUTH',
                      onTap: _requestAlarmKit,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _section('TEST FIRE'),
                  _button(
                    icon: Icons.flash_on,
                    label: 'FIRE TEST NOTIFICATION NOW',
                    onTap: _fireTestNow,
                  ),
                  const SizedBox(height: 8),
                  _button(
                    icon: Icons.alarm,
                    label: 'SCHEDULE PROBE ALARM (+30 s)',
                    onTap: _fireTestIn30s,
                  ),
                  const SizedBox(height: 8),
                  _button(
                    icon: Icons.replay,
                    label: 'RESCHEDULE ALL WAKE ALARMS',
                    onTap: _rescheduleAll,
                  ),
                  const SizedBox(height: 8),
                  _button(
                    icon: Icons.delete_forever,
                    label: 'CANCEL ALL NOTIFICATIONS',
                    onTap: _cancelEverything,
                    danger: true,
                  ),
                  const SizedBox(height: 20),
                  _section('WAKE STATE'),
                  _kv('Due wake habit', () {
                    final h = WakeDebtService.findDueWakeHabit();
                    return h == null ? 'none' : '${h.title} (${h.time})';
                  }()),
                  const SizedBox(height: 20),
                  _section('HABITS (${_habits.length})'),
                  ..._habits.map(_habitRow),
                  const SizedBox(height: 20),
                  _section('PENDING NOTIFICATIONS (${_pending.length})'),
                  if (_pending.isEmpty)
                    _hint('No notifications queued with iOS.'),
                  ..._pending.map(_pendingRow),
                  const SizedBox(height: 20),
                  _section('ACTION LOG'),
                  if (_actionLog.isEmpty) _hint('No actions run yet.'),
                  ..._actionLog.map((l) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Text(
                          l,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.75),
                            fontSize: 12,
                            fontFamily: 'Menlo',
                            height: 1.35,
                          ),
                        ),
                      )),
                ],
              ),
      ),
    );
  }

  // ─────────────────── Row builders ───────────────────

  Widget _section(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        label,
        style: TextStyle(
          color: AppColors.emerald.withOpacity(0.8),
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: 3,
        ),
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0B0B0B),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              k,
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
          ),
          Expanded(
            child: Text(
              v,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _permRow(String label, PermissionStatus? status, VoidCallback? onRequest) {
    final ok = status?.isGranted == true;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: (ok ? AppColors.emerald : AppColors.error).withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: (ok ? AppColors.emerald : AppColors.error).withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            ok ? Icons.check_circle : Icons.warning_amber_rounded,
            color: ok ? AppColors.emerald : AppColors.error,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$label · ${status?.toString().split('.').last ?? 'unknown'}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (onRequest != null && !ok)
            GestureDetector(
              onTap: onRequest,
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.emerald,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'REQUEST',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.4,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _button({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool danger = false,
  }) {
    final color = danger ? AppColors.error : AppColors.emerald;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.5)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _habitRow(Habit h) {
    final isNormal = NormalReminderRegistry.isNormalReminder(h.id);
    final kind = h.type == 'bad_habit'
        ? 'RULE'
        : isNormal
            ? 'CONTRACT REMINDER'
            : (h.time.isNotEmpty ? 'WAKE ALARM' : 'ORDER');
    final future = WakeMissionPrefs.getMission(h.id);
    return FutureBuilder<Mission>(
      future: future,
      builder: (context, snap) {
        final mission = snap.data;
        return Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF0B0B0B),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      h.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Text(
                    kind,
                    style: TextStyle(
                      color: AppColors.emerald.withOpacity(0.7),
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'time=${h.time.isEmpty ? "-" : h.time}  reminderOn=${h.reminderOn}  days=${h.repeatDays.join(",")}',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.55),
                  fontSize: 11,
                  fontFamily: 'Menlo',
                ),
              ),
              if (h.time.isNotEmpty && h.reminderOn && !isNormal) ...[
                const SizedBox(height: 4),
                Text(
                  mission == null
                      ? 'mission=loading…'
                      : 'mission=${mission.name}  reps={loading}',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.55),
                    fontSize: 11,
                    fontFamily: 'Menlo',
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _pendingRow(PendingNotificationRequest n) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0B0B0B),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '#${n.id}',
                style: TextStyle(
                  color: AppColors.emerald.withOpacity(0.75),
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'Menlo',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  n.title ?? '(no title)',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (n.body != null) ...[
            const SizedBox(height: 3),
            Text(
              n.body!,
              style: TextStyle(
                color: Colors.white.withOpacity(0.55),
                fontSize: 11,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  Widget _hint(String s) => Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 8),
        child: Text(
          s,
          style: TextStyle(
            color: Colors.white.withOpacity(0.35),
            fontSize: 12,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
}
