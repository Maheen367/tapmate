// lib/Screen/home/platform_selection_screen.dart

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:tapmate/Screen/constants/app_colors.dart';
import 'package:url_launcher/url_launcher.dart';

class PlatformSelectionScreen extends StatelessWidget {
  const PlatformSelectionScreen({super.key});

  final List<Map<String, dynamic>> popularPlatforms = const [
    {'name': 'YouTube', 'icon': FontAwesomeIcons.youtube, 'color': Color(0xFFFF0000), 'url': 'https://youtube.com'},
    {'name': 'Instagram', 'icon': FontAwesomeIcons.instagram, 'color': Color(0xFFE4405F), 'url': 'https://instagram.com'},
    {'name': 'TikTok', 'icon': FontAwesomeIcons.tiktok, 'color': Color(0xFF000000), 'url': 'https://tiktok.com'},
    {'name': 'Facebook', 'icon': FontAwesomeIcons.facebook, 'color': Color(0xFF1877F2), 'url': 'https://facebook.com'},
    {'name': 'Twitter', 'icon': FontAwesomeIcons.twitter, 'color': Color(0xFF1DA1F2), 'url': 'https://twitter.com'},
    {'name': 'WhatsApp', 'icon': FontAwesomeIcons.whatsapp, 'color': Color(0xFF25D366), 'url': 'https://whatsapp.com'},
  ];

  final List<Map<String, dynamic>> morePlatforms = const [
    {'name': 'Snapchat', 'icon': FontAwesomeIcons.snapchat, 'color': Color(0xFFFFFC00)},
    {'name': 'LinkedIn', 'icon': FontAwesomeIcons.linkedin, 'color': Color(0xFF0077B5)},
    {'name': 'Pinterest', 'icon': FontAwesomeIcons.pinterest, 'color': Color(0xFFBD081C)},
    {'name': 'Reddit', 'icon': FontAwesomeIcons.reddit, 'color': Color(0xFFFF4500)},
    {'name': 'Twitch', 'icon': FontAwesomeIcons.twitch, 'color': Color(0xFF9146FF)},
    {'name': 'Discord', 'icon': FontAwesomeIcons.discord, 'color': Color(0xFF5865F2)},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightSurface,
      body: Column(
        children: [
          // Modern Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 60, 24, 40),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.accent, AppColors.secondary, AppColors.primary],
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(35),
                bottomRight: Radius.circular(35),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Text(
                        'Select Platform',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Text(
                  'Choose where to download from',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Popular Platforms',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.accent,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Popular Platforms Grid
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 0.9,
                    ),
                    itemCount: popularPlatforms.length,
                    itemBuilder: (context, index) {
                      final platform = popularPlatforms[index];
                      return _buildPlatformCard(
                        platform['name'],
                        platform['icon'],
                        platform['color'],
                        onTap: () {
                          _handlePlatformSelection(context, platform['name'], platform['url']);
                        },
                      );
                    },
                  ),

                  const SizedBox(height: 30),

                  const Text(
                    'More Platforms',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.accent,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // More Platforms List
                  ...morePlatforms.map((platform) => _buildMorePlatformItem(
                    platform['name'],
                    platform['icon'],
                    platform['color'],
                    context,  // ✅ context pass kiya
                  )),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlatformCard(String name, IconData icon, Color color, {required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.15),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: FaIcon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 10),
            Text(
              name,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.accent,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ Fixed: Added context parameter
  Widget _buildMorePlatformItem(String name, IconData icon, Color color, BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: FaIcon(icon, color: color, size: 20),
        ),
        title: Text(
          name,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.accent,
          ),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.primary),
        onTap: () {
          _showComingSoonDialog(context, name);  // ✅ context pass kiya
        },
      ),
    );
  }

  void _handlePlatformSelection(BuildContext context, String platformName, String url) async {
    if (platformName == 'YouTube') {
      // YouTube ke liye special handling
      _showYouTubeOptions(context);
    } else {
      // Other platforms - open app or browser
      try {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      } catch (e) {
        _showComingSoonDialog(context, platformName);  // ✅ context pass kiya
      }
    }
  }

  void _showYouTubeOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Download from YouTube',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.accent,
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.link, color: Colors.red),
              ),
              title: const Text('Paste YouTube Link'),
              subtitle: const Text('Copy link from YouTube app and paste here'),
              onTap: () {
                Navigator.pop(context);
                _showLinkInputDialog(context);
              },
            ),
            const Divider(),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.open_in_browser, color: Colors.red),
              ),
              title: const Text('Open YouTube App'),
              subtitle: const Text('Browse and copy link manually'),
              onTap: () async {
                Navigator.pop(context);
                await launchUrl(
                  Uri.parse('https://youtube.com'),
                  mode: LaunchMode.externalApplication,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showLinkInputDialog(BuildContext context) {
    final TextEditingController linkController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter YouTube Link'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Copy link from YouTube app and paste below:'),
            const SizedBox(height: 16),
            TextField(
              controller: linkController,
              decoration: InputDecoration(
                hintText: 'https://youtube.com/watch?v=...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.link),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (linkController.text.isNotEmpty) {
                Navigator.pop(context);
                _navigateToDownload(context, linkController.text);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Download'),
          ),
        ],
      ),
    );
  }

  void _navigateToDownload(BuildContext context, String videoUrl) {
    // Navigate to your download screen with the URL
    Navigator.pushNamed(
      context,
      '/youtube_downloader',
      arguments: {'url': videoUrl},
    );
  }

  // ✅ Fixed: Added context parameter and removed garbage
  void _showComingSoonDialog(BuildContext context, String platformName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$platformName Coming Soon!'),
        content: Text('Support for $platformName will be added soon. Stay tuned!'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}