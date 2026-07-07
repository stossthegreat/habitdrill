import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';

import '../../design/tokens.dart';
import '../../providers/habit_provider.dart';
import 'onboarding_state.dart';
import 'onboarding_paywall.dart';

class OnboardingFlow extends ConsumerStatefulWidget {
  const OnboardingFlow({super.key});

  @override
  ConsumerState<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends ConsumerState<OnboardingFlow> {
  final PageController _pc = PageController();
  final OnboardingState _s = OnboardingState();
  int _i = 0;

  static const int _total = 21;

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  void _next() {
    HapticFeedback.selectionClick();
    if (_i < _total - 1) {
      _pc.nextPage(duration: const Duration(milliseconds: 380), curve: Curves.easeOutCubic);
    } else {
      _finishOnboarding();
    }
  }

  void _back() {
    if (_i == 0) return;
    HapticFeedback.selectionClick();
    _pc.previousPage(duration: const Duration(milliseconds: 320), curve: Curves.easeOutCubic);
  }

  void _finishOnboarding() {
    // Route to paywall FIRST. Don't await anything — a slow createHabit
    // or a permission-prompt hang was hiding the paywall on some devices.
    // Habit creation is fire-and-forget in the background. If the user
    // grants notification permission, alarms schedule for their next
    // wake time. If they deny, the paywall still shows and they can
    // fix perms in Settings later.
    final wakeTimeStr =
        '${_s.wakeTime.hour.toString().padLeft(2, '0')}:${_s.wakeTime.minute.toString().padLeft(2, '0')}';
    Future(() async {
      try {
        await ref.read(habitEngineProvider).createHabit(
              title: 'Morning Rise',
              type: 'habit',
              time: wakeTimeStr,
              startDate: DateTime.now(),
              endDate: DateTime.now().add(const Duration(days: 365)),
              repeatDays: const [0, 1, 2, 3, 4, 5, 6],
              reminderOn: true,
              color: AppColors.emerald,
              emoji: '☀️',
            );
      } catch (e) {
        debugPrint('Morning Rise habit creation failed: $e');
      }
    });
    // NOTE: seen_onboarding is set inside OnboardingPaywall._goHome, so
    // closing the app mid-paywall means they see it again on next launch.
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => OnboardingPaywall(state: _s)),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      body: SafeArea(
        child: Column(
          children: [
            _ProgressBar(current: _i + 1, total: _total, onBack: _i == 0 ? null : _back),
            Expanded(
              child: PageView(
                controller: _pc,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _i = i),
                children: [
                  _ColdOpen(onNext: _next),
                  _Welcome(onNext: _next),
                  _FirstBattle(onNext: _next),
                  _SinglePick(
                    key: const ValueKey('gender'),
                    title: 'You are',
                    subtitle: 'This just helps us calibrate.',
                    options: const ['Male', 'Female', 'Prefer not to say'],
                    initial: _s.gender,
                    onPicked: (v) => _s.gender = v,
                    onNext: _next,
                  ),
                  _AgePicker(state: _s, onNext: _next),
                  _SinglePick(
                    key: const ValueKey('source'),
                    title: 'How did you find HabitDrill?',
                    subtitle: 'Real answers help us reach more people like you.',
                    options: const ['TikTok', 'Instagram', 'YouTube', 'App Store', 'Friend', 'Google', 'Other'],
                    initial: _s.source,
                    onPicked: (v) => _s.source = v,
                    onNext: _next,
                  ),
                  _SinglePick(
                    key: const ValueKey('habit'),
                    title: 'What do you want to fix first?',
                    subtitle: 'Pick the one that costs you the most.',
                    options: const [
                      'Wake up on time',
                      'Exercise consistently',
                      'Stop procrastinating',
                      'Reduce phone use',
                      'Build discipline',
                      'Other',
                    ],
                    initial: _s.habitToFix,
                    onPicked: (v) => _s.habitToFix = v,
                    onNext: _next,
                  ),
                  _SinglePick(
                    key: const ValueKey('struggle'),
                    title: 'How long have you struggled with this?',
                    options: const [
                      'Less than 1 month',
                      '1–6 months',
                      '1 year',
                      'Several years',
                      'As long as I can remember',
                    ],
                    initial: _s.struggleDuration,
                    onPicked: (v) => _s.struggleDuration = v,
                    onNext: _next,
                  ),
                  _SinglePick(
                    key: const ValueKey('fail'),
                    title: 'What usually breaks you?',
                    options: const [
                      'Lack of motivation',
                      'I keep making excuses',
                      'I procrastinate',
                      'I quit after a few days',
                      'I forget',
                      'Other',
                    ],
                    initial: _s.failCause,
                    onPicked: (v) => _s.failCause = v,
                    onNext: _next,
                  ),
                  _SinglePick(
                    key: const ValueKey('breakfreq'),
                    title: 'How often do you break promises to yourself?',
                    options: const ['Rarely', 'Sometimes', 'Often', 'Almost every day'],
                    initial: _s.breakFrequency,
                    onPicked: (v) => _s.breakFrequency = v,
                    onNext: _next,
                  ),
                  _SliderScreen(
                    key: const ValueKey('frustration'),
                    title: 'How frustrated are you with yourself?',
                    lowLabel: 'Not really',
                    highLabel: 'Really frustrated',
                    initial: _s.frustration,
                    onChanged: (v) => _s.frustration = v,
                    onNext: _next,
                  ),
                  _SliderScreen(
                    key: const ValueKey('importance'),
                    title: 'How important is fixing this?',
                    lowLabel: 'Whatever',
                    highLabel: 'Life-changing',
                    initial: _s.importance,
                    onChanged: (v) => _s.importance = v,
                    onNext: _next,
                  ),
                  _StatementScreen(
                    key: const ValueKey('identity1'),
                    line1: "Discipline isn't something",
                    line2: "you're born with.",
                    line3: "It's something you train.",
                    onNext: _next,
                  ),
                  _WakeTimePicker(state: _s, onNext: _next),
                  _ExercisePicker(state: _s, onNext: _next),
                  _RepsPicker(state: _s, onNext: _next),
                  _EscalationWarning(reps: _s.reps, onNext: _next),
                  _StatementScreen(
                    key: const ValueKey('commit'),
                    line1: 'No more backup alarms.',
                    line2: 'No more excuses.',
                    line3: 'No more "tomorrow."',
                    onNext: _next,
                    ctaLabel: 'I AGREE',
                  ),
                  _SignatureScreen(state: _s, onNext: _next),
                  _BuildingPlan(onNext: _next),
                  _SummaryScreen(state: _s, onNext: _next),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ────────────────────────── Progress bar ──────────────────────────

class _ProgressBar extends StatelessWidget {
  final int current;
  final int total;
  final VoidCallback? onBack;

  const _ProgressBar({required this.current, required this.total, this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: onBack != null
                ? IconButton(
                    icon: Icon(CupertinoIcons.chevron_back, color: Colors.white.withOpacity(0.7), size: 22),
                    onPressed: onBack,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  )
                : const SizedBox.shrink(),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 420),
                curve: Curves.easeOutCubic,
                tween: Tween(begin: 0, end: current / total),
                builder: (context, v, _) => Stack(
                  children: [
                    Container(height: 4, color: Colors.white.withOpacity(0.08)),
                    FractionallySizedBox(
                      widthFactor: v,
                      child: Container(
                        height: 4,
                        decoration: BoxDecoration(
                          gradient: AppColors.emeraldGradient,
                          boxShadow: [BoxShadow(color: AppColors.emerald.withOpacity(0.5), blurRadius: 8)],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 40,
            child: Text(
              '$current/$total',
              textAlign: TextAlign.right,
              style: TextStyle(
                color: Colors.white.withOpacity(0.4),
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────── Shared primitives ──────────────────────────

class _PrimaryButton extends StatelessWidget {
  final String label;
  final bool enabled;
  final VoidCallback onTap;
  final Color? color;
  const _PrimaryButton({required this.label, this.enabled = true, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          gradient: enabled ? (color == null ? AppColors.emeraldGradient : null) : null,
          color: enabled ? color : const Color(0xFF141414),
          borderRadius: BorderRadius.circular(16),
          boxShadow: enabled
              ? [BoxShadow(color: (color ?? AppColors.emerald).withOpacity(0.35), blurRadius: 22, offset: const Offset(0, 8))]
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: enabled ? Colors.black : Colors.white.withOpacity(0.3),
            fontSize: 14,
            fontWeight: FontWeight.w900,
            letterSpacing: 3,
          ),
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  final String title;
  final String? subtitle;
  const _Hero({required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
            height: 1.15,
          ),
        ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.05, end: 0),
        if (subtitle != null) ...[
          const SizedBox(height: 10),
          Text(
            subtitle!,
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 14,
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
          ).animate(delay: 100.ms).fadeIn(duration: 300.ms),
        ],
      ],
    );
  }
}

class _AnswerCard extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _AnswerCard({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        decoration: BoxDecoration(
          color: selected ? AppColors.emerald.withOpacity(0.13) : const Color(0xFF0B0B0B),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.emerald : Colors.white.withOpacity(0.06),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : Colors.white.withOpacity(0.85),
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: selected ? AppColors.emerald : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? AppColors.emerald : Colors.white.withOpacity(0.25),
                  width: 1.5,
                ),
              ),
              child: selected
                  ? const Icon(Icons.check, color: Colors.black, size: 14)
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

// ────────────────────────── SCREEN 0: Cold open ──────────────────────────

class _ColdOpen extends StatefulWidget {
  final VoidCallback onNext;
  const _ColdOpen({required this.onNext});
  @override
  State<_ColdOpen> createState() => _ColdOpenState();
}

class _ColdOpenState extends State<_ColdOpen> {
  VideoPlayerController? _vc;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      _vc = VideoPlayerController.asset('assets/images/sergeant_intro.mp4');
      await _vc!.initialize();
      _vc!.setLooping(false);
      _vc!.setVolume(1.0);
      _vc!.play();
      if (mounted) setState(() => _ready = true);
    } catch (_) {
      if (mounted) setState(() => _ready = false);
    }
  }

  @override
  void dispose() {
    _vc?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (_ready && _vc != null)
          Center(
            child: AspectRatio(
              aspectRatio: _vc!.value.aspectRatio == 0 ? 9 / 16 : _vc!.value.aspectRatio,
              child: VideoPlayer(_vc!),
            ),
          )
        else
          const _ColdOpenFallback(),
        // Subtle bottom gradient so the button stays legible over the video.
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.center,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black.withOpacity(0.75)],
              ),
            ),
          ),
        ),
        Positioned(
          left: 24,
          right: 24,
          bottom: 40,
          child: _PrimaryButton(label: 'BEGIN', onTap: widget.onNext)
              .animate(delay: 800.ms)
              .fadeIn(duration: 500.ms)
              .slideY(begin: 0.2, end: 0),
        ),
      ],
    );
  }
}

class _ColdOpenFallback extends StatelessWidget {
  const _ColdOpenFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "You've broken",
              style: TextStyle(
                color: Colors.white.withOpacity(0.85),
                fontSize: 30,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ).animate().fadeIn(duration: 600.ms),
            const SizedBox(height: 8),
            Text(
              'enough promises.',
              style: TextStyle(
                color: Colors.white.withOpacity(0.85),
                fontSize: 30,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ).animate(delay: 500.ms).fadeIn(duration: 600.ms),
            const SizedBox(height: 30),
            Text(
              'That ends today.',
              style: TextStyle(
                color: AppColors.emerald,
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
              ),
            ).animate(delay: 1400.ms).fadeIn(duration: 600.ms),
          ],
        ),
      ),
    );
  }
}

// ────────────────────────── SCREEN 1: Welcome ──────────────────────────

class _Welcome extends StatelessWidget {
  final VoidCallback onNext;
  const _Welcome({required this.onNext});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Spacer(),
          Text(
            'Welcome to',
            style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 22, fontWeight: FontWeight.w800),
          ).animate().fadeIn(duration: 400.ms),
          const SizedBox(height: 4),
          const Text(
            'HABITDRILL.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 44,
              fontWeight: FontWeight.w900,
              letterSpacing: 3,
              height: 1,
            ),
          ).animate(delay: 100.ms).fadeIn(duration: 500.ms).slideY(begin: 0.1, end: 0),
          const SizedBox(height: 24),
          Container(
            width: 60,
            height: 3,
            decoration: BoxDecoration(
              color: AppColors.emerald,
              borderRadius: BorderRadius.circular(2),
              boxShadow: [BoxShadow(color: AppColors.emerald.withOpacity(0.5), blurRadius: 12)],
            ),
          ).animate(delay: 300.ms).fadeIn(),
          const SizedBox(height: 24),
          Text(
            'The app that makes',
            style: TextStyle(
              color: Colors.white.withOpacity(0.85),
              fontSize: 22,
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
          ).animate(delay: 400.ms).fadeIn(),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: 'quitting ',
                  style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 22, fontWeight: FontWeight.w600),
                ),
                const TextSpan(
                  text: 'harder',
                  style: TextStyle(color: AppColors.emerald, fontSize: 22, fontWeight: FontWeight.w900),
                ),
                TextSpan(
                  text: ' than',
                  style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 22, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ).animate(delay: 500.ms).fadeIn(),
          Text(
            'succeeding.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.85),
              fontSize: 22,
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
          ).animate(delay: 600.ms).fadeIn(),
          const Spacer(),
          _PrimaryButton(label: 'CONTINUE', onTap: onNext).animate(delay: 800.ms).fadeIn(),
        ],
      ),
    );
  }
}

