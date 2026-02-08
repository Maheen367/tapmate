// lib/main.dart - WITH ALL COLORS VISIBLE IN THEME
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:tapmate/Screen/Auth/LoginScreen.dart';
import 'package:tapmate/Screen/Auth/splashscreen.dart';
import 'package:tapmate/Screen/home/chat_screen.dart';
import 'package:tapmate/Screen/home/home_screen.dart';
import 'package:tapmate/Screen/home/platform_selection_screen.dart';
import 'package:tapmate/Screen/home/library_screen.dart';
import 'package:tapmate/Screen/home/feed_screen.dart';
import 'package:tapmate/Screen/home/search_screen.dart';
import 'package:tapmate/Screen/home/settings_screen.dart';
import 'package:tapmate/Screen/home/user_profile_screen.dart';
import 'package:tapmate/theme_provider.dart';
import 'package:tapmate/auth_provider.dart';
import 'package:tapmate/utils/guide_manager.dart';
import 'package:tapmate/Screen/constants/app_colors.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ShowCaseWidget(
      onFinish: () {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final userId = authProvider.userId;
        if (userId.isNotEmpty && userId != 'guest') {
          GuideManager.completeGuideForUser(userId);
        }
        if (authProvider.isNewSignUp == true) {
          authProvider.clearNewSignUpFlag();
        }
      },
      builder: (context) {
        return Consumer<ThemeProvider>(
          builder: (context, themeProvider, _) {
            return MaterialApp(
              title: 'TapMate',

              // ✅ LIGHT THEME - ALL COLORS VISIBLE
              theme: ThemeData(
                useMaterial3: true,
                brightness: Brightness.light,

                // Color Scheme - NOW USING MORE COLORS
                colorScheme: ColorScheme.light(
                  primary: AppColors.primary,
                  secondary: AppColors.secondary,
                  tertiary: AppColors.accent,
                  surface: AppColors.lightSurface,
                  background: AppColors.lightBackground,
                  // ✅ ADDED: Using action color for surfaceTint
                  surfaceTint: AppColors.action,
                  // ✅ ADDED: Using dustyTaupe for outline
                  outline: AppColors.dustyTaupe,
                  // ✅ ADDED: Using shadowGrey for shadow
                  shadow: AppColors.shadowGrey.withOpacity(0.1),
                  // ✅ Text colors with more variation
                  onPrimary: Colors.white,
                  onSecondary: Colors.white,
                  onTertiary: Colors.white,
                  onSurface: AppColors.textPrimary,
                  onBackground: AppColors.textPrimary,
                  // ✅ ADDED: Error colors using semantic
                  error: AppColors.error,
                  onError: Colors.white,
                ),

                // Scaffold with gradient possibility
                scaffoldBackgroundColor: AppColors.lightBackground,

                // App Bar - NOW WITH GRADIENT
                appBarTheme: AppBarTheme(
                  backgroundColor: AppColors.lightSurface,
                  foregroundColor: AppColors.primary,
                  elevation: 2,
                  centerTitle: true,
                  // ✅ USING MAUVE SHADOW FOR TITLE
                  titleTextStyle: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: AppColors.mauveShadow, // Changed from primary
                  ),
                  // ✅ USING DUSTY TAUPE FOR ICONS
                  iconTheme: IconThemeData(color: AppColors.dustyTaupe),
                  // ✅ ADDED: Surface tint color
                  surfaceTintColor: AppColors.action.withOpacity(0.1),
                ),

                // Buttons - DIFFERENT STYLES FOR DIFFERENT COLORS
                elevatedButtonTheme: ElevatedButtonThemeData(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 22),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 1,
                    // ✅ ADDED: Shadow color
                    shadowColor: AppColors.shadowGrey.withOpacity(0.2),
                  ),
                ),

                // Text Buttons - USING ACCENT COLORS
                textButtonTheme: TextButtonThemeData(
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.accent, // Changed from primary
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),

                // ✅ NEW: Outlined Button Theme - USING MAUVE SHADOW
                outlinedButtonTheme: OutlinedButtonThemeData(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.secondary,
                    side: BorderSide(color: AppColors.secondary, width: 1.5),
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w500,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 22),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),

                // Input Fields - MORE COLOR VARIATION
                inputDecorationTheme: InputDecorationTheme(
                  filled: true,
                  fillColor: AppColors.lightCard,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: AppColors.dustyTaupe.withOpacity(0.3)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: AppColors.accent.withOpacity(0.3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: AppColors.primary, width: 1.5),
                  ),
                  // ✅ ADDED: Error border
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: AppColors.error, width: 1.5),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: AppColors.error, width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
                  hintStyle: TextStyle(
                    color: AppColors.textSecondary,
                  ),
                  // ✅ ADDED: Label color variation
                  labelStyle: TextStyle(
                    color: AppColors.mauveShadow,
                  ),
                  // ✅ ADDED: Prefix/suffix icon color
                  prefixIconColor: AppColors.secondary,
                  suffixIconColor: AppColors.accent,
                ),

                // Cards - COLOR VARIATIONS
                cardTheme: CardThemeData(
                  color: AppColors.lightCard,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  shadowColor: AppColors.shadowGrey.withOpacity(0.1),
                  // ✅ ADDED: Surface tint
                  surfaceTintColor: AppColors.action.withOpacity(0.05),
                  margin: const EdgeInsets.all(8),
                ),

                // Bottom Navigation - USING MORE COLORS
                bottomNavigationBarTheme: BottomNavigationBarThemeData(
                  backgroundColor: AppColors.lightSurface,
                  selectedItemColor: AppColors.primary,
                  unselectedItemColor: AppColors.textSecondary,
                  selectedLabelStyle: const TextStyle(
                    fontWeight: FontWeight.w500,
                  ),
                  showSelectedLabels: true,
                  showUnselectedLabels: true,
                  type: BottomNavigationBarType.fixed,
                  // ✅ ADDED: Elevation color
                  elevation: 4,
                  // ✅ ADDED: Unselected icon color using accent
                  unselectedIconTheme: IconThemeData(
                    color: AppColors.accent.withOpacity(0.7),
                  ),
                ),

                // Floating Action Button - USING ACTION COLOR
                floatingActionButtonTheme: FloatingActionButtonThemeData(
                  backgroundColor: AppColors.action,
                  foregroundColor: Colors.white,
                  elevation: 4,
                  // ✅ ADDED: Shape with shadow
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  // ✅ ADDED: Extended FAB colors
                  extendedTextStyle: const TextStyle(
                    fontWeight: FontWeight.w500,
                  ),
                ),

                // Text Theme - MORE COLOR VARIATION
                textTheme: TextTheme(
                  displayLarge: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary, // Changed from textPrimary
                  ),
                  displayMedium: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                    color: AppColors.mauveShadow, // Changed
                  ),
                  displaySmall: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                  headlineMedium: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: AppColors.accent, // Added
                  ),
                  headlineSmall: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: AppColors.secondary, // Added
                  ),
                  titleLarge: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.dustyTaupe, // Added
                  ),
                  bodyLarge: TextStyle(
                    fontSize: 16,
                    color: AppColors.textPrimary,
                  ),
                  bodyMedium: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                  labelLarge: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                  // ✅ ADDED: More text styles
                  titleMedium: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: AppColors.shadowGrey,
                  ),
                  titleSmall: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: AppColors.accent,
                  ),
                  labelSmall: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: AppColors.mauveShadow,
                  ),
                ),

                // ✅ ADDED: Divider Theme
                dividerTheme: DividerThemeData(
                  color: AppColors.accent.withOpacity(0.2),
                  thickness: 1,
                  space: 16,
                  indent: 16,
                  endIndent: 16,
                ),

                // ✅ ADDED: Progress Indicator Theme
                progressIndicatorTheme: ProgressIndicatorThemeData(
                  color: AppColors.accent,
                  linearTrackColor: AppColors.accent.withOpacity(0.2),
                  circularTrackColor: AppColors.accent.withOpacity(0.2),
                ),

                // ✅ ADDED: Chip Theme
                chipTheme: ChipThemeData(
                  backgroundColor: AppColors.accent.withOpacity(0.1),
                  selectedColor: AppColors.primary.withOpacity(0.2),
                  secondarySelectedColor: AppColors.secondary.withOpacity(0.2),
                  labelStyle: TextStyle(color: AppColors.textPrimary),
                  secondaryLabelStyle: TextStyle(color: Colors.white),
                  brightness: Brightness.light,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: AppColors.accent.withOpacity(0.3)),
                  ),
                ),

                // ✅ ADDED: Badge Theme
                badgeTheme: BadgeThemeData(
                  backgroundColor: AppColors.error,
                  textColor: Colors.white,
                  alignment: Alignment.topRight,
                ),
              ),

              // ✅ DARK THEME - ALL COLORS VISIBLE
              darkTheme: ThemeData(
                useMaterial3: true,
                brightness: Brightness.dark,

                // Color Scheme - MORE COLOR USAGE
                colorScheme: ColorScheme.dark(
                  primary: AppColors.primary,
                  secondary: AppColors.secondary,
                  tertiary: AppColors.accent,
                  surface: AppColors.darkSurface,
                  background: AppColors.darkBackground,
                  // ✅ ADDED: More colors
                  surfaceTint: AppColors.action,
                  outline: AppColors.dustyTaupe,
                  shadow: AppColors.shadowGrey,
                  // Text colors
                  onPrimary: Colors.white,
                  onSecondary: Colors.white,
                  onTertiary: Colors.white,
                  onSurface: AppColors.textOnDark,
                  onBackground: AppColors.textOnDark,
                  error: AppColors.error,
                  onError: Colors.white,
                ),

                scaffoldBackgroundColor: AppColors.darkBackground,

                // App Bar - DARK WITH GRADIENT POSSIBILITY
                appBarTheme: AppBarTheme(
                  backgroundColor: AppColors.darkSurface,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  centerTitle: true,
                  // ✅ USING ACCENT COLOR FOR TITLE
                  titleTextStyle: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: AppColors.accent, // Changed from white
                  ),
                  // ✅ USING ACTION COLOR FOR ICONS
                  iconTheme: IconThemeData(color: AppColors.action),
                  // ✅ ADDED: Surface tint
                  surfaceTintColor: AppColors.primary.withOpacity(0.1),
                ),

                // Buttons - DARK VARIATION
                elevatedButtonTheme: ElevatedButtonThemeData(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 22),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 2,
                    shadowColor: Colors.black.withOpacity(0.5),
                    // ✅ ADDED: Surface tint
                    surfaceTintColor: AppColors.secondary.withOpacity(0.1),
                  ),
                ),

                // Text Buttons - USING ACCENT IN DARK
                textButtonTheme: TextButtonThemeData(
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.accent,
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),

                // ✅ ADDED: Outlined Buttons in Dark
                outlinedButtonTheme: OutlinedButtonThemeData(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.secondary,
                    side: BorderSide(color: AppColors.secondary, width: 1.5),
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w500,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 22),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),

                // Input Fields - DARK WITH COLOR VARIATION
                inputDecorationTheme: InputDecorationTheme(
                  filled: true,
                  fillColor: AppColors.darkSurfaceLight,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: AppColors.accent.withOpacity(0.3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: AppColors.primary, width: 1.5),
                  ),
                  // ✅ ADDED: Error borders
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: AppColors.error, width: 1.5),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: AppColors.error, width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
                  hintStyle: TextStyle(
                    color: AppColors.textLight,
                  ),
                  // ✅ ADDED: More colors
                  labelStyle: TextStyle(
                    color: AppColors.mauveShadow,
                  ),
                  prefixIconColor: AppColors.secondary,
                  suffixIconColor: AppColors.accent,
                ),

                // Cards - DARK WITH COLOR VARIATION
                cardTheme: CardThemeData(
                  color: AppColors.cardBackground,
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  shadowColor: Colors.black.withOpacity(0.5),
                  // ✅ ADDED: Surface tint
                  surfaceTintColor: AppColors.primary.withOpacity(0.1),
                  margin: const EdgeInsets.all(8),
                ),

                // Bottom Navigation - DARK WITH MORE COLORS
                bottomNavigationBarTheme: BottomNavigationBarThemeData(
                  backgroundColor: AppColors.darkSurface,
                  selectedItemColor: AppColors.primary,
                  unselectedItemColor: AppColors.textLight,
                  selectedLabelStyle: const TextStyle(
                    fontWeight: FontWeight.w500,
                  ),
                  showSelectedLabels: true,
                  showUnselectedLabels: true,
                  type: BottomNavigationBarType.fixed,
                  elevation: 8,
                  // ✅ ADDED: Unselected icon with accent
                  unselectedIconTheme: IconThemeData(
                    color: AppColors.accent.withOpacity(0.7),
                  ),
                ),

                // Floating Action Button - DARK
                floatingActionButtonTheme: FloatingActionButtonThemeData(
                  backgroundColor: AppColors.action,
                  foregroundColor: Colors.white,
                  elevation: 6,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  extendedTextStyle: const TextStyle(
                    fontWeight: FontWeight.w500,
                  ),
                ),

                // Text Theme - DARK WITH COLOR VARIATION
                textTheme: TextTheme(
                  displayLarge: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    color: AppColors.accent, // Changed from white
                  ),
                  displayMedium: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                  displaySmall: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                  headlineMedium: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: AppColors.action, // Added
                  ),
                  headlineSmall: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: AppColors.secondary, // Added
                  ),
                  titleLarge: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.dustyTaupe, // Added
                  ),
                  bodyLarge: TextStyle(
                    fontSize: 16,
                    color: AppColors.textOnDark,
                  ),
                  bodyMedium: TextStyle(
                    fontSize: 14,
                    color: AppColors.textLight,
                  ),
                  labelLarge: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                  // ✅ ADDED: More text styles
                  titleMedium: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textLight,
                  ),
                  titleSmall: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: AppColors.accent,
                  ),
                  labelSmall: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: AppColors.mauveShadow,
                  ),
                ),

                // Divider Theme
                dividerTheme: DividerThemeData(
                  color: AppColors.accent.withOpacity(0.3),
                  thickness: 1,
                  space: 16,
                  indent: 16,
                  endIndent: 16,
                ),

                // Progress Indicator Theme
                progressIndicatorTheme: ProgressIndicatorThemeData(
                  color: AppColors.accent,
                  linearTrackColor: AppColors.accent.withOpacity(0.2),
                  circularTrackColor: AppColors.accent.withOpacity(0.2),
                ),

                // Chip Theme - DARK
                chipTheme: ChipThemeData(
                  backgroundColor: AppColors.accent.withOpacity(0.2),
                  selectedColor: AppColors.primary.withOpacity(0.3),
                  secondarySelectedColor: AppColors.secondary.withOpacity(0.3),
                  labelStyle: TextStyle(color: AppColors.textOnDark),
                  secondaryLabelStyle: TextStyle(color: Colors.white),
                  brightness: Brightness.dark,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: AppColors.accent.withOpacity(0.4)),
                  ),
                ),

                // Badge Theme - DARK
                badgeTheme: BadgeThemeData(
                  backgroundColor: AppColors.error,
                  textColor: Colors.white,
                  alignment: Alignment.topRight,
                ),

                // ✅ ADDED: Dialog Theme
                dialogTheme: DialogThemeData(
                  backgroundColor: AppColors.darkSurface,
                  surfaceTintColor: AppColors.primary.withOpacity(0.1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 8,
                ),
              ),

              // ✅ THEME MODE
              themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,

              home: const SplashScreen(),

              routes: {
                '/home': (context) => const HomeScreen(),
                '/chat': (context) => const ChatScreen(),
                '/search': (context) => const SearchDiscoverScreen(),
                '/platform-selection': (context) => const PlatformSelectionScreen(),
                '/library': (context) => const LibraryScreen(),
                '/feed': (context) => const FeedScreen(),
                '/profile': (context) => const UserProfileScreen(),
                '/settings': (context) => const SettingsScreen(),
                '/login': (context) => const LoginScreen(),
              },

              debugShowCheckedModeBanner: false,
            );
          },
        );
      },
    );
  }
}