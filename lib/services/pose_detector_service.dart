import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:camera/camera.dart';
import 'dart:typed_data';
import 'dart:ui' show Size;
import 'dart:io' show Platform;

/// Service for detecting human poses using Google ML Kit
/// Returns RAW ML Kit data for maximum responsiveness
class PoseDetectorService {
  late PoseDetector _poseDetector;
  bool _isProcessing = false;
  int sensorOrientation = 270; // default 270 for front camera

  PoseDetectorService() {
    // Initialize with stream mode for real-time video
    final options = PoseDetectorOptions(
      mode: PoseDetectionMode.stream,
    );
    _poseDetector = PoseDetector(options: options);
  }

  /// Process a camera frame and return detected pose landmarks
  /// Returns null if no pose detected or if still processing previous frame
  Future<List<PoseLandmark>?> detectPose(CameraImage image) async {
    // Drop frame if still processing previous one (performance optimization)
    if (_isProcessing) {
      return null;
    }

    _isProcessing = true;

    try {
      // Convert CameraImage to InputImage for ML Kit
      final inputImage = _convertCameraImage(image);
      if (inputImage == null) {
        _isProcessing = false;
        return null;
      }

      // Detect pose
      final poses = await _poseDetector.processImage(inputImage);

      _isProcessing = false;

      // Return landmarks from first detected pose
      if (poses.isNotEmpty) {
        return poses.first.landmarks.values.toList();
      }

      return null;
    } catch (e) {
      _isProcessing = false;
      return null;
    }
  }

  /// Returns all detected poses for TargetLock filtering
  Future<List<Pose>?> detectAllPoses(CameraImage image) async {
    if (_isProcessing) return null;
    _isProcessing = true;

    try {
      final inputImage = _convertCameraImage(image);
      if (inputImage == null) { _isProcessing = false; return null; }

      final poses = await _poseDetector.processImage(inputImage);
      _isProcessing = false;
      return poses.isNotEmpty ? poses : null;
    } catch (e) {
      _isProcessing = false;
      return null;
    }
  }

  /// Convert CameraImage to InputImage for ML Kit processing
  InputImage? _convertCameraImage(CameraImage image) {
    try {
      InputImageRotation imageRotation;
      if (Platform.isAndroid) {
        // Use actual camera sensor orientation — not hardcoded
        imageRotation = InputImageRotationValue.fromRawValue(sensorOrientation)
            ?? InputImageRotation.rotation270deg;
      } else {
        imageRotation = InputImageRotation.rotation0deg;
      }

      final Size imageSize = Size(
        image.width.toDouble(),
        image.height.toDouble(),
      );

      // Android uses YUV_420_888, need to convert to NV21
      if (Platform.isAndroid) {
        return _convertYUV420ToInputImage(image, imageSize, imageRotation);
      } else {
        // iOS uses BGRA format
        return _convertBGRAToInputImage(image, imageSize, imageRotation);
      }
    } catch (e) {
      print('❌ Error converting camera image: $e');
      return null;
    }
  }

  /// Convert YUV_420_888 (Android) to NV21 format for ML Kit
  InputImage? _convertYUV420ToInputImage(
    CameraImage image,
    Size imageSize,
    InputImageRotation rotation,
  ) {
    try {
      final int width = image.width;
      final int height = image.height;
      
      final int yRowStride = image.planes[0].bytesPerRow;
      final int uvRowStride = image.planes[1].bytesPerRow;
      final int uvPixelStride = image.planes[1].bytesPerPixel ?? 1;

      // NV21 format: Y plane followed by interleaved VU
      final int ySize = width * height;
      final int uvSize = width * height ~/ 2;
      final Uint8List nv21 = Uint8List(ySize + uvSize);

      // Copy Y plane
      final Uint8List yPlane = image.planes[0].bytes;
      int yIndex = 0;
      for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
          nv21[yIndex++] = yPlane[y * yRowStride + x];
        }
      }

      // Interleave V and U planes (NV21 is VUVU...)
      final Uint8List uPlane = image.planes[1].bytes;
      final Uint8List vPlane = image.planes[2].bytes;
      
      int uvIndex = ySize;
      for (int y = 0; y < height ~/ 2; y++) {
        for (int x = 0; x < width ~/ 2; x++) {
          final int uvOffset = y * uvRowStride + x * uvPixelStride;
          nv21[uvIndex++] = vPlane[uvOffset]; // V first for NV21
          nv21[uvIndex++] = uPlane[uvOffset]; // U second
        }
      }

      final metadata = InputImageMetadata(
        size: imageSize,
        rotation: rotation,
        format: InputImageFormat.nv21,
        bytesPerRow: width,
      );

      return InputImage.fromBytes(
        bytes: nv21,
        metadata: metadata,
      );
    } catch (e) {
      print('❌ Error converting YUV420: $e');
      return null;
    }
  }

  /// Convert BGRA (iOS) to InputImage
  InputImage? _convertBGRAToInputImage(
    CameraImage image,
    Size imageSize,
    InputImageRotation rotation,
  ) {
    try {
      final metadata = InputImageMetadata(
        size: imageSize,
        rotation: rotation,
        format: InputImageFormat.bgra8888,
        bytesPerRow: image.planes[0].bytesPerRow,
      );

      return InputImage.fromBytes(
        bytes: image.planes[0].bytes,
        metadata: metadata,
      );
    } catch (e) {
      print('❌ Error converting BGRA: $e');
      return null;
    }
  }

  /// Clean up resources
  void dispose() {
    _poseDetector.close();
  }
}
