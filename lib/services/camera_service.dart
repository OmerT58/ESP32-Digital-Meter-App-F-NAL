/// camera_service.dart
/// ─────────────────────────────────────────────────────────────
/// Manages the device camera lifecycle. Wraps CameraController
/// as a ChangeNotifier so the widget tree reacts to init state.
/// ─────────────────────────────────────────────────────────────
library;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

class CameraService extends ChangeNotifier {
  CameraController? _controller;
  bool   _isInitialized = false;
  String? errorMessage;
  bool _isStreaming = false;

  CameraController? get controller    => _controller;
  bool              get isInitialized => _isInitialized;

  Future<void> initialize() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        errorMessage = 'No camera found on device.';
        notifyListeners();
        return;
      }

      // Prefer back camera
      final cam = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      _controller = CameraController(
        cam,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: defaultTargetPlatform == TargetPlatform.iOS 
            ? ImageFormatGroup.bgra8888 
            : ImageFormatGroup.yuv420,
      );

      await _controller!.initialize();
      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      errorMessage = e.toString();
      notifyListeners();
    }
  }

  void startTracking(void Function(CameraImage) onImage) {
    if (_controller != null && _isInitialized && !_isStreaming) {
      _controller!.startImageStream((image) {
        onImage(image);
      });
      _isStreaming = true;
    }
  }

  void stopTracking() {
    if (_controller != null && _isStreaming) {
      _controller!.stopImageStream();
      _isStreaming = false;
    }
  }

  @override
  void dispose() {
    if (_isStreaming) {
      _controller?.stopImageStream();
    }
    _controller?.dispose();
    super.dispose();
  }
}
