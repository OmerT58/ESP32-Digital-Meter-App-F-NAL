/// drawing_painter.dart — Autonomous CAD HUD paradigm
///
/// All points are FINAL screen-pixel Offsets.
/// No angle math here — the service owns coordinate computation.
library;

import 'dart:math' as math;
import 'package:flutter/material.dart';

// ── Solid line painter ────────────────────────────────────────────────────────
// `path` contains absolute screen-pixel Offsets. Draws them directly.
class SolidLinePainter extends CustomPainter {
  SolidLinePainter({
    required this.path,
    required this.color,
    required this.selectedShape,
  });

  final List<Offset> path;
  final Color        color;
  final String       selectedShape; // 'Rectangle' | 'Circle' | 'Test'

  @override
  void paint(Canvas canvas, Size size) {
    // TEST MODE: canvas must remain 100% blank.
    // Hard stop — do not draw ANYTHING regardless of _drawingPath contents.
    if (selectedShape == 'Test') return;

    if (path.length < 2) return;

    const double thickness = 3.5;

    // Neon glow layer
    final glowPaint = Paint()
      ..color       = color.withOpacity(0.45)
      ..strokeWidth = thickness * 2.5
      ..strokeCap   = StrokeCap.round
      ..strokeJoin  = StrokeJoin.round
      ..style       = PaintingStyle.stroke
      ..maskFilter  = const MaskFilter.blur(BlurStyle.normal, 5.0);

    // Solid bright line
    final linePaint = Paint()
      ..color       = color
      ..strokeWidth = thickness
      ..strokeCap   = StrokeCap.round
      ..strokeJoin  = StrokeJoin.round
      ..style       = PaintingStyle.stroke;

    // Draw segments
    for (int i = 0; i < path.length - 1; i++) {
      canvas.drawLine(path[i], path[i + 1], glowPaint);
      canvas.drawLine(path[i], path[i + 1], linePaint);
    }

    // Anchor dot at start
    canvas.drawCircle(path.first, thickness, Paint()..color = color);
    canvas.drawCircle(path.first, thickness * 0.5, Paint()..color = Colors.white);

    // End-cap dot at current position
    canvas.drawCircle(path.last, thickness * 0.8, Paint()..color = color);
    canvas.drawCircle(path.last, thickness * 0.4, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant SolidLinePainter old) =>
      old.selectedShape != selectedShape || true;
}


// ── Preview line painter (two-tap mode: A → live pointer) ────────────────────
class PreviewLinePainter extends CustomPainter {
  PreviewLinePainter({required this.from, required this.to, required this.color});

  final Offset from;
  final Offset to;
  final Color  color;

  @override
  void paint(Canvas canvas, Size size) {
    if ((to - from).distance < 1) return;

    const double thickness = 3.5;

    canvas.drawLine(
      from, to,
      Paint()
        ..color       = color.withOpacity(0.3)
        ..strokeWidth = thickness * 2.0
        ..strokeCap   = StrokeCap.round
        ..maskFilter  = const MaskFilter.blur(BlurStyle.normal, 4.0),
    );
    canvas.drawLine(
      from, to,
      Paint()
        ..color       = color.withOpacity(0.85)
        ..strokeWidth = thickness
        ..strokeCap   = StrokeCap.round,
    );

    // Anchor dot at Point A
    canvas.drawCircle(from, thickness, Paint()..color = color);
    canvas.drawCircle(from, thickness * 0.5, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant PreviewLinePainter old) => true;
}

// ── Shape painter (Two-Tap geometric mode) ────────────────────────────────────
// Draws a Rectangle OR Circle outline. Never filled.
class ShapePainter extends CustomPainter {
  ShapePainter({
    required this.pointA,
    required this.pointB,
    required this.shape,   // 'Rectangle' or 'Circle'
    required this.color,
  });

  final Offset pointA;
  final Offset pointB;
  final String shape;
  final Color  color;

  @override
  void paint(Canvas canvas, Size size) {
    if ((pointB - pointA).distance < 2) return;

    const double thickness = 3.0;

    final glowPaint = Paint()
      ..color       = color.withOpacity(0.40)
      ..strokeWidth = thickness * 2.5
      ..style       = PaintingStyle.stroke
      ..maskFilter  = const MaskFilter.blur(BlurStyle.normal, 5.0);

    final solidPaint = Paint()
      ..color       = color
      ..strokeWidth = thickness
      ..style       = PaintingStyle.stroke;

    if (shape == 'Circle') {
      final center = Offset(
        (pointA.dx + pointB.dx) / 2,
        (pointA.dy + pointB.dy) / 2,
      );
      final radius = (pointA - pointB).distance / 2;
      canvas.drawCircle(center, radius, glowPaint);
      canvas.drawCircle(center, radius, solidPaint);

      // Mark center
      canvas.drawCircle(center, 3.0, Paint()..color = color);
      canvas.drawCircle(center, 1.5, Paint()..color = Colors.white);
    } else {
      // Rectangle
      final rect = Rect.fromPoints(pointA, pointB);
      canvas.drawRect(rect, glowPaint);
      canvas.drawRect(rect, solidPaint);
    }

    // Corner dots at A and B
    for (final pt in [pointA, pointB]) {
      canvas.drawCircle(pt, thickness, Paint()..color = color);
      canvas.drawCircle(pt, thickness * 0.5, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(covariant ShapePainter old) => true;
}

// ── Flying Pointer Painter (Optic Scope crosshair) ───────────────────────────
// Draws the (+) symbol at [position].
// Idle  → screen center. Active → gyro-displaced.
class FlyingPointerPainter extends CustomPainter {
  FlyingPointerPainter({required this.position, required this.color});

  final Offset position;
  final Color  color;

  @override
  void paint(Canvas canvas, Size size) {
    const double armLen = 14.0;
    const double gapLen = 3.0;

    final glowPaint = Paint()
      ..color       = color.withOpacity(0.45)
      ..strokeWidth = 3.5
      ..strokeCap   = StrokeCap.round
      ..maskFilter  = const MaskFilter.blur(BlurStyle.normal, 3.0);

    final solidPaint = Paint()
      ..color       = color
      ..strokeWidth = 1.8
      ..strokeCap   = StrokeCap.round;

    final px = position.dx;
    final py = position.dy;

    for (final p in [glowPaint, solidPaint]) {
      canvas.drawLine(Offset(px - armLen, py), Offset(px - gapLen, py), p);
      canvas.drawLine(Offset(px + gapLen, py), Offset(px + armLen, py), p);
      canvas.drawLine(Offset(px, py - armLen), Offset(px, py - gapLen), p);
      canvas.drawLine(Offset(px, py + gapLen), Offset(px, py + armLen), p);
    }

    canvas.drawCircle(position, 3.0, Paint()..color = color.withOpacity(0.5));
    canvas.drawCircle(position, 1.5, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant FlyingPointerPainter old) => true;
}
