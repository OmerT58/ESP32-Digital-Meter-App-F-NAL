/// home_screen.dart — Landscape-aware AR screen with animated neon strip
library;

import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/measurement_provider.dart';
import '../models/settings_provider.dart';
import '../painters/neon_strip_painter.dart';
import '../services/ble_service.dart';
import '../services/camera_service.dart';
import '../services/laser_tracking_service.dart';
import '../theme/app_theme.dart';
import '../widgets/camera_controls.dart';
import '../widgets/top_bar.dart';

// Sidebar width used in landscape mode
const double kSidebarWidth = 84.0;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
<<<<<<< HEAD
    with TickerProviderStateMixin {
  // Looping strip animation — 1 second cycle drives the dash conveyor belt
  late final AnimationController _stripAnim;
  // Legacy rotation animation kept for any future use
  late final AnimationController _rotAnim;

  StreamSubscription? _bleSub;
  Size _currentSize  = Size.zero;
  bool _isLandscape  = false;
=======
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;
  StreamSubscription? _bleSub;
  Size _currentSize = Size.zero;
>>>>>>> 0603b4c11bdf8cd3d14e798584dbc93e36792e21

  @override
  void initState() {
    super.initState();
<<<<<<< HEAD
    _stripAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();

    _rotAnim = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CameraService>().initialize();
      final ble     = context.read<BleService>();
      final tracker = context.read<LaserTrackingService>();
      _bleSub = ble.dataStream.listen((data) {
        if (tracker.isSnapshotMode) {
          tracker.updateSnapshotDrawing(
              data, _currentSize, isLandscape: _isLandscape);
        }
      });
=======
    _anim = AnimationController(
        vsync: this, duration: const Duration(seconds: 3))
      ..repeat();
    WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<CameraService>().initialize();
        final ble = context.read<BleService>();
        final tracker = context.read<LaserTrackingService>();
        _bleSub = ble.dataStream.listen((data) {
          if (tracker.isSnapshotMode) {
             tracker.updateSnapshotDrawing(data, _currentSize);
          }
        });
>>>>>>> 0603b4c11bdf8cd3d14e798584dbc93e36792e21
    });
  }

  @override
