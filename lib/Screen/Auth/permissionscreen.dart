import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tapmate/Screen/constants/app_colors.dart';
import 'package:tapmate/Screen/home/home_screen.dart';
import '../../auth_provider.dart';

class PermissionScreen extends StatefulWidget {
  const PermissionScreen({super.key});

  @override
  State<PermissionScreen> createState() => _PermissionScreenState();
}

class _PermissionScreenState extends State<PermissionScreen> {
  bool overlayPermission = false;
  bool accessibilityPermission = false;
  bool storagePermission = false;
  bool notificationsPermission = false;

  void _grantPermission(String type) {
    setState(() {
      switch (type) {
        case "Overlay":
          overlayPermission = true;
          break;
        case "Accessibility":
          accessibilityPermission = true;
          break;
        case "Storage":
          storagePermission = true;
          break;
        case "Notifications":
          notificationsPermission = true;
          break;
      }
    });
    print("$type Permission Granted!");
  }

  void _navigateToHome() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    authProvider.setLoggedIn(true);
    authProvider.setGuestMode(false);
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightSurface,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, size: 28, color: AppColors.textMain),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(height: 10),
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppColors.secondary, AppColors.primary],
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(Icons.download_rounded, color: AppColors.lightSurface, size: 55),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Center(
                      child: Text(
                        "Grant Permissions",
                        style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.textMain),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Center(
                      child: Text(
                        "TapMate needs these permissions to function properly",
                        style: TextStyle(fontSize: 14, color: AppColors.textMain),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 35),

                    // Permission Tiles
                    _permissionTile(
                      icon: Icons.visibility,
                      title: "Overlay Permission",
                      subtitle: overlayPermission ? "Granted" : "Display floating button on other apps",
                      gradientColors: [AppColors.primary, AppColors.secondary],
                      granted: overlayPermission,
                      onGrant: () => _grantPermission("Overlay"),
                    ),
                    _permissionTile(
                      icon: Icons.check_circle,
                      title: "Accessibility Service",
                      subtitle: accessibilityPermission ? "Granted" : "Detect video links automatically",
                      gradientColors: [AppColors.primary, AppColors.secondary],
                      granted: accessibilityPermission,
                      onGrant: () => _grantPermission("Accessibility"),
                    ),
                    _permissionTile(
                      icon: Icons.folder,
                      title: "Storage Access",
                      subtitle: storagePermission ? "Granted" : "Save videos to your device",
                      gradientColors: [AppColors.primary, AppColors.secondary],
                      granted: storagePermission,
                      onGrant: () => _grantPermission("Storage"),
                    ),
                    _permissionTile(
                      icon: Icons.notifications,
                      title: "Notifications",
                      subtitle: notificationsPermission ? "Granted" : "Alert you when downloads complete",
                      gradientColors: [AppColors.primary, AppColors.secondary],
                      granted: notificationsPermission,
                      onGrant: () => _grantPermission("Notifications"),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom Buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: TextButton(
                      onPressed: _navigateToHome,
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Ink(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppColors.primary, AppColors.secondary],
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Center(
                          child: Text(
                            "Continue",
                            style: TextStyle(color: AppColors.lightSurface, fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: _navigateToHome,
                    child: const Text(
                      "Skip for Now",
                      style: TextStyle(color: AppColors.textMain, fontSize: 15, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 🔥 CLEAN WHITE ICON BOX TILE
  Widget _permissionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required List<Color> gradientColors,
    required bool granted,
    required VoidCallback onGrant,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: granted ? const Color(0xFFF2E5EE) : const Color(0xFFF5F5F5), // light pink-purple if granted
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: AppColors.textMain, blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.lightSurface, // WHITE BOX
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: AppColors.textMain),
            ),
            child: Icon(
              icon,
              size: 26,
              color: granted ?  AppColors.primary : AppColors.textMain, // pink-purple for granted
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: granted ?  AppColors.primary : AppColors.textMain,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: granted ?  AppColors.secondary : AppColors.textMain,
                  ),
                ),
              ],
            ),
          ),

          // BUTTON (BIGGER & PINK-PURPLE)
          SizedBox(
            height: 50,
            width: 120,
            child: ElevatedButton(
              onPressed: granted ? null : onGrant,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                backgroundColor: Colors.transparent,
                elevation: 0,
              ),
              child: Ink(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.secondary],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(
                    granted ? "Granted" : "Grant",
                    style: const TextStyle(color: AppColors.lightSurface, fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );}
}

