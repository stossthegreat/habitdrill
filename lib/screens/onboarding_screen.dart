import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:video_player/video_player.dart';
import '../design/tokens.dart';
import '../models/escalation_config.dart';
import '../services/analytics_service.dart';
import 'main_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  VideoPlayerController? _videoController;
  bool _videoPlaying = false;
  bool _videoFinished = false;

  @override
  void initState() {
    super.initState();
    AnalyticsService.logScreenView('onboarding');
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _initVideo();
  }

  @override
  void dispose() {
    _videoController?.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  Future<void> _initVideo() async {
    try {
      _videoController = VideoPlayerController.asset(EscalationConfig.introVideo);
      await _videoController!.initialize();
      _videoController!.addListener(_onVideoEnd);
      if (mounted) {
        setState(() => _videoPlaying = true);
        _videoController!.play();
      }
    } catch (e) {
      debugPrint('Intro video not available: $e');
      // No video? Go straight to the landing page
      if (mounted) setState(() => _videoFinished = true);
    }
  }

  void _onVideoEnd() {
    if (_videoController != null &&
        _videoController!.value.isInitialized &&
        _videoController!.value.position >= _videoController!.value.duration &&
        _videoController!.value.duration > Duration.zero) {
      _videoController!.removeListener(_onVideoEnd);
      if (mounted) setState(() => _videoFinished = true);
    }
  }

  Future<void> _proceed() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('seen_onboarding', true);
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Phase 1: Play sergeant_intro.mp4 fullscreen
    if (_videoPlaying && !_videoFinished) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: _videoController != null && _videoController!.value.isInitialized
            ? SizedBox.expand(
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: _videoController!.value.size.width,
                    height: _videoController!.value.size.height,
                    child: VideoPlayer(_videoController!),
                  ),
                ),
              )
            : const Center(child: CircularProgressIndicator(color: AppColors.emerald)),
      );
    }

    // Phase 2: Landing page with CONTINUE
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF0A0A0A),
                  Color(0xFF000000),
                  Color(0xFF0A1A0F),
                  Color(0xFF000000),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                const Spacer(flex: 3),

                ClipRRect(
                  borderRadius: BorderRadius.circular(32),
                  child: Image.asset(
                    'assets/icon/app_icon.png',
                    width: 140,
                    height: 140,
                    fit: BoxFit.cover,
                  ),
                ).animate().fadeIn(duration: 800.ms).scale(
                  begin: const Offset(0.6, 0.6),
                  end: const Offset(1, 1),
                  duration: 800.ms,
                  curve: Curves.easeOutBack,
                ),

                const SizedBox(height: 32),

                ShaderMask(
                  shaderCallback: (bounds) => AppColors.emeraldGradient.createShader(bounds),
                  child: const Text(
                    'HABITDRILL',
                    style: TextStyle(fontSize: 44, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 4),
                  ),
                ).animate(delay: 400.ms).fadeIn(duration: 600.ms),

                const SizedBox(height: 16),

                Text(
                  'Set orders.\nBreak them. Pay.',
                  style: AppTextStyles.h3.copyWith(color: Colors.white.withOpacity(0.7), height: 1.4, fontSize: 20),
                  textAlign: TextAlign.center,
                ).animate(delay: 700.ms).fadeIn(duration: 500.ms),

                const SizedBox(height: 24),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 48),
                  child: Text(
                    'Discipline enforcement.\nFail an order and you train.',
                    style: AppTextStyles.body.copyWith(color: Colors.white.withOpacity(0.3), height: 1.6, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ).animate(delay: 1000.ms).fadeIn(duration: 500.ms),

                const Spacer(flex: 4),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: SizedBox(
                    width: double.infinity,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: AppColors.emeraldGradient,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(color: AppColors.emerald.withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 8)),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _proceed,
                          borderRadius: BorderRadius.circular(16),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 18),
                            child: Text(
                              'CONTINUE',
                              style: TextStyle(color: Colors.black, fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: 2),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ).animate(delay: 300.ms).fadeIn(duration: 400.ms).slideY(begin: 0.3, end: 0, duration: 400.ms),

                const SizedBox(height: 48),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
