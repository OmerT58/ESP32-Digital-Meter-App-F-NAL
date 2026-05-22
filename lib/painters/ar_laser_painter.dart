/// ar_laser_painter.dart — Updated with settable laser colour + GEOMETRIC shapes
library;

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/measurement_mode.dart';
import '../models/measurement_provider.dart';

class ArLaserPainter extends CustomPainter {
  ArLaserPainter({
    required this.data,
    required this.mp,
    required this.laserColor,
    required this.animValue,
  });

  final List<double>        data;
  final MeasurementProvider mp;
  final Color               laserColor;
  final double              animValue;

  // ── Derived paint ─────────────────────────────────────────────
  Paint get _glow => Paint()
    ..color       = laserColor.withValues(alpha: 0.35)
    ..strokeWidth = 12
    ..strokeCap   = StrokeCap.round
    ..maskFilter  = const MaskFilter.blur(BlurStyle.normal, 9);

  Paint get _stroke => Paint()
    ..color       = laserColor
    ..strokeWidth = 2
    ..strokeCap   = StrokeCap.round
    ..style       = PaintingStyle.stroke;

  Paint get _fill => Paint()
    ..color = laserColor.withValues(alpha: 0.06)
    ..style = PaintingStyle.fill;

  Paint get _grid => Paint()
    ..color       = laserColor.withValues(alpha: 0.18)
    ..strokeWidth = 0.5;

  Paint get _corner => Paint()
    ..color       = Colors.white
    ..strokeWidth = 2.2
    ..strokeCap   = StrokeCap.square
    ..style       = PaintingStyle.stroke;

  // ── Entry ─────────────────────────────────────────────────────
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final tip    = _tip(size);

