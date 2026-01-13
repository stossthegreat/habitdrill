import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../design/tokens.dart';
import '../services/api_client.dart';
import '../services/habit_vault_service.dart';
import '../services/premium_service.dart';
import '../models/vault_item.dart';
import '../providers/habit_provider.dart';
import '../widgets/simple_header.dart';
import '../widgets/paywall_dialog.dart';
import '../widgets/premium_paywall_screen.dart';

class GoalData {
  final int id;
  final String title;
  final String subtitle;
  final String icon;
  final List<PlanStep> plan;

  GoalData({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.plan,
  });
}

class PlanStep {
  final String action;
  final String why;
  final String study;

  PlanStep({
    required this.action,
    required this.why,
    required this.study,
  });
}

class WhatIfScreen extends ConsumerStatefulWidget {
  const WhatIfScreen({super.key});

  @override
  ConsumerState<WhatIfScreen> createState() => _WhatIfScreenState();
}

class _WhatIfScreenState extends ConsumerState<WhatIfScreen> {
  String? _toast;
  final TextEditingController _customInputController = TextEditingController();
  bool _chatExpanded = false;
  final List<ChatMessage> _messages = [];
  final TextEditingController _chatInputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;
  
  // Custom goals state
  List<GoalData> _customGoals = [];
  bool _loadingCustomGoals = true;
  
  // Preset mode selection
  String _selectedPreset = 'habit-master'; // Default to 'habit-master'

  @override
  void initState() {
    super.initState();
    _loadCustomGoals();
  }

  Future<void> _loadCustomGoals() async {
    try {
      final response = await ApiClient.getPurposeAlignedGoals();
      if (response.success && response.data != null) {
        final goals = response.data!['goals'] as List? ?? [];
        setState(() {
          _customGoals = goals.map((goal) {
            return GoalData(
              id: goal['title'].hashCode,
              title: goal['title'],
              subtitle: goal['subtitle'],
              icon: goal['icon'],
              plan: (goal['plan'] as List).map((step) {
                return PlanStep(
                  action: step['action'],
                  why: step['why'],
                  study: step['study'],
                );
              }).toList(),
            );
          }).toList();
          _loadingCustomGoals = false;
        });
      } else {
        setState(() => _loadingCustomGoals = false);
      }
    } catch (e) {
      debugPrint('No custom goals available: $e');
      setState(() => _loadingCustomGoals = false);
    }
  }

