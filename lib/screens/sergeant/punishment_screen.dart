import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:video_player/video_player.dart';
import '../../design/tokens.dart';
import '../../models/violation.dart';
import '../../models/escalation_config.dart';
import '../../services/sergeant_service.dart';
import 'exercise_circuit_screen.dart';

class PunishmentScreen extends StatefulWidget {
  final Violation violation;
  final VoidCallback onComplete;

  const PunishmentScreen({
    super.key,
    required this.violation,
    required this.onComplete,
  });

  @override
  State<PunishmentScreen> createState() => _PunishmentScreenState();
}

class _PunishmentScreenState extends State<PunishmentScreen> {
  _Phase _phase = _Phase.darkIntro;
  VideoPlayerController? _videoController;
  bool _videoReady = false;
  bool _videoError = false;
  String _sergeantMessage = '';

  @override
  void initState() {
    super.initState();
    // Lock to portrait, hide system UI for immersion
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _startDarkIntro();
  }

  @override
  void dispose() {
    _videoController?.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _startDarkIntro() {
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        _initVideo();
      }
    });
  }

  Future<void> _initVideo() async {
    final videoPath = SergeantService.getVideoPath(widget.violation);

    try {
      // Check if asset exists by trying to load it
      _videoController = VideoPlayerController.asset(videoPath);
      await _videoController!.initialize();
      _videoController!.addListener(_onVideoUpdate);

      if (mounted) {
        setState(() {
          _videoReady = true;
          _phase = _Phase.video;
        });
        _videoController!.play();
      }
    } catch (e) {
      debugPrint('Video not available: $e');
      // Skip to voice/exercise phase if no video
      if (mounted) {
        setState(() {
          _videoError = true;
          _phase = _Phase.voice;
        });
        _startVoicePhase();
      }
    }
  }

  void _onVideoUpdate() {
    if (_videoController != null &&
        _videoController!.value.isInitialized &&
        _videoController!.value.position >= _videoController!.value.duration &&
        _videoController!.value.duration > Duration.zero) {
      // Video finished - move to voice phase
      _videoController!.removeListener(_onVideoUpdate);
      if (mounted) {
        setState(() => _phase = _Phase.voice);
        _startVoicePhase();
      }
    }
  }

  void _startVoicePhase() {
    // Show punishment message, then move to exercises
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() => _phase = _Phase.exercises);
      }
    });
  }

  void _onExercisesComplete() async {
    await SergeantService.clearAllPending();
    if (mounted) {
      widget.onComplete();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 800),
          child: _buildPhase(),
        ),
      ),
    );
  }

  Widget _buildPhase() {
    switch (_phase) {
      case _Phase.darkIntro:
        return _buildDarkIntro();
      case _Phase.video:
        return _buildVideoPhase();
      case _Phase.voice:
        return _buildVoicePhase();
      case _Phase.exercises:
        return ExerciseCircuitScreen(
          violation: widget.violation,
          onComplete: _onExercisesComplete,
        );
    }
  }

  Widget _buildDarkIntro() {
    final isIndulged = widget.violation.violationType == 'indulged';
    return Container(
      key: const ValueKey('dark_intro'),
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.warning_amber_rounded,
              size: 64,
              color: AppColors.error,
            ).animate().fadeIn(duration: 800.ms).shake(delay: 500.ms),
            const SizedBox(height: AppSpacing.xl),
            Text(
              isIndulged
                  ? 'RULE BROKEN.'
                  : 'ORDER FAILED.',
              style: const TextStyle(
                color: Colors.red,
                fontSize: 28,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
              ),
              textAlign: TextAlign.center,
            ).animate(delay: 400.ms).fadeIn(duration: 600.ms),
            const SizedBox(height: AppSpacing.md),
            Text(
              '"${widget.violation.habitTitle}"',
              style: TextStyle(
                color: Colors.red.withOpacity(0.7),
                fontSize: 18,
                fontWeight: FontWeight.w600,
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ).animate(delay: 800.ms).fadeIn(duration: 400.ms),
            const SizedBox(height: AppSpacing.xl),
            Text(
              'OFFENSE #${widget.violation.offenseNumber}',
              style: TextStyle(
                color: Colors.white.withOpacity(0.4),
                fontSize: 14,
                fontWeight: FontWeight.w700,
                letterSpacing: 3,
              ),
            ).animate(delay: 1200.ms).fadeIn(duration: 400.ms),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoPhase() {
    if (!_videoReady || _videoController == null) {
      return Container(
        key: const ValueKey('video_loading'),
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(color: Colors.red),
        ),
      );
    }

    return Container(
      key: const ValueKey('video'),
      color: Colors.black,
      child: Center(
        child: AspectRatio(
          aspectRatio: _videoController!.value.aspectRatio,
          child: VideoPlayer(_videoController!),
        ),
      ),
    );
  }

  Widget _buildVoicePhase() {
    final message = _sergeantMessage.isNotEmpty
        ? _sergeantMessage
        : EscalationConfig.getMessage(
            widget.violation.escalationLevel,
            0,
            widget.violation.habitTitle,
          );

    return Container(
      key: const ValueKey('voice'),
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Sergeant icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.2),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.red.withOpacity(0.5), width: 2),
                ),
                child: const Icon(
                  Icons.record_voice_over,
                  size: 40,
                  color: Colors.red,
                ),
              ).animate().fadeIn().scale(
                begin: const Offset(0.5, 0.5),
                end: const Offset(1, 1),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ).animate(delay: 300.ms).fadeIn(duration: 600.ms),
              const SizedBox(height: AppSpacing.xxl),
              Text(
                'PUNISHMENT INCOMING.',
                style: TextStyle(
                  color: Colors.red.withOpacity(0.6),
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 3,
                ),
              ).animate(delay: 1500.ms).fadeIn().shimmer(
                duration: 1500.ms,
                color: Colors.red.withOpacity(0.3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _Phase { darkIntro, video, voice, exercises }