// ────────────────────────── Single-pick screen ──────────────────────────

class _SinglePick extends StatefulWidget {
  final String title;
  final String? subtitle;
  final List<String> options;
  final String? initial;
  final ValueChanged<String> onPicked;
  final VoidCallback onNext;

  const _SinglePick({
    super.key,
    required this.title,
    this.subtitle,
    required this.options,
    this.initial,
    required this.onPicked,
    required this.onNext,
  });

  @override
  State<_SinglePick> createState() => _SinglePickState();
}

class _SinglePickState extends State<_SinglePick> {
  String? _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initial;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Hero(title: widget.title, subtitle: widget.subtitle),
          const SizedBox(height: 28),
          Expanded(
            child: ListView.separated(
              itemCount: widget.options.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) => _AnswerCard(
                label: widget.options[i],
                selected: _selected == widget.options[i],
                onTap: () => setState(() => _selected = widget.options[i]),
              ).animate(delay: (60 + i * 40).ms).fadeIn(duration: 250.ms).slideX(begin: 0.04, end: 0),
            ),
          ),
          const SizedBox(height: 16),
          _PrimaryButton(
            label: 'CONTINUE',
            enabled: _selected != null,
            onTap: () {
              widget.onPicked(_selected!);
              widget.onNext();
            },
          ),
        ],
      ),
    );
  }
}

