import 'dart:math' as math;
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/ble_service.dart';

class LaserTrackingService extends ChangeNotifier {
  static const int roiSize = 200;
  static const int _missingFramesThreshold = 5;

  // Orientation — updated from HomeScreen via updateSnapshotDrawing
  bool _isLandscape = false;

  // State
  Offset? _trackedCentroid; // Coordinates in pixels relative to the ROI center
  String _status = 'Off Target';
  int _missingFramesCount = 0;

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

  // Measurement history (real entries, shown in drawer)
  List<String> measureHistory = [];

  // Drag-to-Box: remember the first-point 3D vector for width/height calc
  Vector3D? _dragStartPhysical;
  double    _lastDistanceMm = 0.0; // most recent VL53L0X reading

  // Two-Tap Geometric Mode
  bool _isTwoTapMode = false;
  String selectedShape = 'Rectangle'; // 'Rectangle' or 'Circle'
  Offset? _twoTapPointA;
  Offset? _twoTapPointB;
  Offset? _livePreviewPoint;
  int _twoTapClickCount = 0;
  Vector3D? _physicalPointA;
  Vector3D? _physicalPointB;
  double? _geoAreaCm2;
  double? _geoPerimeterCm;

  double currentCameraYaw = 0.0;
  double currentCameraPitch = 0.0;
  double sensitivityMultiplier = 15.0;

  // Screen-freeze — STATE 0 ↔ STATE 1 transition
  bool isScreenFrozen = false;

  /// Toggle the freeze state.
  /// • STATE 0 → STATE 1 (freeze): tare gyro, clear old path, freeze camera.
  /// • STATE 1 → STATE 0 (unfreeze): reset gyro, camera resumes via caller.
  void toggleFreeze() {
    isScreenFrozen = !isScreenFrozen;
    if (isScreenFrozen) {
      currentCameraYaw   = 0.0;
      currentCameraPitch = 0.0;
      _drawingPath.clear();
      _calculatedAreaCm2 = null;
      _twoTapPointA      = null;
      _twoTapPointB      = null;
      _livePreviewPoint  = null;
      _twoTapClickCount  = 0;
      _physicalPointA    = null;
      _physicalPointB    = null;
      _geoAreaCm2        = null;
      _geoPerimeterCm    = null;
      _dragStartPhysical = null;
    } else {
      currentCameraYaw   = 0.0;
      currentCameraPitch = 0.0;
    }
    notifyListeners();
  }

  /// Full reset — clears drawings, history, exits freeze, resumes crosshair.
  void resetAll() {
    isScreenFrozen     = false;
    currentCameraYaw   = 0.0;
    currentCameraPitch = 0.0;
    _drawingPath.clear();
    measureHistory.clear();
    _calculatedAreaCm2 = null;
    _twoTapPointA      = null;
    _twoTapPointB      = null;
    _livePreviewPoint  = null;
    _twoTapClickCount  = 0;
    _physicalPointA    = null;
    _physicalPointB    = null;
    _geoAreaCm2        = null;
    _geoPerimeterCm    = null;
    _dragStartPhysical = null;
    notifyListeners();
  }

  // Last-known screen size — set on every updateSnapshotDrawing call
  Size _lastScreenSize = Size.zero;

  // Live pointer position — updated every BLE frame.
  Offset _pointerPosition = Offset.zero;

  void adjustSensitivity(double delta) {
    sensitivityMultiplier = (sensitivityMultiplier + delta).clamp(0.5, 999.0);
    notifyListeners();
  }

  /// The live screen position of the flying pointer.
  ///
  /// While in snapshot mode this equals the value computed by
  /// `updateSnapshotDrawing` — i.e.:
  ///   effectiveCenter + trackedCentroid + (gyro * multiplier)
  ///
  /// When NOT in snapshot mode (no BLE frames arriving) it falls back to
  /// the center of the last-known screen so the crosshair stays visible.
  Offset get pointerPosition {
    // Idle: gyro forced to 0 → returns screen center (optic scope rest position).
    // Active: returns live gyro-displaced position.
    if (_pointerPosition != Offset.zero) return _pointerPosition;
    return Offset(
      _lastScreenSize.width  / 2,
      _lastScreenSize.height / 2,
    );
  }

