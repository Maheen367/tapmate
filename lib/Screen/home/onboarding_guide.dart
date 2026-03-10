// lib/screens/home/onboarding_guide.dart
import 'package:flutter/material.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:tapmate/Screen/Auth/LoginScreen.dart';
import 'package:tapmate/Screen/constants/app_colors.dart';


/// Keys holder for all showcase elements
class OnboardingGuideKeys {
  final GlobalKey? floatingButtonKey;
  final GlobalKey? profileIconKey;
  final GlobalKey? downloadCardKey;
  final GlobalKey? statsSectionKey;
  final GlobalKey? libraryButtonKey;
  final GlobalKey? settingsButtonKey;
  final GlobalKey? navigationBarKey;

  OnboardingGuideKeys({
    this.floatingButtonKey,
    this.profileIconKey,
    this.downloadCardKey,
    this.statsSectionKey,
    this.libraryButtonKey,
    this.settingsButtonKey,
    this.navigationBarKey,
  });

  List<GlobalKey?> getAllKeys() {
    return [
      downloadCardKey,
      floatingButtonKey,
      profileIconKey,
      statsSectionKey,
      libraryButtonKey,
      settingsButtonKey,
      navigationBarKey,
    ];
  }
}

/// Build a showcase widget for a feature
Widget buildShowcase({
  required GlobalKey key,
  required String title,
  required String description,
  required Widget child,
  required bool isDarkMode,
  required bool isLocked,
}) {
  return Showcase(
    key: key,
    title: title,
    description: isLocked
        ? "$description\n\n🔒 This feature requires an account. Sign up to unlock all features!"
        : description,
    titleTextStyle: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.bold,
      color: isDarkMode ? AppColors.lightSurface : AppColors.accent,
      fontFamily: 'Roboto',
    ),
    descTextStyle: TextStyle(
      fontSize: 15,
      color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
      height: 1.5,
      fontFamily: 'Roboto',
    ),
    targetBorderRadius: BorderRadius.circular(16),
    tooltipBackgroundColor: isDarkMode
        ? const Color(0xFF1E1E1E)
        : AppColors.lightSurface,
    textColor: isDarkMode ? AppColors.lightSurface : AppColors.accent,
    overlayColor: AppColors.textMain.withOpacity(0.7),
    targetPadding: const EdgeInsets.all(8),
    tooltipPadding: const EdgeInsets.all(20),
    showArrow: true,
    blurValue: 0.5,
    child: child,
  );
}

/// Show locked feature dialog for guest users
void showLockedFeatureDialog(BuildContext context, String featureName, bool isDarkMode) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : AppColors.lightSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Icon(Icons.lock_outline, color: AppColors.primary, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Feature Locked',
              style: TextStyle(
                color: isDarkMode ? AppColors.lightSurface : AppColors.accent,
                fontSize: 22,
                fontWeight: FontWeight.bold,
                fontFamily: 'Roboto',
              ),
            ),
          ),
        ],
      ),
      content: Text(
        "This feature requires an account. Sign up to unlock all features!",
        style: TextStyle(
          fontSize: 16,
          color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
          fontFamily: 'Roboto',
          height: 1.5,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Cancel',
            style: TextStyle(
              color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
              fontFamily: 'Roboto',
            ),
          ),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            // Navigate to login/signup screen AFTER pop to avoid context issues
            Future.microtask(() {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (ctx) => const LoginScreen()),
              );
            });
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text(
            'Sign Up',
            style: TextStyle(
              color: AppColors.lightSurface,
              fontWeight: FontWeight.bold,
              fontFamily: 'Roboto',
            ),
          ),
        ),
      ],
    ),
  );
}

