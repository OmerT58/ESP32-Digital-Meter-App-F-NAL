import 'package:flutter/material.dart';
import 'dart:async';
import 'home_screen.dart'; // Ana ekranının dosya yolu

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Tam olarak 4 saniye bekle ve ana ekrana geç
    Timer(const Duration(seconds: 4), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          // Beyazdan buz mavisine yumuşak geçiş
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white, Colors.blue.shade50],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Mühendislik ikonu
              // splash_screen.dart içinde
              Icon(
                  Icons.center_focus_strong, // Cetvel yerine bu "hedef" ikonu çok daha iyi durur
                  size: 90,
                  color: Colors.blue.shade800
              ),

              const SizedBox(height: 30),
              const Text(
                "DIGITAL METER SIM",
                style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 3,
                    color: Colors.black87
                ),
              ),
              const SizedBox(height: 15),
              const Text(
                "CREATED BY ÖMER MERT BAŞCI",
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: Colors.grey,
                    letterSpacing: 1.2
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

