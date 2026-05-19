/// draw_mode_toggle.dart — Shared Continuous / Two-Tap draw mode toggle widget
library;

import 'package:flutter/material.dart';
import '../services/laser_tracking_service.dart';

/// Animated pill/icon toggle for switching between Continuous and Two-Tap draw modes.
///
/// [compact] = true renders an icon-only circular button (for the narrow landscape sidebar).
/// [iconTurns] = 0.25 rotates the icon 90° to face correctly in landscape orientation.
class DrawModeToggle extends StatelessWidget {
  const DrawModeToggle({
    super.key,
    required this.tracker,
    this.iconTurns = 0.0,
    this.compact = false,
  });

  final LaserTrackingService tracker;

  /// Fractional turns for AnimatedRotation (0.25 = 90°).
  final double iconTurns;

  /// compact = true → icon-only circle (landscape sidebar).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final isTwoTap = tracker.isTwoTapMode;

    if (compact) {
      return GestureDetector(
        onTap: () => tracker.setTwoTapMode(!isTwoTap),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isTwoTap
                ? Colors.cyanAccent.withOpacity(0.18)
                : Colors.white.withOpacity(0.08),
            border: Border.all(
              color: isTwoTap ? Colors.cyanAccent : Colors.white30,
              width: 1.2,
            ),
          ),
          child: Center(
            child: AnimatedRotation(
              turns: iconTurns,
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeInOut,
              child: Icon(
                isTwoTap ? Icons.linear_scale_rounded : Icons.gesture_rounded,
                size: 18,
                color: isTwoTap ? Colors.cyanAccent : Colors.white70,
              ),
            ),
          ),
        ),
      );
    }

    // Full pill — portrait drawer
    return GestureDetector(
      onTap: () => tracker.setTwoTapMode(!isTwoTap),
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
            AnimatedRotation(
              turns: iconTurns,
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeInOut,
              child: Icon(
                isTwoTap ? Icons.linear_scale_rounded : Icons.gesture_rounded,
                size: 16,
                color: isTwoTap ? Colors.cyanAccent : Colors.white70,
              ),
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
