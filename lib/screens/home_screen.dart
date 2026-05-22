/// home_screen.dart — Landscape-aware AR screen with animated neon strip
library;

import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/measurement_provider.dart';
import '../models/settings_provider.dart';
import '../painters/drawing_painter.dart';
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

class _HomeScreenState extends State<HomeScreen> {
  StreamSubscription? _bleSub;
  Size _currentSize = Size.zero;
  bool _isLandscape = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CameraService>().initialize();
      final ble     = context.read<BleService>();
      final tracker = context.read<LaserTrackingService>();
      _bleSub = ble.dataStream.listen((data) {
        // Always update — crosshair must be visible even outside snapshot mode
        tracker.updateSnapshotDrawing(
            data, _currentSize, isLandscape: _isLandscape);
      });
    });
  }

  void dispose() {
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
  }

  @override
  Widget build(BuildContext context) {
    final cam     = context.watch<CameraService>();
    final ble     = context.watch<BleService>();
    final mp      = context.watch<MeasurementProvider>();
    final s       = context.watch<SettingsProvider>();

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

              // ── AR tap capture ────────────────────────────────────
              GestureDetector(
                onTapDown: (d) {
                  final tracker = context.read<LaserTrackingService>();
                  if (mp.mode.name == 'geometric') {
                    if (tracker.trackedCentroid != null) {
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
                    }
                  }
                },
                child: const SizedBox.expand(),
              ),

              // ── Laser tracking (background service) ──────────────
              if (cam.isInitialized)
                _LaserTrackingOverlay(
                  cam: cam,
                  ble: ble,
                  tracker: context.read<LaserTrackingService>(),
                  effectiveCenter: effectiveCenter,
                ),

              // ── Layer 3: Continuous drawing lines ──────────────────────────
              // Always present above camera so the Test-mode hard stop works.
                            Consumer<LaserTrackingService>(
                builder: (context, tracker, child) {
                  if (tracker.selectedShape == 'Test') return const SizedBox.shrink();
                  final path = tracker.drawingPath;
                  if (path.length < 2) return const SizedBox.shrink();
                  return SizedBox.expand(
                    child: CustomPaint(
                      painter: SolidLinePainter(
                        path: List.of(path),
                        color: s.laserColor,
                        selectedShape: tracker.selectedShape,
                      ),
                    ),
                  );
                },
              ),

              // ── Layer 4: Two-Tap shape / preview line ─────────────────────
              Consumer<LaserTrackingService>(
                builder: (context, tracker, child) {
                  if (!tracker.isTwoTapMode) return const SizedBox.shrink();
                  if (tracker.twoTapPointA != null && tracker.twoTapPointB != null) {
                    return SizedBox.expand(
                      child: CustomPaint(
                        painter: ShapePainter(
                          pointA: tracker.twoTapPointA!,
                          pointB: tracker.twoTapPointB!,
                          shape:  tracker.selectedShape,
                          color:  s.laserColor,
                        ),
                      ),
                    );
                  }
                  if (tracker.twoTapPointA != null && tracker.livePreviewPoint != null) {
                    return SizedBox.expand(
                      child: CustomPaint(
                        painter: PreviewLinePainter(
                          from:  tracker.twoTapPointA!,
                          to:    tracker.livePreviewPoint!,
                          color: s.laserColor,
                        ),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),


              // ── Layer 5: Flying Pointer crosshair ────────────────────────
              Consumer<LaserTrackingService>(
                builder: (context, tracker, child) {
                  return SizedBox.expand(
                    child: CustomPaint(
                      painter: FlyingPointerPainter(
                        position: tracker.pointerPosition,
                        color: s.laserColor,
                      ),
                    ),
                  );
                },
              ),

              // ── Top bar (BLE + Mode 1/2 + nav) ────────────────────
              const TopBar(),

              // Adaptive bottom drawer / landscape sidebar
              // Always visible in ALL modes so user can switch shapes.
              if (!isLandscape)
                const CameraControls()
              else
                Consumer<LaserTrackingService>(
                  builder: (context, tracker, child) {
                    return _LandscapeSidebar(mp: mp, ble: ble, tracker: tracker);
                  },
                ),

              // ── FOV Tuner — right edge, vertically centered ────────
              Consumer<LaserTrackingService>(
                builder: (context, tracker, child) {
                  final isDark = Theme.of(context).brightness == Brightness.dark;
                  return Positioned(
                    right: 8,
                    top: 0,
                    bottom: 0,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: _FovTuner(tracker: tracker, isDark: isDark),
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

// (Length overlay removed — measurements shown in the bottom drawer only)


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

  @override
  State<_LaserTrackingOverlay> createState() => _LaserTrackingOverlayState();
}

class _LaserTrackingOverlayState extends State<_LaserTrackingOverlay> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.cam
          .startTracking((img) => widget.tracker.processImage(img, widget.ble));
    });
  }

  @override
  void dispose() {
    widget.cam.stopTracking();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

// ── Camera background ─────────────────────────────────────────────
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

// ── FOV Tuner — right-edge floating sensitivity panel ────────────────────────
class _FovTuner extends StatelessWidget {
  const _FovTuner({required this.tracker, required this.isDark});
  final LaserTrackingService tracker;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF0F1117).withOpacity(0.80)
            : Colors.white.withOpacity(0.85),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.black12,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withOpacity(0.18),
            blurRadius: 14,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'FOV',
            style: AppTextStyles.inter(
              size: 8,
              weight: FontWeight.w700,
              color: isDark ? Colors.white54 : Colors.black45,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          // Arttır (+)
          GestureDetector(
            onTap: () => tracker.adjustSensitivity(0.5),
            child: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.accent.withOpacity(0.18),
              ),
              child: const Icon(Icons.add, size: 18, color: AppColors.accent),
            ),
          ),
          const SizedBox(height: 6),
          // Anlık değer
          Text(
            tracker.sensitivityMultiplier.toStringAsFixed(1),
            style: AppTextStyles.inter(
              size: 12,
              weight: FontWeight.w700,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 6),
          // Azalt (-)
          GestureDetector(
            onTap: () => tracker.adjustSensitivity(-0.5),
            child: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.accent.withOpacity(0.18),
              ),
              child: const Icon(Icons.remove, size: 18, color: AppColors.accent),
            ),
          ),
        ],
      ),
    );
  }
}
