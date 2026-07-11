import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
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
import '../../services/rule_break_ledger.dart';

class ExerciseCircuitScreen extends StatefulWidget {
  /// Punishment flow: violation drives the exercise set.
  final Violation? violation;

  /// Wake flow (or any caller): pre-built set. When present, `violation`
  /// is ignored for set derivation. The caller's `onComplete` is
  /// responsible for whatever cleanup that flow needs.
  final ExerciseSet? overrideSet;

  /// When true, skip the "Position Yourself" advice sheet and go
  /// straight into camera init + countdown. WakeExerciseScreen sets
  /// this because it already showed the setup instructions.
  final bool skipAdvice;

  /// When true, the completion callback fully owns navigation — this
  /// screen will NOT call popUntil(isFirst) after firing onComplete.
  /// WakeExerciseScreen sets this so it can pushReplacement to the
  /// share/mission-complete screen without being popped mid-flight.
  final bool ownsNavigation;

  final VoidCallback onComplete;

  const ExerciseCircuitScreen({
    super.key,
    this.violation,
    this.overrideSet,
    this.skipAdvice = false,
    this.ownsNavigation = false,
    required this.onComplete,
  }) : assert(violation != null || overrideSet != null,
            'Provide either violation or overrideSet');

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
  late bool _showAdvice;
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
    _exerciseSet = widget.overrideSet
        ?? SergeantService.getExerciseSet(widget.violation!);
    _showAdvice = !widget.skipAdvice;
    if (widget.skipAdvice) {
      // Kick off camera + countdown without the tap-through advice sheet.
      // The caller (WakeExerciseScreen) already showed setup instructions.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _initCamera();
        _startCountdown();
      });
    }
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
    // When the parent flow owns navigation (wake share screen), let it
    // route. Otherwise pop everything back to the home tree.
    if (widget.ownsNavigation) return;
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

  final GlobalKey _shameCardKey = GlobalKey();
  bool _shareBusy = false;

  Future<void> _shareShame() async {
    if (_shareBusy) return;
    _shareBusy = true;
    HapticFeedback.mediumImpact();
    try {
      final ctx = _shameCardKey.currentContext;
      if (ctx == null) return;
      final boundary = ctx.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;
      final bytes = byteData.buffer.asUint8List();
      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/habitdrill_shame_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(bytes);
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Broke my promise. Paid the price.\nHabitDrill.',
      );
    } catch (e) {
      debugPrint('shame share failed: $e');
    } finally {
      _shareBusy = false;
    }
  }

  Widget _buildDismissed() {
    final v = widget.violation;
    // The wake flow doesn't come through here (its share screen is
    // WakeCompleteScreen), so if there's no violation this is a
    // generic "punishment done" state and we just show the simple
    // check-mark + button. When there IS a violation, render the
    // shaming share card.
    if (v == null) return _buildSimpleDismissed();
    return _buildShameCard(v);
  }

  Widget _buildSimpleDismissed() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
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
                "Don't fail again.",
                style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 16, fontWeight: FontWeight.w600),
              ).animate(delay: 500.ms).fadeIn(),
              const SizedBox(height: 48),
              _ReturnToBaseButton(onTap: _finishNow)
                  .animate(delay: 800.ms).fadeIn(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShameCard(Violation v) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              const SizedBox(height: 12),
              _ShameBadge(offense: v.offenseNumber),
              const SizedBox(height: 18),
              const Text(
                'DEBT PAID.\nDON\'T DO IT AGAIN.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1,
                  height: 1.02,
                ),
              ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.05, end: 0),
              const SizedBox(height: 22),
              Expanded(
                child: Center(
                  child: RepaintBoundary(
                    key: _shameCardKey,
                    child: _ShameShareCard(v: v),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              _SharePrimaryButton(onTap: _shareShame)
                  .animate(delay: 500.ms).fadeIn().slideY(begin: 0.05, end: 0),
              const SizedBox(height: 10),
              _ReturnToBaseButton(onTap: _finishNow)
                  .animate(delay: 600.ms).fadeIn(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// ────────────────────────── Shame UI pieces ─────────────────────────

class _ShameBadge extends StatelessWidget {
  final int offense;
  const _ShameBadge({required this.offense});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.error.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.error.withOpacity(0.55), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 14),
          const SizedBox(width: 6),
          Text(
            'OFFENSE #$offense',
            style: TextStyle(
              color: AppColors.error,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 3,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms);
  }
}

class _ShameShareCard extends StatelessWidget {
  final Violation v;
  const _ShameShareCard({required this.v});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final date = DateFormat('EEE · d MMM').format(now).toUpperCase();
    final time = DateFormat('HH:mm').format(now);

    final line = v.violationType == 'indulged'
        ? 'Broke my rule.\nOwn it. Move on.'
        : "Skipped the order.\nOwn it. Move on.";

    // Per-day counters — sourced from RuleBreakLedger which is
    // written the moment `confess()` runs on Home. streakLost is the
    // value we zeroed on the FIRST break of the day, so if this is
    // that first break we've got the number to shame with.
    final streakLost = RuleBreakLedger.streakLostToday(v.habitId);
    final todayOffenses = RuleBreakLedger.offensesToday(v.habitId);

    return Container(
      width: 320,
      padding: const EdgeInsets.fromLTRB(24, 26, 24, 22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A0606), Color(0xFF0A0303)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.error.withOpacity(0.5), width: 1),
        boxShadow: [
          BoxShadow(
            color: AppColors.error.withOpacity(0.30),
            blurRadius: 40,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 6,
                height: 22,
                decoration: BoxDecoration(
                  color: AppColors.error,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(
                      text: 'Habit',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                    TextSpan(
                      text: 'Drill',
                      style: TextStyle(
                        color: AppColors.error,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                date,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.35),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Text(
            v.habitTitle.toUpperCase(),
            style: TextStyle(
              color: Colors.white.withOpacity(0.55),
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 3,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Text(
            'BROKEN AT $time',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.w900,
              letterSpacing: -1,
              height: 1,
            ),
          ),
          if (streakLost > 0) ...[
            const SizedBox(height: 10),
            Text(
              'LOST A $streakLost-DAY STREAK',
              style: TextStyle(
                color: AppColors.error.withOpacity(0.85),
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '#${v.offenseNumber}',
                style: TextStyle(
                  color: AppColors.error,
                  fontSize: 66,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -3,
                  height: 1,
                  shadows: [
                    Shadow(color: AppColors.error.withOpacity(0.55), blurRadius: 26),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'OFFENSE',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                        height: 1,
                      ),
                    ),
                    if (todayOffenses > 1) ...[
                      const SizedBox(height: 4),
                      Text(
                        'X$todayOffenses TODAY',
                        style: TextStyle(
                          color: AppColors.error.withOpacity(0.9),
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(height: 1, color: Colors.white.withOpacity(0.06)),
          const SizedBox(height: 12),
          Text(
            line,
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 16,
              fontWeight: FontWeight.w800,
              height: 1.3,
              letterSpacing: -0.1,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                'HABITDRILL.APP',
                style: TextStyle(
                  color: AppColors.error.withOpacity(0.9),
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 3,
                ),
              ),
              const Spacer(),
              Text(
                'THE DRILL SGT. APP',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.3),
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SharePrimaryButton extends StatelessWidget {
  final VoidCallback onTap;
  const _SharePrimaryButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          gradient: AppColors.emeraldGradient,
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(
              color: AppColors.emerald.withOpacity(0.5),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LucideIcons.share2, color: Colors.black, size: 18),
            SizedBox(width: 10),
            Text(
              'SHARE THE SHAME',
              style: TextStyle(
                color: Colors.black,
                fontSize: 14,
                fontWeight: FontWeight.w900,
                letterSpacing: 3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReturnToBaseButton extends StatelessWidget {
  final VoidCallback onTap;
  const _ReturnToBaseButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Text(
          'RETURN TO BASE',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withOpacity(0.55),
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 2.5,
          ),
        ),
      ),
    );
  }
}