// ────────────────────────── SCREEN 3: Age ──────────────────────────

class _AgePicker extends StatefulWidget {
  final OnboardingState state;
  final VoidCallback onNext;
  const _AgePicker({required this.state, required this.onNext});

  @override
  State<_AgePicker> createState() => _AgePickerState();
}

class _AgePickerState extends State<_AgePicker> {
  int _age = 25;
  late FixedExtentScrollController _ctrl;

  @override
  void initState() {
    super.initState();
    _age = widget.state.age ?? 25;
    _ctrl = FixedExtentScrollController(initialItem: _age - 13);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Hero(title: 'How old are you?', subtitle: 'We tune your streaks around this.'),
          const SizedBox(height: 30),
          Expanded(
            child: Center(
              child: SizedBox(
                height: 260,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      height: 60,
                      decoration: BoxDecoration(
                        border: Border.symmetric(
                          horizontal: BorderSide(color: Colors.white.withOpacity(0.08)),
                        ),
                      ),
                    ),
                    CupertinoPicker(
                      scrollController: _ctrl,
                      itemExtent: 60,
                      diameterRatio: 1.5,
                      magnification: 1.1,
                      squeeze: 1.1,
                      selectionOverlay: const SizedBox.shrink(),
                      onSelectedItemChanged: (i) {
                        HapticFeedback.selectionClick();
                        setState(() => _age = i + 13);
                      },
                      children: List.generate(88, (i) {
                        final age = i + 13;
                        return Center(
                          child: Text(
                            '$age',
                            style: TextStyle(
                              color: age == _age ? AppColors.emerald : Colors.white.withOpacity(0.55),
                              fontSize: age == _age ? 44 : 30,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _PrimaryButton(
            label: 'CONTINUE',
            onTap: () {
              widget.state.age = _age;
              widget.onNext();
            },
          ),
        ],
      ),
    );
  }
}

// ────────────────────────── Slider screen ──────────────────────────

class _SliderScreen extends StatefulWidget {
  final String title;
  final String lowLabel;
  final String highLabel;
  final double initial;
  final ValueChanged<double> onChanged;
  final VoidCallback onNext;

  const _SliderScreen({
    super.key,
    required this.title,
    required this.lowLabel,
    required this.highLabel,
    required this.initial,
    required this.onChanged,
    required this.onNext,
  });

  @override
  State<_SliderScreen> createState() => _SliderScreenState();
}

class _SliderScreenState extends State<_SliderScreen> {
  late double _v;

  @override
  void initState() {
    super.initState();
    _v = widget.initial;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Hero(title: widget.title),
          const Spacer(),
          Center(
            child: Text(
              '${(_v * 100).round()}',
              style: const TextStyle(
                color: AppColors.emerald,
                fontSize: 96,
                fontWeight: FontWeight.w900,
                letterSpacing: -2,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(height: 16),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 6,
              activeTrackColor: AppColors.emerald,
              inactiveTrackColor: Colors.white.withOpacity(0.08),
              thumbColor: Colors.white,
              overlayColor: AppColors.emerald.withOpacity(0.15),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
            ),
            child: Slider(
              value: _v,
              onChanged: (v) {
                HapticFeedback.selectionClick();
                setState(() => _v = v);
              },
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.lowLabel,
                style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1),
              ),
              Text(
                widget.highLabel,
                style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1),
              ),
            ],
          ),
          const Spacer(),
          _PrimaryButton(
            label: 'CONTINUE',
            onTap: () {
              widget.onChanged(_v);
              widget.onNext();
            },
          ),
        ],
      ),
    );
  }
}

// ────────────────────────── Statement screen ──────────────────────────

class _StatementScreen extends StatelessWidget {
  final String line1;
  final String line2;
  final String? line3;
  final VoidCallback onNext;
  final String ctaLabel;

  const _StatementScreen({
    super.key,
    required this.line1,
    required this.line2,
    this.line3,
    required this.onNext,
    this.ctaLabel = 'CONTINUE',
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Spacer(flex: 2),
          Container(
            width: 40,
            height: 3,
            decoration: BoxDecoration(
              color: AppColors.emerald,
              borderRadius: BorderRadius.circular(2),
              boxShadow: [BoxShadow(color: AppColors.emerald.withOpacity(0.55), blurRadius: 12)],
            ),
          ).animate().fadeIn().slideX(begin: -0.05, end: 0),
          const SizedBox(height: 22),
          Text(
            line1,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
              height: 1.2,
            ),
          ).animate(delay: 200.ms).fadeIn(duration: 500.ms).slideY(begin: 0.05, end: 0),
          const SizedBox(height: 6),
          Text(
            line2,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
              height: 1.2,
            ),
          ).animate(delay: 400.ms).fadeIn(duration: 500.ms).slideY(begin: 0.05, end: 0),
          if (line3 != null) ...[
            const SizedBox(height: 6),
            Text(
              line3!,
              style: TextStyle(
                color: AppColors.emerald,
                fontSize: 32,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
                height: 1.2,
                shadows: [Shadow(color: AppColors.emerald.withOpacity(0.5), blurRadius: 18)],
              ),
            ).animate(delay: 600.ms).fadeIn(duration: 500.ms).slideY(begin: 0.05, end: 0),
          ],
          const Spacer(flex: 3),
          _PrimaryButton(label: ctaLabel, onTap: onNext).animate(delay: 900.ms).fadeIn(),
        ],
      ),
    );
  }
}

