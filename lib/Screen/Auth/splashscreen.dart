import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart'; // 🔥 ADD THIS IMPORT
import 'package:tapmate/Screen/constants/app_colors.dart';
import 'package:tapmate/Screen/Auth/OnboardingScreen.dart';
import 'package:tapmate/Screen/Auth/permissionscreen.dart';
import 'package:tapmate/Screen/home/home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkUserAndNavigate(); // 🔥 Updated method name
  }

  // 🔥🔥🔥 NEW METHOD WITH FLAG CHECKS 🔥🔥🔥
  _checkUserAndNavigate() async {
    await Future.delayed(const Duration(seconds: 3));

    // Check flags
    final prefs = await SharedPreferences.getInstance();
    bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
    bool permissionsGranted = prefs.getBool('permissions_granted') ?? false;
    bool isNewUser = prefs.getBool('isNewUser') ?? true;

    if (!isLoggedIn) {
      // User not logged in - go to Onboarding
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const OnboardingScreen()),
      );
    }
    else if (isLoggedIn && !permissionsGranted && isNewUser) {
      // Logged in but permissions not granted and is new user - go to Permission Screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const PermissionScreen()),
      );
    }
    else {
      // All good - go to Home
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.accent, // Dark Maroon
              AppColors.secondary, // Deep Purple
              AppColors.primary, // Dusty Pink
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  color: AppColors.lightSurface,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.textMain.withOpacity(0.4),
                      blurRadius: 25,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.download_for_offline_outlined,
                  size: 70,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 40),
              const Text(
                'TapMate',
                style: TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.bold,
                  color: AppColors.lightSurface,
                  letterSpacing: 2.0,
                  shadows: [
                    Shadow(
                      blurRadius: 15,
                      color: AppColors.textMain,
                      offset: Offset(3, 3),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 15),
              const Text(
                'Download Videos from All Platforms',
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.lightSurface,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 60),
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.lightSurface),
                strokeWidth: 3,
              ),
            ],
          ),
        ),
      ),
    );
  }
}