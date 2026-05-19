/// main.dart — entry point with splash route + MultiProvider + dynamic theme
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'models/measurement_provider.dart';
import 'models/settings_provider.dart';
import 'services/ble_service.dart';
import 'services/camera_service.dart';
import 'services/laser_tracking_service.dart';
import 'screens/splash_screen.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Allow portrait + landscape for OrientationBuilder
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor          : Colors.transparent,
    statusBarIconBrightness : Brightness.light,
    statusBarBrightness     : Brightness.dark,
  ));

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<BleService>.value(value: BleService.instance),
        ChangeNotifierProvider<CameraService>(create: (_) => CameraService()),
        ChangeNotifierProvider<LaserTrackingService>(create: (_) => LaserTrackingService()),
        ChangeNotifierProvider<MeasurementProvider>(
            create: (_) => MeasurementProvider()),
        ChangeNotifierProvider<SettingsProvider>(
            create: (_) => SettingsProvider()),
      ],
      child: const DigitalMeterApp(),
    ),
  );
}

class DigitalMeterApp extends StatelessWidget {
  const DigitalMeterApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Listen to SettingsProvider for live theme switching
    final settings = context.watch<SettingsProvider>();

    return MaterialApp(
      title                     : 'Digital Meter Sim',
      debugShowCheckedModeBanner: false,
      theme                     : AppTheme.light,
      darkTheme                 : AppTheme.dark,
      themeMode                 : settings.themeMode,
      home                      : const SplashScreen(),
    );
  }
}
