/// neon_strip_painter.dart
/// ─────────────────────────────────────────────────────────────────
/// Renders the AR drawing path as an animated neon measurement tape:
///
///   • Thick (14 px) semi-transparent ribbon filled with a cyan gradient
///   • Outer soft-glow halo (blurred, wider stroke)
///   • Inner flowing dash pattern — offset driven by [animValue] to
///     create a continuous conveyor-belt / pulse animation
///   • Anchor dot at the first point
///   • Works for both Continuous paths (polyline) and Two-Tap segments
/// ─────────────────────────────────────────────────────────────────
library;

import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

class NeonStripPainter extends CustomPainter {
  NeonStripPainter({
    required this.path,
    required this.animValue, // 0.0 → 1.0 looped from AnimationController
  });

  final List<Offset> path;

  /// Animation value from the 1-second looping controller.
  /// Drives the internal dash offset for the conveyor-belt effect.
  final double animValue;

  // ── Strip dimensions ──────────────────────────────────────────────
  static const double _stripWidth  = 14.0;
  static const double _glowWidth   = 26.0;
  static const double _dashLen     = 18.0;
  static const double _gapLen      = 10.0;
  static const double _segmentLen  = _dashLen + _gapLen; // 28 px cycle

  // ── Colours ───────────────────────────────────────────────────────
  static const Color _cyanBright  = Color(0xFF00FFFF);
  static const Color _cyanMid     = Color(0xFF00E5FF);
  static const Color _cyanDim     = Color(0xFF0097A7);
  static const Color _glowColor   = Color(0x5500FFFF);
  static const Color _dashColor   = Color(0xCCFFFFFF);
  static const Color _anchorColor = Color(0xFF00FFFF);