  final List<GoalData> _goals = [
    GoalData(
      id: 1,
      title: 'Smoother Skin',
      subtitle: 'Natural anti-aging',
      icon: '✨',
      plan: [
        PlanStep(action: 'SPF 50+ daily AM', why: 'Prevents 80% of aging', study: 'Dermatology Research 2021'),
        PlanStep(action: 'Retinol 0.3% 3x/week PM', why: 'Boosts collagen 47%', study: 'Stanford Medicine 2020'),
        PlanStep(action: 'Vitamin C serum AM', why: 'Brightens & protects', study: 'Skin Science 2022'),
        PlanStep(action: 'Hydrate 2.5L daily', why: 'Improves elasticity 40%', study: 'NIH 2022'),
        PlanStep(action: 'Omega-3 with meals', why: 'Reduces inflammation', study: 'Harvard Nutrition 2021'),
        PlanStep(action: 'Niacinamide serum PM', why: 'Minimizes pores', study: 'Clinical Derm 2021'),
        PlanStep(action: 'Silk pillowcase', why: 'Reduces friction wrinkles', study: 'Sleep Dermatology 2020'),
      ],
    ),
    GoalData(
      id: 2,
      title: 'Get In Shape',
      subtitle: 'Lean & strong',
      icon: '💪',
      plan: [
        PlanStep(action: 'Strength train 4x/week', why: 'Builds lean muscle', study: 'Exercise Science 2021'),
        PlanStep(action: '10k steps minimum daily', why: 'Burns 300-500 cal', study: 'Activity Research 2022'),
        PlanStep(action: 'Protein 1g per lb bodyweight', why: 'Muscle synthesis', study: 'Nutrition Journal 2020'),
        PlanStep(action: 'HIIT cardio 2x/week', why: 'Max fat burn', study: 'Metabolism 2021'),
        PlanStep(action: 'Sleep 7-9 hours', why: 'Recovery & growth hormone', study: 'Sleep & Exercise 2022'),
        PlanStep(action: 'Track calories in app', why: '64% better results', study: 'Behavioral Science 2020'),
        PlanStep(action: 'Meal prep Sundays', why: 'Consistency wins', study: 'Habit Formation 2021'),
      ],
    ),
    GoalData(
      id: 3,
      title: 'Lose 20kg',
      subtitle: 'Sustainable fat loss',
      icon: '📉',
      plan: [
        PlanStep(action: '500 cal deficit daily', why: '1kg/week safely', study: 'Weight Loss Meta 2021'),
        PlanStep(action: 'High protein breakfast 30g+', why: '60% less cravings', study: 'Metabolism 2022'),
        PlanStep(action: '30min movement daily', why: 'Preserves muscle', study: 'Exercise Phys 2020'),
        PlanStep(action: '500ml water before meals', why: '13% less intake', study: 'Obesity Research 2021'),
        PlanStep(action: 'Cut liquid calories', why: '400 cal/day saved', study: 'Nutrition Science 2022'),
        PlanStep(action: 'Strength train 3x/week', why: 'Maintains metabolism', study: 'Body Comp 2020'),
        PlanStep(action: 'Weigh daily, track weekly avg', why: 'Data beats emotion', study: 'Weight Mgmt 2021'),
        PlanStep(action: 'Sleep 7+ hours', why: 'Poor sleep = 30% more hunger', study: 'Sleep & Appetite 2022'),
      ],
    ),
    GoalData(
      id: 4,
      title: 'More Energy',
      subtitle: 'All-day vitality',
      icon: '⚡',
      plan: [
        PlanStep(action: '10min morning sun 6-8am', why: 'Anchors circadian', study: 'Sleep Medicine 2022'),
        PlanStep(action: 'No sugar after 2pm', why: 'Stabilizes afternoon', study: 'Glycemic Control 2021'),
        PlanStep(action: 'Magnesium glycinate 400mg', why: 'ATP production', study: 'Energy Metabolism 2020'),
        PlanStep(action: 'Cold shower 30sec finish', why: 'Boosts mitochondria', study: 'Cold Exposure 2021'),
        PlanStep(action: 'B-complex AM', why: 'Energy conversion', study: 'Nutrition Research 2022'),
        PlanStep(action: 'No caffeine after 2pm', why: 'Protects sleep quality', study: 'Caffeine Studies 2020'),
      ],
    ),
    GoalData(
      id: 5,
      title: 'Build Muscle',
      subtitle: 'Pack on size',
      icon: '🏋️',
      plan: [
        PlanStep(action: 'Progressive overload 4-5x/week', why: 'Triggers hypertrophy', study: 'Strength Science 2021'),
        PlanStep(action: '300-500 cal surplus daily', why: 'Building materials', study: 'Muscle Growth 2022'),
        PlanStep(action: 'Protein 1.6g per kg', why: 'Optimal synthesis', study: 'Protein Research 2020'),
        PlanStep(action: '8-9 hours sleep', why: 'Growth hormone peaks', study: 'Sleep & Recovery 2020'),
        PlanStep(action: 'Creatine 5g daily', why: '8-15% more strength', study: 'Sports Science 2021'),
        PlanStep(action: 'Train each muscle 2x/week', why: 'Higher frequency growth', study: 'Hypertrophy 2022'),
        PlanStep(action: 'Carbs around workouts', why: 'Fuels performance', study: 'Exercise Nutrition 2021'),
      ],
    ),
    GoalData(
      id: 6,
      title: 'Better Sleep',
      subtitle: 'Deep rest',
      icon: '🌙',
      plan: [
        PlanStep(action: 'Same bedtime daily ±30min', why: 'Trains rhythm', study: 'Sleep Foundation 2022'),
        PlanStep(action: 'Dim lights 2hrs before', why: '2x melatonin', study: 'Circadian Research 2021'),
        PlanStep(action: 'Cool room 18°C (65°F)', why: 'Optimal deep sleep', study: 'Sleep Medicine 2020'),
        PlanStep(action: 'Magnesium threonate 200mg', why: 'Crosses brain barrier', study: 'Neuroscience 2022'),
        PlanStep(action: 'No screens 1hr before', why: 'Blue light blocks', study: 'Digital Health 2021'),
        PlanStep(action: 'Blackout curtains/mask', why: 'Darkness = quality', study: 'Sleep Environment 2020'),
      ],
    ),
    GoalData(
      id: 7,
      title: 'Save £10k',
      subtitle: 'Build wealth fast',
      icon: '💰',
      plan: [
        PlanStep(action: 'Auto-save £192/week', why: 'Removes willpower', study: 'Behavioral Econ 2021'),
        PlanStep(action: 'Track every expense', why: '23% more saving', study: 'Personal Finance 2022'),
        PlanStep(action: 'One no-spend day/week', why: 'Builds impulse control', study: 'Habit Formation 2020'),
        PlanStep(action: 'Cancel unused subscriptions', why: '£640/yr wasted avg', study: 'Consumer Research 2023'),
        PlanStep(action: '30-day rule for £50+ purchases', why: 'Kills impulse buys', study: 'Spending Behavior 2021'),
        PlanStep(action: 'Cook 5 nights/week', why: 'Saves £200+ monthly', study: 'Budget Studies 2022'),
      ],
    ),
    GoalData(
      id: 8,
      title: 'Clear Skin',
      subtitle: 'Acne-free',
      icon: '🌟',
      plan: [
        PlanStep(action: 'Gentle cleanser 2x daily', why: 'Removes bacteria', study: 'Dermatology 2021'),
        PlanStep(action: 'Niacinamide 10% serum', why: '30% less sebum', study: 'Skin Research 2022'),
        PlanStep(action: 'Change pillowcase 2x/week', why: 'Prevents transfer', study: 'Acne Studies 2020'),
        PlanStep(action: 'Salicylic acid spot treat', why: 'Unclogs pores', study: 'Clinical Derm 2021'),
        PlanStep(action: 'Dairy-free 30 days trial', why: '47% acne link', study: 'Nutrition & Skin 2022'),
        PlanStep(action: 'Zinc supplement 30mg', why: '50% less lesions', study: 'Derm Research 2020'),
      ],
    ),
    GoalData(
      id: 9,
      title: 'Stop Procrastinating',
      subtitle: 'Get things done',
      icon: '🎯',
      plan: [
        PlanStep(action: '2-min rule: if <2min do now', why: 'Beats activation energy', study: 'Atomic Habits'),
        PlanStep(action: 'Pomodoro 25min blocks', why: '40% more focus', study: 'Productivity 2021'),
        PlanStep(action: 'Phone in another room', why: '#1 distraction gone', study: 'Digital Wellness 2022'),
        PlanStep(action: 'Plan tomorrow tonight', why: 'Kills decision fatigue', study: 'Cognitive Science 2020'),
        PlanStep(action: 'Eat frog: hardest first', why: 'Willpower highest AM', study: 'Psychology Today 2021'),
        PlanStep(action: 'Block calendar deep work', why: 'Protects focus time', study: 'Time Management 2022'),
      ],
    ),
    GoalData(
      id: 10,
      title: 'Read 30+ Books',
      subtitle: 'Become smarter',
      icon: '📚',
      plan: [
        PlanStep(action: '20 pages before bed', why: '30+ books/year', study: 'Habit Formation 2021'),
        PlanStep(action: 'Always carry book', why: 'Fill dead time', study: 'Time Management 2020'),
        PlanStep(action: 'Kindle on phone', why: 'Read anywhere', study: 'Reading Behavior 2022'),
        PlanStep(action: 'Join book club', why: 'Social pressure works', study: 'Group Dynamics 2021'),
        PlanStep(action: 'Set Goodreads goal', why: '42% more achievement', study: 'Goal Psychology 2020'),
      ],
    ),
    GoalData(
      id: 11,
      title: 'Quit Smoking',
      subtitle: 'Break free',
      icon: '🚭',
      plan: [
        PlanStep(action: 'Nicotine replacement (patch/gum)', why: '2x success rate', study: 'Addiction Medicine 2021'),
        PlanStep(action: 'Avoid triggers 30 days', why: 'Breaks associations', study: 'Behavioral Science 2022'),
        PlanStep(action: 'New ritual replacement', why: 'Fills habit void', study: 'Habit Research 2020'),
        PlanStep(action: 'Tell everyone quit date', why: 'Public commitment', study: 'Social Psychology 2021'),
        PlanStep(action: 'QuitSure app', why: 'Daily support', study: 'Digital Interventions 2022'),
        PlanStep(action: 'Calculate money saved daily', why: 'Visual motivation', study: 'Behavioral Econ 2020'),
      ],
    ),
    GoalData(
      id: 12,
      title: 'Learn Language',
      subtitle: 'Fluent in months',
      icon: '🗣️',
      plan: [
        PlanStep(action: 'Duolingo 15min daily', why: 'Spaced repetition', study: 'Language Acquisition 2021'),
        PlanStep(action: 'Shows with subtitles', why: '45% better comprehension', study: 'Linguistics 2022'),
        PlanStep(action: 'iTalki tutor 2x/week 30min', why: 'Real conversation', study: 'Language Learning 2020'),
        PlanStep(action: 'Anki flashcards daily', why: 'Active recall king', study: 'Memory Research 2021'),
        PlanStep(action: 'Think in target language 5min', why: 'Builds neural paths', study: 'Cognitive Science 2022'),
        PlanStep(action: 'Change phone language', why: 'Immersion accelerates', study: 'Applied Linguistics 2020'),
      ],
    ),
  ];

