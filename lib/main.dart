import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:audioplayers/audioplayers.dart';

// Timezone init
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';

import 'models/habit.dart';
import 'models/violation.dart';
import 'services/local_storage.dart';
import 'services/alarm_service.dart';
// LocalStorageService import already covers Habit lookup by id.
import 'services/sergeant_service.dart';
import 'services/retention_service.dart';
import 'services/premium_service.dart';
import 'services/wake_debt_service.dart';
import 'services/analytics_service.dart';
import 'screens/main_screen.dart';
import 'screens/onboarding/onboarding_flow.dart';
import 'screens/sergeant/punishment_screen.dart';
import 'screens/morning_alarm_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/terms_screen.dart';
import 'screens/privacy_screen.dart';
import 'screens/support_screen.dart';
import 'design/theme.dart';

Future<void> _initTimezone() async {
  try {
    tzdata.initializeTimeZones();
    final String localTz = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(localTz));
    debugPrint('Timezone initialized: $localTz');
  } catch (e) {
    debugPrint('Timezone fallback to UTC: $e');
    tz.setLocalLocation(tz.getLocation('UTC'));
  }
}

Future<void> main() async {
  // Catch any uncaught zone errors so the app never dies at launch
  // (this matters for App Review on iPad where unexpected viewport / plugin
  // edge cases can otherwise surface a red Flutter error screen).
  await runZonedGuarded<Future<void>>(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Replace Flutter's default red error screen with a safe black fallback
    // so a single widget exception never blocks app launch (Apple flags this
    // as "displayed an error message at launch").
    ErrorWidget.builder = (FlutterErrorDetails details) {
      debugPrint('ErrorWidget caught: ${details.exception}');
      return const ColoredBox(color: Colors.black);
    };
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      debugPrint('FlutterError: ${details.exception}');
    };
    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      debugPrint('PlatformDispatcher error: $error');
      return true;
    };

    // Initialize Firebase (for analytics)
    try {
      await Firebase.initializeApp();
    } catch (e) {
      debugPrint('Firebase init failed: $e');
    }

    try {
      await _initTimezone();
    } catch (e) {
      debugPrint('Timezone init failed: $e');
    }

    try {
      await AlarmService.initialize();
      // If the app was launched by the user tapping a scheduled alarm,
      // AlarmService stashes the habit id so PunishmentGate can route to
      // the MorningAlarm screen instead of home.
      await AlarmService.handleColdStartAlarm();
    } catch (e) {
      debugPrint('AlarmService init failed: $e');
    }

    // Configure iOS audio session so alarm + sergeant audio play at full
    // volume even when the phone is on silent. This is what Alarmy /
    // Sleep Cycle do — AVAudioSessionCategory.playback overrides the
    // physical silent switch for our session.
    try {
      await AudioPlayer.global.setAudioContext(
        const AudioContext(
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.playback,
            options: [
              AVAudioSessionOptions.mixWithOthers,
              AVAudioSessionOptions.duckOthers,
            ],
          ),
          android: AudioContextAndroid(
            isSpeakerphoneOn: false,
            stayAwake: true,
            contentType: AndroidContentType.music,
            usageType: AndroidUsageType.alarm,
            audioFocus: AndroidAudioFocus.gainTransientMayDuck,
          ),
        ),
      );
      debugPrint('✅ Audio session set to playback (bypasses silent switch)');
    } catch (e) {
      debugPrint('AudioContext setup failed: $e');
    }

    try {
      await Hive.initFlutter();
      if (!Hive.isAdapterRegistered(0)) {
        Hive.registerAdapter(HabitAdapter());
      }
      if (!Hive.isAdapterRegistered(1)) {
        Hive.registerAdapter(ViolationAdapter());
      }
      await LocalStorageService.initialize();
      await SergeantService.initialize();
      await RetentionService.initialize();
      await RetentionService.ensureScheduled();
    } catch (e) {
      debugPrint('Init failed: $e');
    }

    try {
      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarIconBrightness: Brightness.light,
        ),
      );
    } catch (e) {
      debugPrint('System UI overlay setup failed: $e');
    }

    runApp(const ProviderScope(child: HabitDrillApp()));
  }, (Object error, StackTrace stack) {
    debugPrint('Uncaught zone error: $error');
  });
}

