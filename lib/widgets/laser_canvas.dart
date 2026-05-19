/// laser_canvas.dart
/// ─────────────────────────────────────────────────────────────
/// Animated widget that hosts [LaserPainter].
///
/// Drives a looping [AnimationController] that forwards the
/// current animation tick into the painter to animate the range
/// rings and other time-varying effects.
/// ─────────────────────────────────────────────────────────────
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../painters/laser_painter.dart';
import '../services/ble_service.dart';
import '../theme/app_theme.dart';

class LaserCanvas extends StatefulWidget {
  const LaserCanvas({super.key});

  @override
  State<LaserCanvas> createState() => _LaserCanvasState();
}

class _LaserCanvasState extends State<LaserCanvas>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync   : this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ble = context.watch<BleService>();

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Container(
            decoration: BoxDecoration(
              color : AppColors.surface,
              border: Border.all(
                color: ble.isConnected
                    ? AppColors.neonRedDim
                    : AppColors.divider,
                width: 1.5,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: ble.isConnected
                  ? [
                      BoxShadow(
                        color      : AppColors.neonRedGlow,
                        blurRadius : 24,
                        spreadRadius: 4,
                      )
                    ]
                  : [],
            ),
            child: CustomPaint(
              painter: LaserPainter(
                data     : ble.latestData,
                animValue: _controller.value,
              ),
              // Fill available space
              child: const SizedBox.expand(),
            ),
          ),
        );
      },
    );
  }
}
