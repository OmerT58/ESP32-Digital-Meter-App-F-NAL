/// settings_provider.dart — unit, laser colour, and theme mode state
library;

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum MeasurementUnit { cm, mm, inches }

extension MeasurementUnitExt on MeasurementUnit {
  String get label => switch (this) {
    MeasurementUnit.cm     => 'cm',
    MeasurementUnit.mm     => 'mm',
    MeasurementUnit.inches => 'in',
  };

  double convert(double metres) => switch (this) {
    MeasurementUnit.cm     => metres * 100,
    MeasurementUnit.mm     => metres * 1000,
    MeasurementUnit.inches => metres * 39.3701,
  };
}

class SettingsProvider extends ChangeNotifier {
  MeasurementUnit _unit       = MeasurementUnit.cm;
  Color           _laserColor = AppColors.laserRed;
  ThemeMode       _themeMode  = ThemeMode.dark;

  MeasurementUnit get unit       => _unit;
  Color           get laserColor => _laserColor;
  ThemeMode       get themeMode  => _themeMode;

  static const List<Color> availableLaserColors = [
    AppColors.laserRed,
    AppColors.laserGreen,
    AppColors.laserBlue,
    AppColors.laserYellow,
  ];

  void setUnit(MeasurementUnit u) {
    _unit = u;
    notifyListeners();
  }

  void setLaserColor(Color c) {
    _laserColor = c;
    notifyListeners();
  }

  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    notifyListeners();
  }

  void toggleTheme() {
    _themeMode =
        _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }
}
