import 'dart:math' as math;
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/ble_service.dart';

class LaserTrackingService extends ChangeNotifier {
  static const int roiSize = 200;
  static const int _missingFramesThreshold = 5;
<<<<<<< HEAD

  // Orientation — updated from HomeScreen via updateSnapshotDrawing
  bool _isLandscape = false;

=======
  
>>>>>>> 0603b4c11bdf8cd3d14e798584dbc93e36792e21
  // State
  Offset? _trackedCentroid; // Coordinates in pixels relative to the ROI center
  String _status = 'Off Target';
  int _missingFramesCount = 0;
<<<<<<< HEAD

=======
  
>>>>>>> 0603b4c11bdf8cd3d14e798584dbc93e36792e21
  // Expose basic dimensions
  double imgWidth = 0;
  double imgHeight = 0;

  // Smoothing
  Offset? _emaCentroid;
  static const double _emaAlpha = 0.15; // Smooths roughly over 10-15 frames

  // Debug Mode
  static const bool debugMode = true;
  Offset? _rawCentroid; // Raw brightest/reddest pixel before smoothing
  int _lastLogTime = 0;

  Offset? get trackedCentroid => _trackedCentroid;
  Offset? get rawCentroid => _rawCentroid;
  String get status => _status;

  bool _isProcessing = false;

  // Measurement State
  int _lastButtonState = 0;
  Vector3D? _pointA;
  Vector3D? _pointB;
  double? _measuredDistanceCm;
  bool _isRecording = false;

  // Snapshot & Area State
  bool _isSnapshotMode = false;
  Vector3D? _initialAngles;
  double _initialDistance = 0.0;
  final List<Offset> _drawingPath = [];
  double? _calculatedAreaCm2;

  // Two-Tap mode
  bool _isTwoTapMode = false;
  Offset? _twoTapPointA;           // First tap anchor (screen coords)
  Offset? _livePreviewPoint;       // Live crosshair position for preview line
  int _twoTapClickCount = 0;       // 0 = waiting for 1st tap, 1 = waiting for 2nd tap

  Vector3D? get pointA => _pointA;
  Vector3D? get pointB => _pointB;
  double? get measuredDistanceCm => _measuredDistanceCm;
  bool get isRecording => _isRecording;
  bool get isSnapshotMode => _isSnapshotMode;
  bool get isTwoTapMode => _isTwoTapMode;
  Offset? get twoTapPointA => _twoTapPointA;
  Offset? get livePreviewPoint => _livePreviewPoint;
  List<Offset> get drawingPath => _drawingPath;
  double? get calculatedAreaCm2 => _calculatedAreaCm2;

  /// Toggle between continuous-draw and two-tap modes.
  void setTwoTapMode(bool enabled) {
    _isTwoTapMode = enabled;
    _twoTapPointA = null;
    _livePreviewPoint = null;
    _twoTapClickCount = 0;
    notifyListeners();
  }

  void toggleSnapshotMode(bool enable, {double currentDist = 0, double currentRoll = 0, double currentPitch = 0, double currentYaw = 0}) {
    _isSnapshotMode = enable;
    if (enable) {
       _initialDistance = currentDist;
       _initialAngles = Vector3D(currentRoll, currentPitch, currentYaw);
       _drawingPath.clear();
       _calculatedAreaCm2 = null;
    } else {
      _drawingPath.clear();
      _calculatedAreaCm2 = null;
      _initialAngles = null;
    }
    notifyListeners();
  }

<<<<<<< HEAD
  // Sidebar width that is subtracted in landscape (must match kSidebarWidth in home_screen)
  static const double _sidebarWidth = 84.0;

