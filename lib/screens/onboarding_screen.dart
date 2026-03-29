import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../design/tokens.dart';
import 'auth/login_screen.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  Future<void> _proceed(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('seen_onboarding', true);
    if (context.mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Full immersive
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Full-screen background gradient
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

          // Content
          SafeArea(
            child: Column(
              children: [
                const Spacer(flex: 3),

                // App icon - big and bold
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

                // Title
                ShaderMask(
                  shaderCallback: (bounds) =>
                      AppColors.emeraldGradient.createShader(bounds),
                  child: const Text(
                    'DRILLSARJ',
                    style: TextStyle(
                      fontSize: 44,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 4,
                    ),
                  ),
                ).animate(delay: 400.ms).fadeIn(duration: 600.ms),

                const SizedBox(height: 16),

                // Tagline
                Text(
                  'Break a habit?\nFace the sergeant.',
                  style: AppTextStyles.h3.copyWith(
                    color: Colors.white.withOpacity(0.7),
                    height: 1.4,
                    fontSize: 20,
                  ),
                  textAlign: TextAlign.center,
                ).animate(delay: 700.ms).fadeIn(duration: 500.ms),

                const SizedBox(height: 24),

                // Subtitle
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 48),
                  child: Text(
                    'Build discipline through accountability.\nMiss a habit and the drill sergeant makes you train.',
                    style: AppTextStyles.body.copyWith(
                      color: Colors.white.withOpacity(0.35),
                      height: 1.6,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ).animate(delay: 1000.ms).fadeIn(duration: 500.ms),

                const Spacer(flex: 4),

                // Continue button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: SizedBox(
                    width: double.infinity,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: AppColors.emeraldGradient,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.emerald.withOpacity(0.4),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _proceed(context),
                          borderRadius: BorderRadius.circular(16),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 18),
                            child: Text(
                              'CONTINUE',
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 2,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ).animate(delay: 1300.ms).fadeIn(duration: 400.ms).slideY(
                  begin: 0.3,
                  end: 0,
                  duration: 400.ms,
                ),

                const SizedBox(height: 48),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