<<<<<<< HEAD
  void dispose() {
    _stripAnim.dispose();
    _rotAnim.dispose();
    _bleSub?.cancel();
    super.dispose();
  }

  /// Effective drawing-area centre:
  ///   Portrait  → centre of top 80 % of screen (above bottom drawer)
  ///   Landscape → centre of the area to the right of the sidebar
  Offset _effectiveCenter(Size size, bool isLandscape) {
    if (isLandscape) {
      final usableWidth = size.width - kSidebarWidth;
      return Offset(kSidebarWidth + usableWidth / 2, size.height / 2);
    }
    return Offset(size.width / 2, (size.height * 0.8) / 2);
=======
  void dispose() { 
    _anim.dispose(); 
    _bleSub?.cancel();
    super.dispose(); 
>>>>>>> 0603b4c11bdf8cd3d14e798584dbc93e36792e21
  }

  @override
  Widget build(BuildContext context) {
<<<<<<< HEAD
    final cam     = context.watch<CameraService>();
    final ble     = context.watch<BleService>();
    final mp      = context.watch<MeasurementProvider>();
    final s       = context.watch<SettingsProvider>();
    final tracker = context.watch<LaserTrackingService>();
=======
    final cam = context.watch<CameraService>();
    final ble = context.watch<BleService>();
    final mp  = context.watch<MeasurementProvider>();
    final s   = context.watch<SettingsProvider>();
    final tracker = context.watch<LaserTrackingService>();
    final size = MediaQuery.sizeOf(context);
    _currentSize = size;
    
    final effectiveCenter = Offset(size.width / 2, (size.height * 0.8) / 2);
>>>>>>> 0603b4c11bdf8cd3d14e798584dbc93e36792e21

    return Scaffold(
      backgroundColor: AppColors.background,
      body: OrientationBuilder(
        builder: (context, orientation) {
          final size       = MediaQuery.sizeOf(context);
          _currentSize     = size;
          final isLandscape = orientation == Orientation.landscape;
          _isLandscape     = isLandscape;

          final effectiveCenter = _effectiveCenter(size, isLandscape);

          return Stack(
            fit: StackFit.expand,
            children: [
              // ── Camera background (full-screen cover) ────────────
              _CameraBackground(camera: cam),
<<<<<<< HEAD

              // ── AR tap capture ────────────────────────────────────
=======
              // ── AR laser overlay + tap capture ─────────────────
>>>>>>> 0603b4c11bdf8cd3d14e798584dbc93e36792e21
              GestureDetector(
                onTapDown: (d) {
                  if (mp.mode.name == 'geometric') {
                    if (tracker.trackedCentroid != null) {
<<<<<<< HEAD
                      mp.capture(Offset(
                        (effectiveCenter.dx + tracker.trackedCentroid!.dx) /
                            size.width,
                        (effectiveCenter.dy + tracker.trackedCentroid!.dy) /
                            size.height,
                      ));
                    } else {
                      mp.capture(Offset(
                        d.localPosition.dx / size.width,
                        d.localPosition.dy / size.height,
                      ));
                    }
                  } else {
                    if (tracker.trackedCentroid != null) {
                      mp.capture(Offset(
                        (effectiveCenter.dx + tracker.trackedCentroid!.dx) /
                            size.width,
                        (effectiveCenter.dy + tracker.trackedCentroid!.dy) /
                            size.height,
                      ));
=======
                       // Capture the tracked dot normalized coordinates
                       final pt = Offset(
                         (effectiveCenter.dx + tracker.trackedCentroid!.dx) / size.width,
                         (effectiveCenter.dy + tracker.trackedCentroid!.dy) / size.height,
                       );
                       mp.capture(pt);
                    } else {
                       mp.capture(Offset(
                         d.localPosition.dx / size.width,
                         d.localPosition.dy / size.height,
                       ));
                    }
                  } else {
                    if (tracker.trackedCentroid != null) {
                       final pt = Offset(
                         (effectiveCenter.dx + tracker.trackedCentroid!.dx) / size.width,
                         (effectiveCenter.dy + tracker.trackedCentroid!.dy) / size.height,
                       );
                       mp.capture(pt);
>>>>>>> 0603b4c11bdf8cd3d14e798584dbc93e36792e21
                    }
                  }
                },
                child: const SizedBox.expand(),
              ),

<<<<<<< HEAD
              // ── Laser tracking (background service) ──────────────
              if (cam.isInitialized)
                _LaserTrackingOverlay(
                  cam: cam,
                  ble: ble,
                  tracker: tracker,
                  effectiveCenter: effectiveCenter,
=======
              // ── Tracking overlay ───────────────────────────────
              if (cam.isInitialized)
                 _LaserTrackingOverlay(cam: cam, ble: ble, tracker: tracker, effectiveCenter: effectiveCenter),

              // ── Elegant center reticle & status text ─────────────
              _MinimalReticle(color: s.laserColor, tracker: tracker, effectiveCenter: effectiveCenter),

              // ── Snapshot Drawing Overlay (permanent lines) ──────────
              if (tracker.isSnapshotMode)
                CustomPaint(
                  size: Size.infinite,
                  painter: _DrawingPainter(path: tracker.drawingPath),
                ),

              // ── Two-Tap preview line (dashed, from A to live pos) ───
              if (tracker.isSnapshotMode && tracker.isTwoTapMode && tracker.twoTapPointA != null && tracker.livePreviewPoint != null)
                CustomPaint(
                  size: Size.infinite,
                  painter: _PreviewLinePainter(
                    from: tracker.twoTapPointA!,
                    to: tracker.livePreviewPoint!,
                  ),
                ),

              // ── Mode toggle pill (Continuous / Two-Tap) ─────────────
              if (tracker.isSnapshotMode)
                Positioned(
                  top: effectiveCenter.dy + 30,
                  left: 0, right: 0,
                  child: Center(
                    child: _DrawModeToggle(tracker: tracker),
                  ),
>>>>>>> 0603b4c11bdf8cd3d14e798584dbc93e36792e21
                ),

              // ── Animated neon strip drawing ───────────────────────
              if (tracker.isSnapshotMode && tracker.drawingPath.length >= 2)
                AnimatedBuilder(
                  animation: _stripAnim,
                  builder: (_, __) => CustomPaint(
                    size: Size.infinite,
                    painter: NeonStripPainter(
                      path: List.unmodifiable(tracker.drawingPath),
                      animValue: _stripAnim.value,
                    ),
                  ),
                ),

              // ── Two-Tap animated preview line ─────────────────────
              if (tracker.isSnapshotMode &&
                  tracker.isTwoTapMode &&
                  tracker.twoTapPointA != null &&
                  tracker.livePreviewPoint != null)
                AnimatedBuilder(
                  animation: _stripAnim,
                  builder: (_, __) => CustomPaint(
                    size: Size.infinite,
                    painter: NeonPreviewLinePainter(
                      from: tracker.twoTapPointA!,
                      to:   tracker.livePreviewPoint!,
                      animValue: _stripAnim.value,
                    ),
                  ),
                ),

              // ── Center reticle & status text ──────────────────────
              _MinimalReticle(
                color: s.laserColor,
                tracker: tracker,
                effectiveCenter: effectiveCenter,
                isLandscape: isLandscape,
                size: size,
              ),

              // ── Top bar (BLE + Mode 1/2 + nav) ────────────────────
              const TopBar(),

              // ── Adaptive bottom drawer / landscape sidebar ─────────
              if (!isLandscape)
                const CameraControls()
              else
                _LandscapeSidebar(mp: mp, ble: ble, tracker: tracker),
            ],
          );
        },
      ),
    );
  }
}

<<<<<<< HEAD
// ── Minimal center crosshair & status text ────────────────────────
class _MinimalReticle extends StatelessWidget {
  const _MinimalReticle({
    required this.color,
    required this.tracker,
    required this.effectiveCenter,
    required this.isLandscape,
    required this.size,
  });
  final Color                color;
  final LaserTrackingService tracker;
  final Offset               effectiveCenter;
  final bool                 isLandscape;
  final Size                 size;

  @override
  Widget build(BuildContext context) {
    final isRecording = tracker.isRecording;
    final onTarget    = tracker.status == 'On Target';

    String statusText  = 'TARGET OFF';
    Color  statusColor = AppColors.offline.withOpacity(0.8);
    if (isRecording) {
      statusText  = 'RECORDING';
      statusColor = Colors.redAccent;
    } else if (onTarget) {
      statusText  = 'TARGET ON';
      statusColor = AppColors.accentGreen;
    }

    final statusWidget = Text(
      statusText,
      style: AppTextStyles.inter(
        size: 14, weight: FontWeight.bold,
        color: statusColor, letterSpacing: 1.2,
      ),
=======
// ── Minimal center crosshair & Status ────────────────────────────
/// A clean, professional reticle and dynamic status text.
class _MinimalReticle extends StatelessWidget {
  const _MinimalReticle({required this.color, required this.tracker, required this.effectiveCenter});
  final Color color;
  final LaserTrackingService tracker;
  final Offset effectiveCenter;

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final bool isRecording = tracker.isRecording;
    final bool onTarget = tracker.status == 'On Target';

    String statusText = 'TARGET OFF';
    Color statusColor = AppColors.offline.withOpacity(0.8);

    if (isRecording) {
      statusText = 'RECORDING';
      statusColor = Colors.redAccent;
    } else if (onTarget) {
      statusText = 'TARGET ON';
      statusColor = AppColors.accentGreen;
    }

    return Stack(
      children: [
        // Crosshair centered on the effectiveCenter
        Positioned(
          top: effectiveCenter.dy - 14,
          left: effectiveCenter.dx - 14,
          child: SizedBox(
            width: 28, height: 28,
            child: CustomPaint(painter: _ReticlePainter(color: color)),
          ),
        ),
        
        // Status text positioned ~20px above the bottom drawer (which starts at 80% height)
        Positioned(
          bottom: (screenSize.height * 0.2) + 20,
          left: 0, right: 0,
          child: Center(
            child: Text(
              statusText,
              style: AppTextStyles.inter(
                size: 14,
                weight: FontWeight.bold,
                color: statusColor,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ),
        
        // Measurement Result Overlay
        if (tracker.measuredDistanceCm != null)
          Positioned(
            top: 100, // Below TopBar
            left: 0, right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.accentGreen.withOpacity(0.5)),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accentGreen.withOpacity(0.2),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Text(
                  'Length: ${tracker.measuredDistanceCm!.toStringAsFixed(1)} cm',
                  style: AppTextStyles.inter(
                    size: 24,
                    weight: FontWeight.bold,
                    color: AppColors.accentGreen,
                  ),
                ),
              ),
            ),
          ),
      ],
>>>>>>> 0603b4c11bdf8cd3d14e798584dbc93e36792e21
    );

    return Stack(
      children: [
        // Crosshair centred on effectiveCenter
        Positioned(
          top:  effectiveCenter.dy - 14,
          left: effectiveCenter.dx - 14,
          child: SizedBox(
            width: 28, height: 28,
            child: CustomPaint(painter: _ReticlePainter(color: color)),
          ),
        ),

        // Status text
        if (isLandscape)
          Positioned(
            left: kSidebarWidth + 12,
            top:  effectiveCenter.dy + 20,
            child: statusWidget,
          )
        else
          Positioned(
            bottom: (size.height * 0.2) + 20,
            left: 0, right: 0,
            child: Center(child: statusWidget),
          ),

        // Measurement result overlay
        if (tracker.measuredDistanceCm != null)
          Positioned(
            top:  100,
            left: isLandscape ? kSidebarWidth + 16 : 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppColors.accentGreen.withOpacity(0.5)),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accentGreen.withOpacity(0.2),
                      blurRadius: 10, spreadRadius: 2,
                    ),
                  ],
                ),
                child: Text(
                  'Length: ${tracker.measuredDistanceCm!.toStringAsFixed(1)} cm',
                  style: AppTextStyles.inter(
                    size: 24, weight: FontWeight.bold,
                    color: AppColors.accentGreen,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ReticlePainter extends CustomPainter {
  _ReticlePainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width  / 2;
    final cy = size.height / 2;
    const length = 10.0;
    const thick  = 1.0;

<<<<<<< HEAD
    final glowPaint = Paint()
      ..color       = color.withOpacity(0.4)
      ..strokeWidth = thick + 2.0
      ..strokeCap   = StrokeCap.round
      ..maskFilter  = const MaskFilter.blur(BlurStyle.normal, 2.0);
    final paint = Paint()
      ..color       = color
=======
    const length = 10.0;
    const thick = 1.0;

    final glowPaint = Paint()
      ..color = color.withOpacity(0.4)
      ..strokeWidth = thick + 2.0
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0);

    final paint = Paint()
      ..color = color
>>>>>>> 0603b4c11bdf8cd3d14e798584dbc93e36792e21
      ..strokeWidth = thick
      ..strokeCap   = StrokeCap.round;

<<<<<<< HEAD
    canvas.drawLine(
        Offset(cx, cy - length), Offset(cx, cy + length), glowPaint);
    canvas.drawLine(
        Offset(cx - length, cy), Offset(cx + length, cy), glowPaint);
    canvas.drawLine(
        Offset(cx, cy - length), Offset(cx, cy + length), paint);
    canvas.drawLine(
        Offset(cx - length, cy), Offset(cx + length, cy), paint);
=======
    // Draw subtle glow
    canvas.drawLine(Offset(cx, cy - length), Offset(cx, cy + length), glowPaint);
    canvas.drawLine(Offset(cx - length, cy), Offset(cx + length, cy), glowPaint);

    // Draw sharp core
    canvas.drawLine(Offset(cx, cy - length), Offset(cx, cy + length), paint);
    canvas.drawLine(Offset(cx - length, cy), Offset(cx + length, cy), paint);

>>>>>>> 0603b4c11bdf8cd3d14e798584dbc93e36792e21
    canvas.drawCircle(Offset(cx, cy), 1.0, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _ReticlePainter old) => old.color != color;
}

<<<<<<< HEAD
// ── Laser tracking overlay (background image processor) ──────────
class _LaserTrackingOverlay extends StatefulWidget {
  const _LaserTrackingOverlay({
    required this.cam,
    required this.ble,
    required this.tracker,
    required this.effectiveCenter,
  });
  final CameraService        cam;
  final BleService           ble;
  final LaserTrackingService tracker;
  final Offset               effectiveCenter;
=======
// ── Tracking overlay ─────────────────────────────────────────────
class _LaserTrackingOverlay extends StatefulWidget {
  const _LaserTrackingOverlay({required this.cam, required this.ble, required this.tracker, required this.effectiveCenter});
  final CameraService cam;
  final BleService ble;
  final LaserTrackingService tracker;
  final Offset effectiveCenter;
>>>>>>> 0603b4c11bdf8cd3d14e798584dbc93e36792e21

  @override
  State<_LaserTrackingOverlay> createState() => _LaserTrackingOverlayState();
}

class _LaserTrackingOverlayState extends State<_LaserTrackingOverlay> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
<<<<<<< HEAD
      widget.cam
          .startTracking((img) => widget.tracker.processImage(img, widget.ble));
=======
      widget.cam.startTracking((img) => widget.tracker.processImage(img, widget.ble));
>>>>>>> 0603b4c11bdf8cd3d14e798584dbc93e36792e21
    });
  }

  @override
  void dispose() {
    widget.cam.stopTracking();
    super.dispose();
  }

  @override
<<<<<<< HEAD
  Widget build(BuildContext context) => const SizedBox.shrink();
}

// ── Camera background ─────────────────────────────────────────────
=======
  Widget build(BuildContext context) {
    return const SizedBox.shrink(); // Logic is handled in background, UI is clean
  }
}

// ── Draw Mode Toggle pill ──────────────────────────────────────────
class _DrawModeToggle extends StatelessWidget {
  const _DrawModeToggle({required this.tracker});
  final LaserTrackingService tracker;

  @override
  Widget build(BuildContext context) {
    final isTwoTap = tracker.isTwoTapMode;
    return GestureDetector(
      onTap: () {
        tracker.setTwoTapMode(!isTwoTap);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: isTwoTap
              ? Colors.cyanAccent.withOpacity(0.18)
              : Colors.white.withOpacity(0.10),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: isTwoTap ? Colors.cyanAccent : Colors.white30,
            width: 1.2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isTwoTap ? Icons.linear_scale_rounded : Icons.gesture_rounded,
              size: 16,
              color: isTwoTap ? Colors.cyanAccent : Colors.white70,
            ),
            const SizedBox(width: 8),
            Text(
              isTwoTap ? 'TWO-TAP' : 'CONTINUOUS',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isTwoTap ? Colors.cyanAccent : Colors.white70,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawingPainter extends CustomPainter {
  _DrawingPainter({required this.path});
  final List<Offset> path;

  @override
  void paint(Canvas canvas, Size size) {
    if (path.isEmpty) return;

    final paint = Paint()
      ..color = Colors.cyanAccent
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final glow = Paint()
      ..color = Colors.cyanAccent.withOpacity(0.4)
      ..strokeWidth = 6.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0);

    final p = Path();
    p.moveTo(path.first.dx, path.first.dy);
    for (int i = 1; i < path.length; i++) {
      p.lineTo(path[i].dx, path[i].dy);
    }
    
    canvas.drawPath(p, glow);
    canvas.drawPath(p, paint);
  }

  @override
  bool shouldRepaint(covariant _DrawingPainter oldDelegate) => true;
}

// ── Preview line painter (Two-Tap mode) ───────────────────────────
class _PreviewLinePainter extends CustomPainter {
  _PreviewLinePainter({required this.from, required this.to});
  final Offset from;
  final Offset to;

  @override
  void paint(Canvas canvas, Size size) {
    final dashPaint = Paint()
      ..color = Colors.cyanAccent.withOpacity(0.65)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Draw dashed line
    const dashLen = 10.0;
    const gapLen  = 6.0;
    final total = (to - from).distance;
    if (total < 1) return;
    final dir = (to - from) / total;
    double covered = 0;
    while (covered < total) {
      final segEnd = (covered + dashLen).clamp(0.0, total);
      canvas.drawLine(from + dir * covered, from + dir * segEnd, dashPaint);
      covered += dashLen + gapLen;
    }

    // Dot at Point A
    canvas.drawCircle(from, 5,
      Paint()..color = Colors.cyanAccent
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
  }

  @override
  bool shouldRepaint(covariant _PreviewLinePainter o) =>
      o.from != from || o.to != to;
}

// ── Camera background ────────────────────────────────────────────
>>>>>>> 0603b4c11bdf8cd3d14e798584dbc93e36792e21
class _CameraBackground extends StatelessWidget {
  const _CameraBackground({required this.camera});
  final CameraService camera;

  @override
  Widget build(BuildContext context) {
    if (camera.isInitialized && camera.controller != null) {
      return SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          alignment: Alignment.center,
          child: SizedBox(
            width:  camera.controller!.value.previewSize!.height,
            height: camera.controller!.value.previewSize!.width,
            child:  CameraPreview(camera.controller!),
          ),
        ),
      );
    }
    if (camera.errorMessage != null) {
      return Container(
        color: AppColors.background,
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.no_photography_rounded,
                color: AppColors.offline, size: 48),
            const SizedBox(height: 12),
            Text('CAMERA UNAVAILABLE',
                style: AppTextStyles.inter(
                    size: 13, color: AppColors.offline)),
            const SizedBox(height: 8),
            Text(camera.errorMessage!,
                textAlign: TextAlign.center,
                style: AppTextStyles.inter(
                    size: 10, color: AppColors.textTertiary)),
          ]),
        ),
      );
    }
    return Container(
      color: AppColors.background,
      child: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const CircularProgressIndicator(
              color: AppColors.accentGreen, strokeWidth: 2),
          const SizedBox(height: 16),
          Text('INITIALISING CAMERA…',
              style: AppTextStyles.inter(
                  size: 11, color: AppColors.textSecondary)),
        ]),
      ),
    );
  }
}

