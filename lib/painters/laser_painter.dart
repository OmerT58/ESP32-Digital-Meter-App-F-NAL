/// laser_painter.dart
/// ─────────────────────────────────────────────────────────────
/// CustomPainter that renders the interactive laser-beam canvas.
///
/// Visual elements:
///   • Dark grid / crosshair backdrop
///   • Origin point (laser source) at canvas center
///   • Red neon beam whose direction is controlled by yaw & pitch
///   • Glow effect (blurred wider stroke behind the crisp stroke)
///   • Animated concentric range rings
///   • Hit-point spark at the beam tip
///   • HUD overlay: angle readout text
/// ─────────────────────────────────────────────────────────────
library;

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class LaserPainter extends CustomPainter {
  LaserPainter({
    required this.data,
    required this.animValue, // 0.0 → 1.0 looped animation tick
  });

  final List<double> data;
  final double    animValue;

  // ── Paint instances (reused to avoid per-frame allocation) ─────
  final Paint _glowPaint = Paint()
    ..color     = AppColors.neonRedDim
    ..strokeWidth = 18
    ..strokeCap   = StrokeCap.round
    ..maskFilter  = const MaskFilter.blur(BlurStyle.normal, 12);

  final Paint _beamPaint = Paint()
    ..color     = AppColors.neonRed
    ..strokeWidth = 2.5
    ..strokeCap   = StrokeCap.round;

  final Paint _gridPaint = Paint()
    ..color     = const Color(0xFF1A1A1A)
    ..strokeWidth = 0.5;

  final Paint _ringPaint = Paint()
    ..color   = AppColors.neonRedGlow
    ..style   = PaintingStyle.stroke
    ..strokeWidth = 1;

  final Paint _originPaint = Paint()
    ..color = AppColors.neonRed;

  final Paint _sparkPaint = Paint()
    ..color     = AppColors.neonRed
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width  / 2;
    final cy = size.height / 2;

    _drawGrid(canvas, size, cx, cy);
    _drawRangeRings(canvas, cx, cy, size);
    _drawOrigin(canvas, cx, cy);
    _drawBeam(canvas, cx, cy, size);
    _drawHud(canvas, size);
  }

  // ── Grid ───────────────────────────────────────────────────────
  void _drawGrid(Canvas canvas, Size size, double cx, double cy) {
    const step = 40.0;

    // Vertical lines
    for (double x = cx % step; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), _gridPaint);
    }
    // Horizontal lines
    for (double y = cy % step; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), _gridPaint);
    }

    // Crosshair
    final crossPaint = Paint()
      ..color     = AppColors.neonGreenDim
      ..strokeWidth = 0.8;
    canvas.drawLine(Offset(cx, 0), Offset(cx, size.height), crossPaint);
    canvas.drawLine(Offset(0, cy), Offset(size.width, cy), crossPaint);
  }

  // ── Animated range rings ───────────────────────────────────────
  void _drawRangeRings(Canvas canvas, double cx, double cy, Size size) {
    final maxRadius = math.min(size.width, size.height) * 0.45;
    const ringCount = 4;

    for (int i = 1; i <= ringCount; i++) {
      final baseRadius = maxRadius * i / ringCount;

      // Pulsate outward from center, phase-shifted per ring
      final phase   = (animValue + i / ringCount) % 1.0;
      final radius  = baseRadius + phase * (maxRadius / ringCount * 0.3);
      final opacity = (1 - phase).clamp(0.0, 1.0);

      _ringPaint.color = AppColors.neonRedGlow.withValues(alpha: opacity * 0.6);
      canvas.drawCircle(Offset(cx, cy), radius, _ringPaint);
    }
  }

  // ── Origin dot ─────────────────────────────────────────────────
  void _drawOrigin(Canvas canvas, double cx, double cy) {
    // Outer glow
    canvas.drawCircle(
      Offset(cx, cy),
      10,
      Paint()
        ..color     = AppColors.neonRedDim
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    // Solid dot
    canvas.drawCircle(Offset(cx, cy), 4, _originPaint);
  }

  // ── Laser beam ─────────────────────────────────────────────────
  void _drawBeam(Canvas canvas, double cx, double cy, Size size) {
    // Map yaw (−180…+180°) → canvas direction angle
    // yaw=0 points right (+X), yaw grows counter-clockwise
    // Map pitch (−90…+90°) → scale the beam length
    //   pitch = 0  → full length
    //   |pitch| high → shorter projected length on the 2-D canvas

    final double distanceMm = data.isNotEmpty ? data[0] : 0.0;
    final double pitchDeg = data.length > 1 ? data[1] : 0.0;
    final double yawDeg = data.length > 2 ? data[2] : 0.0;
    
    final yawRad   = yawDeg * math.pi / 180.0;
    final pitchRad = pitchDeg * math.pi / 180.0;

    // Maximum beam length scales with canvas size
    final maxLen = math.min(size.width, size.height) * 0.42;

    // Length decreases as |pitch| increases (cosine projection)
    final beamLen = maxLen * math.cos(pitchRad).clamp(0.05, 1.0) *
        _normaliseDistance(distanceMm);

    // Direction vector (canvas: +Y is down, so negate sin for yaw)
    final dx = math.cos(yawRad);
    final dy = -math.sin(yawRad); // flip so yaw=0 → right

    final tipX = cx + dx * beamLen;
    final tipY = cy + dy * beamLen;

    // Glow stroke
    canvas.drawLine(Offset(cx, cy), Offset(tipX, tipY), _glowPaint);

    // Crisp beam
    canvas.drawLine(Offset(cx, cy), Offset(tipX, tipY), _beamPaint);

    // Hit-point spark
    _sparkPaint.color = AppColors.neonRed;
    canvas.drawCircle(Offset(tipX, tipY), 6, _sparkPaint);
    canvas.drawCircle(
      Offset(tipX, tipY),
      3,
      Paint()..color = Colors.white,
    );

    // Dashed distance tick marks along beam
    _drawBeamTicks(canvas, cx, cy, dx, dy, beamLen);
  }

  void _drawBeamTicks(Canvas canvas, double cx, double cy,
      double dx, double dy, double beamLen) {
    const tickCount = 5;
    final tickPaint = Paint()
      ..color     = AppColors.neonRed.withValues(alpha: 0.4)
      ..strokeWidth = 1;

    for (int i = 1; i <= tickCount; i++) {
      final t  = i / tickCount;
      final px = cx + dx * beamLen * t;
      final py = cy + dy * beamLen * t;

      // Perpendicular tick
      final perpX = -dy * 4;
      final perpY =  dx * 4;

      canvas.drawLine(
        Offset(px - perpX, py - perpY),
        Offset(px + perpX, py + perpY),
        tickPaint,
      );
    }
  }

  // ── HUD overlay ────────────────────────────────────────────────
  void _drawHud(Canvas canvas, Size size) {
    final double pitchDeg = data.length > 1 ? data[1] : 0.0;
    final double yawDeg = data.length > 2 ? data[2] : 0.0;
    
    _drawHudText(
      canvas,
      'YAW  ${yawDeg.toStringAsFixed(1)}°',
      Offset(12, size.height - 44),
    );
    _drawHudText(
      canvas,
      'PTCH ${pitchDeg.toStringAsFixed(1)}°',
      Offset(12, size.height - 24),
    );
  }

  void _drawHudText(Canvas canvas, String text, Offset position) {
    final tp = TextPainter(
      text: TextSpan(
        text : text,
        style: TextStyle(
          fontFamily: 'poppins',
          fontSize  : 11,
          color     : AppColors.neonGreen.withValues(alpha: 0.8),
          letterSpacing: 1.2,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, position);
  }

  // ── Distance normalisation ─────────────────────────────────────
  /// Returns a 0.05…1.0 factor: full length at 10 m, min at 0.
  double _normaliseDistance(double distanceMm) {
    const maxMm = 10000; // 10 m
    if (distanceMm <= 0) return 0.05;
    return (distanceMm / maxMm).clamp(0.05, 1.0);
  }

  @override
  bool shouldRepaint(LaserPainter old) =>
      old.data      != data ||
      old.animValue != animValue;
}
