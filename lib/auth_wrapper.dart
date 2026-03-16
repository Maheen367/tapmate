import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tapmate/Screen/Auth/LoginScreen.dart';
import 'package:tapmate/Screen/Auth/OnboardingScreen.dart';
import 'package:tapmate/Screen/Auth/permissionscreen.dart';
import 'package:tapmate/Screen/Auth/email_otp_screen.dart';
import 'package:tapmate/Screen/home/home_screen.dart';
import 'package:tapmate/auth_provider.dart';
import 'Screen/Auth/splashscreen.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isLoading = true;
  bool _hasCompletedOnboarding = false;
  bool _permissionsGranted = false;
  bool _isGuest = false;

  @override
  void initState() {
    super.initState();
    _checkInitialStatus();
  }

  Future<void> _checkInitialStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      setState(() {
        _hasCompletedOnboarding = prefs.getBool('has_completed_onboarding') ?? false;
        _permissionsGranted = prefs.getBool('permissions_granted') ?? false;
        _isGuest = prefs.getBool('is_guest') ?? false;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error checking status: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 🔥 AGAR LOADING HAI TO SPLASH SCREEN DIKHAO
    if (_isLoading) {
      return const SplashScreen();
    }

    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        final user = authProvider.currentUser;

        debugPrint('🟢 AuthWrapper - User: ${user?.email ?? 'null'}');
        debugPrint('🟢 Email verified: ${user?.emailVerified ?? false}');

        // ---------- 1. FIREBASE USER EXISTS (LOGGED IN) ----------
        if (user != null) {
          // Email verification check
          if (!user.emailVerified) {
            return EmailVerificationScreen(email: user.email ?? '');
          }

          // Permissions check
          if (_permissionsGranted) {
            return const HomeScreen();
          } else {
            return const PermissionScreen();
          }
        }

        // ---------- 2. GUEST USER ----------
        else if (_isGuest) {
          return const HomeScreen();
        }

        // ---------- 3. NO USER (LOGGED OUT OR NEW USER) ----------
        else {
          // 🔥 YAHAN SPLASH SCREEN DIKHAO
          return const SplashScreen();
        }
      },
    );
  }
}