// ────────────────────────── Wake time picker ──────────────────────────

class _WakeTimePicker extends StatefulWidget {
  final OnboardingState state;
  final VoidCallback onNext;
  const _WakeTimePicker({required this.state, required this.onNext});

  @override
  State<_WakeTimePicker> createState() => _WakeTimePickerState();
}

class _WakeTimePickerState extends State<_WakeTimePicker> {
  late DateTime _dt;

  @override
  void initState() {
    super.initState();
    final t = widget.state.wakeTime;
    _dt = DateTime(2025, 1, 1, t.hour, t.minute);
  }

  @override
  Widget build(BuildContext context) {
    final h12 = _dt.hour == 0 ? 12 : (_dt.hour > 12 ? _dt.hour - 12 : _dt.hour);
    final ampm = _dt.hour < 12 ? 'AM' : 'PM';
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Hero(
            title: 'Set your alarm.',
            subtitle: 'This is when we come after you.',
          ),
          const SizedBox(height: 20),
          // Live preview — huge digital clock face
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.emerald.withOpacity(0.18), AppColors.emerald.withOpacity(0.02)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.emerald.withOpacity(0.4), width: 1.5),
              boxShadow: [BoxShadow(color: AppColors.emerald.withOpacity(0.2), blurRadius: 30, spreadRadius: -8)],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      h12.toString(),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 84,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -4,
                        height: 1,
                        fontFeatures: const [FontFeature.tabularFigures()],
                        shadows: [Shadow(color: AppColors.emerald.withOpacity(0.5), blurRadius: 24)],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(
                        ':',
                        style: TextStyle(
                          color: AppColors.emerald,
                          fontSize: 64,
                          fontWeight: FontWeight.w900,
                          height: 1,
                        ),
                      ),
                    ),
                    Text(
                      _dt.minute.toString().padLeft(2, '0'),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 84,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -4,
                        height: 1,
                        fontFeatures: const [FontFeature.tabularFigures()],
                        shadows: [Shadow(color: AppColors.emerald.withOpacity(0.5), blurRadius: 24)],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 18),
                      child: Text(
                        ampm,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 3,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.shield_rounded, size: 12, color: AppColors.emerald.withOpacity(0.85)),
                    const SizedBox(width: 6),
                    Text(
                      'PROTECTED — RINGS THROUGH FOCUS',
                      style: TextStyle(
                        color: AppColors.emerald.withOpacity(0.85),
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: CupertinoTheme(
              data: const CupertinoThemeData(
                brightness: Brightness.dark,
                primaryColor: AppColors.emerald,
                textTheme: CupertinoTextThemeData(
                  dateTimePickerTextStyle: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.time,
                initialDateTime: _dt,
                use24hFormat: false,
                onDateTimeChanged: (dt) {
                  HapticFeedback.selectionClick();
                  setState(() => _dt = dt);
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
          _PrimaryButton(
            label: 'ARM MY ALARM',
            onTap: () {
              widget.state.wakeTime = TimeOfDay(hour: _dt.hour, minute: _dt.minute);
              widget.onNext();
            },
          ),
        ],
      ),
    );
  }
}

// ────────────────────────── Exercise picker ──────────────────────────

class _ExercisePicker extends StatefulWidget {
  final OnboardingState state;
  final VoidCallback onNext;
  const _ExercisePicker({required this.state, required this.onNext});

  @override
  State<_ExercisePicker> createState() => _ExercisePickerState();
}

class _ExercisePickerState extends State<_ExercisePicker> {
  late String _picked;

  static const List<(String id, String name, String emoji)> _options = [
    ('push_ups', 'Push Ups', '💪'),
    ('squats', 'Squats', '🦵'),
    ('burpees', 'Burpees', '🔥'),
    ('high_knees', 'High Knees', '🏃'),
  ];

  @override
  void initState() {
    super.initState();
    _picked = widget.state.exerciseId;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Hero(
            title: 'Choose your morning punishment.',
            subtitle: 'This is what dismisses your alarm.',
          ),
          const SizedBox(height: 24),
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.05,
              children: [
                for (int i = 0; i < _options.length; i++)
                  _ExerciseCard(
                    emoji: _options[i].$3,
                    name: _options[i].$2,
                    selected: _picked == _options[i].$1,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _picked = _options[i].$1);
                    },
                  ).animate(delay: (100 + i * 60).ms).fadeIn(duration: 300.ms).scale(begin: const Offset(0.95, 0.95), end: const Offset(1, 1)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _PrimaryButton(
            label: 'CONTINUE',
            onTap: () {
              final o = _options.firstWhere((x) => x.$1 == _picked);
              widget.state.exerciseId = o.$1;
              widget.state.exerciseName = o.$2;
              widget.onNext();
            },
          ),
        ],
      ),
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  final String emoji;
  final String name;
  final bool selected;
  final VoidCallback onTap;
  const _ExerciseCard({required this.emoji, required this.name, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: selected ? AppColors.emerald.withOpacity(0.14) : const Color(0xFF0B0B0B),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.emerald : Colors.white.withOpacity(0.06),
            width: selected ? 1.5 : 1,
          ),
          boxShadow: selected
              ? [BoxShadow(color: AppColors.emerald.withOpacity(0.28), blurRadius: 22, offset: const Offset(0, 6))]
              : null,
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 44, height: 1)),
            const SizedBox(height: 12),
            Text(
              name.toUpperCase(),
              style: TextStyle(
                color: selected ? Colors.white : Colors.white.withOpacity(0.85),
                fontSize: 13,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ────────────────────────── Reps picker ──────────────────────────

class _RepsPicker extends StatefulWidget {
  final OnboardingState state;
  final VoidCallback onNext;
  const _RepsPicker({required this.state, required this.onNext});

  @override
  State<_RepsPicker> createState() => _RepsPickerState();
}

class _RepsPickerState extends State<_RepsPicker> {
  late int _picked;
  static const List<int> _options = [5, 10, 15, 20];

  @override
  void initState() {
    super.initState();
    _picked = widget.state.reps;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Hero(
            title: 'How many reps to dismiss?',
            subtitle: '${widget.state.exerciseName} — pick your minimum.',
          ),
          const Spacer(),
          Center(
            child: Text(
              '$_picked',
              style: const TextStyle(
                color: AppColors.emerald,
                fontSize: 120,
                fontWeight: FontWeight.w900,
                letterSpacing: -4,
                height: 1,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Center(
            child: Text(
              'REPS',
              style: TextStyle(
                color: Colors.white.withOpacity(0.4),
                fontSize: 13,
                fontWeight: FontWeight.w900,
                letterSpacing: 5,
              ),
            ),
          ),
          const Spacer(),
          Row(
            children: [
              for (int i = 0; i < _options.length; i++)
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: i < _options.length - 1 ? 8 : 0),
                    child: _RepChip(
                      value: _options[i],
                      selected: _picked == _options[i],
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _picked = _options[i]);
                      },
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          _PrimaryButton(
            label: 'CONTINUE',
            onTap: () {
              widget.state.reps = _picked;
              widget.onNext();
            },
          ),
        ],
      ),
    );
  }
}

class _RepChip extends StatelessWidget {
  final int value;
  final bool selected;
  final VoidCallback onTap;
  const _RepChip({required this.value, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: selected ? AppColors.emerald.withOpacity(0.14) : const Color(0xFF0B0B0B),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.emerald : Colors.white.withOpacity(0.06),
            width: selected ? 1.5 : 1,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          '$value',
          style: TextStyle(
            color: selected ? AppColors.emerald : Colors.white.withOpacity(0.8),
            fontSize: 20,
            fontWeight: FontWeight.w900,
            letterSpacing: 1,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }
}

// ────────────────────────── Escalation warning ──────────────────────────

class _EscalationWarning extends StatelessWidget {
  final int reps;
  final VoidCallback onNext;
  const _EscalationWarning({required this.reps, required this.onNext});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Hero(
            title: 'Miss the first minute?',
            subtitle: 'The punishment gets harder.',
          ),
          const SizedBox(height: 30),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Every extra minute after your alarm rings,',
                    style: TextStyle(color: Colors.white.withOpacity(0.65), fontSize: 15, fontWeight: FontWeight.w500, height: 1.5),
                  ).animate().fadeIn(),
                  const SizedBox(height: 4),
                  const Text(
                    '+5 REPS.',
                    style: TextStyle(
                      color: AppColors.emerald,
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 3,
                      shadows: [Shadow(color: Color(0x8810B981), blurRadius: 20)],
                    ),
                  ).animate(delay: 200.ms).fadeIn().slideX(begin: -0.02, end: 0),
                  const SizedBox(height: 24),
                  for (int i = 0; i < 4; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _MinuteRow(
                        minute: i + 1,
                        reps: reps + i * 5,
                      ).animate(delay: (400 + i * 100).ms).fadeIn(duration: 300.ms).slideX(begin: 0.05, end: 0),
                    ),
                  const SizedBox(height: 16),
                  Text(
                    'The clock starts when the alarm rings. Not when you feel like it.',
                    style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12, fontStyle: FontStyle.italic, height: 1.5),
                  ).animate(delay: 900.ms).fadeIn(),
                ],
              ),
            ),
          ),
          _PrimaryButton(label: 'I UNDERSTAND', onTap: onNext),
        ],
      ),
    );
  }
}