  @override
  void paint(Canvas canvas, Size size) {
    if (path.length < 2) return;

    // Build the flutter Path
    final flutterPath = Path()..moveTo(path.first.dx, path.first.dy);
    for (int i = 1; i < path.length; i++) {
      flutterPath.lineTo(path[i].dx, path[i].dy);
    }

    // ── 1. Soft outer glow ──────────────────────────────────────────
    final glowPaint = Paint()
      ..color       = _glowColor
      ..strokeWidth = _glowWidth
      ..strokeCap   = StrokeCap.round
      ..strokeJoin  = StrokeJoin.round
      ..style       = PaintingStyle.stroke
      ..maskFilter  = const MaskFilter.blur(BlurStyle.normal, 10.0);
    canvas.drawPath(flutterPath, glowPaint);

    // ── 2. Thick ribbon with gradient (segment-by-segment) ──────────
    _drawGradientStrip(canvas);

    // ── 3. Animated internal dashes ─────────────────────────────────
    _drawFlowingDashes(canvas);

    // ── 4. Bright centre-line spine ─────────────────────────────────
    final spinePaint = Paint()
      ..color       = _cyanBright.withOpacity(0.55)
      ..strokeWidth = 1.5
      ..strokeCap   = StrokeCap.round
      ..strokeJoin  = StrokeJoin.round
      ..style       = PaintingStyle.stroke;
    canvas.drawPath(flutterPath, spinePaint);

    // ── 5. Anchor dot at start ───────────────────────────────────────
    canvas.drawCircle(
      path.first,
      5.5,
      Paint()
        ..color      = _anchorColor
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawCircle(path.first, 3.0, Paint()..color = Colors.white);

    // ── 6. End-cap dot at last point ────────────────────────────────
    if (path.length >= 2) {
      canvas.drawCircle(
        path.last,
        4.0,
        Paint()
          ..color      = _cyanMid
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
      canvas.drawCircle(path.last, 2.5, Paint()..color = Colors.white);
    }
  }

  /// Draws the thick ribbon segment-by-segment, applying a local
  /// linear gradient along each segment direction.
  void _drawGradientStrip(Canvas canvas) {
    for (int i = 0; i < path.length - 1; i++) {
      final a = path[i];
      final b = path[i + 1];
      final dist = (b - a).distance;
      if (dist < 0.5) continue;

      final shader = ui.Gradient.linear(
        a, b,
        [_cyanDim, _cyanBright, _cyanMid, _cyanDim],
        [0.0,      0.35,        0.65,      1.0],
      );

      final ribbonPaint = Paint()
        ..shader      = shader
        ..strokeWidth = _stripWidth
        ..strokeCap   = StrokeCap.round
        ..style       = PaintingStyle.stroke
        ..strokeJoin  = StrokeJoin.round;

      canvas.drawLine(a, b, ribbonPaint);
    }
  }

  /// Walks the polyline and places animated dashes whose phase offset
  /// is driven by [animValue], producing a conveyor-belt flow effect.
  void _drawFlowingDashes(Canvas canvas) {
    final dashPaint = Paint()
      ..color       = _dashColor
      ..strokeWidth = 3.5
      ..strokeCap   = StrokeCap.round
      ..style       = PaintingStyle.stroke;

    final basePhase = animValue * _segmentLen;
    double accumulatedDist = 0.0;

    for (int seg = 0; seg < path.length - 1; seg++) {
      final a = path[seg];
      final b = path[seg + 1];
      final segDist = (b - a).distance;
      if (segDist < 0.5) continue;

      final dir = (b - a) / segDist;

      // We want to draw dashes on this segment.
      // A dash exists for distances D where (D - basePhase) % _segmentLen < _dashLen.
      // D is absolute distance along the polyline.
      
      // For this segment, D ranges from accumulatedDist to accumulatedDist + segDist.
      // We can map this to local distance t from 0 to segDist.
      // D = accumulatedDist + t
      // (accumulatedDist + t - basePhase) % _segmentLen < _dashLen
      
      // So local dash starts at t where:
      // accumulatedDist + t - basePhase = k * _segmentLen
      // t = k * _segmentLen + basePhase - accumulatedDist
      
      final double phaseOffset = (basePhase - accumulatedDist) % _segmentLen;
      // phaseOffset is the first positive t where a dash cycle starts.
      // But we also need to check the cycle just before it, in case a dash overlaps t=0.
      
      double t = phaseOffset;
      if (t > 0) {
        t -= _segmentLen;
      }

      while (t < segDist) {
        final dashStart = math.max(0.0, t);
        final dashEnd = math.min(t + _dashLen, segDist);
        
        if (dashEnd > dashStart) {
          canvas.drawLine(
            a + dir * dashStart,
            a + dir * dashEnd,
            dashPaint,
          );
        }
        t += _segmentLen;
      }

      accumulatedDist += segDist;
    }
  }

  @override
  bool shouldRepaint(covariant NeonStripPainter old) =>
      old.animValue != animValue || old.path != path;
}

/// Preview-line painter for Two-Tap mode — uses the same neon style
/// but with a dashed animation to indicate "pending" state.
class NeonPreviewLinePainter extends CustomPainter {
  NeonPreviewLinePainter({
    required this.from,
    required this.to,
    required this.animValue,
  });

  final Offset from;
  final Offset to;
  final double animValue;

  static const double _dashLen    = 14.0;
  static const double _gapLen     = 8.0;
  static const double _segmentLen = _dashLen + _gapLen;

  @override
  void paint(Canvas canvas, Size size) {
    final total = (to - from).distance;
    if (total < 1) return;
    final dir = (to - from) / total;

    // Outer glow
    canvas.drawLine(
      from, to,
      Paint()
        ..color       = const Color(0x4400FFFF)
        ..strokeWidth = 18
        ..strokeCap   = StrokeCap.round
        ..maskFilter  = const MaskFilter.blur(BlurStyle.normal, 8),
    );

    // Animated dashes (scrolling opposite direction for "targeting" feel)
    final phaseOffset = (1.0 - animValue) * _segmentLen;
    final dashPaint = Paint()
      ..color       = const Color(0xCC00FFFF)
      ..strokeWidth = 3.0
      ..strokeCap   = StrokeCap.round;

    double t = _segmentLen - phaseOffset;
    if (t >= _segmentLen) t -= _segmentLen;
    while (t < total) {
      final dashEnd = math.min(t + _dashLen, total);
      canvas.drawLine(from + dir * t, from + dir * dashEnd, dashPaint);
      t += _segmentLen;
    }

    // Anchor dot at Point A
    canvas.drawCircle(
      from, 5.5,
      Paint()
        ..color      = const Color(0xFF00FFFF)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    canvas.drawCircle(from, 3.0, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant NeonPreviewLinePainter old) =>
      old.from != from || old.to != to || old.animValue != animValue;
}
