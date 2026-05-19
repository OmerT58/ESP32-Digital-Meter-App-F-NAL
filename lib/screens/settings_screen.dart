/// settings_screen.dart — Unit selection + Laser colour picker + Light/Dark toggle
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/settings_provider.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s      = context.watch<SettingsProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bg       = isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7);
    final appBarBg = isDark ? const Color(0xFF2C2C2E) : Colors.white;
    final primary  = isDark ? AppColors.darkTextPrimary  : AppColors.textPrimary;
    final secondary= isDark ? AppColors.darkTextSecondary: AppColors.textSecondary;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: appBarBg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded,
              color: primary, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'SETTINGS',
          style: AppTextStyles.inter(
            size: 14, weight: FontWeight.w700,
            color: primary, letterSpacing: 3),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [

          // ── Appearance section ────────────────────────────────
          _SectionHeader('APPEARANCE', secondary),
          const SizedBox(height: 10),
          _SoftCard(
            isDark: isDark,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  // Icon
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.10)
                          : AppColors.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isDark
                          ? Icons.dark_mode_rounded
                          : Icons.light_mode_rounded,
                      size: 18,
                      color: AppColors.accent,
                    ),
                  ),
                  const SizedBox(width: 14),
                  // Label
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('THEME',
                            style: AppTextStyles.inter(
                              size: 11, weight: FontWeight.w700,
                              color: primary)),
                        const SizedBox(height: 2),
                        Text(
                          isDark ? 'Dark Mode' : 'Light Mode',
                          style: AppTextStyles.inter(
                              size: 10, color: secondary),
                        ),
                      ],
                    ),
                  ),
                  // Toggle
                  Switch.adaptive(
                    value: isDark,
                    activeThumbColor: Colors.white,
                    activeTrackColor: AppColors.accent,
                    onChanged: (_) => context
                        .read<SettingsProvider>()
                        .toggleTheme(),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 28),

          // ── Unit section ──────────────────────────────────────
          _SectionHeader('MEASUREMENT UNIT', secondary),
          const SizedBox(height: 10),
          _SoftCard(
            isDark: isDark,
            child: Column(
              children: MeasurementUnit.values.map((u) {
                final selected = s.unit == u;
                return InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () =>
                      context.read<SettingsProvider>().setUnit(u),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        Text(
                          u.label.toUpperCase(),
                          style: AppTextStyles.inter(
                            size: 13,
                            color: selected
                                ? AppColors.accent : primary,
                            weight: selected
                                ? FontWeight.w700 : FontWeight.w400,
                          ),
                        ),
                        const Spacer(),
                        if (selected)
                          const Icon(Icons.check_rounded,
                              color: AppColors.accent, size: 18),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 28),

          // ── Laser colour section ──────────────────────────────
          _SectionHeader('RETICLE COLOR', secondary),
          const SizedBox(height: 10),
          _SoftCard(
            isDark: isDark,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('SELECT LASER BEAM COLOUR',
                      style: AppTextStyles.inter(
                          size: 10, color: secondary)),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: SettingsProvider.availableLaserColors
                        .map((c) => _ColorSwatch(
                              color: c,
                              selected:
                                  s.laserColor.toARGB32() == c.toARGB32(),
                              onTap: () => context
                                  .read<SettingsProvider>()
                                  .setLaserColor(c),
                            ))
                        .toList(),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 28),

          // ── About section ──────────────────────────────────────
          _SectionHeader('ABOUT', secondary),
          const SizedBox(height: 10),
          _SoftCard(
            isDark: isDark,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('DIGITAL METER SIM',
                      style: AppTextStyles.inter(
                          size: 13, weight: FontWeight.w700,
                          color: primary)),
                  const SizedBox(height: 4),
                  Text('Created by Ömer Mert Başcı',
                      style: AppTextStyles.inter(
                          size: 11, color: secondary)),
                  const SizedBox(height: 4),
                  Text('ESP32-S3 BLE Companion  •  v1.0.0',
                      style: AppTextStyles.inter(
                          size: 10,
                          color: isDark
                              ? AppColors.darkTextTertiary
                              : AppColors.textTertiary)),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ── Helper widgets ───────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text, this.color);
  final String text;
  final Color  color;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 2),
    child: Text(text,
        style: AppTextStyles.inter(size: 10, color: color)),
  );
}

class _SoftCard extends StatelessWidget {
  const _SoftCard({required this.child, required this.isDark});
  final Widget child;
  final bool   isDark;
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: isDark ? AppColors.darkCard : AppColors.cardBg,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: isDark ? Colors.black38 : AppColors.shadow,
          blurRadius: 20,
          spreadRadius: -2,
          offset: const Offset(0, 6),
        ),
      ],
      border: Border.all(
        color: isDark
            ? const Color(0x22FFFFFF)
            : const Color(0x10000000),
        width: 0.5,
      ),
    ),
    child: child,
  );
}

class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({
    required this.color,
    required this.selected,
    required this.onTap,
  });
  final Color        color;
  final bool         selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 52, height: 52,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          boxShadow: selected
              ? [BoxShadow(color: color.withValues(alpha: 0.5),
                           blurRadius: 14, spreadRadius: 2)]
              : [],
          border: Border.all(
            color: selected ? Colors.white : Colors.transparent,
            width: 3,
          ),
        ),
        child: selected
            ? const Icon(Icons.check_rounded,
                         color: Colors.white, size: 22)
            : null,
      ),
    );
  }
}