class _MinuteRow extends StatelessWidget {
  final int minute;
  final int reps;
  const _MinuteRow({required this.minute, required this.reps});

  @override
  Widget build(BuildContext context) {
    final penalty = minute > 1;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: penalty ? AppColors.error.withOpacity(0.06) : const Color(0xFF0B0B0B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: penalty ? AppColors.error.withOpacity(0.25) : Colors.white.withOpacity(0.05),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(6),
            ),
            alignment: Alignment.center,
            child: Text(
              'MIN $minute',
              style: TextStyle(
                color: Colors.white.withOpacity(0.55),
                fontSize: 9,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Row(
              children: [
                Text(
                  '$reps',
                  style: TextStyle(
                    color: penalty ? AppColors.error : Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'reps',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.35),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          if (penalty)
            Text(
              '+5',
              style: TextStyle(
                color: AppColors.error,
                fontSize: 14,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
        ],
      ),
    );
  }
}

// ────────────────────────── Signature screen ──────────────────────────

class _SignatureScreen extends StatefulWidget {
  final OnboardingState state;
  final VoidCallback onNext;
  const _SignatureScreen({required this.state, required this.onNext});

  @override
  State<_SignatureScreen> createState() => _SignatureScreenState();
}

class _SignatureScreenState extends State<_SignatureScreen> {
  final GlobalKey _boundaryKey = GlobalKey();
  final List<List<Offset>> _strokes = [];
  bool _saving = false;

  bool get _hasSignature => _strokes.any((s) => s.length > 3);

  void _startStroke(Offset p) {
    HapticFeedback.selectionClick();
    setState(() => _strokes.add([p]));
  }

  void _extendStroke(Offset p) {
    if (_strokes.isEmpty) return;
    setState(() => _strokes.last.add(p));
  }

  void _clear() {
    HapticFeedback.mediumImpact();
    setState(() => _strokes.clear());
  }

  Future<void> _sign() async {
    if (!_hasSignature || _saving) return;
    setState(() => _saving = true);
    HapticFeedback.heavyImpact();
    try {
      final boundary = _boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary != null) {
        final image = await boundary.toImage(pixelRatio: 2.5);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        if (bytes != null) {
          widget.state.signatureBytes = bytes.buffer.asUint8List();
        }
      }
    } catch (_) {}
    if (!mounted) return;
    widget.onNext();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Hero(
            title: 'Sign your commitment.',
            subtitle: 'You are giving your word to yourself. Not to us.',
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.emerald.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.emerald.withOpacity(0.25), width: 1),
            ),
            child: Text(
              'I commit to completing my HabitDrill every morning.',
              style: TextStyle(
                color: Colors.white.withOpacity(0.85),
                fontSize: 13,
                fontWeight: FontWeight.w600,
                fontStyle: FontStyle.italic,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF0B0B0B),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.08), width: 1),
              ),
              child: RepaintBoundary(
                key: _boundaryKey,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Container(color: const Color(0xFF0B0B0B)),
                      ),
                      // Baseline
                      Positioned(
                        left: 24,
                        right: 24,
                        bottom: 40,
                        child: Container(height: 1, color: Colors.white.withOpacity(0.15)),
                      ),
                      Positioned(
                        left: 24,
                        bottom: 20,
                        child: Text(
                          _hasSignature ? '' : 'SIGN HERE ↑',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.3),
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 3,
                          ),
                        ),
                      ),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onPanStart: (d) => _startStroke(d.localPosition),
                        onPanUpdate: (d) => _extendStroke(d.localPosition),
                        child: CustomPaint(
                          size: Size.infinite,
                          painter: _SignaturePainter(strokes: _strokes),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              GestureDetector(
                onTap: _hasSignature ? _clear : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF141414),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.08), width: 1),
                  ),
                  child: Text(
                    'CLEAR',
                    style: TextStyle(
                      color: Colors.white.withOpacity(_hasSignature ? 0.7 : 0.25),
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _PrimaryButton(
                  label: _saving ? 'SIGNING…' : 'SIGN & CONTINUE',
                  enabled: _hasSignature && !_saving,
                  onTap: _sign,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SignaturePainter extends CustomPainter {
  final List<List<Offset>> strokes;
  _SignaturePainter({required this.strokes});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.emerald
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    for (final stroke in strokes) {
      if (stroke.length < 2) {
        if (stroke.isNotEmpty) canvas.drawPoints(ui.PointMode.points, stroke, paint);
        continue;
      }
      final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);
      for (int i = 1; i < stroke.length; i++) {
        path.lineTo(stroke[i].dx, stroke[i].dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SignaturePainter oldDelegate) => true;
}

// ────────────────────────── Building plan (loader) ──────────────────

class _BuildingPlan extends StatefulWidget {
  final VoidCallback onNext;
  const _BuildingPlan({required this.onNext});

  @override
  State<_BuildingPlan> createState() => _BuildingPlanState();
}

class _BuildingPlanState extends State<_BuildingPlan> with SingleTickerProviderStateMixin {
  int _step = 0;
  Timer? _timer;
  static const List<String> _steps = [
    'Calibrating discipline model…',
    'Scheduling alarm…',
    'Locking in your contract…',
    'Loading drill sergeant…',
    'Your plan is ready.',
  ];

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 700), (t) {
      if (_step < _steps.length - 1) {
        setState(() => _step++);
      } else {
        t.cancel();
        Future.delayed(const Duration(milliseconds: 600), () {
          if (mounted) widget.onNext();
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Spacer(),
          Text(
            'Building your plan.',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ).animate().fadeIn(),
          const SizedBox(height: 40),
          for (int i = 0; i < _steps.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: AnimatedOpacity(
                opacity: _step >= i ? 1 : 0.2,
                duration: const Duration(milliseconds: 300),
                child: Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: _step > i ? AppColors.emerald : Colors.transparent,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _step >= i ? AppColors.emerald : Colors.white.withOpacity(0.2),
                          width: 1.5,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: _step > i
                          ? const Icon(Icons.check, color: Colors.black, size: 12)
                          : _step == i
                              ? const SizedBox(width: 8, height: 8, child: CircularProgressIndicator(strokeWidth: 1.5, color: AppColors.emerald))
                              : null,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        _steps[i],
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.85),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const Spacer(),
        ],
      ),
    );
  }
}

// ────────────────────────── Summary ──────────────────────────

class _SummaryScreen extends StatelessWidget {
  final OnboardingState state;
  final VoidCallback onNext;
  const _SummaryScreen({required this.state, required this.onNext});

  @override
  Widget build(BuildContext context) {
    final t = state.wakeTime;
    final period = t.period == DayPeriod.am ? 'AM' : 'PM';
    final h12 = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final timeStr = '${h12.toString()}:${t.minute.toString().padLeft(2, '0')} $period';
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Hero(
            title: 'Tomorrow.',
            subtitle: 'This is what you signed up for.',
          ),
          const SizedBox(height: 30),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _TimelineStep(
                    icon: Icons.wb_sunny_rounded,
                    title: 'ALARM',
                    detail: timeStr,
                    delay: 100,
                  ),
                  const _TimelineConnector(),
                  _TimelineStep(
                    icon: Icons.fitness_center_rounded,
                    title: state.exerciseName.toUpperCase(),
                    detail: '${state.reps} reps to dismiss',
                    delay: 300,
                  ),
                  const _TimelineConnector(),
                  _TimelineStep(
                    icon: Icons.check_circle_rounded,
                    title: 'ALARM CLEARED',
                    detail: 'AI verifies every rep',
                    delay: 500,
                  ),
                  const _TimelineConnector(),
                  _TimelineStep(
                    icon: Icons.local_fire_department_rounded,
                    title: 'STREAK BEGINS',
                    detail: 'Day 1 · Discipline +3',
                    accent: AppColors.fire,
                    delay: 700,
                  ),
                ],
              ),
            ),
          ),
          _PrimaryButton(label: 'UNLOCK HABITDRILL', onTap: onNext),
        ],
      ),
    );
  }
}

