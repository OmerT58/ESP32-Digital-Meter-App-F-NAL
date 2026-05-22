/// top_bar.dart — Minimal AR overlay top bar with settings shortcut
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../screens/settings_screen.dart';
import '../screens/gyroscope_test_screen.dart';
import '../services/ble_service.dart';
import '../theme/app_theme.dart';

class TopBar extends StatelessWidget {
  const TopBar({super.key});

  @override
  Widget build(BuildContext context) {
    final ble = context.watch<BleService>();

    final (label, color) = switch (ble.connectionState) {
      BleConnectionState.connected  => ('● CONNECTED',   AppColors.connected),
      BleConnectionState.scanning   => ('◌ SCANNING…',  AppColors.scanning),
      BleConnectionState.connecting => ('◌ LINKING…',   AppColors.scanning),
      BleConnectionState.error      => ('✕ ERROR',       AppColors.offline),
      BleConnectionState.idle       => ('○ OFFLINE',     AppColors.textSecondary),
    };

    return Positioned(
      top: 0, left: 0, right: 0,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: Row(
            mainAxisSize: MainAxisSize.max,
            children: [
              // ── BLE status pill ─────────────────────────────
              GestureDetector(
                onTap: () => ble.isConnected
                    ? ble.disconnect() : ble.startScan(),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 7),
                  decoration: softCard(warm: false)
                      .copyWith(borderRadius: BorderRadius.circular(20)),
                  child: Text(label,
                      style: AppTextStyles.inter(
                          size: 10, color: color),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1),
                ),
              ),

              // Single spacer pushes right-side group to the edge
              const Spacer(),

              // ── Test Mode pill ───────────────────────────────
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  PageRouteBuilder(
                    opaque: false,
                    pageBuilder: (_, __, ___) => const GyroscopeTestScreen(),
                    transitionsBuilder: (context, animation, secondaryAnimation, child) {
                      return FadeTransition(opacity: animation, child: child);
                    },
                  ),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: softCard(warm: false)
                      .copyWith(borderRadius: BorderRadius.circular(14)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.explore,
                          size: 14, color: AppColors.textSecondary),
                      const SizedBox(width: 6),
                      Text('BUBBLE LEVEL', style: AppTextStyles.inter(size: 9, color: AppColors.textSecondary, weight: FontWeight.w700)),
                    ]
                  ),
                ),
              ),

              const SizedBox(width: 8),

              // ── Settings icon pill ───────────────────────────
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const SettingsScreen()),
                ),
                child: Container(
                  padding: const EdgeInsets.all(9),
                  decoration: softCard(warm: false)
                      .copyWith(borderRadius: BorderRadius.circular(14)),
                  child: const Icon(Icons.tune_rounded,
                      size: 16, color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
