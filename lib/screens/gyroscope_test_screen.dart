import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/ble_service.dart';

class GyroscopeTestScreen extends StatelessWidget {
  const GyroscopeTestScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      body: Stack(
        children: [
          Positioned.fill(
            child: StreamBuilder<List<double>>(
              stream: BleService.instance.dataStream,
              initialData: BleService.instance.latestData,
              builder: (context, snapshot) {
                final data = snapshot.data ?? [0.0, 0.0, 0.0, 0.0];
                final double roll = data.length > 1 ? data[1] : 0.0;
                final double pitch = data.length > 2 ? data[2] : 0.0;
                return _BubbleLevelVisualizer(
                  roll: roll,
                  pitch: pitch,
                );
              },
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16,
            child: IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Color(0x4DE5E7EB),
              ),
              onPressed: () => Navigator.pop(context),
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
            ),
          ),
        ],
      ),
    );
  }
}

class _BubbleLevelVisualizer extends StatelessWidget {
  const _BubbleLevelVisualizer({
    required this.roll,
    required this.pitch,
  });

  final double roll;
  final double pitch;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOutCubic,
      tween: Tween<double>(begin: roll, end: roll),
      builder: (context, animRoll, child) {
        return TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutCubic,
          tween: Tween<double>(begin: pitch, end: pitch),
          builder: (context, animPitch, child) {
            return CustomPaint(
              size: Size.infinite,
              painter: BubbleLevelPainter(
                roll: animRoll,
                pitch: animPitch,
              ),
            );
          },
        );
      },
    );
  }
}

class BubbleLevelPainter extends CustomPainter {
  BubbleLevelPainter({
    required this.roll,
    required this.pitch,
  });

  final double roll;
  final double pitch;

  @override
  void paint(Canvas canvas, Size size) {
    final double cx = size.width / 2;
    final double cy = size.height / 2;

    final bool isLevel = roll.abs() <= 1.0 && pitch.abs() <= 1.0;
    
    final Color activeColor = isLevel ? Colors.greenAccent : Colors.cyanAccent;
    final Color inactiveColor = const Color(0xFF333333);

    // Max angle represented by the edge of the circle (e.g. 45 degrees)
    const double maxAngle = 45.0;
    
    // Outer vial body radius
    final double maxRadius = math.min(size.width, size.height) * 0.35;
    
    // Background of the level
    final Paint bgPaint = Paint()
      ..color = const Color(0xFF0A0A0A)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx, cy), maxRadius, bgPaint);

    // Grid lines inside the vial
    final Paint gridPaint = Paint()
      ..color = inactiveColor
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    
    canvas.drawLine(Offset(cx - maxRadius, cy), Offset(cx + maxRadius, cy), gridPaint);
    canvas.drawLine(Offset(cx, cy - maxRadius), Offset(cx, cy + maxRadius), gridPaint);

    // Draw concentric circles
    canvas.drawCircle(Offset(cx, cy), maxRadius, gridPaint);
    canvas.drawCircle(Offset(cx, cy), maxRadius * 0.6, gridPaint);
    canvas.drawCircle(Offset(cx, cy), maxRadius * 0.2, Paint()
      ..color = activeColor.withOpacity(0.5)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke);

    // Calculate bubble position
    // Bubble moves opposite to tilt for realism (like an air bubble in water)
    // Actually, if device tilts left (roll < 0), bubble moves right.
    // If device tilts up (pitch > 0), bubble moves down.
    double clampRoll = roll.clamp(-maxAngle, maxAngle);
    double clampPitch = pitch.clamp(-maxAngle, maxAngle);
    
    double dx = -(clampRoll / maxAngle) * maxRadius;
    double dy = -(clampPitch / maxAngle) * maxRadius;

    // Make sure bubble stays inside the circle (euclidean clamping)
    final double dist = math.sqrt(dx * dx + dy * dy);
    final double bubbleRadius = maxRadius * 0.15;
    final double maxMove = maxRadius - bubbleRadius;
    
    if (dist > maxMove) {
      dx = dx / dist * maxMove;
      dy = dy / dist * maxMove;
    }

    final Offset bubblePos = Offset(cx + dx, cy + dy);

    // Bubble glow
    final Paint bubbleGlow = Paint()
      ..color = activeColor.withOpacity(0.4)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(bubblePos, bubbleRadius * 1.5, bubbleGlow);

    // Inner bubble
    final Paint bubblePaint = Paint()
      ..color = activeColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(bubblePos, bubbleRadius, bubblePaint);
    
    // Bubble highlight
    final Paint highlight = Paint()
      ..color = Colors.white.withOpacity(0.6)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(bubblePos + Offset(-bubbleRadius*0.3, -bubbleRadius*0.3), bubbleRadius * 0.25, highlight);

    // Draw text overlays for current angles
    _drawText(canvas, 'PITCH: ${pitch.toStringAsFixed(1)}°', Offset(cx, cy + maxRadius + 40), activeColor);
    _drawText(canvas, 'ROLL: ${roll.toStringAsFixed(1)}°', Offset(cx, cy + maxRadius + 70), activeColor);
    if (isLevel) {
      _drawText(canvas, 'PERFECTLY LEVEL', Offset(cx, cy - maxRadius - 50), Colors.greenAccent, isBold: true);
    }
  }

  void _drawText(Canvas canvas, String text, Offset center, Color color, {bool isBold = false}) {
    final textSpan = TextSpan(
      text: text,
      style: TextStyle(
        color: color,
        fontSize: 16,
        fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
        fontFamily: 'Inter',
        letterSpacing: 2.0,
      ),
    );
    final textPainter = TextPainter(
      text: textSpan,
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(center.dx - textPainter.width / 2, center.dy - textPainter.height / 2));
  }

  @override
  bool shouldRepaint(covariant BubbleLevelPainter oldDelegate) {
    return oldDelegate.roll != roll || oldDelegate.pitch != pitch;
  }
}