class _TimelineStep extends StatelessWidget {
  final IconData icon;
  final String title;
  final String detail;
  final Color accent;
  final int delay;
  const _TimelineStep({
    required this.icon,
    required this.title,
    required this.detail,
    this.accent = AppColors.emerald,
    required this.delay,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF0B0B0B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withOpacity(0.25), width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: accent.withOpacity(0.12),
              shape: BoxShape.circle,
              border: Border.all(color: accent.withOpacity(0.35), width: 1),
            ),
            child: Icon(icon, color: accent, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  detail,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate(delay: delay.ms).fadeIn(duration: 400.ms).slideX(begin: 0.05, end: 0);
  }
}

class _TimelineConnector extends StatelessWidget {
  const _TimelineConnector();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 20,
      child: Center(
        child: Container(
          width: 2,
          decoration: BoxDecoration(
            color: AppColors.emerald.withOpacity(0.4),
            borderRadius: BorderRadius.circular(1),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════ NEW BEAST-MODE SCREENS ══════════════════════════

// ────────────────────────── First Battle philosophy ──────────────────────

class _FirstBattle extends StatelessWidget {
  final VoidCallback onNext;
  const _FirstBattle({required this.onNext});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.error.withOpacity(0.12),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: AppColors.error.withOpacity(0.4), width: 1),
            ),
            child: Text(
              'THE TRUTH',
              style: TextStyle(
                color: AppColors.error,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 3,
              ),
            ),
          ).animate().fadeIn(),
          const SizedBox(height: 22),
          const Text(
            'Discipline gets\nattacked every day.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
              height: 1.15,
            ),
          ).animate(delay: 150.ms).fadeIn().slideY(begin: 0.05, end: 0),
          const SizedBox(height: 18),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: 'The first attack is the moment ',
                  style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 17, fontWeight: FontWeight.w500, height: 1.5),
                ),
                const TextSpan(
                  text: 'your eyes open.',
                  style: TextStyle(color: AppColors.emerald, fontSize: 17, fontWeight: FontWeight.w800, height: 1.5),
                ),
              ],
            ),
          ).animate(delay: 400.ms).fadeIn(),
          const SizedBox(height: 20),
          Text(
            'Win that first battle and your whole day tilts. Lose it and every temptation after gets easier.',
            style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 15, fontWeight: FontWeight.w500, height: 1.5),
          ).animate(delay: 600.ms).fadeIn(),
          const Spacer(),
          _PrimaryButton(label: 'I WANT TO WIN', onTap: onNext).animate(delay: 900.ms).fadeIn(),
        ],
      ),
    );
  }
}

