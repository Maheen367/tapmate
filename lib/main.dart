import 'package:flutter/material.dart';
import 'Screen/Auth/splashscreen.dart';
void main() {
  runApp(const TapMateApp());
}

class TapMateApp extends StatelessWidget {
  const TapMateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TapMate',
      theme: ThemeData(
        // 🔥 PINKISH-PURPLE FOCUS
        primaryColor: const Color(0xFFA64D79), // Pink-Purple Priority
        scaffoldBackgroundColor: Colors.white,
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFFA64D79), // 🔥 Pink-Purple Text
          elevation: 1,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFA64D79), // Pink Buttons
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        textTheme: const TextTheme(
          displayLarge: TextStyle(
            color: Color(0xFFA64D79), // 🔥 Pink-Purple Headings
            fontWeight: FontWeight.bold,
          ),
          bodyLarge: TextStyle(
            color: Colors.black87, // Dark Text for readability
          ),
        ),
      ),
      home: SplashScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}