  Vector3D? get pointA => _pointA;
  Vector3D? get pointB => _pointB;
  double? get measuredDistanceCm => _measuredDistanceCm;
  bool get isRecording => _isRecording;
  bool get isSnapshotMode => _isSnapshotMode;
  bool get isTwoTapMode => _isTwoTapMode;
  Offset? get twoTapPointA => _twoTapPointA;
  Offset? get twoTapPointB => _twoTapPointB;
  Offset? get livePreviewPoint => _livePreviewPoint;
  List<Offset> get drawingPath => _drawingPath;
  double? get calculatedAreaCm2 => _calculatedAreaCm2;
  double? get geoAreaCm2 => _geoAreaCm2;
  double? get geoPerimeterCm => _geoPerimeterCm;

  /// Toggle between continuous-draw and two-tap modes.
  void setTwoTapMode(bool enabled) {
    _isTwoTapMode = enabled;
    _twoTapPointA = null;
    _twoTapPointB = null;
    _livePreviewPoint = null;
    _twoTapClickCount = 0;
    _physicalPointA = null;
    _physicalPointB = null;
    _geoAreaCm2 = null;
    _geoPerimeterCm = null;
    notifyListeners();
  }

  /// Set shape type for Two-Tap mode.
  void setShape(String shape) {
    selectedShape = shape;
    // Reset taps so user starts fresh with the new shape
    _twoTapPointA = null;
    _twoTapPointB = null;
    _twoTapClickCount = 0;
    _physicalPointA = null;
    _physicalPointB = null;
    _geoAreaCm2 = null;
    _geoPerimeterCm = null;
    notifyListeners();
  }

  void toggleSnapshotMode(bool enable, {double currentDist = 0, double currentRoll = 0, double currentPitch = 0, double currentYaw = 0}) {
    _isSnapshotMode = enable;
    if (enable) {
       _initialDistance = currentDist;
       _initialAngles = Vector3D(currentRoll, currentPitch, currentYaw);
       _drawingPath.clear();
       _calculatedAreaCm2 = null;
       currentCameraYaw   = 0.0;
       currentCameraPitch = 0.0;
    } else {
      _drawingPath.clear();
      _calculatedAreaCm2 = null;
      _initialAngles = null;
      currentCameraYaw   = 0.0;
      currentCameraPitch = 0.0;
    }
    notifyListeners();
  }

  /// Simulation-mode fast lock: immediately enters snapshot mode using the
  /// current sensor readings as the (0,0) angular origin.
  /// Bypasses all camera-based target detection requirements.
  void forceSimulationLock({
    required double distanceMm,
    required double roll,
    required double pitch,
    required double yaw,
  }) {
    _isSnapshotMode = true;
    _initialDistance = distanceMm / 10.0; // store in cm
    _initialAngles   = Vector3D(roll, pitch, yaw);
    _drawingPath.clear();
    _calculatedAreaCm2 = null;
    // Also reset two-tap state so drawing starts clean
    _twoTapPointA    = null;
    _livePreviewPoint = null;
    _twoTapClickCount = 0;
    _twoTapClickCount = 0;
    currentCameraYaw = 0.0;
    currentCameraPitch = 0.0;
    notifyListeners();
  }

  // ── Sidebar width (must match kSidebarWidth in home_screen) ──────────────
  static const double _sidebarWidth = 84.0;

  /// Returns the effective screen centre for the drawing overlay.
  ///   Portrait  → centre of top 80% of screen height
  ///   Landscape → centre of the area right of the sidebar
  Offset _effectiveCenter(Size screenSize, {bool isLandscape = false}) {
    if (isLandscape) {
      final usableW = screenSize.width - _sidebarWidth;
      return Offset(_sidebarWidth + usableW / 2, screenSize.height / 2);
    }
    return Offset(screenSize.width / 2, (screenSize.height * 0.8) / 2);
  }

