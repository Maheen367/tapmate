// dart
import 'package:flutter/material.dart';
import '../home/home_screen.dart';

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
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
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
                      icon: const Icon(Icons.arrow_back, size: 28, color: Colors.black),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(height: 10),
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF6A1E55), Color(0xFFA64D79)],
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(Icons.shield_outlined, color: Colors.white, size: 55),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Center(
                      child: Text(
                        "Grant Permissions",
                        style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.black),
                      ),
                    ),
                    const SizedBox(height: 5),
                    const Center(
                      child: Text(
                        "TapMate needs these permissions to function properly",
                        style: TextStyle(fontSize: 14, color: Colors.black54),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 35),

                    // PERMISSION TILES
                    _permissionTile(
                      icon: Icons.visibility,
                      title: "Overlay Permission",
                      subtitle: overlayPermission ? "Granted" : "Display floating button on other apps",
                      gradientColors: [Colors.blueAccent, Colors.lightBlueAccent],
                      granted: overlayPermission,
                      onGrant: () => _grantPermission("Overlay"),
                    ),
                    _permissionTile(
                      icon: Icons.check_circle,
                      title: "Accessibility Service",
                      subtitle: accessibilityPermission ? "Granted" : "Detect video links automatically",
                      gradientColors: [Colors.purple, Colors.purpleAccent],
                      granted: accessibilityPermission,
                      onGrant: () => _grantPermission("Accessibility"),
                    ),
                    _permissionTile(
                      icon: Icons.folder,
                      title: "Storage Access",
                      subtitle: storagePermission ? "Granted" : "Save videos to your device",
                      gradientColors: [Colors.green, Colors.lightGreen],
                      granted: storagePermission,
                      onGrant: () => _grantPermission("Storage"),
                    ),
                    _permissionTile(
                      icon: Icons.notifications,
                      title: "Notifications",
                      subtitle: notificationsPermission ? "Granted" : "Alert you when downloads complete",
                      gradientColors: [Colors.orange, Colors.deepOrangeAccent],
                      granted: notificationsPermission,
                      onGrant: () => _grantPermission("Notifications"),
                    ),
                  ],
                ),
              ),
            ),

            // Continue + Skip buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: TextButton(
                      onPressed: _navigateToHome,
                      style: TextButton.styleFrom(padding: EdgeInsets.zero, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                      child: Ink(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [Color(0xFF6A1E55), Color(0xFFA64D79)]),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Center(
                          child: Text(
                            "Continue",
                            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
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
                      style: TextStyle(color: Colors.black54, fontSize: 15, fontWeight: FontWeight.bold),
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
        color: granted ? Colors.green[50] : const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          // Gradient Icon Container
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: gradientColors),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 26),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: granted ? Colors.green : Colors.black)),
                const SizedBox(height: 4),
                Text(subtitle, style: TextStyle(fontSize: 13, color: granted ? Colors.green[700] : Colors.black54)),
              ],
            ),
          ),
          // Gradient Grant Button
          SizedBox(
            height: 40,
            child: ElevatedButton(
              onPressed: granted ? null : onGrant,
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                backgroundColor: Colors.transparent,
                elevation: 0,
              ),
              child: Ink(
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: granted ? [Colors.green, Colors.greenAccent] : gradientColors),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(granted ? "Granted" : "Grant", style: const TextStyle(color: Colors.white)),
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
}