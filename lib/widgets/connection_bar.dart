/// connection_bar.dart
/// ─────────────────────────────────────────────────────────────
/// Top-bar widget showing BLE connection status.
///
/// Displays:
///   • Animated pulsing dot (colour = state)
///   • State label ("CONNECTED · ESP32-S3-Meter", "SCANNING…", etc.)
///   • Tap-to-scan / tap-to-disconnect action
/// ─────────────────────────────────────────────────────────────
library;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../services/ble_service.dart';
import '../theme/app_theme.dart';

class ConnectionBar extends StatelessWidget {
  const ConnectionBar({super.key});

  @override
  Widget build(BuildContext context) {
    final ble = context.watch<BleService>();

    final (label, color, icon) = _resolveState(ble);

    return GestureDetector(
      onTap: () => _handleTap(ble),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color : AppColors.surfaceCard,
          border: const Border(
            bottom: BorderSide(color: AppColors.divider, width: 1),
          ),
        ),
        child: Row(
          children: [
            // ── Status dot ───────────────────────────────────────
            _StatusDot(color: color, ble: ble),

            const SizedBox(width: 12),

            // ── Label ────────────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'DIGITAL METER',
                    style: AppTextStyles.inter(
                      size  : 10,
                      color : AppColors.textSecondary,
                      weight: FontWeight.w600,
                      letterSpacing: 3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    style: AppTextStyles.inter(
                      size : 13,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),

            // ── Action icon ───────────────────────────────────────
            Icon(icon, color: color, size: 20),
          ],
        ),
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────

  (String, Color, IconData) _resolveState(BleService ble) {
    switch (ble.connectionState) {
      case BleConnectionState.connected:
        return (
          'CONNECTED · ${ble.connectedDeviceName ?? "ESP32-S3-Meter"}',
          AppColors.neonGreen,
          Icons.bluetooth_connected_rounded,
        );
      case BleConnectionState.scanning:
        return (
          'SCANNING FOR ESP32-S3-Meter…',
          AppColors.neonCyan,
          Icons.radar_rounded,
        );
      case BleConnectionState.connecting:
        return (
          'CONNECTING…',
          AppColors.neonCyan,
          Icons.settings_input_antenna_rounded,
        );
      case BleConnectionState.error:
        return (
          ble.errorMessage ?? 'ERROR — Tap to retry',
          AppColors.neonRed,
          Icons.refresh_rounded,
        );
      case BleConnectionState.idle:
        return (
          'TAP TO SCAN',
          AppColors.textSecondary,
          Icons.bluetooth_searching_rounded,
        );
    }
  }

  void _handleTap(BleService ble) {
    if (ble.connectionState == BleConnectionState.connected) {
      ble.disconnect();
    } else {
      ble.startScan();
    }
  }
}

// ── Animated pulsing status dot ───────────────────────────────────
class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.color, required this.ble});

  final Color     color;
  final BleService ble;

  @override
  Widget build(BuildContext context) {
    final shouldPulse = ble.connectionState == BleConnectionState.scanning ||
        ble.connectionState == BleConnectionState.connecting;

    Widget dot = Container(
      width : 10,
      height: 10,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 8),
        ],
      ),
    );

    if (shouldPulse) {
      dot = dot
          .animate(onPlay: (c) => c.repeat())
          .scaleXY(end: 1.6, duration: 600.ms)
          .then()
          .scaleXY(end: 1.0, duration: 600.ms);
    }

    return dot;
  }
}