  /// Converts current angle deltas to a screen-space Offset.
  /// Matches the effectiveCenter logic in HomeScreen:
  ///   Portrait  → centre of top 80 % of screen height
  ///   Landscape → centre of the area to the right of the sidebar
  Offset _anglestoScreen(double pitch, double yaw, Size screenSize,
      {bool isLandscape = false}) {
=======
  /// Converts current angle deltas to a screen-space Offset relative to effectiveCenter.
  Offset _anglestoScreen(double pitch, double yaw, Size screenSize) {
>>>>>>> 0603b4c11bdf8cd3d14e798584dbc93e36792e21
    final dPitch = pitch - _initialAngles!.y;
    final dYaw   = yaw   - _initialAngles!.z;

    final d = _initialDistance;
    final fovHRads = 60.0 * math.pi / 180.0;
    final fovVRads = 45.0 * math.pi / 180.0;

<<<<<<< HEAD
    // Usable drawing area dimensions
    final double usableW =
        isLandscape ? screenSize.width - _sidebarWidth : screenSize.width;
    final double usableH =
        isLandscape ? screenSize.height : screenSize.height * 0.8;

    final wReal = 2 * d * math.tan(fovHRads / 2);
    final hReal = 2 * d * math.tan(fovVRads / 2);

    final scaleX = wReal > 0 ? usableW / wReal : 0.0;
    final scaleY = hReal > 0 ? usableH / hReal : 0.0;

    final dx = -d * math.tan(dYaw   * math.pi / 180.0) * scaleX;
    final dy =  d * math.tan(dPitch * math.pi / 180.0) * scaleY;

    // Effective centre coordinates in screen space
    final double startX = isLandscape
        ? _sidebarWidth + usableW / 2
        : screenSize.width / 2;
    final double startY = isLandscape
        ? screenSize.height / 2
        : usableH / 2;

    return Offset(startX + dx, startY + dy);
  }

  void updateSnapshotDrawing(List<double> bleData, Size screenSize,
      {bool isLandscape = false}) {
    _isLandscape = isLandscape;
=======
    final wReal = 2 * d * math.tan(fovHRads / 2);
    final hReal = 2 * d * math.tan(fovVRads / 2);

    final scaleX = wReal > 0 ? screenSize.width  / wReal : 0.0;
    final scaleY = hReal > 0 ? screenSize.height / hReal : 0.0;

    final dx = -d * math.tan(dYaw   * math.pi / 180.0) * scaleX; // inverted: right turn → right on screen
    final dy =  d * math.tan(dPitch * math.pi / 180.0) * scaleY;

    final startX = screenSize.width  / 2;
    final startY = (screenSize.height * 0.8) / 2;
    return Offset(startX + dx, startY - dy); // Pitch up → Y decreases
  }

  void updateSnapshotDrawing(List<double> bleData, Size screenSize) {
>>>>>>> 0603b4c11bdf8cd3d14e798584dbc93e36792e21
    if (!_isSnapshotMode || _initialAngles == null) return;
    if (bleData.length < 5) return;

    final buttonState = bleData[4].toInt();
    final pitch = bleData[2];
    final yaw   = bleData[3];

    if (_isTwoTapMode) {
      // ── Two-Tap Mode ──────────────────────────────────────────
<<<<<<< HEAD
      final currentPt =
          _anglestoScreen(pitch, yaw, screenSize, isLandscape: isLandscape);
=======
      final currentPt = _anglestoScreen(pitch, yaw, screenSize);
>>>>>>> 0603b4c11bdf8cd3d14e798584dbc93e36792e21

      // Always update the live preview position
      _livePreviewPoint = currentPt;

      final isClick = (buttonState == 1 && _lastButtonState == 0);
      if (isClick) {
        if (_twoTapClickCount == 0) {
          // First click → capture Point A
          _twoTapPointA   = currentPt;
          _twoTapClickCount = 1;
        } else {
          // Second click → draw permanent line A→B
          if (_twoTapPointA != null) {
            _drawingPath.add(_twoTapPointA!);
            _drawingPath.add(currentPt);
            // Keep pointA as new anchor for connected lines
            _twoTapPointA   = currentPt;
            // Stay in _twoTapClickCount == 1 so next click is the next B
          }
        }
        notifyListeners();
      } else {
        // Just live preview movement
        notifyListeners();
      }
    } else {
      // ── Continuous Draw Mode ──────────────────────────────────
      if (buttonState == 1) {
<<<<<<< HEAD
        final currentPt =
            _anglestoScreen(pitch, yaw, screenSize, isLandscape: isLandscape);
=======
        final currentPt = _anglestoScreen(pitch, yaw, screenSize);
>>>>>>> 0603b4c11bdf8cd3d14e798584dbc93e36792e21
        if (_drawingPath.isEmpty || (_drawingPath.last - currentPt).distance > 2.0) {
          _drawingPath.add(currentPt);
          notifyListeners();
        }
      } else if (_lastButtonState == 1 && buttonState == 0) {
        // Button released → close shape if endpoints are close
        if (_drawingPath.length > 2) {
          final distToStart = (_drawingPath.first - _drawingPath.last).distance;
          if (distToStart < 40.0) {
            _drawingPath.add(_drawingPath.first);
            _calculateArea(screenSize);
          }
        }
      }
    }
    _lastButtonState = buttonState;
  }

  void _calculateArea(Size screenSize) {
    if (_drawingPath.length < 3) return;
    double areaPx = 0.0;
    for (int i = 0; i < _drawingPath.length - 1; i++) {
      areaPx += _drawingPath[i].dx * _drawingPath[i+1].dy;
      areaPx -= _drawingPath[i+1].dx * _drawingPath[i].dy;
    }
    areaPx = (areaPx.abs()) / 2.0;

    final d = _initialDistance; // in cm
    final fovHRads = 60.0 * math.pi / 180.0;
    final fovVRads = 45.0 * math.pi / 180.0;
    final wReal = 2 * d * math.tan(fovHRads / 2);
    final hReal = 2 * d * math.tan(fovVRads / 2);
    
    final pixelAreaInCm2 = (wReal / screenSize.width) * (hReal / screenSize.height);
    _calculatedAreaCm2 = areaPx * pixelAreaInCm2;
    notifyListeners();
  }

  void processImage(CameraImage image, BleService bleService) {
    if (_isProcessing) return;
    _isProcessing = true;

    try {
      imgWidth = image.width.toDouble();
      imgHeight = image.height.toDouble();
      
      int roiCenterRawX;
      int roiCenterRawY;
<<<<<<< HEAD

      // The camera sensor stream is rotated relative to the screen.
      // imgWidth > imgHeight means the raw sensor is landscape-rotated.
      //
      // Portrait UI  → effective centre = top-80% centre of screen
      //   Sensor rotated (imgW > imgH): sensorX ↔ screenY, sensorY ↔ screenX
      //     roiCenterRawX maps to the 80%-height half → (imgWidth * 0.8) / 2
      //     roiCenterRawY maps to screen horizontal centre → imgHeight / 2
      //   Sensor portrait (imgW < imgH): standard mapping
      //     roiCenterRawX = imgWidth / 2
      //     roiCenterRawY = (imgHeight * 0.8) / 2
      //
      // Landscape UI → effective centre = centre of right area (sidebar offset)
      //   Sidebar fraction of screen width = kSidebarWidth / screenWidth.
      //   Because sensor coords are rotated we adjust the primary axis.
      if (_isLandscape) {
        // In landscape UI the sidebar is on the left; the usable horizontal
        // fraction starts after the sidebar.  The sensor's primary axis that
        // maps to screen-X differs by rotation state.
        if (imgWidth > imgHeight) {
          // Rotated sensor: sensorX → screenY, sensorY → screenX
          // Sensor centre for screen-Y (= sensorX) stays at mid-height → imgWidth/2
          // Sensor centre for screen-X (= sensorY): shift by sidebar fraction
          final sidebarFrac = _sidebarWidth / (imgHeight * 2); // approx
          roiCenterRawX = (imgWidth / 2).toInt();
          roiCenterRawY = (imgHeight * (0.5 + sidebarFrac / 2)).toInt();
        } else {
          // Non-rotated sensor, landscape UI
          final sidebarFrac = _sidebarWidth / imgWidth;
          roiCenterRawX =
              (imgWidth * (sidebarFrac + (1.0 - sidebarFrac) / 2)).toInt();
          roiCenterRawY = (imgHeight / 2).toInt();
        }
      } else {
        // Portrait UI
        if (imgWidth > imgHeight) {
          // Rotated 90° sensor on portrait screen
          roiCenterRawX = ((imgWidth * 0.8) / 2).toInt();
          roiCenterRawY = (imgHeight / 2).toInt();
        } else {
          roiCenterRawX = (imgWidth / 2).toInt();
          roiCenterRawY = ((imgHeight * 0.8) / 2).toInt();
        }
=======
      
      // Calculate ROI coordinates mapping screen top-80% center to raw sensor
      if (imgWidth > imgHeight) {
        // Rotated 90 degrees (landscape sensor on portrait screen)
        // Screen Y maps to Sensor X. Screen X maps to Sensor Y.
        roiCenterRawX = ((imgWidth * 0.8) / 2).toInt();
        roiCenterRawY = (imgHeight / 2).toInt();
      } else {
        // Portrait sensor
        roiCenterRawX = (imgWidth / 2).toInt();
        roiCenterRawY = ((imgHeight * 0.8) / 2).toInt();
>>>>>>> 0603b4c11bdf8cd3d14e798584dbc93e36792e21
      }
      
      final roiStartX = roiCenterRawX - (roiSize ~/ 2);
      final roiStartY = roiCenterRawY - (roiSize ~/ 2);
      
      if (roiStartX < 0 || roiStartY < 0) {
        _isProcessing = false;
        return;
      }

      int sumX = 0;
      int sumY = 0;
      int pixelCount = 0;

      int maxR = 0;
      int maxG = 0;
      int maxB = 0;
      int maxImgX = 0;
      int maxImgY = 0;
      int maxBrightness = -1;

      // Handle different image formats
      if (image.format.group == ImageFormatGroup.yuv420) {
        final planeY = image.planes[0];
        final planeU = image.planes[1];
        final planeV = image.planes[2];

        final yStride = planeY.bytesPerRow;
        final uvStride = planeU.bytesPerRow;
        final uvPixelStride = planeU.bytesPerPixel ?? 1;

        for (int y = 0; y < roiSize; y++) {
          final imgY = roiStartY + y;
          for (int x = 0; x < roiSize; x++) {
            final imgX = roiStartX + x;

            final yIndex = imgY * yStride + imgX;
            final uvIndex = (imgY ~/ 2) * uvStride + (imgX ~/ 2) * uvPixelStride;

            final luma = planeY.bytes[yIndex];
            final u = planeU.bytes[uvIndex];
            final v = planeV.bytes[uvIndex];

            // Simplified YUV to RGB for red tracking
            final int r = (luma + 1.402 * (v - 128)).round().clamp(0, 255);
            final int g = (luma - 0.344 * (u - 128) - 0.714 * (v - 128)).round().clamp(0, 255);
            final int b = (luma + 1.772 * (u - 128)).round().clamp(0, 255);
            
            final int brightness = math.max(r, math.max(g, b));
            final int redness = r - math.max(g, b);
            
            if (brightness > maxBrightness) {
              maxBrightness = brightness;
              maxR = r; maxG = g; maxB = b;
              maxImgX = imgX; maxImgY = imgY;
            }

            final bool isWhiteCore = brightness > 230 && (r - g).abs() < 30 && (r - b).abs() < 30 && (g - b).abs() < 30;
            final bool isRedHalo = brightness > 200 && r > g * 1.5 && r > b * 1.5;

            if (isWhiteCore || isRedHalo) {
              sumX += imgX;
              sumY += imgY;
              pixelCount++;
            }
          }
        }
      } else if (image.format.group == ImageFormatGroup.bgra8888) {
        final plane = image.planes[0];
        final stride = plane.bytesPerRow;

        for (int y = 0; y < roiSize; y++) {
          final imgY = roiStartY + y;
          for (int x = 0; x < roiSize; x++) {
            final imgX = roiStartX + x;
            final index = imgY * stride + imgX * 4;

            final b = plane.bytes[index];
            final g = plane.bytes[index + 1];
            final r = plane.bytes[index + 2];
            
            final int brightness = math.max(r, math.max(g, b));
            final int redness = r - math.max(g, b);

            if (brightness > maxBrightness) {
              maxBrightness = brightness;
              maxR = r; maxG = g; maxB = b;
              maxImgX = imgX; maxImgY = imgY;
            }

            final bool isWhiteCore = brightness > 230 && (r - g).abs() < 30 && (r - b).abs() < 30 && (g - b).abs() < 30;
            final bool isRedHalo = brightness > 200 && r > g * 1.5 && r > b * 1.5;

            if (isWhiteCore || isRedHalo) {
              sumX += imgX;
              sumY += imgY;
              pixelCount++;
            }
          }
        }
      }

      // 1-second Throttled Debug Logging
      final now = DateTime.now().millisecondsSinceEpoch;
      if (debugMode && now - _lastLogTime > 1000) {
        _lastLogTime = now;
        final hsv = HSVColor.fromColor(Color.fromARGB(255, maxR, maxG, maxB));
        debugPrint('--- LASER DEBUG ---');
        debugPrint('Format: ${image.format.group}, Stream Size: ${imgWidth}x${imgHeight}');
        debugPrint('Brightest/Reddest Pixel HSV: H:${hsv.hue.toStringAsFixed(1)} S:${hsv.saturation.toStringAsFixed(2)} V:${hsv.value.toStringAsFixed(2)}');
        debugPrint('Found Pixels in ROI: $pixelCount (Ultra-Tight Threshold)');
        if (imgWidth > imgHeight) {
          debugPrint('WARNING: Image width > height. Camera stream is rotated 90 degrees! Coordinates may be swapped.');
        }
      }

      if (pixelCount > 0) {
        double rawDispX = maxImgX - roiCenterRawX.toDouble();
        double rawDispY = maxImgY - roiCenterRawY.toDouble();
        
        // Handle potential 90-degree rotation swapping
        if (imgWidth > imgHeight) {
           _rawCentroid = Offset(rawDispY, rawDispX);
        } else {
           _rawCentroid = Offset(rawDispX, rawDispY);
        }

        final double centroidX = sumX / pixelCount;
        final double centroidY = sumY / pixelCount;
        
        // Displacement from the effective center of the image
        double dispRawX = centroidX - roiCenterRawX.toDouble();
        double dispRawY = centroidY - roiCenterRawY.toDouble();

        double dispX = dispRawX;
        double dispY = dispRawY;

        // Swap coordinates if rotated
        if (imgWidth > imgHeight) {
          dispX = dispRawY;
          dispY = dispRawX;
        }

        final currentPt = Offset(dispX, dispY);

        // Apply Exponential Moving Average (EMA)
        if (_emaCentroid == null) {
          _emaCentroid = currentPt;
        } else {
          _emaCentroid = Offset(
            (currentPt.dx * _emaAlpha) + (_emaCentroid!.dx * (1 - _emaAlpha)),
            (currentPt.dy * _emaAlpha) + (_emaCentroid!.dy * (1 - _emaAlpha)),
          );
        }
        
        _trackedCentroid = _emaCentroid;
        _missingFramesCount = 0;
        
        final double distToCenter = math.sqrt(_trackedCentroid!.dx * _trackedCentroid!.dx + _trackedCentroid!.dy * _trackedCentroid!.dy);
        if (distToCenter <= 15.0) {
          _status = 'On Target';
        } else {
          _status = 'Off Target';
        }
      } else {
        double rawDispX = maxImgX - roiCenterRawX.toDouble();
        double rawDispY = maxImgY - roiCenterRawY.toDouble();
        if (imgWidth > imgHeight) {
           _rawCentroid = Offset(rawDispY, rawDispX);
        } else {
           _rawCentroid = Offset(rawDispX, rawDispY);
        }

        _missingFramesCount++;
        if (_missingFramesCount > _missingFramesThreshold) {
          _trackedCentroid = null;
          _emaCentroid = null;
          _status = 'Off Target';
        }
      }

      // ── Measurement Logic ───────────────────────────────────────────
      if (bleService.latestData.length >= 5) {
        final distanceMm = bleService.latestData[0];
        final rollDeg = bleService.latestData[1];
        final pitchDeg = bleService.latestData[2];
        final buttonState = bleService.latestData[4].toInt();

        if (_status == 'On Target' && distanceMm > 0) {
          final d = distanceMm / 10.0; // convert to cm
          final roll = rollDeg * math.pi / 180.0;
          final pitch = pitchDeg * math.pi / 180.0;
          
          final z = d * math.cos(pitch) * math.cos(roll);
          final x = d * math.sin(roll);
          final y = d * math.sin(pitch);
          
          final currentPoint = Vector3D(x, y, z);
          
          if (buttonState == 1 && _lastButtonState == 0) {
            // Button Pressed
            if (!_isRecording) {
              // Start measuring: Point A
              _pointA = currentPoint;
              _pointB = null;
              _measuredDistanceCm = null;
              _isRecording = true;
            } else {
              // Stop measuring: Point B
              _pointB = currentPoint;
              _measuredDistanceCm = _pointA!.distanceTo(_pointB!);
              _isRecording = false;
            }
          } else if (_isRecording) {
            // Continuously update distance while in recording mode
            _measuredDistanceCm = _pointA!.distanceTo(currentPoint);
          }
        }
        
        _lastButtonState = buttonState;
      }

    } catch (e) {
      debugPrint('Error processing frame: $e');
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }

  // Displacement in cm
  Offset? getDisplacementCm(double distanceMm, double fovH, double fovV, double widgetWidth, double widgetHeight) {
    if (_trackedCentroid == null) return null;

    final double d = distanceMm / 10.0; // cm

    final double fovHRads = fovH * math.pi / 180.0;
    final double fovVRads = fovV * math.pi / 180.0;

    final double wReal = 2 * d * math.tan(fovHRads / 2);
    final double hReal = 2 * d * math.tan(fovVRads / 2);

    final double scaleX = wReal / widgetWidth;
    final double scaleY = hReal / widgetHeight;

    return Offset(_trackedCentroid!.dx * scaleX, _trackedCentroid!.dy * scaleY);
  }
}

class Vector3D {
  final double x, y, z;
  Vector3D(this.x, this.y, this.z);

  double distanceTo(Vector3D other) {
    final dx = other.x - x;
    final dy = other.y - y;
    final dz = other.z - z;
    return math.sqrt(dx * dx + dy * dy + dz * dz);
  }
}