// ── Landscape left sidebar ────────────────────────────────────────
class _LandscapeSidebar extends StatelessWidget {
  const _LandscapeSidebar({
    required this.mp,
    required this.ble,
    required this.tracker,
  });
  final MeasurementProvider  mp;
  final BleService           ble;
  final LaserTrackingService tracker;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Positioned(
      top: 0, bottom: 0, left: 0,
      width: kSidebarWidth,
      child: ClipRect(
        child: Container(
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF0F1117).withOpacity(0.82)
                : Colors.white.withOpacity(0.82),
            border: Border(
              right: BorderSide(
                color: isDark
                    ? Colors.white.withOpacity(0.10)
                    : Colors.black.withOpacity(0.08),
              ),
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _RotatedSideBtn(
                  icon: Icons.undo_rounded,
                  label: 'UNDO',
                  isDark: isDark,
                  onTap: mp.undo,
                ),
                _LandscapeMeasureBtn(mp: mp, ble: ble, tracker: tracker),
                _RotatedSideBtn(
                  icon: Icons.refresh_rounded,
                  label: 'RESET',
                  isDark: isDark,
                  onTap: () {
                    mp.reset();
                    tracker.toggleSnapshotMode(false);
                    context
                        .read<CameraService>()
                        .controller
                        ?.resumePreview();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Rotated sidebar icon-button ────────────────────────────────────
class _RotatedSideBtn extends StatelessWidget {
  const _RotatedSideBtn({
    required this.icon,
    required this.label,
    required this.isDark,
    required this.onTap,
  });
  final IconData     icon;
  final String       label;
  final bool         isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedRotation(
            turns: 0.25,
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeInOut,
            child: Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark
                    ? Colors.white.withOpacity(0.06)
                    : Colors.black.withOpacity(0.05),
                border: Border.all(
                    color: isDark ? Colors.white24 : Colors.black12),
              ),
              child: Icon(icon,
                  size: 20,
                  color: isDark ? Colors.white70 : Colors.black87),
            ),
          ),
          const SizedBox(height: 4),
          RotatedBox(
            quarterTurns: 3,
            child: Text(
              label,
              style: AppTextStyles.inter(
                size: 8, weight: FontWeight.w600,
                color: isDark ? Colors.white54 : Colors.black54,
                letterSpacing: 1.1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Landscape measure button ──────────────────────────────────────
class _LandscapeMeasureBtn extends StatelessWidget {
  const _LandscapeMeasureBtn({
    required this.mp,
    required this.ble,
    required this.tracker,
  });
  final MeasurementProvider  mp;
  final BleService           ble;
  final LaserTrackingService tracker;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (tracker.status == 'On Target' && ble.latestData.length >= 4) {
          final cam = context.read<CameraService>();
          tracker.toggleSnapshotMode(true,
              currentDist:  ble.latestData[0] / 10.0,
              currentRoll:  ble.latestData[1],
              currentPitch: ble.latestData[2],
              currentYaw:   ble.latestData[3]);
          cam.controller?.pausePreview();
        } else if (tracker.trackedCentroid != null) {
          final size = MediaQuery.sizeOf(context);
          final ec   = Offset(
            kSidebarWidth + (size.width - kSidebarWidth) / 2,
            size.height / 2,
          );
          mp.capture(Offset(
            (ec.dx + tracker.trackedCentroid!.dx) / size.width,
            (ec.dy + tracker.trackedCentroid!.dy) / size.height,
          ));
        } else {
          mp.capture(const Offset(0.5, 0.5));
        }
      },
      child: Container(
        width: 58, height: 58,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withOpacity(0.1),
          boxShadow: [
            BoxShadow(
              color: AppColors.accent.withOpacity(0.4),
              blurRadius: 18, spreadRadius: 2,
            ),
          ],
          border: Border.all(
              color: Colors.white.withOpacity(0.25), width: 1.5),
        ),
        child: Center(
          child: Container(
            width: 44, height: 44,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.accent,
            ),
            child: const Icon(Icons.gps_fixed_rounded,
                size: 22, color: Colors.white),
          ),
        ),
      ),
    );
  }
}