class HabitDrillApp extends StatelessWidget {
  const HabitDrillApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HabitDrill',
      theme: _getSafeTheme(),
      home: const AppRouter(),
      debugShowCheckedModeBanner: false,
      navigatorObservers: [AnalyticsService.observer],
      routes: {
        '/settings': (context) => const SettingsScreen(),
        '/terms': (context) => const TermsScreen(),
        '/privacy': (context) => const PrivacyScreen(),
        '/support': (context) => const SupportScreen(),
      },
    );
  }

  ThemeData _getSafeTheme() {
    try {
      return AppTheme.darkTheme;
    } catch (e) {
      return ThemeData.dark().copyWith(scaffoldBackgroundColor: Colors.black);
    }
  }
}

/// Flow: Loading → Onboarding (once) → PunishmentGate → Home
class AppRouter extends StatefulWidget {
  const AppRouter({super.key});

  @override
  State<AppRouter> createState() => _AppRouterState();
}

class _AppRouterState extends State<AppRouter> {
  bool _isLoading = true;
  bool _needsOnboarding = false;

  @override
  void initState() {
    super.initState();
    _checkAppState();
  }

  Future<void> _checkAppState() async {
    final prefs = await SharedPreferences.getInstance();
    final seenOnboarding = prefs.getBool('seen_onboarding') ?? false;

    if (!mounted) return;
    setState(() {
      _needsOnboarding = !seenOnboarding;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    if (_needsOnboarding) {
      return const OnboardingFlow();
    }

    return const PunishmentGate();
  }
}

/// Wraps MainScreen - intercepts with punishment if violations are pending
class PunishmentGate extends StatefulWidget {
  const PunishmentGate({super.key});

  @override
  State<PunishmentGate> createState() => _PunishmentGateState();
}

class _PunishmentGateState extends State<PunishmentGate> with WidgetsBindingObserver {
  bool _showPunishment = false;
  Violation? _activeViolation;
  Habit? _forcedWakeHabit;
  Timer? _wakePoll;
  // Which wake habit id we already popped routes for. When this
  // matches the current wake id we skip popUntil so that
  // MorningAlarmScreen's push of WakeExerciseScreen isn't immediately
  // popped back off on the next 500 ms timer tick. Cleared whenever
  // there's no active wake.
  String? _poppedForWakeId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Listen to WakeDebtService — every markActive / clearActive nudges
    // this notifier so we swap the root screen instantly instead of
    // waiting for the next poll tick.
    WakeDebtService.wakeChanged.addListener(_refreshWakeState);
    // Brute-force rebuild every 500 ms while the widget is mounted.
    // Every rebuild re-runs `build()` which synchronously calls
    // findDueWakeHabit() — meaning the moment a wake habit's fire
    // window opens, the very next tick (≤500 ms) flips the app into
    // MorningAlarmScreen. No lifecycle event needed, no state
    // machinery, no "close and reopen." Cheap: findDueWakeHabit is
    // an in-memory Hive scan.
    _wakePoll = Timer.periodic(
      const Duration(milliseconds: 500),
      (_) {
        if (mounted) setState(() {});
      },
    );
    // First check as soon as the first frame commits — before any tab
    // renders behind it.
    WidgetsBinding.instance.addPostFrameCallback((_) => _onEnter());
  }

  @override
  void dispose() {
    WakeDebtService.wakeChanged.removeListener(_refreshWakeState);
    _wakePoll?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // React to ANY non-paused/detached transition. On iOS with UIScene
    // lifecycle, "resumed" is sometimes skipped and we go straight from
    // inactive → active without a resumed callback. Catch inactive too.
    if (state == AppLifecycleState.resumed
        || state == AppLifecycleState.inactive) {
      _onEnter();
    }
  }

  /// One entry-point for every "app is now in foreground" event.
  Future<void> _onEnter() async {
    // Consume any fresh notification-tap payload so it doesn't linger
    // (we ignore the value — the wake state check below finds it too).
    await AlarmService.consumeRecentAlarmTap();
    await _refreshWakeState();
    if (_forcedWakeHabit == null) {
      _checkForPunishment();
    }
    // Escalation pings are one-shots — top up the ladder for the next
    // upcoming fire so notifications keep firing tomorrow too.
    try {
      await AlarmService.rescheduleWakeAlarms(
        LocalStorageService.getAllHabits(),
      );
    } catch (_) {}
  }

  /// Decide whether the app should be showing MorningAlarmScreen right
  /// now. Called from three places: the every-10s timer, the app-resume
  /// lifecycle event, and WakeDebtService.wakeChanged. Idempotent.
  Future<void> _refreshWakeState() async {
    if (!mounted) return;
    // 1. Anything explicitly marked active wins (user opened the wake
    //    screen but didn't finish reps yet).
    final activeId = await WakeDebtService.getActiveHabitId();
    Habit? habit;
    if (activeId != null) {
      habit = LocalStorageService.getAllHabits()
          .where((h) => h.id == activeId)
          .firstOrNull;
    }
    // 2. Otherwise, find any wake habit whose fire happened in the last
    //    30 minutes AND that isn't already done. This catches:
    //      • AlarmKit rang while the app was foregrounded
    //      • User pressed the AlarmKit OPEN button (no notif payload)
    //      • User cold-started the app after the alarm rang
    habit ??= WakeDebtService.findDueWakeHabit();
    if (habit != null && activeId == null) {
      // Persist so we survive backgrounding + relaunch.
      await WakeDebtService.markActive(habit.id);
      return; // markActive fires wakeChanged → this method re-runs.
    }
    if (habit?.id != _forcedWakeHabit?.id) {
      setState(() => _forcedWakeHabit = habit);
    }
  }

  void _checkForPunishment() async {
    // The legacy violation-based PunishmentScreen (spawned when a rule
    // or contract went overdue) has been retired. The ONLY punishment
    // in HabitDrill now is the morning-wake workout gate above. Users
    // reported the old screen firing on top of the wake flow as
    // "second punishment popping up after morning workout" — this
    // no-op fixes that. Kept as a stub so all the wiring
    // (initState/postFrameCallback/didChangeAppLifecycleState) can
    // stay untouched.
    return;
  }

  void _onPunishmentComplete() {
    if (mounted) {
      setState(() {
        _showPunishment = false;
        _activeViolation = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // WAKE FIRST. When a wake alarm is due, THE APP IS THE PUNISHMENT
    // SCREEN. No tabs, no home, no way to browse around it.
    //
    // We check `findDueWakeHabit()` synchronously on EVERY build in
    // addition to trusting the async-driven `_forcedWakeHabit` state.
    // This is the "close-and-reopen fixes it" bug: the async state
    // machine had a race window where the user could see MainScreen
    // for a beat before punishment took over. The build-time check
    // eliminates that window — the moment build runs (and it runs on
    // every rebuild, every setState, every timer tick), a due wake
    // wins.
    final syncDueWake = WakeDebtService.findDueWakeHabit();
    final wake = _forcedWakeHabit ?? syncDueWake;
    if (wake != null) {
      // Belt-and-braces: if the user had ANY route pushed on top of
      // PunishmentGate (Settings, contract editor, terms, etc.) when
      // the alarm fires, that pushed route stays visible and hides
      // the punishment screen even though we've swapped the root. Pop
      // it all off ONCE after this frame so MorningAlarmScreen becomes
      // the only visible surface. We DON'T re-pop on later rebuilds,
      // because MorningAlarmScreen legitimately pushes WakeExerciseScreen
      // during the workout — and we'd otherwise kick the user back to
      // the alarm every 500 ms.
      if (_poppedForWakeId != wake.id) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final nav = Navigator.maybeOf(context);
          if (nav != null && nav.canPop()) {
            nav.popUntil((r) => r.isFirst);
          }
          _poppedForWakeId = wake.id;
        });
      }
      return MorningAlarmScreen(
        key: ValueKey('wake_${wake.id}'),
        habit: wake,
      );
    }
    // No wake right now — clear the pop marker so a future wake can
    // reset routes again.
    _poppedForWakeId = null;
    if (_showPunishment && _activeViolation != null) {
      return PunishmentScreen(
        violation: _activeViolation!,
        onComplete: _onPunishmentComplete,
      );
    }
    return const MainScreen();
  }
}
