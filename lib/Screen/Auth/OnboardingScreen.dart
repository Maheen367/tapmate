import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tapmate/Screen/constants/app_colors.dart';
import 'LoginScreen.dart';
import '../home/home_screen.dart';
import '../../auth_provider.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightSurface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Logo with Gradient
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.secondary, AppColors.primary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(
                  Icons.download_rounded,
                  color: AppColors.lightSurface,
                  size: 50,
                ),
              ),
              const SizedBox(height: 30),
              const Text(
                "TapMate",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.secondary,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                "Download, Share & Connect",
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.textMain,
                ),
              ),
              const SizedBox(height: 50),

              // Feature List
              Column(
                children: [
                  _featureTile(
                    Icons.flash_on,
                    "Lightning-fast downloads",
                    "Download videos in seconds with our optimized technology",
                  ),
                  const SizedBox(height: 15),
                  _featureTile(
                    Icons.handshake,
                    "Connect with creators",
                    "Follow and interact with your favorite creators",
                  ),
                  const SizedBox(height: 15),
                  _featureTile(
                    Icons.sync,
                    "Sync across devices",
                    "Access your downloads anywhere, anytime",
                  ),
                ],
              ),

              const Spacer(),

              // Get Started Button with Gradient - ✅ FIXED
              SizedBox(
                width: double.infinity,
                height: 55,
                child: TextButton(
                  onPressed: () {
                    Navigator.pushReplacement(  // ✅ yahan change kiya
                      context,
                      MaterialPageRoute(
                          builder: (context) => const LoginScreen()),
                    );
                  },
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Ink(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.secondary, AppColors.primary],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Text(
                        "Get Started",
                        style: TextStyle(
                          color: AppColors.lightSurface,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 15),

              // Continue as Guest - ✅ Already fixed hai
              GestureDetector(
                onTap: () {
                  final authProvider = Provider.of<AuthProvider>(context, listen: false);
                  authProvider.setGuestMode(true);
                  authProvider.setOnboardingCompleted(true);
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const HomeScreen()),
                  );
                },
                child: const Text(
                  "Continue as Guest",
                  style: TextStyle(
                    color: AppColors.textMain,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _featureTile(IconData icon, String title, String subtitle) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFF0E5FF),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppColors.primary),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textMain,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  color: AppColors.textMain,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

