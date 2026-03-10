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
  bool _isLoggedIn = false;
  bool _hasCompletedOnboarding = false;
  bool _permissionsGranted = false;
  bool _isGuest = false;
  bool _isEmailVerified = false;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      final user = authProvider.currentUser;

      setState(() {
        _isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
        _hasCompletedOnboarding =
            prefs.getBool('has_completed_onboarding') ?? false;
        _permissionsGranted = prefs.getBool('permissions_granted') ?? false;
        _isGuest = prefs.getBool('is_guest') ?? false;
        _isEmailVerified = user?.emailVerified ?? false;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error checking login status: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SplashScreen();
    }

    // LOGGED IN USER
    if (_isLoggedIn) {
      final authProvider = Provider.of<AuthProvider>(context);

      // Email verified nahi hai to verification screen dikhao
      if (!_isEmailVerified && !_isGuest) {
        return EmailVerificationScreen(email: authProvider.userEmail);
      }

      // Permissions granted hai to home, nahi to permission screen
      if (_permissionsGranted) {
        return const HomeScreen();
      } else {
        return const PermissionScreen();
      }
    }

    // GUEST USER
    else if (_isGuest) {
      return const HomeScreen();
    }

    // NEW USER
    else {
      if (_hasCompletedOnboarding) {
        return const LoginScreen();
      } else {
        return const OnboardingScreen();
      }
    }
  }
}
