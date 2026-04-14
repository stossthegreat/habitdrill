import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';

// Timezone init
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';

import 'models/habit.dart';
import 'models/violation.dart';
import 'services/local_storage.dart';
import 'services/alarm_service.dart';
import 'services/sergeant_service.dart';
import 'services/retention_service.dart';
import 'services/premium_service.dart';
import 'services/analytics_service.dart';
import 'screens/main_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/sergeant/punishment_screen.dart';
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
    } catch (e) {
      debugPrint('AlarmService init failed: $e');
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
      return const OnboardingScreen();
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkForPunishment();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkForPunishment();
    }
  }

  void _checkForPunishment() async {
    final isPro = await PremiumService.isPremium();
    if (!isPro) return;

    await SergeantService.scanForOverdueToday();

    final violation = SergeantService.getWorstPendingViolation();
    if (violation != null && mounted) {
      setState(() {
        _activeViolation = violation;
        _showPunishment = true;
      });
    }
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
    if (_showPunishment && _activeViolation != null) {
      return PunishmentScreen(
        violation: _activeViolation!,
        onComplete: _onPunishmentComplete,
      );
    }
    return const MainScreen();
  }
}
