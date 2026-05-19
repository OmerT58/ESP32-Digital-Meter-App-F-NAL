/// metric_card.dart
/// ─────────────────────────────────────────────────────────────
/// Glassmorphic card displaying a single measurement metric.
///
/// Used for Distance, Area and Volume readouts at the bottom of
/// the home screen.
/// ─────────────────────────────────────────────────────────────
library;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';

class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.unit,
    this.accentColor = AppColors.neonGreen,
    this.isLarge     = false,
  });

  final String label;
  final String value;
  final String unit;
  final Color  accentColor;

  /// Distance card gets a slightly larger value text
  final bool   isLarge;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        // Glassmorphism background
        color        : AppColors.glassWhite,
        borderRadius : BorderRadius.circular(16),
        border       : Border.all(color: AppColors.glassBorder, width: 1),
        boxShadow    : [
          BoxShadow(
            color      : accentColor.withValues(alpha: 0.08),
            blurRadius : 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Label ─────────────────────────────────────────────
          Text(
            label,
            style: AppTextStyles.inter(
              size : 10,
              color: AppColors.textSecondary,
            ),
          ),

          const SizedBox(height: 6),

          // ── Value ──────────────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: Text(
                  value,
                  style: AppTextStyles.inter(
                    size  : isLarge ? 30 : 22,
                    weight: FontWeight.w700,
                    color : accentColor,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  unit,
                  style: AppTextStyles.inter(
                    size : 11,
                    color: accentColor.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ],
          ),

          // ── Accent rule ────────────────────────────────────────
          const SizedBox(height: 8),
          Container(
            height: 1.5,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [accentColor.withValues(alpha: 0.8), Colors.transparent],
              ),
            ),
          ),
        ],
      ),
    )
        .animate(key: ValueKey(value))
        .shimmer(duration: 400.ms, color: accentColor.withValues(alpha: 0.15));
  }
}