  void updateSnapshotDrawing(
    List<double> bleData,
    Size screenSize, {
    bool isLandscape = false,
  }) {
    _isLandscape    = isLandscape;
    _lastScreenSize = screenSize;

    if (bleData.length < 5) return;

    final buttonState = bleData[4].toInt();

    // ── Gyro data (MPU6050) — only sent when button is held ───────────────
    double gy = 0.0;
    double gz = 0.0;
    if (bleData.length >= 8) {
      gy = bleData[6];
      gz = bleData[7];
    }
    // Always capture the latest distance reading
    if (bleData.isNotEmpty && bleData[0] > 0) {
      _lastDistanceMm = bleData[0];
    }
    const double dt = 0.03;

    // ════════════════════════════════════════════════════════════════════════
    // TEST MODE — COMPLETELY ISOLATED FROM STATE MACHINE
    //
    // • Camera NEVER freezes (isScreenFrozen always forced to false).
    // • Hardware trigger held  → gyro integrates (pointer flies).
    // • Hardware trigger released → gyro reset to 0 (pointer snaps to centre).
    // • _drawingPath cleared every frame → canvas stays 100% blank.
    // • Returns early — drawing / geometric logic below NEVER runs.
    // ════════════════════════════════════════════════════════════════════════
    if (selectedShape == 'Test') {
      if (isScreenFrozen) {
        isScreenFrozen = false; // Force-unfreeze — Test never freezes camera
      }
      if (buttonState == 1) {
        currentCameraYaw   += (-gz) * dt;
        currentCameraPitch += ( gy) * dt;
      } else {
        // Snap crosshair back to centre when trigger released
        currentCameraYaw   = 0.0;
        currentCameraPitch = 0.0;
      }
      final double px = (screenSize.width  / 2) + (currentCameraYaw   * sensitivityMultiplier);
      final double py = (screenSize.height / 2) + (currentCameraPitch * sensitivityMultiplier);
      _pointerPosition = Offset(px, py);
      _drawingPath.clear(); // Enforce blank canvas — no residual lines
      _lastButtonState = buttonState;
      notifyListeners();
      return; // ← Exit. Drawing / geometric / freeze logic below skipped.
    }

    // ════════════════════════════════════════════════════════════════════════
    // STATE MACHINE (Rectangle / Circle draw modes only)
    //
    //  STATE 0 — isScreenFrozen == false (LIVE VIEW)
    //    • Camera stream is live (processImage runs normally)
    //    • Force gyro angles to 0 → crosshair stays LOCKED at screen centre
    //    • Hardware trigger is IGNORED for drawing
    //
    //  STATE 1 — isScreenFrozen == true (FROZEN / DRAWING)
    //    • Camera frame is frozen (processImage returns early)
    //    • Gyro integrates freely → crosshair acts as flying mouse pointer
    //    • Hardware trigger held → every frame appends pointer to _drawingPath
    //    • Two-Tap mode: rising edge of trigger captures A then B, computes geo
    // ════════════════════════════════════════════════════════════════════════

    if (!isScreenFrozen) {
      // ── STATE 0: live view ──────────────────────────────────────────────
      currentCameraYaw   = 0.0;
      currentCameraPitch = 0.0;
      _pointerPosition   = Offset(screenSize.width / 2, screenSize.height / 2);
      _lastButtonState   = buttonState;
      notifyListeners();
      return;
    }


    // ── STATE 1: frozen — integrate gyro ───────────────────────────────────
    if (buttonState == 1 && _lastButtonState == 0) {
      // Rising edge: tare gyro so pointer starts from its current position
      // (do NOT reset to 0 here — user may have already moved the crosshair)
    }
    if (buttonState == 1 || _lastButtonState == 1) {
      // Integrate while held OR on the frame button is released
      // Yaw: invert Z → left turn = pointer left
      currentCameraYaw   += (-gz) * dt;
      currentCameraPitch += ( gy) * dt;
    }

    // ── Pointer position (screen-space) ─────────────────────────────────
    final double pointerX = (screenSize.width  / 2) + (currentCameraYaw   * sensitivityMultiplier);
    final double pointerY = (screenSize.height / 2) + (currentCameraPitch * sensitivityMultiplier);
    final Offset currentPointer = Offset(pointerX, pointerY);
    _pointerPosition = currentPointer;

    // ── TWO-TAP mode ─────────────────────────────────────────────────────
    if (_isTwoTapMode) {
      _livePreviewPoint = currentPointer;

      final isRisingEdge = (buttonState == 1 && _lastButtonState == 0);
      if (isRisingEdge) {
        // Build physical 3D point from VL53L0X distance + MPU angles
        Vector3D? physPt;
        if (bleData.isNotEmpty) {
          final distMm = bleData[0];
          if (distMm > 0) {
            final dCm    = distMm / 10.0;
            final pitchR = currentCameraPitch * (math.pi / 180.0);
            final yawR   = currentCameraYaw   * (math.pi / 180.0);
            physPt = Vector3D(
              dCm * math.sin(yawR),                       // X
              dCm * math.sin(pitchR),                     // Y
              dCm * math.cos(pitchR) * math.cos(yawR),   // Z (depth)
            );
          }
        }

        if (_twoTapClickCount == 0) {
          // TAP 1 — set anchor
          _twoTapPointA     = currentPointer;
          _twoTapPointB     = null;
          _physicalPointA   = physPt;
          _physicalPointB   = null;
          _geoAreaCm2       = null;
          _geoPerimeterCm   = null;
          _twoTapClickCount = 1;
        } else {
          // TAP 2 — finalize shape + compute real-world geometry
          _twoTapPointB     = currentPointer;
          _physicalPointB   = physPt;
          _twoTapClickCount = 0;

          if (_physicalPointA != null && _physicalPointB != null) {
            final pa = _physicalPointA!;
            final pb = _physicalPointB!;
            if (selectedShape == 'Circle') {
              final diameter      = pa.distanceTo(pb);
              final radius        = diameter / 2.0;
              _geoAreaCm2     = math.pi * radius * radius;
              _geoPerimeterCm = 2.0 * math.pi * radius;
              measureHistory.add(
                'Daire ─ Alan: ${_geoAreaCm2!.toStringAsFixed(2)} cm²  '
                'Çevre: ${_geoPerimeterCm!.toStringAsFixed(2)} cm',
              );
            } else {
              final w         = (pb.x - pa.x).abs();
              final h         = (pb.y - pa.y).abs();
              _geoAreaCm2     = w * h;
              _geoPerimeterCm = 2.0 * (w + h);
              measureHistory.add(
                'Dikdörtgen ─ Alan: ${_geoAreaCm2!.toStringAsFixed(2)} cm²  '
                'Çevre: ${_geoPerimeterCm!.toStringAsFixed(2)} cm',
              );
            }
          }
        }
      }

    } else {
      // ── CONTINUOUS draw mode ─────────────────────────────────────────────
      // TEST mode: trigger only moves the crosshair — no drawing at all.
      if (selectedShape != 'Test' && buttonState == 1) {
        _drawingPath.add(currentPointer);
        // On the very first held frame, record the 3D start point
        if (_lastButtonState == 0) {
          _dragStartPhysical = _build3dPoint();
        }
      }

      // ── FALLING EDGE: trigger released ─────────────────────────────────
      if (_lastButtonState == 1 && buttonState == 0 && _drawingPath.length >= 2) {
        final startPt = _drawingPath.first;
        final endPt   = _drawingPath.last;
        final endPhys = _build3dPoint(); // 3D vector at release moment

        if (selectedShape == 'Circle') {
          // ── DRAG-TO-CIRCLE ─────────────────────────────────────────────
          // first & last define the DIAMETER
          final cx = (startPt.dx + endPt.dx) / 2.0;
          final cy = (startPt.dy + endPt.dy) / 2.0;
          final r  = (startPt - Offset(cx, cy)).distance;

          // Replace freehand stroke with 60-point screen circle
          _drawingPath.clear();
          const int steps = 60;
          const double twoPi = 2.0 * math.pi;
          for (int i = 0; i <= steps; i++) {
            final angle = i * (twoPi / steps);
            _drawingPath.add(Offset(cx + r * math.cos(angle),
                                    cy + r * math.sin(angle)));
          }

          // Real 3D diameter from VL53L0X + MPU angular delta
          double realRadius = r / 10.0; // px fallback → treat as mm→cm
          if (_dragStartPhysical != null) {
            final pa = _dragStartPhysical!;
            final pb = endPhys;
            final realDiameter = pa.distanceTo(pb);
            realRadius = realDiameter / 2.0;
          }

          _geoAreaCm2     = math.pi * realRadius * realRadius;
          _geoPerimeterCm = 2.0 * math.pi * realRadius;

          measureHistory.add(
            'Daire \u2500 Alan: ${_geoAreaCm2!.toStringAsFixed(2)} cm\u00b2  '
            '\u00c7evre: ${_geoPerimeterCm!.toStringAsFixed(2)} cm',
          );

        } else {
          // ── DRAG-TO-RECTANGLE ──────────────────────────────────────────
          _drawingPath
            ..clear()
            ..add(startPt)                            // top-left
            ..add(Offset(endPt.dx, startPt.dy))      // top-right
            ..add(endPt)                              // bottom-right
            ..add(Offset(startPt.dx, endPt.dy))      // bottom-left
            ..add(startPt);                           // close

          double areaCm2 = 0.0, perimeterCm = 0.0;
          if (_dragStartPhysical != null) {
            final pa = _dragStartPhysical!;
            final pb = endPhys;
            final w = (pb.x - pa.x).abs();
            final h = (pb.y - pa.y).abs();
            areaCm2     = w * h;
            perimeterCm = 2.0 * (w + h);
          } else {
            final dx = (endPt.dx - startPt.dx).abs();
            final dy = (endPt.dy - startPt.dy).abs();
            areaCm2     = dx * dy;
            perimeterCm = 2.0 * (dx + dy);
          }

          _geoAreaCm2     = areaCm2;
          _geoPerimeterCm = perimeterCm;

          measureHistory.add(
            'Dikd\u00f6rtgen \u2500 Alan: ${areaCm2.toStringAsFixed(2)} cm\u00b2  '
            '\u00c7evre: ${perimeterCm.toStringAsFixed(2)} cm',
          );
        }

        _dragStartPhysical = null;
      }
    }


    _lastButtonState = buttonState;
    notifyListeners(); // CRITICAL: repaint canvas every frame in STATE 1
  }