    switch (mp.mode) {
      case MeasurementMode.line:
        _drawLine(canvas, center, tip);
      case MeasurementMode.area:
        _drawRect(canvas, size, center, tip, withDepth: false);
      case MeasurementMode.test:
        // Test mode: simple crosshair only, no AR overlay
        break;
      case MeasurementMode.geometric:
        _drawGeometric(canvas, size);
    }
    _drawTip(canvas, tip);
  }

  // ── LINE ──────────────────────────────────────────────────────
  void _drawLine(Canvas canvas, Offset o, Offset tip) {
    canvas.drawLine(o, tip, _glow);
    canvas.drawLine(o, tip, _stroke);
    _ticks(canvas, o, tip, 5);
  }

  // ── AREA / VOLUME ─────────────────────────────────────────────
  void _drawRect(Canvas canvas, Size sz, Offset ctr, Offset tip,
      {required bool withDepth}) {
    final hw = (tip.dx - ctr.dx).abs().clamp(12.0, sz.width  * 0.46);
    final hh = (tip.dy - ctr.dy).abs().clamp(12.0, sz.height * 0.44);
    final r  = Rect.fromCenter(center: ctr, width: hw * 2, height: hh * 2);

    _localGrid(canvas, r);
    canvas.drawRect(r, _fill);

    // animated border
    final pm = (Path()..addRect(r)).computeMetrics().first;
    final t  = ((animValue * 1.25).clamp(0.0, 1.0));
    canvas.drawPath(pm.extractPath(0, pm.length * t),
        Paint()
          ..color       = laserColor.withValues(alpha: 0.4)
          ..strokeWidth = 8
          ..style       = PaintingStyle.stroke
          ..maskFilter  = const MaskFilter.blur(BlurStyle.normal, 7));
    canvas.drawPath(pm.extractPath(0, pm.length * t), _stroke);

    // highlight dot
    final dot = pm.getTangentForOffset(pm.length * animValue)!.position;
    canvas.drawCircle(dot, 5,
        Paint()..color = Colors.white
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));

    _corners(canvas, r);
    
    final double distanceMm = data.isNotEmpty ? data[0] : 0.0;
    final double pitchDeg = data.length > 1 ? data[1] : 0.0;
    final double distanceM = distanceMm / 1000.0;
    final double pitchRad = pitchDeg * math.pi / 180.0;
    final double horizontalM = distanceM * math.cos(pitchRad);
    
    _dimLabel(canvas, '${(hw * 2 / sz.width  * horizontalM * 2 * 100).toStringAsFixed(1)} cm',
        Offset(r.center.dx, r.bottom + 14));

    if (withDepth) {
      const d = 36.0;
      final back = r.shift(const Offset(d, -d));
      final dp = Paint()
        ..color       = laserColor.withValues(alpha: 0.5)
        ..strokeWidth = 1.2
        ..style       = PaintingStyle.stroke;
      canvas.drawRect(back, dp);
      for (final pair in [(r.topLeft, back.topLeft),
                          (r.topRight, back.topRight),
                          (r.bottomLeft, back.bottomLeft),
                          (r.bottomRight, back.bottomRight)]) {
        canvas.drawLine(pair.$1, pair.$2, dp);
      }
    }
  }

  // ── GEOMETRIC ─────────────────────────────────────────────────
  void _drawGeometric(Canvas canvas, Size size) {
    final pts = mp.points;
    if (pts.isEmpty) return;

    final p0 = _normToScreen(pts[0], size);
    
    final double distanceMm = data.isNotEmpty ? data[0] : 0.0;
    final double pitchDeg = data.length > 1 ? data[1] : 0.0;
    final double distanceM = distanceMm / 1000.0;
    final double pitchRad = pitchDeg * math.pi / 180.0;
    final double horizontalM = distanceM * math.cos(pitchRad);

    if (mp.geoShape == GeometricShape.circle) {
      if (pts.length < 2) {
        // show centre dot only
        canvas.drawCircle(p0, 6, Paint()..color = laserColor);
        return;
      }
      final p1 = _normToScreen(pts[1], size);
      final r  = (p1 - p0).distance;
      canvas.drawCircle(p0, r, _fill);
      canvas.drawCircle(p0, r,
          Paint()
            ..color       = laserColor.withValues(alpha: 0.5)
            ..strokeWidth = 8
            ..style       = PaintingStyle.stroke
            ..maskFilter  = const MaskFilter.blur(BlurStyle.normal, 7));
      canvas.drawCircle(p0, r, _stroke);
      canvas.drawLine(p0, p1, _stroke);
      // radius label
      _dimLabel(canvas,
          'R = ${(r / size.width * horizontalM * 2 * 100).toStringAsFixed(1)} cm',
          Offset(p0.dx, p0.dy - r - 16));

    } else {
      // Square: p0 & p1 are opposite corners
      if (pts.length < 2) {
        canvas.drawCircle(p0, 6, Paint()..color = laserColor);
        return;
      }
      final p1 = _normToScreen(pts[1], size);
      final rect = Rect.fromPoints(p0, p1);
      // make it square from the diagonal
      final side = (p1 - p0).distance / math.sqrt2;
      final sqRect = Rect.fromCenter(
        center: rect.center, width: side, height: side);
      _localGrid(canvas, sqRect);
      canvas.drawRect(sqRect, _fill);
      canvas.drawRect(sqRect,
          Paint()
            ..color       = laserColor.withValues(alpha: 0.45)
            ..strokeWidth = 7
            ..style       = PaintingStyle.stroke
            ..maskFilter  = const MaskFilter.blur(BlurStyle.normal, 7));
      canvas.drawRect(sqRect, _stroke);
      _corners(canvas, sqRect);
      _dimLabel(canvas,
          'S = ${(side / size.width * horizontalM * 2 * 100).toStringAsFixed(1)} cm',
          Offset(sqRect.center.dx, sqRect.bottom + 14));
    }
  }

  // ── Helpers ───────────────────────────────────────────────────

  Offset _tip(Size sz) {
    final double pitchDeg = data.length > 1 ? data[1] : 0.0;
    final double yawDeg = data.length > 2 ? data[2] : 0.0;
    
    final nx = (yawDeg   / 30.0).clamp(-1.0, 1.0);
    final ny = (-pitchDeg / 22.5).clamp(-1.0, 1.0);
    return Offset(sz.width * (0.5 + nx * 0.42),
                  sz.height * (0.5 + ny * 0.42));
  }

  Offset _normToScreen(Offset n, Size sz) =>
      Offset(n.dx * sz.width, n.dy * sz.height);

  void _localGrid(Canvas canvas, Rect bounds) {
    const step = 28.0;
    for (double x = bounds.left + step; x < bounds.right;  x += step) {
      canvas.drawLine(Offset(x, bounds.top),
                      Offset(x, bounds.bottom), _grid);
    }
    for (double y = bounds.top  + step; y < bounds.bottom; y += step) {
      canvas.drawLine(Offset(bounds.left, y),
                      Offset(bounds.right, y), _grid);
    }
  }

  void _corners(Canvas canvas, Rect r) {
    const L = 14.0;
    for (final t in [(r.left, r.top, 1, 1), (r.right, r.top, -1, 1),
                     (r.left, r.bottom, 1, -1), (r.right, r.bottom, -1, -1)]) {
      canvas
        ..drawLine(Offset(t.$1, t.$2),
                   Offset(t.$1 + t.$3 * L, t.$2), _corner)
        ..drawLine(Offset(t.$1, t.$2),
                   Offset(t.$1, t.$2 + t.$4 * L), _corner);
    }
  }

  void _ticks(Canvas canvas, Offset o, Offset tip, int n) {
    final p = Paint()
      ..color       = laserColor.withValues(alpha: 0.4)
      ..strokeWidth = 1;
    final dx = tip.dx - o.dx, dy = tip.dy - o.dy;
    final len = math.sqrt(dx * dx + dy * dy);
    if (len == 0) return;
    for (int i = 1; i <= n; i++) {
      final t  = i / n;
      final px = o.dx + dx * t, py = o.dy + dy * t;
      final ex = -dy / len * 5, ey = dx / len * 5;
      canvas.drawLine(Offset(px - ex, py - ey),
                      Offset(px + ex, py + ey), p);
    }
  }

  /// Minimal sensor-tip indicator — small dot + clean crosshair arms.
  /// No glow, no pulse, no bloom: matches the Soft UI design language.
  void _drawTip(Canvas canvas, Offset tip) {
    // Solid laser-colour dot
    canvas.drawCircle(tip, 3.5, Paint()..color = laserColor);
    // White centre highlight
    canvas.drawCircle(tip, 1.5, Paint()..color = Colors.white);

    // Four clean crosshair arms
    final p = Paint()
      ..color       = Colors.white.withValues(alpha: 0.80)
      ..strokeWidth = 1.2
      ..strokeCap   = StrokeCap.round;
    const gap = 5.0;
    const arm = 11.0;
    canvas.drawLine(tip + Offset(-arm, 0), tip + Offset(-gap, 0), p);
    canvas.drawLine(tip + Offset( gap, 0), tip + Offset( arm, 0), p);
    canvas.drawLine(tip + Offset(0, -arm), tip + Offset(0, -gap), p);
    canvas.drawLine(tip + Offset(0,  gap), tip + Offset(0,  arm), p);
  }

  void _dimLabel(Canvas canvas, String text, Offset pos) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: 'Orbitron',
          fontSize  : 10,
          color     : Colors.white,
          shadows   : const [Shadow(blurRadius: 6, color: Colors.black)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, pos - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(ArLaserPainter o) =>
      o.data != data || o.animValue != animValue ||
      o.mp.mode != mp.mode || o.mp.points != mp.points ||
      o.laserColor != laserColor;
}
