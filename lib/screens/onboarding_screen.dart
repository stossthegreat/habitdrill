import 'package:flutter/material.dart';
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
    return Scaffold(
      backgroundColor: Colors.black,
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.backgroundGradient,
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(flex: 2),

                // App icon
                ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: Image.asset(
                    'assets/icon/app_icon.png',
                    width: 120,
                    height: 120,
                    fit: BoxFit.cover,
                  ),
                ).animate().fadeIn(duration: 600.ms).scale(
                  begin: const Offset(0.8, 0.8),
                  end: const Offset(1, 1),
                  duration: 600.ms,
                ),

                const SizedBox(height: AppSpacing.xl),

                // Title
                ShaderMask(
                  shaderCallback: (bounds) =>
                      AppColors.emeraldGradient.createShader(bounds),
                  child: const Text(
                    'DRILLSARJ',
                    style: TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 3,
                    ),
                  ),
                ).animate(delay: 300.ms).fadeIn(duration: 500.ms),

                const SizedBox(height: AppSpacing.lg),

                // Tagline
                Text(
                  'Break a habit?\nFace the sergeant.',
                  style: AppTextStyles.h3.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ).animate(delay: 500.ms).fadeIn(duration: 500.ms),

                const SizedBox(height: AppSpacing.md),

                // Description
                Text(
                  'Build discipline through accountability.\nMiss a habit and the drill sergeant makes you train.',
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.textTertiary,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ).animate(delay: 700.ms).fadeIn(duration: 500.ms),

                const Spacer(flex: 3),

                // Get Started button
                SizedBox(
                  width: double.infinity,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: AppColors.emeraldGradient,
                      borderRadius: BorderRadius.circular(AppBorderRadius.lg),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.emerald.withOpacity(0.4),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _proceed(context),
                        borderRadius:
                            BorderRadius.circular(AppBorderRadius.lg),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                          child: Text(
                            'GET STARTED',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                  ),
                ).animate(delay: 900.ms).fadeIn(duration: 400.ms).slideY(
                  begin: 0.3,
                  end: 0,
                  duration: 400.ms,
                ),

                const SizedBox(height: AppSpacing.xxl),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
