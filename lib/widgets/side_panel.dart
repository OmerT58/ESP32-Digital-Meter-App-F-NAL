/// side_panel.dart — Soft card-based measurement + mode panel
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/measurement_mode.dart';
import '../models/measurement_provider.dart';
import '../models/settings_provider.dart';
import '../services/ble_service.dart';
import '../screens/settings_screen.dart';
import '../theme/app_theme.dart';

class SidePanel extends StatelessWidget {
  const SidePanel({super.key});

  @override
  Widget build(BuildContext context) {
    final ble  = context.watch<BleService>();
    final mp   = context.watch<MeasurementProvider>();
    final s    = context.watch<SettingsProvider>();
    final List<double> data = ble.latestData;
    
    final double distanceMm = data.isNotEmpty ? data[0] : 0.0;
    final double pitchDeg = data.length > 1 ? data[1] : 0.0;
    final double rollDeg = data.length > 2 ? data[2] : 0.0;
    final double distanceM = distanceMm / 1000.0;

    return Positioned(
      left: 12, top: 0, bottom: 0,
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [

            // ── Status card ──────────────────────────────────────
            _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Label('STATUS'),
                  const SizedBox(height: 4),
                  Text(
                    ble.isConnected ? 'CONNECTED' : 'OFFLINE',
                    style: AppTextStyles.inter(
                      size: 10,
                      weight: FontWeight.w700,
                      color: ble.isConnected
                          ? AppColors.connected : AppColors.offline,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // ── Measurements card ────────────────────────────────
            _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Label('MEASUREMENTS'),
                  const SizedBox(height: 8),
                  _Row('DIST',
                      '${s.unit.convert(distanceM).toStringAsFixed(1)} '
                      '${s.unit.label}',
                      AppColors.accentGreen),
                  const SizedBox(height: 4),
                  _Row('ROLL',
                      '${rollDeg.toStringAsFixed(1)}°',
                      AppColors.accent),
                  const SizedBox(height: 4),
                  _Row('PTCH',
                      '${pitchDeg.toStringAsFixed(1)}°',
                      AppColors.accent),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // ── Modes card ───────────────────────────────────────
            _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Label('MODES'),
                  const SizedBox(height: 6),
                  for (final m in MeasurementMode.values)
                    _ModeChip(
                      mode    : m,
                      active  : mp.mode == m,
                      onTap   : () => mp.switchMode(m),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // ── Settings ─────────────────────────────────────────
            GestureDetector(
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(
                      builder: (_) => const SettingsScreen())),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: softCard(warm: false)
                    .copyWith(borderRadius: BorderRadius.circular(14)),
                child: const Icon(Icons.tune_rounded,
                    size: 18, color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Sub-widgets ─────────────────────────────────────────────────

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: softCard(),
    child: child,
  );
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(text,
      style: AppTextStyles.inter(
          size: 8, color: AppColors.textSecondary));
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value, this.color);
  final String label, value;
  final Color  color;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text('$label ',
          style: AppTextStyles.inter(
              size: 8, color: AppColors.textTertiary)),
      Text(value,
          style: AppTextStyles.inter(
              size: 9, color: color, weight: FontWeight.w600)),
    ],
  );
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.mode, required this.active, required this.onTap});
  final MeasurementMode mode;
  final bool active;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin : const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: active
            ? AppColors.accent.withValues(alpha: 0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: active ? AppColors.accent : Colors.transparent,
          width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(mode.icon, size: 10,
              color: active ? AppColors.accent : AppColors.textSecondary),
          const SizedBox(width: 4),
          Text(mode.label,
              style: AppTextStyles.inter(
                size: 7.5,
                color: active ? AppColors.accent : AppColors.textSecondary,
                weight: active ? FontWeight.w700 : FontWeight.w400,
              )),
        ],
      ),
    ),
  );
}
