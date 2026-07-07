import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../design/tokens.dart';
import '../../models/violation.dart';
import '../../models/exercise_set.dart';
import '../../services/sergeant_service.dart';
import '../../services/pose_detector_service.dart';
import '../../services/workout_session.dart';
import '../../widgets/skeleton_painter.dart';
import '../../widgets/power_gauge.dart';
import '../../widgets/pt_setup_advice_screen.dart';
import '../../services/sergeant_audio_service.dart';
import '../../services/analytics_service.dart';
import '../../services/ledger_service.dart';

class ExerciseCircuitScreen extends StatefulWidget {
  final Violation violation;
  final VoidCallback onComplete;

  const ExerciseCircuitScreen({
    super.key,
    required this.violation,
    required this.onComplete,
  });

  @override
  State<ExerciseCircuitScreen> createState() => _ExerciseCircuitScreenState();
}

class _ExerciseCircuitScreenState extends State<ExerciseCircuitScreen> {
  late ExerciseSet _exerciseSet;

  // Camera + AI
  CameraController? _cameraController;
  PoseDetectorService? _poseDetector;
  WorkoutSession? _session;
  List<PoseLandmark>? _landmarks;
  bool _cameraReady = false;
  bool _isProcessing = false;

  // State
  int _currentExerciseIndex = 0;
  bool _showAdvice = true;
  bool _countdown = false;
  int _countdownValue = 5;
  bool _exerciseActive = false;
  bool _showComplete = false;

  // UI feedback
  String _feedback = '';
  double _chargeProgress = 0.0;

  @override
  void initState() {
    super.initState();
    AnalyticsService.logScreenView('exercise_circuit');
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    WakelockPlus.enable();
    _exerciseSet = SergeantService.getExerciseSet(widget.violation);
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _poseDetector?.dispose();
    SergeantAudioService.stop();
    WakelockPlus.disable();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      final frontCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.yuv420 : ImageFormatGroup.bgra8888,
      );

      await _cameraController!.initialize();

      _poseDetector = PoseDetectorService();
      _poseDetector!.sensorOrientation = frontCamera.sensorOrientation;

      _cameraController!.startImageStream(_processFrame);

