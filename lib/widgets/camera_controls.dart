/// camera_controls.dart — Modern bottom drawer with gradient card + Soft UI measure button
library;

import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/measurement_mode.dart';
import '../models/measurement_provider.dart';
import '../models/settings_provider.dart';
import '../services/ble_service.dart';
import '../services/camera_service.dart';
import '../services/laser_tracking_service.dart';
import '../theme/app_theme.dart';

class CameraControls extends StatefulWidget {
  const CameraControls({super.key});
  @override
  State<CameraControls> createState() => _CameraControlsState();
}

class _CameraControlsState extends State<CameraControls> {
  late final PageController _pageCtrl;
  final _modes = MeasurementMode.values;
  double _sheetExtent = 0.18;

  @override
  void initState() {
    super.initState();
    final initialPage = _modes.indexOf(MeasurementMode.area);
    _pageCtrl = PageController(
      viewportFraction: 0.36,
      initialPage: initialPage,
    );
    // Start collapsed to the tight portrait height
    _sheetExtent = 0.18;
  }

  @override
  void dispose() { _pageCtrl.dispose(); super.dispose(); }

  void _onPageChanged(int idx) {
    HapticFeedback.selectionClick();
    context.read<MeasurementProvider>().switchMode(_modes[idx]);
  }

  @override
  Widget build(BuildContext context) {
    final ble = context.watch<BleService>();
    final mp  = context.watch<MeasurementProvider>();
    final s   = context.watch<SettingsProvider>();
    final tracker = context.watch<LaserTrackingService>();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Calculate opacity: 0.0 at 0.22, 1.0 at 0.4
    double contentOpacity = ((_sheetExtent - 0.18) / 0.22).clamp(0.0, 1.0);

    return NotificationListener<DraggableScrollableNotification>(
      onNotification: (notification) {
        setState(() {
          _sheetExtent = notification.extent;
        });
        return false;
      },
      child: DraggableScrollableSheet(
        initialChildSize: 0.18,
        minChildSize: 0.18,
        maxChildSize: 0.8,
        builder: (context, scrollController) {
          return ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark 
                      ? const Color(0xFF0F1117).withOpacity(0.55)
                      : Colors.white.withOpacity(0.65),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                  border: Border.all(
                    color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
                  ),
                ),
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: SafeArea(
                    top: false,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // ── Drag handle ──────────────────────────────────
                        Container(
                          margin: const EdgeInsets.only(top: 10, bottom: 20),
                          width: 40, height: 5,
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white24 : Colors.black26,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),

                        // ── ALWAYS VISIBLE: Control row ──────────────────
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 48),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              _SideBtn(
                                icon: Icons.undo_rounded,
                                label: 'UNDO',
                                isDark: isDark,
                                onTap: () {
                                  HapticFeedback.lightImpact();
                                  mp.undo();
                                },
                              ),
                              _MeasureButton(mp: mp, ble: ble),
                              _SideBtn(
                                icon: Icons.refresh_rounded,
                                label: 'RESET',
                                isDark: isDark,
                                onTap: () {
                                  HapticFeedback.lightImpact();
                                  mp.reset();
                                  final tracker = context.read<LaserTrackingService>();
                                  tracker.toggleSnapshotMode(false);
                                  final cam = context.read<CameraService>();
                                  cam.controller?.resumePreview();
                                },
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // ── FADING CONTENT ───────────────────────────────
                        Opacity(
                          opacity: contentOpacity,
                          child: IgnorePointer(
                            ignoring: contentOpacity == 0.0,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Result band
                                _ResultBand(mp: mp, ble: ble, s: s, isDark: isDark),
                                const SizedBox(height: 24),

                                // Mode toggles
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 20),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      _ModeTogglePlaceholder(
                                        label: 'Continuous Mode',
                                        active: !tracker.isTwoTapMode,
                                        onTap: () {
                                          HapticFeedback.selectionClick();
                                          tracker.setTwoTapMode(false);
                                        },
                                      ),
                                      const SizedBox(width: 12),
                                      _ModeTogglePlaceholder(
                                        label: '2-Tap Mode',
                                        active: tracker.isTwoTapMode,
                                        onTap: () {
                                          HapticFeedback.selectionClick();
                                          tracker.setTwoTapMode(true);
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 14),

                                // Geometric sub-selector
                                if (mp.mode == MeasurementMode.geometric)
                                  _GeoSubSelector(mp: mp, isDark: isDark),

                                // PageView mode strip
                                SizedBox(
                                  height: 36,
                                  child: PageView.builder(
                                    controller: _pageCtrl,
                                    itemCount: _modes.length,
                                    onPageChanged: _onPageChanged,
                                    itemBuilder: (_, i) {
                                      final active = _modes[i] == mp.mode;
                                      return Center(
                                        child: AnimatedDefaultTextStyle(
                                          duration: const Duration(milliseconds: 200),
                                          style: AppTextStyles.inter(
                                            size: active ? 13 : 11,
                                            color: active
                                                ? (isDark ? Colors.white : AppColors.textPrimary)
                                                : AppColors.textTertiary,
                                            weight: active ? FontWeight.w600 : FontWeight.w400,
                                            letterSpacing: 1.0,
                                          ),
                                          child: Text(_modes[i].label),
                                        ),
                                      );
                                    },
                                  ),
                                ),

                                const SizedBox(height: 24),
                                Divider(color: isDark ? Colors.white12 : Colors.black12, height: 1),
                                Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text('MEASUREMENT HISTORY', style: AppTextStyles.inter(size: 11, weight: FontWeight.w600, color: isDark ? Colors.white54 : Colors.black54)),
                                  ),
                                ),
                                _HistoryItem(title: 'Distance', value: '1.24 m', icon: Icons.straighten, isDark: isDark),
                                _HistoryItem(title: 'Area', value: '4.50 m²', icon: Icons.square_foot, isDark: isDark),
                                _HistoryItem(title: 'Volume', value: '12.0 m³', icon: Icons.view_in_ar, isDark: isDark),
                                const SizedBox(height: 40),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ModeTogglePlaceholder extends StatelessWidget {
  const _ModeTogglePlaceholder({required this.label, required this.active, required this.onTap});
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: active ? AppColors.accent.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? AppColors.accent : Colors.grey.withOpacity(0.3),
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.inter(
            size: 10,
            color: active ? AppColors.accent : Colors.grey,
            weight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _HistoryItem extends StatelessWidget {
  const _HistoryItem({required this.title, required this.value, required this.icon, required this.isDark});
  final String title;
  final String value;
  final IconData icon;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: isDark ? Colors.white54 : Colors.black54, size: 20),
          const SizedBox(width: 12),
          Text(title, style: AppTextStyles.inter(size: 12, color: isDark ? Colors.white70 : Colors.black87)),
          const Spacer(),
          Text(value, style: AppTextStyles.inter(size: 12, weight: FontWeight.w500, color: isDark ? Colors.white : Colors.black)),
        ],
      ),
    );
  }
}

// ── Geometric sub-mode selector ──────────────────────────────────
class _GeoSubSelector extends StatelessWidget {
  const _GeoSubSelector({required this.mp, required this.isDark});
  final MeasurementProvider mp;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: GeometricShape.values.map((s) {
          final active = mp.geoShape == s;
          return GestureDetector(
            onTap: () => mp.switchGeoShape(s),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.symmetric(horizontal: 6),
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: active
                    ? AppColors.accent : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: active
                      ? AppColors.accent : AppColors.textTertiary),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    s == GeometricShape.circle
                        ? Icons.circle_outlined
                        : Icons.crop_square_rounded,
                    size: 14,
                    color: active ? Colors.white : AppColors.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    s == GeometricShape.circle ? 'CIRCLE' : 'SQUARE',
                    style: AppTextStyles.inter(
                      size: 9,
                      color: active ? Colors.white : AppColors.textSecondary,
                      weight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Result band ──────────────────────────────────────────────────
class _ResultBand extends StatelessWidget {
  const _ResultBand({
    required this.mp,
    required this.ble,
    required this.s,
    required this.isDark,
  });
  final MeasurementProvider mp;
  final BleService          ble;
  final SettingsProvider    s;
  final bool                isDark;

  @override
  Widget build(BuildContext context) {
    final unit = s.unit;

    return StreamBuilder<List<double>>(
      stream: ble.dataStream,
      initialData: ble.latestData,
      builder: (context, snapshot) {
        final List<double> data = snapshot.data ?? ble.latestData;
        
        // Calculate derived metrics since BleService now streams raw [X, Y, Z] 
        // where X = distanceMm, Y = pitchDeg, Z = rollDeg
        final double distanceMm = data.isNotEmpty ? data[0] : 0.0;
        final double pitchDeg = data.length > 1 ? data[1] : 0.0;
        final double distanceM = distanceMm / 1000.0;
        final double pitchRad = pitchDeg * (math.pi / 180.0);
        final double horizontalM = distanceM * math.cos(pitchRad);
        final double estimatedAreaM2 = horizontalM * horizontalM;
        final double estimatedVolumeM3 = estimatedAreaM2 * (distanceM * math.sin(pitchRad.abs()));

        final String labelText = switch (mp.mode) {
          MeasurementMode.line => 'DISTANCE',
          MeasurementMode.area => 'AREA',
          MeasurementMode.volume => 'VOLUME',
          MeasurementMode.geometric => 'GEOMETRIC',
        };

        final String valueText = switch (mp.mode) {
          MeasurementMode.line =>
            '${unit.convert(horizontalM).toStringAsFixed(2)} ${unit.label}',
          MeasurementMode.area =>
            '${estimatedAreaM2.toStringAsFixed(4)} m²',
          MeasurementMode.volume =>
            '${estimatedVolumeM3.toStringAsFixed(4)} m³',
          MeasurementMode.geometric =>
            _geoResult(mp, horizontalM, unit),
        };

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withOpacity(0.04)
                  : Colors.black.withOpacity(0.02),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark
                    ? Colors.white.withOpacity(0.08)
                    : Colors.black.withOpacity(0.05),
                width: 1.0,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(labelText,
                    style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: isDark
                            ? Colors.white54
                            : Colors.black54,
                        letterSpacing: 2.0)),
                const SizedBox(height: 8),
                Text(valueText,
                    style: GoogleFonts.orbitron(
                      fontSize: 24,
                      color: isDark ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.w600,
                    ).copyWith(
                      shadows: isDark ? [
                        Shadow(
                          color: Colors.white.withOpacity(0.3),
                          blurRadius: 12,
                        ),
                      ] : [],
                    ),
                    textAlign: TextAlign.center),
              ],
            ),
          ),
        );
      }
    );
  }

  String _geoResult(
      MeasurementProvider mp, double horizontalM, MeasurementUnit unit) {
    if (mp.points.length < 2) return 'TAP 2 POINTS';
    const screenSize = Size(390, 844); // approx iPhone 15
    final d = horizontalM;
    if (mp.geoShape == GeometricShape.circle) {
      final r = mp.circleRadiusM(screenSize, d);
      final a = mp.circleAreaM2(screenSize, d);
      return 'R: ${(r * 100).toStringAsFixed(1)} cm\nA: ${a.toStringAsFixed(3)} m²';
    } else {
      final side = mp.squareSideM(screenSize, d);
      final area = mp.squareAreaM2(screenSize, d);
      return 'S: ${(side * 100).toStringAsFixed(1)} cm\nA: ${area.toStringAsFixed(3)} m²';
    }
  }
}

// ── Main MEASURE button ──────────────────────────────────────────
/// Large Soft UI button with a subtle target/crosshair icon.
/// Outer ring = white with blue shadow, inner = blue gradient.
class _MeasureButton extends StatelessWidget {
  const _MeasureButton({required this.mp, required this.ble});
  final MeasurementProvider mp;
  final BleService          ble;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        final tracker = context.read<LaserTrackingService>();
        if (tracker.status == 'On Target' && ble.latestData.length >= 4) {
          final cam = context.read<CameraService>();
<<<<<<< HEAD
          tracker.toggleSnapshotMode(true,
=======
          tracker.toggleSnapshotMode(true, 
>>>>>>> 0603b4c11bdf8cd3d14e798584dbc93e36792e21
             currentDist: ble.latestData[0] / 10.0,
             currentRoll: ble.latestData[1],
             currentPitch: ble.latestData[2],
             currentYaw: ble.latestData[3],
          );
          cam.controller?.pausePreview();
        } else if (tracker.trackedCentroid != null) {
<<<<<<< HEAD
          // Portrait: effective centre is top-80% mid-point
          final size = MediaQuery.sizeOf(context);
          final ecX = size.width / 2;
          final ecY = (size.height * 0.8) / 2;
          final pt = Offset(
            (ecX + tracker.trackedCentroid!.dx) / size.width,
            (ecY + tracker.trackedCentroid!.dy) / size.height,
          );
          mp.capture(pt);
        } else {
          mp.capture(const Offset(0.5, 0.4));
=======
          final size = MediaQuery.sizeOf(context);
          final pt = Offset(
            (size.width / 2 + tracker.trackedCentroid!.dx) / size.width,
            ((size.height * 0.8) / 2 + tracker.trackedCentroid!.dy) / size.height,
          );
          mp.capture(pt);
        } else {
          mp.capture(const Offset(0.5, 0.4)); // 0.4 is 80% / 2
>>>>>>> 0603b4c11bdf8cd3d14e798584dbc93e36792e21
        }
      },
      child: Container(
        width: 72, height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withOpacity(0.1),
          boxShadow: [
            BoxShadow(
              color: AppColors.accent.withOpacity(0.4),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
          border: Border.all(
              color: Colors.white.withOpacity(0.3),
              width: 1.5),
        ),
        child: Center(
          child: Container(
            width: 56, height: 56,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.accent,
            ),
            child: const Icon(Icons.gps_fixed_rounded,
                size: 28, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

// ── Side buttons ─────────────────────────────────────────────────
class _SideBtn extends StatelessWidget {
  const _SideBtn({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.isDark,
  });
  final IconData     icon;
  final String       label;
  final VoidCallback onTap;
  final bool         isDark;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 48, height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isDark
            ? Colors.white.withOpacity(0.05)
            : Colors.black.withOpacity(0.05),
        border: Border.all(
          color: isDark ? Colors.white24 : Colors.black12,
        ),
      ),
      child: Icon(icon,
          size: 20,
          color: isDark
              ? Colors.white70
              : Colors.black87),
    ),
  );
}