  /// Build a real-world 3D point from the current gyro angles + last VL53L0X distance.
  Vector3D _build3dPoint() {
    final dCm    = _lastDistanceMm / 10.0;
    final pitchR = currentCameraPitch * (math.pi / 180.0);
    final yawR   = currentCameraYaw   * (math.pi / 180.0);
    return Vector3D(
      dCm * math.sin(yawR),
      dCm * math.sin(pitchR),
      dCm * math.cos(pitchR) * math.cos(yawR),
    );
  }

  /// Shoelace area in screen pixels² (the painter canvas IS the screen).
  void _calculateArea() {

    if (_drawingPath.length < 3) return;
    double area = 0.0;
    for (int i = 0; i < _drawingPath.length - 1; i++) {
      area += _drawingPath[i].dx * _drawingPath[i + 1].dy;
      area -= _drawingPath[i + 1].dx * _drawingPath[i].dy;
    }
    _calculatedAreaCm2 = area.abs() / 2.0; // stored as px² for now
    notifyListeners();
  }

  void processImage(CameraImage image, BleService bleService) {
    // Freeze: skip all CV processing while screen is frozen
    if (isScreenFrozen) return;
    if (_isProcessing) return;
    _isProcessing = true;

    try {
      imgWidth = image.width.toDouble();
      imgHeight = image.height.toDouble();
      
      int roiCenterRawX;
      int roiCenterRawY;

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
        // Status is purely informational — does NOT gate drawing or measurement
        _status = 'On Target';
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

        if (distanceMm > 0) {
          final d = distanceMm / 10.0;
          final roll  = rollDeg  * math.pi / 180.0;
          final pitch = pitchDeg * math.pi / 180.0;

          final z = d * math.cos(pitch) * math.cos(roll);
          final x = d * math.sin(roll);
          final y = d * math.sin(pitch);

          final currentPoint = Vector3D(x, y, z);

          if (buttonState == 1 && _lastButtonState == 0) {
            if (!_isRecording) {
              _pointA = currentPoint;
              _pointB = null;
              _measuredDistanceCm = null;
              _isRecording = true;
            } else {
              _pointB = currentPoint;
              _measuredDistanceCm = _pointA!.distanceTo(_pointB!);
              _isRecording = false;
            }
          } else if (_isRecording) {
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