  @override
  void dispose() {
    _customInputController.dispose();
    _chatInputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _showToast(String message) {
    setState(() => _toast = message);
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _toast = null);
    });
  }

  Future<void> _commitGoal(GoalData goal) async {
    try {
      // Build title with ALL micro goals (all action steps with bullet points)
      final microGoals = goal.plan.map((step) => '• ${step.action}').join('\n');
      final fullTitle = '${goal.title}\n$microGoals';
      
      // Create habit using HabitEngine
      await ref.read(habitEngineProvider).createHabit(
        title: fullTitle,
        type: 'habit',
        time: '07:00',
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 21)),
        repeatDays: [1, 2, 3, 4, 5, 6, 0], // All days for 21-day commitment
        color: AppColors.emerald,
        emoji: goal.icon,
        reminderOn: false,
      );

      _showToast('💚 ${goal.title} committed for 21 days!');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to commit: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _sendChatMessage() async {
    final message = _chatInputController.text.trim();
    if (message.isEmpty) return;

    // 🔒 PAYWALL: Let backend handle premium check, show paywall on 402 error
    // Removed frontend premium check - backend will return 402 if not premium

    final userMessage = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      role: 'user',
      text: message,
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.add(userMessage);
      _isLoading = true;
      _chatInputController.clear();
    });

    _scrollToBottom();

    try {
      // Use new What-If implementation coach (context-aware + citations)
      // Pass selected preset to backend for appropriate system prompt
      final result = await ApiClient.sendWhatIfMessage(
        message,
        preset: _selectedPreset,
      );

      if (result.success && result.data != null) {
        final aiMessage = result.data!['message'] as String;
        final suggestedPlan = result.data!['suggestedPlan'];
        final splitFutureCard = result.data!['splitFutureCard'] as String?;
        final sources = result.data!['sources'] as List?;
        final outputCard = result.data!['outputCard']; // NEW!
        final habits = result.data!['habits'] as List?; // NEW!

        final responseMessage = ChatMessage(
          id: (DateTime.now().millisecondsSinceEpoch + 1).toString(),
          role: 'future',
          text: aiMessage,
          timestamp: DateTime.now(),
        );

        setState(() {
          _messages.add(responseMessage);
          
          // If AI generated OUTPUT CARD, add it as a special card message! (NEW!)
          if (outputCard != null && outputCard is Map) {
            debugPrint('🎯 FRONTEND: Creating card message with ${(outputCard as Map).keys.toList()}');
            _messages.add(ChatMessage(
              id: (DateTime.now().millisecondsSinceEpoch + 2).toString(),
              role: 'card',
              text: 'Output Card',
              timestamp: DateTime.now(),
              outputCard: Map<String, dynamic>.from(outputCard as Map),
              habits: habits,
            ));
            debugPrint('🎯 FRONTEND: Card message added, total messages: ${_messages.length}');
          } else {
            debugPrint('🎯 FRONTEND: No outputCard found - outputCard: $outputCard, habits: $habits');
          }
          
          // 🔥 FALLBACK: If response is long and contains "Locked", force show as card
          if (outputCard == null && aiMessage.length > 1000 && (aiMessage.contains('Locked') || aiMessage.contains('THE TWO FUTURES') || aiMessage.contains('PHASE 1'))) {
            _messages.add(ChatMessage(
              id: (DateTime.now().millisecondsSinceEpoch + 2).toString(),
              role: 'card',
              text: 'Output Card',
              timestamp: DateTime.now(),
              outputCard: {
                'title': _selectedPreset == 'simulator' ? 'What-If Simulation' : 'Habit Master Plan',
                'sections': [{'type': 'content', 'content': aiMessage}],
              },
              habits: habits,
            ));
          }
          
          _isLoading = false;
        });

        // Fallback: If AI generated a plan (legacy), show it as dialog
        if (outputCard == null && suggestedPlan != null && suggestedPlan is Map) {
          _showSuggestedPlanCard(Map<String, dynamic>.from(suggestedPlan as Map));
        }
      } else {
        setState(() => _isLoading = false);
        if (!mounted) return;
        
        // Check if it's a paywall error
        if (result.error?.contains('Premium') == true || result.error?.contains('premium') == true) {
          Navigator.of(context).push(
            MaterialPageRoute(
              fullscreenDialog: true,
              builder: (context) => const PremiumPaywallScreen(feature: 'What If Engine'),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.error ?? 'Chat failed'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint('❌ Chat error: $e');
      
      // Check if it's a premium error in the exception message
      if (mounted && e.toString().toLowerCase().contains('premium')) {
        Navigator.of(context).push(
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (context) => const PremiumPaywallScreen(feature: 'What If Engine'),
          ),
        );
      }
    }

    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showSuggestedPlanCard(Map<String, dynamic> plan) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF0F1F0F),
                Colors.black,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.emerald.withOpacity(0.3), width: 2),
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: AppColors.emeraldGradient,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(22),
                    topRight: Radius.circular(22),
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      plan['icon'] ?? '🎯',
                      style: const TextStyle(fontSize: 32),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            plan['title'] ?? 'Your Plan',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: Colors.black,
                            ),
                          ),
                          Text(
                            plan['subtitle'] ?? 'Science-backed steps',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Plan steps
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: (plan['plan'] as List?)?.length ?? 0,
                  itemBuilder: (context, index) {
                    final step = (plan['plan'] as List)[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.emerald.withOpacity(0.2),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppColors.emerald.withOpacity(0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(
                                    '${index + 1}',
                                    style: const TextStyle(
                                      color: AppColors.emerald,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    step['action'] ?? '',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '💡 ${step['why'] ?? ''}',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '📚 ${step['study'] ?? ''}',
                              style: TextStyle(
                                color: AppColors.emerald.withOpacity(0.8),
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Commit button
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text(
                          'Not Yet',
                          style: TextStyle(color: AppColors.textTertiary),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _commitPlanFromChat(plan);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.emerald,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Commit This Plan 🔥',
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _commitPlanFromChat(Map<String, dynamic> plan) async {
    try {
      // Extract plan details
      final title = plan['title'] ?? 'AI-Generated Plan';
      final steps = plan['steps'] as List? ?? [];
      
      // Build full title with all action steps (like presets do)
      final microGoals = steps.map((step) => '• ${step['action']}').join('\n');
      final fullTitle = '$title\n$microGoals';
      
      // Determine duration from plan or default to 21 days
      final durationStr = plan['duration_estimate'] ?? '21 days';
      final durationDays = _parseDurationDays(durationStr);
      
      // Create habit using HabitEngine (same as preset goals)
      await ref.read(habitEngineProvider).createHabit(
        title: fullTitle,
        type: 'habit',
        time: '07:00',
        startDate: DateTime.now(),
        endDate: DateTime.now().add(Duration(days: durationDays)),
        repeatDays: [1, 2, 3, 4, 5, 6, 0], // All days
        color: AppColors.emerald,
        emoji: '🎯', // Default emoji for AI plans
        reminderOn: false,
      );

      _showToast('💚 $title committed for $durationDays days!');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to commit: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  // Helper to parse duration string to days
  int _parseDurationDays(String durationStr) {
    final match = RegExp(r'(\d+)').firstMatch(durationStr);
    return match != null ? int.parse(match.group(1)!) : 21;
  }

  // NEW: Show beautiful OUTPUT CARD from GPT-5!
  void _showOutputCard(Map<String, dynamic> card, List<dynamic>? habits) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF0F1F0F),
                Colors.black,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.emerald.withOpacity(0.3), width: 2),
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: AppColors.emeraldGradient,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(22),
                    topRight: Radius.circular(22),
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      _selectedPreset == 'simulator' ? '🌗' : '🧩',
                      style: const TextStyle(fontSize: 32),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        card['title'] ?? 'Your Future Simulation',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Card content (all sections)
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Summary
                      if (card['summary'] != null) ...[
                        Text(
                          card['summary'],
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 15,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Sections (timelines, comparison, explanation, commit card, quote, etc.)
                      ...((card['sections'] as List?) ?? []).map((section) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 20),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.emerald.withOpacity(0.2),
                              ),
                            ),
                            child: SelectableText(
                              section['content'] ?? '',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.85),
                                fontSize: 14,
                                height: 1.6,
                              ),
                            ),
                          ),
                        );
                      }).toList(),

                      // Habits to commit (if any)
                      if (habits != null && habits.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text(
                          '🎯 HABITS TO COMMIT',
                          style: TextStyle(
                            color: AppColors.emerald,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...habits.map((habit) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.emerald.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: AppColors.emerald.withOpacity(0.3),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    habit['emoji'] ?? '✅',
                                    style: const TextStyle(fontSize: 20),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          habit['title'] ?? '',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                          ),
                                        ),
                                        if (habit['frequency'] != null)
                                          Text(
                                            habit['frequency'],
                                            style: TextStyle(
                                              color: Colors.white.withOpacity(0.6),
                                              fontSize: 12,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ],

                      // Sources (if any)
                      if (card['sources'] != null && (card['sources'] as List).isNotEmpty) ...[
                        const SizedBox(height: 20),
                        Text(
                          '📚 SOURCES CITED',
                          style: TextStyle(
                            color: AppColors.emerald,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          (card['sources'] as List).join(' • '),
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // Action buttons
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text(
                          'Not Yet',
                          style: TextStyle(color: AppColors.textTertiary),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (habits != null && habits.isNotEmpty)
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            _commitHabitsFromCard(habits);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.emerald,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Commit Habits 🔥',
                            style: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // NEW: Commit habits from OUTPUT CARD
  Future<void> _commitHabitsFromCard(List<dynamic> habits) async {
    if (habits.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('No habits to commit'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }

    try {
      int successCount = 0;
      for (final habit in habits) {
        final title = habit['title'] ?? '';
        if (title.isEmpty) continue;

        final emoji = habit['emoji'] ?? '✅';
        final time = habit['time'] ?? '07:00';
        final frequency = habit['frequency'] ?? 'Daily';
        
        // Parse frequency to repeatDays (simple version - all days for now)
        final repeatDays = [1, 2, 3, 4, 5, 6, 0]; // Daily
        
        await ref.read(habitEngineProvider).createHabit(
          title: title,
          type: 'habit',
          time: time,
          startDate: DateTime.now(),
          endDate: DateTime.now().add(const Duration(days: 90)), // 90 days default
          repeatDays: repeatDays,
          color: AppColors.emerald,
          emoji: emoji,
          reminderOn: false,
        );
        successCount++;
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Successfully committed $successCount habit${successCount > 1 ? 's' : ''}!'),
            backgroundColor: AppColors.emerald,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to commit: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  // ✅ Save card to Habit Vault (local-first)
  Future<void> _saveCardToVault(Map<String, dynamic> card, List<dynamic>? habits) async {
    try {
      // Import at top of file
      final vaultItem = HabitVaultItem.fromWhatIfCard(
        card: card,
        habits: habits,
      );
      
      final success = await HabitVaultService.saveItem(vaultItem);
      
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('💾 Saved to Habit Vault! Check Habit Master tab.'),
            backgroundColor: AppColors.emerald,
            duration: const Duration(seconds: 3),
          ),
        );
      } else if (mounted) {
        throw Exception('Failed to save');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  // NEW: Copy card to clipboard
  void _copyCardToClipboard(Map<String, dynamic> card) {
    final buffer = StringBuffer();
    buffer.writeln(card['title'] ?? 'Your Simulation');
    buffer.writeln('');
    
    if (card['summary'] != null) {
      buffer.writeln(card['summary']);
      buffer.writeln('');
    }
    
    for (var section in (card['sections'] as List? ?? [])) {
      buffer.writeln(section['content'] ?? '');
      buffer.writeln('');
    }
    
    if (card['sources'] != null && (card['sources'] as List).isNotEmpty) {
      buffer.writeln('Sources: ${(card['sources'] as List).join(', ')}');
    }
    
    Clipboard.setData(ClipboardData(text: buffer.toString()));
    _showToast('📋 Copied to clipboard!');
  }

  void _startCustomChat() {
    final customGoal = _customInputController.text.trim();
    if (customGoal.isEmpty) return;

    final userMessage = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      role: 'user',
      text: 'What if I $customGoal?',
      timestamp: DateTime.now(),
    );

    final aiResponse = ChatMessage(
      id: (DateTime.now().millisecondsSinceEpoch + 1).toString(),
      role: 'future',
      text: 'Interesting goal! Let\'s break this down. What does success look like to you in 3 months?',
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.add(userMessage);
      _messages.add(aiResponse);
      _customInputController.clear();
      _chatExpanded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Main content with scrollable header
          CustomScrollView(
            slivers: [
              // Header that disappears when scrolling
              SliverAppBar(
                expandedHeight: 80,
                floating: true,
                snap: true,
                pinned: false,
                backgroundColor: Colors.transparent,
                elevation: 0,
                flexibleSpace: const SimpleHeader(),
              ),
              // Content
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Simple title section
                        Row(
                          children: [
                            Icon(LucideIcons.sparkles, color: AppColors.emerald, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Habit Library · Science-Backed Goals',
                              style: AppTextStyles.caption.copyWith(color: AppColors.textTertiary),
                            ),
                          ],
                        ).animate().fadeIn(duration: 400.ms),
                        
                        const SizedBox(height: 8),
                        
                        ShaderMask(
                          shaderCallback: (bounds) => LinearGradient(
                            colors: [AppColors.emerald, AppColors.emerald.withOpacity(0.7)],
                          ).createShader(bounds),
                          child: const Text(
                            'Research-Backed Habit Systems',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                        ).animate().fadeIn(duration: 600.ms, delay: 100.ms).slideY(begin: 0.1, end: 0),
                        
                        const SizedBox(height: 8),
                        
                        Text(
                          'Pick a goal. Get a detailed plan backed by research from Harvard, Stanford, NIH. One-click commit.',
                          style: AppTextStyles.body.copyWith(
                            color: AppColors.textTertiary,
                            height: 1.5,
                          ),
                        ).animate().fadeIn(duration: 600.ms, delay: 200.ms),
                        
                        const SizedBox(height: AppSpacing.xl),
                        
                        // Custom goals section
                        if (_customGoals.isNotEmpty) ...[
                          _buildCustomGoalsSection(),
                          const SizedBox(height: AppSpacing.xl),
                        ],
                        // Preset goals header
                        _buildPresetsHeader(),
                        const SizedBox(height: AppSpacing.lg),
                        _buildGoalsGrid(),
                        const SizedBox(height: 150), // Bottom padding for nav
                      ],
                    ),
                  ),
                ),
            ],
          ),

          // Toast
          if (_toast != null) _buildToast(),

          // Chat is now a separate full-screen route (no overlay)
        ],
      ),
    );
  }

  Widget _buildHeroSection() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppBorderRadius.xxl),
        gradient: LinearGradient(
          colors: [
            AppColors.emerald.withOpacity(0.1),
            AppColors.emerald.withOpacity(0.05),
            Colors.transparent,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: AppColors.emerald.withOpacity(0.2),
        ),
      ),
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: AppColors.emerald.withOpacity(0.2),
              borderRadius: BorderRadius.circular(AppBorderRadius.full),
              border: Border.all(
                color: AppColors.emerald.withOpacity(0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  LucideIcons.sparkles,
                  size: 16,
                  color: AppColors.emerald,
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'Science-Backed Goals',
                  style: AppTextStyles.captionSmall.copyWith(
                    color: AppColors.emerald,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'What if you actually achieved it?',
            style: AppTextStyles.h1.copyWith(
              fontSize: 32,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Pick a goal. Get a detailed plan backed by research from Harvard, Stanford, NIH. One-click commit.',
            style: AppTextStyles.body.copyWith(
              color: AppColors.textTertiary,
              height: 1.5,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildCustomGoalInput() {
    return Column(
      children: [
        // AI What-If Simulator Button
        GestureDetector(
          onTap: () async {
            // ✅ PAYWALL: Check premium status before allowing simulator
            final isPremium = await PremiumService.isPremium();
            if (!isPremium) {
              if (mounted) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    fullscreenDialog: true,
                    builder: (context) => const PremiumPaywallScreen(feature: 'What If Simulator'),
                  ),
                );
              }
              return;
            }
            
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => _WhatIfChatScreen(
                  preset: 'simulator',
                  messages: _messages,
                ),
              ),
            );
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.xl),
            decoration: BoxDecoration(
              gradient: AppColors.emeraldGradient,
              borderRadius: BorderRadius.circular(AppBorderRadius.xl),
              boxShadow: [
                BoxShadow(
                  color: AppColors.emerald.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(AppBorderRadius.md),
                  ),
                  child: const Text(
                    '🔮',
                    style: TextStyle(fontSize: 32),
                  ),
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AI What-If Simulator',
                        style: AppTextStyles.h3.copyWith(
                          color: Colors.black,
                          fontWeight: FontWeight.w900,
                          fontSize: 20,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'See both futures → Choose wisely',
                        style: AppTextStyles.caption.copyWith(
                          color: Colors.black87,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  LucideIcons.chevronRight,
                  color: Colors.black,
                  size: 28,
                ),
              ],
            ),
          ),
        ).animate(delay: 200.ms).fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0),
        
        const SizedBox(height: AppSpacing.lg),
        
        // AI Habit Master Button
        GestureDetector(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => _WhatIfChatScreen(
                  preset: 'habit-master',
                  messages: _messages,
                ),
              ),
            );
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.xl),
            decoration: BoxDecoration(
              gradient: AppColors.emeraldGradient,
              borderRadius: BorderRadius.circular(AppBorderRadius.xl),
              boxShadow: [
                BoxShadow(
                  color: AppColors.emerald.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(AppBorderRadius.md),
                  ),
                  child: const Text(
                    '🧩',
                    style: TextStyle(fontSize: 32),
                  ),
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AI Habit Master',
                        style: AppTextStyles.h3.copyWith(
                          color: Colors.black,
                          fontWeight: FontWeight.w900,
                          fontSize: 20,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Science-backed habit implementation',
                        style: AppTextStyles.caption.copyWith(
                          color: Colors.black87,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  LucideIcons.chevronRight,
                  color: Colors.black,
                  size: 28,
                ),
              ],
            ),
          ),
        ).animate(delay: 300.ms).fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0),
      ],
    );
  }

  Widget _buildCustomGoalsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: AppColors.emeraldGradient,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(LucideIcons.target, size: 24, color: Colors.black),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Goals Aligned With Your Purpose',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: AppColors.emerald,
                    ),
                  ),
                  Text(
                    'AI-generated based on your discovery',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Display custom goals
        ..._customGoals.map((goal) => Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: _buildGoalCard(goal, isCustom: true),
        )),
      ],
    );
  }

  Widget _buildPresetsHeader() {
    return Row(
      children: [
        const Icon(LucideIcons.bookOpen, size: 20, color: AppColors.emerald),
        const SizedBox(width: 8),
        Text(
          'Science-Backed Classics',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildGoalsGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 1,
        childAspectRatio: 0.75,
        mainAxisSpacing: AppSpacing.lg,
        crossAxisSpacing: AppSpacing.lg,
      ),
      itemCount: _goals.length,
      itemBuilder: (context, index) {
        final goal = _goals[index];
        return _buildGoalCard(goal, index: index);
      },
    );
  }

  Widget _buildGoalCard(GoalData goal, {int? index, bool isCustom = false}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(AppBorderRadius.xl),
        border: Border.all(
          color: AppColors.emerald.withOpacity(0.2),
        ),
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(goal.icon, style: const TextStyle(fontSize: 40)),
          const SizedBox(height: AppSpacing.md),
          Text(
            goal.title,
            style: AppTextStyles.h3.copyWith(
              fontSize: 20,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            goal.subtitle,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.emerald.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Expanded(
            child: ListView.builder(
              itemCount: goal.plan.length,
              itemBuilder: (context, i) {
                final step = goal.plan[i];
                return Container(
                  margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(AppBorderRadius.md),
                    border: Border.all(
                      color: AppColors.emerald.withOpacity(0.2),
                    ),
                  ),
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: AppColors.emerald.withOpacity(0.2),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.emerald.withOpacity(0.4),
                          ),
                        ),
                        child: Center(
                          child: Text(
                            '${i + 1}',
                            style: AppTextStyles.captionSmall.copyWith(
                              color: AppColors.emerald,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              step.action,
                              style: AppTextStyles.caption.copyWith(
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              step.why,
                              style: AppTextStyles.captionSmall.copyWith(
                                color: AppColors.emerald.withOpacity(0.6),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                const Icon(
                                  LucideIcons.bookOpen,
                                  size: 10,
                                  color: AppColors.emerald,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    step.study,
                                    style: const TextStyle(
                                      fontSize: 9,
                                      color: AppColors.emerald,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _commitGoal(goal),
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      gradient: AppColors.emeraldGradient,
                      borderRadius: BorderRadius.circular(AppBorderRadius.md),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.emerald.withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Text(
                      '💚 Commit 21d',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              GestureDetector(
                onTap: () {
                  final promptMsg = ChatMessage(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    role: 'user',
                    text: 'Tell me more about: ${goal.title}',
                    timestamp: DateTime.now(),
                  );
                  final aiReply = ChatMessage(
                    id: (DateTime.now().millisecondsSinceEpoch + 1).toString(),
                    role: 'future',
                    text: 'Let\'s explore ${goal.title}. What\'s your main motivation for this goal?',
                    timestamp: DateTime.now(),
                  );
                  setState(() {
                    _messages.add(promptMsg);
                    _messages.add(aiReply);
                    _chatExpanded = true;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(AppBorderRadius.md),
                    border: Border.all(
                      color: AppColors.emerald.withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    'Chat',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.emerald,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate(delay: ((index ?? 0) * 100).ms).fadeIn(duration: 400.ms).scale(begin: const Offset(0.95, 0.95));
  }

  Widget _buildToast() {
    return Positioned(
      bottom: 140,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.95),
            borderRadius: BorderRadius.circular(AppBorderRadius.xl),
            border: Border.all(
              color: AppColors.emerald.withOpacity(0.4),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.emerald.withOpacity(0.2),
                blurRadius: 20,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.emerald,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Text(
                _toast!,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.2, end: 0),
      ),
    );
  }

  Widget _buildChatOverlay() {
    return Container(
      color: Colors.black,
      child: Stack(
        children: [
          // Scrollable content (header + messages)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            bottom: 140, // Space for input at bottom
            child: CustomScrollView(
              controller: _scrollController,
              slivers: [
                // Scrollable Header
                SliverAppBar(
                  expandedHeight: 140, // Header + Preset buttons height
                  floating: true,
                  snap: true,
                  pinned: false,
                  backgroundColor: const Color(0xFF18181B),
                  elevation: 0,
                  automaticallyImplyLeading: false,
                  flexibleSpace: FlexibleSpaceBar(
                    background: SafeArea(
                      child: Column(
                        children: [
                          // Header
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.lg,
                              vertical: AppSpacing.md,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF18181B),
                              border: Border(
                                bottom: BorderSide(
                                  color: AppColors.emerald.withOpacity(0.2),
                                ),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Goal Exploration',
                                      style: AppTextStyles.h3.copyWith(fontSize: 18),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${_messages.where((m) => m.role == 'user').length} messages',
                                      style: AppTextStyles.captionSmall.copyWith(
                                        color: AppColors.textTertiary,
                                      ),
                                    ),
                                  ],
                                ),
                                IconButton(
                                  onPressed: () => setState(() => _chatExpanded = false),
                                  icon: const Icon(
                                    LucideIcons.x,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Preset Buttons
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.lg,
                              vertical: AppSpacing.md,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF18181B),
                              border: Border(
                                bottom: BorderSide(
                                  color: AppColors.emerald.withOpacity(0.1),
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: _buildPresetButton(
                                    label: '🔮 What-If Simulator',
                                    preset: 'simulator',
                                    selected: _selectedPreset == 'simulator',
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.md),
                                Expanded(
                                  child: _buildPresetButton(
                                    label: '🧩 Habit Master',
                                    preset: 'habit-master',
                                    selected: _selectedPreset == 'habit-master',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Messages
                SliverPadding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final message = _messages[index];
                        return _buildMessageBubble(message);
                      },
                      childCount: _messages.length,
                    ),
                  ),
                ),

                // Loading indicator as a sliver
                if (_isLoading)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: AppSpacing.sm,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.glassBackground,
                              borderRadius: BorderRadius.circular(AppBorderRadius.lg),
                              border: Border.all(
                                color: AppColors.emerald.withOpacity(0.2),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      AppColors.emerald,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Text(
                                  'Thinking...',
                                  style: AppTextStyles.caption.copyWith(
                                    color: AppColors.textTertiary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Bottom padding for input field
                const SliverToBoxAdapter(
                  child: SizedBox(height: 100),
                ),
              ],
            ),
          ),

          // Input (moves with keyboard, nav stays fixed)
          Positioned(
            left: 0,
            right: 0,
            bottom: MediaQuery.of(context).viewInsets.bottom, // Rises with keyboard
            child: Container(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                140, // Extra space above nav tabs
              ),
              decoration: BoxDecoration(
                color: const Color(0xFF18181B),
                border: Border(
                  top: BorderSide(
                    color: AppColors.emerald.withOpacity(0.2),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.glassBackground,
                        borderRadius: BorderRadius.circular(AppBorderRadius.xl),
                        border: Border.all(
                          color: AppColors.emerald.withOpacity(0.2),
                        ),
                      ),
                      child: TextField(
                        controller: _chatInputController,
                        style: AppTextStyles.body,
                        maxLines: null,
                        decoration: InputDecoration(
                          hintText: 'Tell me more...',
                          hintStyle: AppTextStyles.body.copyWith(
                            color: AppColors.textQuaternary,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.all(AppSpacing.md),
                        ),
                        onSubmitted: (_) => _sendChatMessage(),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  GestureDetector(
                    onTap: _sendChatMessage,
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: AppColors.emeraldGradient,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.emerald.withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        LucideIcons.send,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }

  Widget _buildMessageBubble(ChatMessage message) {
    debugPrint('🎨 FRONTEND: Building message bubble - role: ${message.role}, hasOutputCard: ${message.outputCard != null}');
    
    // Special rendering for OUTPUT CARDS!
    if (message.role == 'card' && message.outputCard != null) {
      debugPrint('🎨 FRONTEND: Rendering output card with sections: ${message.outputCard!['sections']?.length ?? 0}');
      return _buildInlineOutputCard(message.outputCard!, message.habits);
    }
    
    final isUser = message.role == 'user';

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          Flexible(
            child: isUser
                ? Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      gradient: AppColors.emeraldGradient,
                      borderRadius: BorderRadius.circular(AppBorderRadius.lg),
                      border: Border.all(
                        color: AppColors.emerald.withOpacity(0.3),
                      ),
                    ),
                    child: SelectableText(
                      message.text,
                      style: AppTextStyles.body.copyWith(
                        color: Colors.black,
                      ),
                    ),
                  )
                : SelectableText(
                    message.text,
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // NEW: Beautiful inline output card (stays in chat!)
  Widget _buildInlineOutputCard(Map<String, dynamic> card, List<dynamic>? habits) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF0F1F0F),
              Colors.black,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.emerald.withOpacity(0.3), width: 2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: AppColors.emeraldGradient,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(22),
                  topRight: Radius.circular(22),
                ),
              ),
              child: Row(
                children: [
                  Text(
                    _selectedPreset == 'simulator' ? '🌗' : '🧩',
                    style: const TextStyle(fontSize: 32),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      card['title'] ?? 'Your Future Simulation',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Card content
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Summary
                  if (card['summary'] != null) ...[
                    SelectableText(
                      card['summary'],
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 15,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Sections
                  ...((card['sections'] as List?) ?? []).map((section) {
                    final content = section['content'] ?? '';
                    final sectionType = section['type'] ?? ''; // 🔥 Backend sends 'type' not 'title'!
                    
                    // Check if this is chart/comparison data (contains pipes |)
                    final isChartData = content.contains('|') && content.split('\n').length > 2;
                    
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Chart data = horizontal scroll
                          if (isChartData)
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppColors.emerald.withOpacity(0.2),
                                ),
                              ),
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.all(16),
                                child: SelectableText(
                                  content,
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.85),
                                    fontSize: 13,
                                    height: 1.8,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ),
                            )
                          else
                            // Regular text = normal box
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppColors.emerald.withOpacity(0.2),
                                ),
                              ),
                              child: SelectableText(
                                content,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.85),
                                  fontSize: 14,
                                  height: 1.6,
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  }).toList(),

                  // Habits
                  if (habits != null && habits.isNotEmpty) ...[
                    Text(
                      '🎯 HABITS TO COMMIT',
                      style: TextStyle(
                        color: AppColors.emerald,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...habits.map((habit) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.emerald.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppColors.emerald.withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              Text(
                                habit['emoji'] ?? '✅',
                                style: const TextStyle(fontSize: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      habit['title'] ?? '',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                    if (habit['frequency'] != null)
                                      Text(
                                        habit['frequency'],
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.6),
                                          fontSize: 12,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                    const SizedBox(height: 16),
                  ],

                  // Sources
                  if (card['sources'] != null && (card['sources'] as List).isNotEmpty) ...[
                    Text(
                      '📚 SOURCES CITED',
                      style: TextStyle(
                        color: AppColors.emerald,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SelectableText(
                      (card['sources'] as List).join(' • '),
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Action buttons (3 buttons: Vault, Copy, Commit)
                  Row(
                    children: [
                      // Save to Vault button
                      Expanded(
                        child: TextButton(
                          onPressed: () => _saveCardToVault(card, habits),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            backgroundColor: AppColors.emerald.withOpacity(0.1),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            '💾 Vault',
                            style: TextStyle(
                              color: AppColors.emerald,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Copy button
                      Expanded(
                        child: TextButton(
                          onPressed: () => _copyCardToClipboard(card),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            backgroundColor: Colors.white.withOpacity(0.05),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            '📋 Copy',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Commit Habits button (only if habits exist)
                      if (habits != null && habits.isNotEmpty)
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: () => _commitHabitsFromCard(habits),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.emerald,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Commit 🔥',
                              style: TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPresetButton({
    required String label,
    required String preset,
    required bool selected,
  }) {
    return GestureDetector(
      onTap: () {
        setState(() {
          if (_selectedPreset != preset) {
            // Switching presets - clear conversation history
            _selectedPreset = preset;
            _messages.clear();
            
            // Add welcome message based on preset
            final welcomeMessage = preset == 'simulator'
                ? "I'm the Future-You Simulator. I'll help you see both timelines — what happens if you commit vs. if you stay the same. What goal are you considering?"
                : "I'm the Habit Master. I'll help you build this habit with science-backed strategies. What habit do you want to implement?";
            
            _messages.add(ChatMessage(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              text: welcomeMessage,
              role: 'assistant',
              timestamp: DateTime.now(),
            ));
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          gradient: selected
              ? AppColors.emeraldGradient
              : null,
          color: selected
              ? null
              : AppColors.glassBackground,
          borderRadius: BorderRadius.circular(AppBorderRadius.lg),
          border: Border.all(
            color: selected
                ? AppColors.emerald
                : AppColors.glassBorder,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: AppTextStyles.captionSmall.copyWith(
                color: selected
                    ? Colors.white
                    : AppColors.textSecondary,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// Full-screen What-If Chat Screen (no bottom nav!)
class _WhatIfChatScreen extends StatefulWidget {
  final String preset;
  final List<ChatMessage> messages;

  const _WhatIfChatScreen({
    required this.preset,
    required this.messages,
  });

  @override
  State<_WhatIfChatScreen> createState() => _WhatIfChatScreenState();
}

class _WhatIfChatScreenState extends State<_WhatIfChatScreen> {
  final _chatInputController = TextEditingController();
  final _scrollController = ScrollController();
  late List<ChatMessage> _messages;
  late String _selectedPreset;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _messages = List.from(widget.messages);
    _selectedPreset = widget.preset;
    
    // Add welcome message if no messages yet
    if (_messages.isEmpty) {
      final welcomeMessages = {
        'simulator': '🔮 **What-If Simulator**\n\nI\'m your personal future-simulator, powered by the latest behavioral science and health studies.\n\nI\'ll ask you sharp questions about your goal, training, sleep, diet, and timeline—then show you **two futures**: one where you stay the same, and one where you commit fully.\n\nLet\'s start. **What goal or change are you exploring?** (e.g., "build muscle," "more energy," "lose fat")',
        'habit-master': '🧩 **Habit Master**\n\nI\'m your behavioral architect, trained on implementation science from Fogg, Clear, Duhigg, and decades of habit research.\n\nI\'ll understand your reality (schedule, energy, environment), then design a **3-phase plan** that removes friction, builds momentum, and creates lasting change—backed by studies and real proof.\n\n**What habit or goal are you trying to build?** Be specific.',
      };
      
      _messages.add(ChatMessage(
        id: 'welcome',
        role: 'assistant',
        text: welcomeMessages[_selectedPreset] ?? welcomeMessages['habit-master']!,
        timestamp: DateTime.now(),
      ));
    }
  }

  @override
  void dispose() {
    _chatInputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendChatMessage() async {
    final text = _chatInputController.text.trim();
    if (text.isEmpty || _isLoading) return;

    // ✅ PAYWALL: Check premium status before allowing simulator chat
    final isPremium = await PremiumService.isPremium();
    if (!isPremium) {
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (context) => const PremiumPaywallScreen(feature: 'What If Simulator'),
          ),
        );
      }
      return;
    }

    final userMessage = ChatMessage(
      id: DateTime.now().toString(),
      role: 'user',
      text: text,
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.add(userMessage);
      _isLoading = true;
    });

    _chatInputController.clear();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 200,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });

    try {
      final response = await ApiClient.sendWhatIfMessage(
        text,
        preset: _selectedPreset,
      );

      if (response.success && response.data != null) {
        final aiMessage = ChatMessage(
          id: DateTime.now().toString(),
          role: response.data!['role'] ?? 'assistant',
          text: response.data!['message'] ?? '',
          timestamp: DateTime.now(),
          outputCard: response.data!['outputCard'],
          habits: response.data!['habits'],
        );

        setState(() {
          _messages.add(aiMessage);
          _isLoading = false;
        });

        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent + 200,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        });
      } else {
        throw Exception(response.error ?? 'Unknown error');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send message: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    
    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: false, // We handle keyboard manually
      body: SafeArea(
        child: Stack(
          children: [
            // Content
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              bottom: 80 + keyboardHeight, // Adjust for keyboard!
              child: CustomScrollView(
                controller: _scrollController,
                slivers: [
                  // Header with back button
                  SliverAppBar(
                    expandedHeight: 140,
                    floating: true,
                    snap: true,
                    pinned: false,
                    backgroundColor: const Color(0xFF18181B),
                    elevation: 0,
                    leading: IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(LucideIcons.arrowLeft, color: AppColors.textPrimary),
                    ),
                    flexibleSpace: FlexibleSpaceBar(
                      background: Column(
                        children: [
                          // Header
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.lg,
                              vertical: AppSpacing.md,
                            ),
                            margin: const EdgeInsets.only(top: 50),
                            decoration: BoxDecoration(
                              color: const Color(0xFF18181B),
                              border: Border(
                                bottom: BorderSide(
                                  color: AppColors.emerald.withOpacity(0.2),
                                ),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Goal Exploration',
                                        style: AppTextStyles.h3.copyWith(fontSize: 18),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${_messages.where((m) => m.role == 'user').length} messages',
                                        style: AppTextStyles.captionSmall.copyWith(
                                          color: AppColors.textTertiary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Preset Buttons
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.lg,
                              vertical: AppSpacing.md,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF18181B),
                              border: Border(
                                bottom: BorderSide(
                                  color: AppColors.emerald.withOpacity(0.1),
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: _buildPresetButton(
                                    label: '🔮 What-If Simulator',
                                    preset: 'simulator',
                                    selected: _selectedPreset == 'simulator',
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.md),
                                Expanded(
                                  child: _buildPresetButton(
                                    label: '🧩 Habit Master',
                                    preset: 'habit-master',
                                    selected: _selectedPreset == 'habit-master',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Messages
                  SliverPadding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final message = _messages[index];
                          return _buildMessageBubble(message);
                        },
                        childCount: _messages.length,
                      ),
                    ),
                  ),

                  // Loading indicator
                  if (_isLoading)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(AppSpacing.md),
                              decoration: BoxDecoration(
                                color: AppColors.glassBackground,
                                borderRadius: BorderRadius.circular(AppBorderRadius.lg),
                                border: Border.all(
                                  color: AppColors.emerald.withOpacity(0.2),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    width: 12,
                                    height: 12,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.emerald),
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
                                  Text(
                                    'Thinking...',
                                    style: AppTextStyles.caption.copyWith(
                                      color: AppColors.textTertiary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Bottom padding
                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
              ),
            ),

            // Input (rises with keyboard, NO bottom nav!)
            Positioned(
              left: 0,
              right: 0,
              bottom: MediaQuery.of(context).viewInsets.bottom,
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: const Color(0xFF18181B),
                  border: Border(
                    top: BorderSide(color: AppColors.emerald.withOpacity(0.2)),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.glassBackground,
                          borderRadius: BorderRadius.circular(AppBorderRadius.xl),
                          border: Border.all(
                            color: AppColors.emerald.withOpacity(0.2),
                          ),
                        ),
                        child: TextField(
                          controller: _chatInputController,
                          style: AppTextStyles.body,
                          maxLines: null,
                          decoration: InputDecoration(
                            hintText: 'Tell me more...',
                            hintStyle: AppTextStyles.body.copyWith(
                              color: AppColors.textQuaternary,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.all(AppSpacing.md),
                          ),
                          onSubmitted: (_) => _sendChatMessage(),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    GestureDetector(
                      onTap: _sendChatMessage,
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: AppColors.emeraldGradient,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.emerald.withOpacity(0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          LucideIcons.send,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPresetButton({required String label, required String preset, required bool selected}) {
    return GestureDetector(
      onTap: () => setState(() => _selectedPreset = preset),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.emerald.withOpacity(0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppBorderRadius.lg),
          border: Border.all(
            color: selected
                ? AppColors.emerald
                : AppColors.glassBorder,
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.captionSmall.copyWith(
            color: selected ? Colors.white : AppColors.textSecondary,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    if (message.role == 'card' && message.outputCard != null) {
      // Reuse the inline output card from parent
      return _buildInlineOutputCard(message.outputCard!, message.habits);
    }
    
    final isUser = message.role == 'user';
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          Flexible(
            child: isUser
                ? Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      gradient: AppColors.emeraldGradient,
                      borderRadius: BorderRadius.circular(AppBorderRadius.lg),
                      border: Border.all(
                        color: AppColors.emerald.withOpacity(0.3),
                      ),
                    ),
                    child: SelectableText(
                      message.text,
                      style: AppTextStyles.body.copyWith(
                        color: Colors.black,
                      ),
                    ),
                  )
                : SelectableText(
                    message.text,
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // Copy the inline output card method from parent (simplified for now)
  Widget _buildInlineOutputCard(Map<String, dynamic> card, List<dynamic>? habits) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [const Color(0xFF0F1F0F), Colors.black],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.emerald.withOpacity(0.3), width: 2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: AppColors.emeraldGradient,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(22),
                  topRight: Radius.circular(22),
                ),
              ),
              child: Text(
                card['title'] ?? 'Your Simulation',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: Colors.black,
                ),
              ),
            ),
            // Content (simplified - just show summary)
            Padding(
              padding: const EdgeInsets.all(20),
              child: SelectableText(
                card['summary'] ?? card['title'] ?? 'Generated simulation',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 15,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