// ────────────────────────── Not A Wrapper ──────────────────────

class _NotAWrapper extends StatelessWidget {
  final VoidCallback onNext;
  const _NotAWrapper({required this.onNext});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Hero(
            title: 'This is not another\ntracking app.',
            subtitle: 'Other apps ask if you did it. We verify.',
          ),
          const SizedBox(height: 30),
          Expanded(
            child: Column(
              children: [
                _CompareRow(
                  left: 'Other apps',
                  leftBody: 'Tap a button to say you did it.',
                  right: 'HabitDrill',
                  rightBody: 'AI counts every rep. Fake reps do not count.',
                ).animate(delay: 200.ms).fadeIn(),
                const SizedBox(height: 14),
                _CompareRow(
                  left: 'Other alarms',
                  leftBody: 'Snooze forever. No consequence.',
                  right: 'HabitDrill',
                  rightBody: 'The alarm does not stop until you move.',
                ).animate(delay: 400.ms).fadeIn(),
                const SizedBox(height: 14),
                _CompareRow(
                  left: 'Other trackers',
                  leftBody: 'A pretty chart of your failures.',
                  right: 'HabitDrill',
                  rightBody: 'Every failure = real punishment reps you owe.',
                ).animate(delay: 600.ms).fadeIn(),
              ],
            ),
          ),
          _PrimaryButton(label: 'CONTINUE', onTap: onNext).animate(delay: 900.ms).fadeIn(),
        ],
      ),
    );
  }
}

class _CompareRow extends StatelessWidget {
  final String left;
  final String leftBody;
  final String right;
  final String rightBody;

  const _CompareRow({
    required this.left,
    required this.leftBody,
    required this.right,
    required this.rightBody,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF0B0B0B),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.05), width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.close, color: AppColors.error, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        left.toUpperCase(),
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.4),
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    leftBody,
                    style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12, fontWeight: FontWeight.w600, height: 1.35),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.emerald.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.emerald.withOpacity(0.45), width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.check, color: AppColors.emerald, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        right.toUpperCase(),
                        style: const TextStyle(
                          color: AppColors.emerald,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    rightBody,
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700, height: 1.35),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────── AI-Verified pitch ──────────────────────

class _AiVerifiedPitch extends StatefulWidget {
  final VoidCallback onNext;
  const _AiVerifiedPitch({required this.onNext});

  @override
  State<_AiVerifiedPitch> createState() => _AiVerifiedPitchState();
}

class _AiVerifiedPitchState extends State<_AiVerifiedPitch> {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Hero(
            title: 'Real AI. Real reps.',
            subtitle: 'Our pose model watches every rep. Fake reps count for nothing.',
          ),
          const SizedBox(height: 24),
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: 0.85,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      colors: [
                        AppColors.emerald.withOpacity(0.15),
                        Colors.transparent,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.emerald.withOpacity(0.35), width: 1.5),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CustomPaint(painter: _SkeletonPainter()),
                      Positioned(
                        top: 14,
                        left: 14,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.emerald,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.circle, color: Colors.black, size: 8),
                              SizedBox(width: 6),
                              Text('LIVE · TRACKING', style: TextStyle(color: Colors.black, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1)),
                            ],
                          ),
                        ).animate(onPlay: (c) => c.repeat()).fade(begin: 1, end: 0.4, duration: 800.ms),
                      ),
                      Positioned(
                        bottom: 14,
                        left: 14,
                        right: 14,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: AppColors.emerald.withOpacity(0.35)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.check_circle, color: AppColors.emerald, size: 14),
                                  const SizedBox(width: 6),
                                  Text(
                                    'GOOD FORM',
                                    style: TextStyle(color: AppColors.emerald, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: AppColors.emerald.withOpacity(0.5)),
                              ),
                              child: TweenAnimationBuilder<int>(
                                duration: const Duration(seconds: 3),
                                tween: IntTween(begin: 0, end: 15),
                                builder: (context, v, _) => Text(
                                  '$v / 15',
                                  style: TextStyle(
                                    color: AppColors.emerald,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                    fontFeatures: const [FontFeature.tabularFigures()],
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
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'MediaPipe pose detection. Runs on your device. Nothing sent to us.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11, fontWeight: FontWeight.w600, height: 1.5),
          ),
          const SizedBox(height: 16),
          _PrimaryButton(label: 'CONTINUE', onTap: widget.onNext),
        ],
      ),
    );
  }
}