      if (mounted) {
        setState(() => _cameraReady = true);
      }
    } catch (e) {
      debugPrint('Camera init error: $e');
      // Fall back to honor system if camera fails
      if (mounted) {
        setState(() {
          _cameraReady = false;
          _showAdvice = false;
          _exerciseActive = true;
        });
      }
    }
  }

  Future<void> _processFrame(CameraImage image) async {
    if (_isProcessing || !_exerciseActive || _poseDetector == null) return;
    _isProcessing = true;

    try {
      final landmarks = await _poseDetector!.detectPose(image);
      if (landmarks != null && mounted) {
        setState(() => _landmarks = landmarks);

        // Feed to workout session
        if (_session != null) {
          _session!.processPose(landmarks);

          // Update gauge
          setState(() {
            _chargeProgress = _session!.chargeProgress;
            _feedback = _session!.feedback;
          });
        }
      }
    } catch (e) {
      // Skip frame on error
    }

    _isProcessing = false;
  }

  void _onAdviceDismissed() {
    setState(() => _showAdvice = false);
    _initCamera();
    _startCountdown();
  }

  void _startCountdown() {
    setState(() {
      _countdown = true;
      _countdownValue = 5;
    });

    // Play exercise start announcement immediately
    final exercise = _exerciseSet.exercises[_currentExerciseIndex];
    SergeantAudioService.playExerciseStart(exercise.engineId);

    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() => _countdownValue--);
      if (_countdownValue <= 0) {
        _startExercise();
        return false;
      }
      return true;
    });
  }

  void _startExercise() {
    final exercise = _exerciseSet.exercises[_currentExerciseIndex];

    _session = WorkoutSession();
    _session!.onRepCounted = (reps) {
      if (mounted) {
        setState(() {
          exercise.completedReps = reps;
        });

        // Play audio at the right moment
        SergeantAudioService.onRepCounted(
          currentRep: reps,
          targetReps: exercise.reps,
          exerciseId: exercise.engineId,
        );

        if (reps >= exercise.reps) {
          exercise.completed = true;
          _onExerciseFinished();
        }
      }
    };
    _session!.onFeedback = (msg) {
      if (mounted) setState(() => _feedback = msg);
    };

    _session!.startExercise(
      exerciseId: exercise.engineId,
      sets: 1,
      reps: exercise.reps,
    );

    setState(() {
      _countdown = false;
      _exerciseActive = true;
    });
  }

  void _onExerciseFinished() {
    _exerciseActive = false;
    _session = null;

    final done = _exerciseSet.exercises[_currentExerciseIndex];
    // Await with a short timeout — reps must persist for the Ledger to
    // show the correct total, but a slow write must not stall the UI.
    LedgerService.addReps(done.engineId, done.reps)
        .timeout(const Duration(milliseconds: 800))
        .catchError((_) {});

    if (_currentExerciseIndex < _exerciseSet.exercises.length - 1) {
      // Next exercise after brief pause
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _currentExerciseIndex++;
            _chargeProgress = 0;
            _feedback = '';
            _landmarks = null;
          });
          _startCountdown();
        }
      });
    } else {
      // All done - circuit complete
      SergeantAudioService.playCircuitComplete();
      setState(() => _showComplete = true);
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted && !_finished) _finishNow();
      });
    }
  }

  bool _finished = false;

  void _finishNow() {
    if (_finished) return;
    _finished = true;
    HapticFeedback.mediumImpact();
    // Fire callback for state cleanup — do NOT wait for it. Async writes
    // can hang and have burned us before.
    widget.onComplete();
    // Pop the punishment route DIRECTLY, right now. This is the fix.
    // popUntil(isFirst) unwinds every pushed route on top of the home
    // (AppRouter). No callback chain to depend on. No race conditions.
    if (mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  /// Fallback: manual tap to count rep (when camera unavailable)
  void _manualRep() {
    final exercise = _exerciseSet.exercises[_currentExerciseIndex];
    setState(() {
      exercise.completedReps++;
    });

    SergeantAudioService.onRepCounted(
      currentRep: exercise.completedReps,
      targetReps: exercise.reps,
      exerciseId: exercise.engineId,
    );

    if (exercise.completedReps >= exercise.reps) {
      exercise.completed = true;
      _onExerciseFinished();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_showComplete) return _buildDismissed();
    if (_showAdvice) return _buildAdvicePhase();

    final exercise = _exerciseSet.exercises[_currentExerciseIndex];

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Camera preview (no Transform - skeleton painter handles front camera flip)
          if (_cameraReady && _cameraController != null)
            CameraPreview(_cameraController!)
          else
            Container(color: Colors.black),

          // Skeleton overlay
          if (_landmarks != null && _cameraReady)
            CustomPaint(
              painter: SkeletonPainter(
                landmarks: _landmarks,
                imageSize: Platform.isAndroid
                    ? Size(
                        _cameraController!.value.previewSize?.height ?? 480,
                        _cameraController!.value.previewSize?.width ?? 640,
                      )
                    : Size(
                        _cameraController!.value.previewSize?.width ?? 480,
                        _cameraController!.value.previewSize?.height ?? 640,
                      ),
                isFrontCamera: true,
                chargeProgress: _chargeProgress,
              ),
              size: Size.infinite,
            ),

          // Dark overlay at top for text readability
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 180,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black.withOpacity(0.8), Colors.transparent],
                ),
              ),
            ),
          ),

          // Top HUD
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16,
            right: 16,
            child: Column(
              children: [
                // Exercise name
                Text(
                  exercise.name.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 8),
                // Rep counter
                if (_exerciseActive || exercise.completedReps > 0)
                  Text(
                    '${exercise.completedReps} / ${exercise.reps}',
                    style: TextStyle(
                      color: exercise.completed ? AppColors.emerald : Colors.red,
                      fontSize: 48,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                if (_countdown)
                  Text(
                    '$_countdownValue',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 72,
                      fontWeight: FontWeight.w900,
                    ),
                  ).animate().scale(
                    begin: const Offset(1.5, 1.5),
                    end: const Offset(1, 1),
                    duration: 300.ms,
                  ),
              ],
            ),
          ),

          // Feedback text
          if (_feedback.isNotEmpty)
            Positioned(
              bottom: 160,
              left: 32,
              right: 32,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _feedback,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),

          // Power gauge (left side)
          if (_exerciseActive)
            Positioned(
              left: 16,
              top: MediaQuery.of(context).size.height * 0.35,
              child: PowerGauge(fillPercent: _chargeProgress),
            ),

          // Progress bar at bottom
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildBottomBar(exercise),
          ),

          // Manual tap fallback (when no camera)
          if (!_cameraReady && _exerciseActive)
            Positioned(
              bottom: 120,
              left: 32,
              right: 32,
              child: GestureDetector(
                onTap: _manualRep,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  decoration: BoxDecoration(
                    color: AppColors.emerald.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.emerald.withOpacity(0.5)),
                  ),
                  child: const Text(
                    'TAP TO COUNT REP',
                    style: TextStyle(
                      color: AppColors.emerald,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAdvicePhase() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.accessibility_new, size: 64, color: AppColors.emerald),
              const SizedBox(height: 24),
              const Text(
                'POSITION YOURSELF',
                style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 2),
              ),
              const SizedBox(height: 32),
              _adviceRow(Icons.phone_android, 'Place phone below hip height'),
              _adviceRow(Icons.straighten, 'Stand 6-8 feet away'),
              _adviceRow(Icons.accessibility_new, 'Full body must be visible'),
              _adviceRow(Icons.light_mode, 'Good lighting works best'),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: AppColors.emeraldGradient,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _onAdviceDismissed,
                      borderRadius: BorderRadius.circular(16),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          'READY',
                          style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 1),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _adviceRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Icon(icon, color: AppColors.emerald, size: 24),
          const SizedBox(width: 16),
          Text(text, style: const TextStyle(color: Colors.white70, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildBottomBar(Exercise exercise) {
    final progress = _exerciseSet.exercises
        .where((e) => e.completed)
        .length / _exerciseSet.exercises.length;

    return Container(
      padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).padding.bottom + 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Colors.black.withOpacity(0.9), Colors.transparent],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Exercise progress dots
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: _exerciseSet.exercises.asMap().entries.map((entry) {
              final i = entry.key;
              final ex = entry.value;
              return Container(
                width: 10,
                height: 10,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: ex.completed
                      ? AppColors.emerald
                      : i == _currentExerciseIndex
                          ? Colors.red
                          : Colors.white24,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          // Overall progress
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white12,
              valueColor: const AlwaysStoppedAnimation(AppColors.emerald),
              minHeight: 4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Exercise ${_currentExerciseIndex + 1} of ${_exerciseSet.exercises.length}',
            style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildDismissed() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _finishNow,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle_outline, size: 80, color: AppColors.emerald)
                  .animate().scale(
                    begin: const Offset(0.5, 0.5),
                    end: const Offset(1, 1),
                    duration: 400.ms,
                  ),
              const SizedBox(height: 24),
              const Text(
                'PUNISHMENT COMPLETE.',
                style: TextStyle(color: AppColors.emerald, fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: 3),
              ).animate(delay: 200.ms).fadeIn(),
              const SizedBox(height: 12),
              Text(
                'Don\'t fail again.',
                style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 16, fontWeight: FontWeight.w600),
              ).animate(delay: 500.ms).fadeIn(),
              const SizedBox(height: 48),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.emerald,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: AppColors.emerald.withOpacity(0.4), blurRadius: 16, offset: const Offset(0, 4))],
                ),
                child: const Text(
                  'RETURN TO BASE',
                  style: TextStyle(color: Colors.black, fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 2),
                ),
              ).animate(delay: 800.ms).fadeIn(),
            ],
          ),
        ),
      ),
    );
  }
}
