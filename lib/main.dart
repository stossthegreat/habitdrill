import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Timezone init
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';

import 'models/habit.dart';
import 'services/local_storage.dart';
import 'services/alarm_service.dart';
import 'screens/main_screen.dart';
import 'screens/auth/login_screen.dart';
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
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Initialize Firebase
    try {
      await Firebase.initializeApp();
      debugPrint('Firebase initialized');
    } catch (e) {
      debugPrint('Firebase initialization failed: $e');
    }

    // Initialize timezone
    await _initTimezone();

    // Initialize alarm service
    await AlarmService.initialize();
    debugPrint('AlarmService initialized');

    // Hive setup
    try {
      await Hive.initFlutter();
      if (!Hive.isAdapterRegistered(0)) {
        Hive.registerAdapter(HabitAdapter());
      }
      await LocalStorageService.initialize();
      debugPrint('Hive initialized');
    } catch (e) {
      debugPrint('Hive/Sync initialization failed: $e');
    }

    // System UI
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );

    runApp(const ProviderScope(child: FutureYouApp()));
  }, (error, stack) {
    debugPrint('Fatal error: $error\n$stack');
  });
}

class FutureYouApp extends StatelessWidget {
  const FutureYouApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Drillsarj',
      theme: _getSafeTheme(),
      home: const AppRouter(),
      debugShowCheckedModeBanner: false,
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
      debugPrint('Custom theme failed, using fallback: $e');
      return ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
        primaryColor: Colors.blue,
      );
    }
  }
}

class AppRouter extends StatefulWidget {
  const AppRouter({super.key});

  @override
  State<AppRouter> createState() => _AppRouterState();
}

class _AppRouterState extends State<AppRouter> {
  bool _isAuthenticated = false;
  bool _isLoading = true;
  String _errorMessage = '';
  StreamSubscription<User?>? _authStateSubscription;

  @override
  void initState() {
    super.initState();
    _checkAppState();
    _listenToAuthChanges();
  }

  @override
  void dispose() {
    _authStateSubscription?.cancel();
    super.dispose();
  }

  void _listenToAuthChanges() {
    try {
      _authStateSubscription = FirebaseAuth.instance.authStateChanges().listen((User? user) {
        debugPrint('Auth state changed: ${user?.uid ?? "null"}');
        if (mounted) {
          setState(() {
            _isAuthenticated = user != null;
          });
        }
      });
    } catch (e) {
      debugPrint('Could not listen to auth changes: $e');
    }
  }

  Future<void> _checkAppState() async {
    try {
      bool isAuthenticated = false;
      try {
        final user = FirebaseAuth.instance.currentUser;
        isAuthenticated = user != null;
      } catch (e) {
        debugPrint('Firebase Auth not available: $e');
        final prefs = await SharedPreferences.getInstance();
        final userId = prefs.getString('user_id');
        isAuthenticated = userId != null && userId.isNotEmpty;
      }

      if (!mounted) return;
      setState(() {
        _isAuthenticated = isAuthenticated;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('App state check error: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Error state
    if (_errorMessage.isNotEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 48),
                const SizedBox(height: 20),
                const Text(
                  'Initialization Error',
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Text(
                  _errorMessage,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 30),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _errorMessage = '';
                      _isLoading = true;
                    });
                    _checkAppState();
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Loading state
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.blue),
              SizedBox(height: 20),
              Text(
                'Loading Drillsarj...',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
            ],
          ),
        ),
      );
    }

    // Show login if not authenticated, otherwise main app
    if (!_isAuthenticated) {
      return const LoginScreen();
    }

    return const MainScreen();
  }
}
