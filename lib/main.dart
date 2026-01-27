// lib/main.dart
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
        // Called when any showcase tour finishes. Mark guide completed for current user.
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

              // ✅ LIGHT THEME
              theme: ThemeData(
                primaryColor: const Color(0xFFA64D79),
                colorScheme: ColorScheme.fromSeed(
                  seedColor: const Color(0xFFA64D79),
                  primary: const Color(0xFFA64D79),
                  secondary: const Color(0xFF6A1E55),
                  brightness: Brightness.light,
                ),
                scaffoldBackgroundColor: Colors.white,
                useMaterial3: true,
                appBarTheme: const AppBarTheme(
                  backgroundColor: Colors.white,
                  foregroundColor: Color(0xFFA64D79),
                  elevation: 1,
                ),
                elevatedButtonTheme: ElevatedButtonThemeData(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFA64D79),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                textTheme: const TextTheme(
                  displayLarge: TextStyle(
                    color: Color(0xFFA64D79),
                    fontWeight: FontWeight.bold,
                  ),
                  bodyLarge: TextStyle(
                    color: Colors.black87,
                  ),
                ),
              ),

              // ✅ DARK THEME
              darkTheme: ThemeData(
                primaryColor: const Color(0xFFA64D79),
                colorScheme: ColorScheme.fromSeed(
                  seedColor: const Color(0xFFA64D79),
                  primary: const Color(0xFFA64D79),
                  secondary: const Color(0xFF6A1E55),
                  brightness: Brightness.dark,
                ),
                scaffoldBackgroundColor: const Color(0xFF121212),
                useMaterial3: true,
                appBarTheme: const AppBarTheme(
                  backgroundColor: Color(0xFF1E1E1E),
                  foregroundColor: Colors.white,
                  elevation: 1,
                ),
                elevatedButtonTheme: ElevatedButtonThemeData(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFA64D79),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                textTheme: const TextTheme(
                  displayLarge: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  bodyLarge: TextStyle(
                    color: Colors.white70,
                  ),
                ),
              ),

              // ✅ THEME MODE SET
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