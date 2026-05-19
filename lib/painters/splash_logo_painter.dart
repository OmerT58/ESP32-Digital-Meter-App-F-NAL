/// splash_logo_painter.dart — Minimalist digital meter icon
library;

import 'dart:math' as math;
import 'package:flutter/material.dart';

class SplashLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cy = size.height / 2;
    final w  = size.width;
    final h  = size.height;

    // ── Device body ──────────────────────────────────────────
    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.12, h * 0.28, w * 0.50, h * 0.44),
      const Radius.circular(10),
    );
    canvas.drawRRect(
      bodyRect,
      Paint()
        ..color = const Color(0xFF2A2D3A)
        ..style = PaintingStyle.fill,
    );
    canvas.drawRRect(
      bodyRect,
      Paint()
        ..color = const Color(0xFF30D158)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke,
    );

    // ── Emitter nub ───────────────────────────────────────────
    canvas.drawRect(
      Rect.fromLTWH(w * 0.60, h * 0.40, w * 0.08, h * 0.20),
      Paint()..color = const Color(0xFF30D158),
    );

    // ── Laser beam (dashed line) ───────────────────────────────
    final beamPaint = Paint()
      ..color = const Color(0xFFFF3B30)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    const dashLen = 5.0;
    const gapLen  = 4.0;
    double x = w * 0.70;
    final endX = w * 0.94;
    final beamY = cy;
    while (x < endX) {
      canvas.drawLine(
        Offset(x, beamY),
        Offset(math.min(x + dashLen, endX), beamY),
        beamPaint,
      );
      x += dashLen + gapLen;
    }

    // ── Target circle ─────────────────────────────────────────
    final targetPaint = Paint()
      ..color = const Color(0xFFFF3B30)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(Offset(w * 0.90, cy), 9, targetPaint);
    canvas.drawCircle(Offset(w * 0.90, cy), 3,
        Paint()..color = const Color(0xFFFF3B30));

    // ── Small screen on device body ───────────────────────────
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.18, h * 0.36, w * 0.28, h * 0.16),
        const Radius.circular(4),
      ),
      Paint()..color = const Color(0xFF30D158).withValues(alpha: 0.25),
    );

    // ── Angle arc ─────────────────────────────────────────────
    final arcRect = Rect.fromCenter(
      center: Offset(w * 0.68, h * 0.50), width: 24, height: 24);
    canvas.drawArc(arcRect, -math.pi / 4, math.pi / 2,
        false,
        Paint()
          ..color = const Color(0xFF007AFF)
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke);
  }

  @override
  bool shouldRepaint(SplashLogoPainter _) => false;
}
