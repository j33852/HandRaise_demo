import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

class HandRaiseViewModel extends ChangeNotifier {
  CameraController? cameraController;
  late PoseDetector _poseDetector;
  bool _isProcessing = false;
  bool isHandRaised = false;

  int _raiseFrameCount = 0;
  static const int _requiredFrames = 3; 

  HandRaiseViewModel() {
    final options = PoseDetectorOptions(
      model: PoseDetectionModel.base,
      mode: PoseDetectionMode.stream,
    );
    _poseDetector = PoseDetector(options: options);
  }

  Future<void> initializeCamera(CameraDescription camera) async {
    cameraController = CameraController(
      camera,
      ResolutionPreset.high,
      imageFormatGroup: Platform.isIOS ? ImageFormatGroup.bgra8888 : ImageFormatGroup.yuv420,
      enableAudio: false,
    );

    await cameraController?.initialize();
    notifyListeners();

    cameraController?.startImageStream((CameraImage image) {
      if (_isProcessing) return;
      _isProcessing = true;
      _processCameraImage(image, camera);
    });
  }

  Future<void> _processCameraImage(CameraImage image, CameraDescription camera) async {
    try {
      final sensorOrientation = camera.sensorOrientation;
      final InputImageRotation? rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
      if (rotation == null) return;

      final InputImageFormat? format = InputImageFormatValue.fromRawValue(image.format.raw);
      if (format == null ||
          (Platform.isAndroid && format != InputImageFormat.yuv420) ||
          (Platform.isIOS && format != InputImageFormat.bgra8888)) {
        return; 
      }

      final WriteBuffer allBytes = WriteBuffer();
      for (final Plane plane in image.planes) {
        allBytes.putUint8List(plane.bytes);
      }
      final bytes = allBytes.done().buffer.asUint8List();

      final metadata = InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes.first.bytesPerRow,
      );

      final inputImage = InputImage.fromBytes(bytes: bytes, metadata: metadata);
      final poses = await _poseDetector.processImage(inputImage);
      _detectHandRaise(poses);

    } catch (e) {
      debugPrint("画像処理エラー: $e");
    } finally {
      _isProcessing = false;
    }
  }

  // 判定ロジックの強化（厳格な条件判定）
  void _detectHandRaise(List<Pose> poses) {
    bool currentFrameDetected = false;
    // 確信度のしきい値を0.8以上に引き上げ、人間以外の誤認を排除
    const double confidenceThreshold = 0.8; 

    for (Pose pose in poses) {
      final leftShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
      final rightShoulder = pose.landmarks[PoseLandmarkType.rightShoulder];
      final leftWrist = pose.landmarks[PoseLandmarkType.leftWrist];
      final rightWrist = pose.landmarks[PoseLandmarkType.rightWrist];
      final leftElbow = pose.landmarks[PoseLandmarkType.leftElbow];
      final rightElbow = pose.landmarks[PoseLandmarkType.rightElbow];

      // 左手の厳格判定
      if (leftShoulder != null && leftWrist != null && leftElbow != null) {
        if (leftShoulder.likelihood > confidenceThreshold &&
            leftWrist.likelihood > confidenceThreshold &&
            leftElbow.likelihood > confidenceThreshold) {
          
          double armLength = (leftShoulder.y - leftElbow.y).abs();
          // 手首が肩よりも「腕の長さ分(1.0)」以上高い位置にあることを条件にする
          double margin = armLength * 1.0;

          // 条件：手首が肩より遥かに高い ＆ 肘も肩と同じかそれより高い位置にある
          if (leftWrist.y < (leftShoulder.y - margin) && leftElbow.y < (leftShoulder.y + (margin * 0.2))) {
            currentFrameDetected = true;
            break;
          }
        }
      }

      // 右手の厳格判定
      if (!currentFrameDetected && rightShoulder != null && rightWrist != null && rightElbow != null) {
        if (rightShoulder.likelihood > confidenceThreshold &&
            rightWrist.likelihood > confidenceThreshold &&
            rightElbow.likelihood > confidenceThreshold) {
          
          double armLength = (rightShoulder.y - rightElbow.y).abs();
          double margin = armLength * 1.0;

          if (rightWrist.y < (rightShoulder.y - margin) && rightElbow.y < (rightShoulder.y + (margin * 0.2))) {
            currentFrameDetected = true;
            break;
          }
        }
      }
    }

    if (currentFrameDetected) {
      _raiseFrameCount++;
    } else {
      _raiseFrameCount = 0;
    }

    bool shouldBeRaised = _raiseFrameCount >= _requiredFrames;

    if (isHandRaised != shouldBeRaised) {
      isHandRaised = shouldBeRaised;
      notifyListeners(); 
    }
  }

  @override
  void dispose() {
    cameraController?.dispose();
    _poseDetector.close();
    super.dispose();
  }
}