class _SkeletonPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final joints = <Offset>[
      Offset(w * 0.5, h * 0.15), // head
      Offset(w * 0.5, h * 0.28), // shoulders center
      Offset(w * 0.32, h * 0.28), // L shoulder
      Offset(w * 0.68, h * 0.28), // R shoulder
      Offset(w * 0.22, h * 0.45), // L elbow
      Offset(w * 0.78, h * 0.45), // R elbow
      Offset(w * 0.20, h * 0.60), // L wrist
      Offset(w * 0.80, h * 0.60), // R wrist
      Offset(w * 0.5, h * 0.55), // hips center
      Offset(w * 0.40, h * 0.55), // L hip
      Offset(w * 0.60, h * 0.55), // R hip
      Offset(w * 0.36, h * 0.75), // L knee
      Offset(w * 0.64, h * 0.75), // R knee
      Offset(w * 0.34, h * 0.92), // L ankle
      Offset(w * 0.66, h * 0.92), // R ankle
    ];

    final linePaint = Paint()
      ..color = AppColors.emerald
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    final glowPaint = Paint()
      ..color = AppColors.emerald.withOpacity(0.35)
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

    void bone(int a, int b) {
      canvas.drawLine(joints[a], joints[b], glowPaint);
      canvas.drawLine(joints[a], joints[b], linePaint);
    }

    bone(0, 1); // head to shoulders
    bone(2, 3); // shoulders
    bone(2, 4); bone(4, 6); // L arm
    bone(3, 5); bone(5, 7); // R arm
    bone(1, 8); // spine
    bone(9, 10); // hips
    bone(9, 11); bone(11, 13); // L leg
    bone(10, 12); bone(12, 14); // R leg

    final dotPaint = Paint()..color = AppColors.emerald;
    final dotGlow = Paint()
      ..color = AppColors.emerald.withOpacity(0.6)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    for (final j in joints) {
      canvas.drawCircle(j, 6, dotGlow);
      canvas.drawCircle(j, 3.5, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ────────────────────────── Screen Time pitch ──────────────────────

class _ScreenTimePitch extends StatelessWidget {
  final VoidCallback onNext;
  const _ScreenTimePitch({required this.onNext});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Hero(
            title: 'Doom-scroll?\nYou owe reps.',
            subtitle: 'HabitDrill can watch your screen time and punish overuse.',
          ),
          const SizedBox(height: 30),
          Expanded(
            child: Column(
              children: [
                _ScreenTimeRow(app: 'Instagram', limit: '30 min', used: '2h 14m', over: true).animate(delay: 200.ms).fadeIn().slideX(begin: 0.03, end: 0),
                const SizedBox(height: 10),
                _ScreenTimeRow(app: 'TikTok', limit: '20 min', used: '1h 32m', over: true).animate(delay: 320.ms).fadeIn().slideX(begin: 0.03, end: 0),
                const SizedBox(height: 10),
                _ScreenTimeRow(app: 'X (Twitter)', limit: '20 min', used: '18 min', over: false).animate(delay: 440.ms).fadeIn().slideX(begin: 0.03, end: 0),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.error.withOpacity(0.35), width: 1),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Total debt: 40 burpees before your phone unlocks.',
                          style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 13, fontWeight: FontWeight.w700, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ).animate(delay: 700.ms).fadeIn(),
              ],
            ),
          ),
          Text(
            'Requires iOS Family Controls permission. Rolling out now.',
            style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 10, fontWeight: FontWeight.w600, fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 12),
          _PrimaryButton(label: 'GOOD.', onTap: onNext),
        ],
      ),
    );
  }
}

class _ScreenTimeRow extends StatelessWidget {
  final String app;
  final String limit;
  final String used;
  final bool over;
  const _ScreenTimeRow({required this.app, required this.limit, required this.used, required this.over});

  @override
  Widget build(BuildContext context) {
    final color = over ? AppColors.error : AppColors.emerald;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: over ? AppColors.error.withOpacity(0.06) : const Color(0xFF0B0B0B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: over ? AppColors.error.withOpacity(0.35) : Colors.white.withOpacity(0.06), width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  app,
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  'Limit $limit',
                  style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                used,
                style: TextStyle(
                  color: color,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                over ? 'OVER' : 'CLEAN',
                style: TextStyle(color: color.withOpacity(0.85), fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.5),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ────────────────────────── Real alarm pitch ──────────────────────

class _RealAlarmPitch extends StatelessWidget {
  final VoidCallback onNext;
  const _RealAlarmPitch({required this.onNext});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Hero(
            title: 'A real alarm.\nOn silent mode.',
            subtitle: "We use Apple's Critical Alerts. Your phone rings even on silent.",
          ),
          const SizedBox(height: 30),
          Expanded(
            child: Column(
              children: [
                _Bullet(icon: Icons.volume_up_rounded, title: 'Full volume', body: 'Rings through silent mode and Focus.'),
                const SizedBox(height: 14),
                _Bullet(icon: Icons.vibration_rounded, title: 'Vibration + haptics', body: 'Feels like an emergency because it is one.'),
                const SizedBox(height: 14),
                _Bullet(icon: Icons.timer_off_rounded, title: 'No snooze', body: 'The only dismiss button is your body moving.'),
              ],
            ),
          ),
          Text(
            'Critical Alerts require Apple entitlement — pending approval.',
            style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 10, fontWeight: FontWeight.w600, fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 12),
          _PrimaryButton(label: 'LET IT RIP', onTap: onNext),
        ],
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  const _Bullet({required this.icon, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF0B0B0B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.05), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.emerald.withOpacity(0.15),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.emerald.withOpacity(0.4), width: 1),
            ),
            child: Icon(icon, color: AppColors.emerald, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 13, fontWeight: FontWeight.w500, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────── Social proof ──────────────────────

class _SocialProof extends StatelessWidget {
  final VoidCallback onNext;
  const _SocialProof({required this.onNext});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 20),
          const _LaurelStrip(),
          const SizedBox(height: 26),
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              children: [
                const TextSpan(
                  text: '89%',
                  style: TextStyle(
                    color: AppColors.emerald,
                    fontSize: 88,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -3,
                    shadows: [Shadow(color: Color(0x8810B981), blurRadius: 22)],
                  ),
                ),
              ],
            ),
          ).animate().fadeIn().scale(begin: const Offset(0.85, 0.85), end: const Offset(1, 1), duration: 500.ms),
          const SizedBox(height: 6),
          Text(
            'complete their morning routine\nafter 30 days on HabitDrill.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 15, fontWeight: FontWeight.w600, height: 1.5),
          ).animate(delay: 300.ms).fadeIn(),
          const SizedBox(height: 40),
          _Stat(number: '2.4M', label: 'Verified reps counted').animate(delay: 500.ms).fadeIn().slideY(begin: 0.05, end: 0),
          const SizedBox(height: 10),
          _Stat(number: '18K', label: 'Alarms dismissed by movement').animate(delay: 600.ms).fadeIn().slideY(begin: 0.05, end: 0),
          const SizedBox(height: 10),
          _Stat(number: '4.8', label: 'Average App Store rating').animate(delay: 700.ms).fadeIn().slideY(begin: 0.05, end: 0),
          const Spacer(),
          _PrimaryButton(label: 'JOIN THEM', onTap: onNext),
        ],
      ),
    );
  }
}

class _LaurelStrip extends StatelessWidget {
  const _LaurelStrip();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('🌿', style: TextStyle(fontSize: 32)),
        const SizedBox(width: 8),
        Row(
          children: [
            for (int i = 0; i < 5; i++)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 1),
                child: Icon(Icons.star_rounded, color: AppColors.amber, size: 24),
              ),
          ],
        ),
        const SizedBox(width: 8),
        const Text('🌿', style: TextStyle(fontSize: 32)),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  final String number;
  final String label;
  const _Stat({required this.number, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF0B0B0B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.05), width: 1),
      ),
      child: Row(
        children: [
          Text(
            number,
            style: const TextStyle(
              color: AppColors.emerald,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
