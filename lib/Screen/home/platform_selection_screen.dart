import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'platform_auth_screen.dart';
import 'package:tapmate/Screen/constants/app_colors.dart';


class PlatformSelectionScreen extends StatelessWidget {
  const PlatformSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightSurface,
      body: Column(
        children: [
          // Gradient Header - REDUCED HEIGHT
          Container(
            height: 160, // Reduced from 200
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.accent, AppColors.secondary, AppColors.primary],
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(25),
                bottomRight: Radius.circular(25),
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back, color: AppColors.lightSurface, size: 24),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const Expanded(
                          child: Text(
                            'Select Platform',
                            style: TextStyle(
                              color: AppColors.lightSurface,
                              fontWeight: FontWeight.bold,
                              fontSize: 22, // Slightly smaller
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8), // Reduced spacing
                    Padding(
                      padding: const EdgeInsets.only(left: 55), // Align with text
                      child: Text(
                        'Choose where to download from',
                        style: TextStyle(
                          fontSize: 15,
                          color: AppColors.lightSurface.withOpacity(0.9),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Content - FIXED POSITIONING
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Popular Platforms',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.accent,
                    ),
                  ),
                  const SizedBox(height: 15),

                  // Platforms Grid
                  Expanded(
                    child: GridView.count(
                      crossAxisCount: 3, // Changed to 3 columns for better layout
                      shrinkWrap: true,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.85, // Better for square-ish cards
                      children: [
                        _buildPlatformCard(
                          context,
                          'YouTube',
                          FontAwesomeIcons.youtube,
                          const Color(0xFFFF0000),
                          'youtube',
                        ),
                        _buildPlatformCard(
                          context,
                          'Instagram',
                          FontAwesomeIcons.instagram,
                          const Color(0xFFE4405F),
                          'instagram',
                        ),
                        _buildPlatformCard(
                          context,
                          'TikTok',
                          FontAwesomeIcons.tiktok,
                          const Color(0xFF000000),
                          'tiktok',
                        ),
                        _buildPlatformCard(
                          context,
                          'Facebook',
                          FontAwesomeIcons.facebook,
                          const Color(0xFF1877F2),
                          'facebook',
                        ),
                        _buildPlatformCard(
                          context,
                          'Twitter',
                          FontAwesomeIcons.twitter,
                          const Color(0xFF1DA1F2),
                          'twitter',
                        ),
                        _buildPlatformCard(
                          context,
                          'WhatsApp',
                          FontAwesomeIcons.whatsapp,
                          const Color(0xFF25D366),
                          'whatsapp',
                        ),
                        _buildPlatformCard(
                          context,
                          'Snapchat',
                          FontAwesomeIcons.snapchat,
                          const Color(0xFFFFFC00),
                          'snapchat',
                        ),
                        _buildPlatformCard(
                          context,
                          'LinkedIn',
                          FontAwesomeIcons.linkedin,
                          const Color(0xFF0077B5),
                          'linkedin',
                        ),
                        _buildPlatformCard(
                          context,
                          'Pinterest',
                          FontAwesomeIcons.pinterest,
                          const Color(0xFFBD081C),
                          'pinterest',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlatformCard(
      BuildContext context,
      String platformName,
      IconData icon,
      Color color,
      String platformId,
      ) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PlatformAuthScreen(
              platformName: platformName,
              platformId: platformId,
              platformColor: color,
              platformIcon: icon,
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.lightSurface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.accent.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
          border: Border.all(
            color: AppColors.accent.withOpacity(0.1),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Platform Icon with gradient background
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    color.withOpacity(0.2),
                    color.withOpacity(0.05),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: FaIcon(
                icon,
                color: color,
                size: 28,
              ),
            ),
            const SizedBox(height: 10),

            // Platform Name
            Text(
              platformName,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.accent,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),

            // Small indicator
            const SizedBox(height: 6),
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

