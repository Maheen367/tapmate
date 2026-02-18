import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tapmate/Screen/home/feed_screen.dart';
import 'package:tapmate/auth_provider.dart';
import 'package:tapmate/utils/guide_manager.dart';
import 'library_screen.dart';
import 'platform_content_screen.dart';
import 'package:tapmate/Screen/constants/app_colors.dart';


enum DownloadStatus {
  downloading,
  paused,
  completed,
  failed,
}

class DownloadProgressScreen extends StatefulWidget {
  final String platformName;
  final String contentTitle;
  final String? storagePath;
  final bool isDeviceStorage;
  final bool fromPlatformScreen;
  final String? previousScreen; // Track previous screen name
  final String? sourcePlatform; // NEW: Actual platform you came from

  const DownloadProgressScreen({
    super.key,
    required this.platformName,
    required this.contentTitle,
    this.storagePath,
    required this.isDeviceStorage,
    this.fromPlatformScreen = true,
    this.previousScreen,
    this.sourcePlatform, // NEW parameter
  });

  @override
  State<DownloadProgressScreen> createState() => _DownloadProgressScreenState();
}

class _DownloadProgressScreenState extends State<DownloadProgressScreen> {
  double _progress = 0.0;
  DownloadStatus _status = DownloadStatus.downloading;
  String _speed = '2.5 MB/s';
  String _downloaded = '0 MB';
  String _totalSize = '12.5 MB';
  String _timeRemaining = '5s';

  @override
  void initState() {
    super.initState();
    _startDownload();
  }

  void _startDownload() {
    if (_status == DownloadStatus.downloading) {
      _simulateDownload();
    }
  }

  void _simulateDownload() {
    if (_status != DownloadStatus.downloading || _progress >= 1.0) {
      if (_progress >= 1.0) {
        setState(() {
          _status = DownloadStatus.completed;
        });
      }
      return;
    }

    Future.delayed(const Duration(milliseconds: 200), () {
      if (!mounted || _status != DownloadStatus.downloading) return;

      setState(() {
        _progress += 0.02;
        _downloaded = '${(_progress * 12.5).toStringAsFixed(1)} MB';
        _speed = '${(2.0 + (1 - _progress) * 0.5).toStringAsFixed(1)} MB/s';
        _timeRemaining = '${((1 - _progress) * 250).toStringAsFixed(0)}s';

        if (_progress >= 1.0) {
          _status = DownloadStatus.completed;
          _downloaded = _totalSize;
          _speed = '0 MB/s';
          _timeRemaining = 'Complete';
        }
      });

      if (_status == DownloadStatus.downloading) {
        _simulateDownload();
      } else if (_status == DownloadStatus.completed) {
        // Show first-download celebration once per user
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (!mounted) return;
          final authProvider = Provider.of<AuthProvider>(context, listen: false);
          final userId = authProvider.userId;

          // Only for logged-in users
          if (userId.isNotEmpty && userId != 'guest') {
            final alreadyShown = await GuideManager.hasShownFirstDownload(userId);
            if (!alreadyShown) {
              // Mark as shown
              await GuideManager.markFirstDownloadShown(userId);

              // Show dialog
              if (!mounted) return;
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Congratulations!'),
                  content: const Text('You have downloaded your first video. Share it with the community or find more in the Library.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Close'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const LibraryScreen()),
                        );
                      },
                      child: const Text('Open Library'),
                    ),
                  ],
                ),
              );
            }
          }
        });
      }
    });
  }

  void _pauseDownload() {
    setState(() {
      _status = DownloadStatus.paused;
    });
  }

  void _resumeDownload() {
    setState(() {
      _status = DownloadStatus.downloading;
    });
    _simulateDownload();
  }

  void _cancelDownload() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Download'),
        content: const Text('Are you sure you want to cancel this download?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _handleBackNavigation();
            },
            child: const Text('Yes, Cancel', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
  void _handleBackNavigation() {
    // DEBUG LOGS with more details
    print("=== BACK NAVIGATION DEBUG ===");
    print("Source Platform: ${widget.sourcePlatform}");
    print("Platform Name: ${widget.platformName}");
    print("From Platform Screen: ${widget.fromPlatformScreen}");
    print("Platform ID from source: ${widget.sourcePlatform}");
    print("Platform ID from name: ${_getPlatformId(widget.platformName)}");
    print("=============================");

    if (widget.sourcePlatform == 'search') {
      print("Navigating back to SearchDiscoverScreen");
      Navigator.pushReplacementNamed(context, '/search');
      return;
    }

    // FIRST: Check if we're coming from Feed
    if (widget.sourcePlatform == 'feed') {
      print("Navigating back to FeedScreen");
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const FeedScreen()),
            (route) => false,
      );
      return;
    }

    // SECOND: Check if we can pop normally
    if (Navigator.of(context).canPop()) {
      print("Normal pop available");
      Navigator.of(context).pop();
      return;
    }

    // THIRD: Check if coming from platform screen
    if (widget.fromPlatformScreen && widget.platformName.isNotEmpty) {
      // FIXED: Use the actual platform that was passed
      // The issue was using widget.platformName directly without proper platform detection
      String platformName = widget.platformName;
      String platformId = widget.sourcePlatform ?? _getPlatformId(platformName);

      // Special handling for platform names
      // Convert display name to actual platform ID if needed
      if (platformId.isEmpty) {
        platformId = _getPlatformId(platformName);
      }

      print("Platform to navigate: $platformName");
      print("Platform ID: $platformId");

      // Get platform color and icon based on the actual platform
      Color platformColor = _getPlatformColor(platformName);
      IconData platformIcon = _getPlatformIcon(platformName);

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => PlatformContentScreen(
            platformName: platformName,
            platformId: platformId,
            platformColor: platformColor,
            platformIcon: platformIcon,
          ),
        ),
            (route) => false,
      );
      return;
    }

    // FINAL FALLBACK: Go to home
    print("Fallback to HomeScreen");
    Navigator.pushNamedAndRemoveUntil(
      context,
      '/home',
          (route) => false,
    );
  }

  // Mini download indicator widget
  Widget _buildMiniDownloadIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.lightSurface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppColors.textMain.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 30,
                height: 30,
                child: CircularProgressIndicator(
                  value: _progress,
                  strokeWidth: 3,
                  backgroundColor: Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _status == DownloadStatus.completed
                        ? Colors.green
                        : AppColors.primary,
                  ),
                ),
              ),
              Icon(
                _status == DownloadStatus.completed
                    ? Icons.check
                    : Icons.download_rounded,
                size: 14,
                color: AppColors.lightSurface,
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _status == DownloadStatus.completed
                      ? 'Downloaded'
                      : 'Downloading...',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.accent,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  widget.contentTitle,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey[600],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (_status == DownloadStatus.downloading)
            Text(
              '${(_progress * 100).toStringAsFixed(0)}%',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightSurface,
      body: SafeArea(
        child: Column(
          children: [
            // Header with Mini Indicator
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.accent, AppColors.secondary, AppColors.primary],
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(25),
                  bottomRight: Radius.circular(25),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accent.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: AppColors.lightSurface),
                        onPressed: () {
                          // Use the FIXED back navigation
                          _handleBackNavigation();
                        },
                      ),
                      const Expanded(
                        child: Text(
                          'Download Manager',
                          style: TextStyle(
                            color: AppColors.lightSurface,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.video_library_rounded, color: AppColors.lightSurface),
                        onPressed: () {
                          // Go to Library screen
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const LibraryScreen(),
                            ),
                          );
                        },
                        tooltip: 'Go to Library',
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Mini Download Indicator in Header
                  _buildMiniDownloadIndicator(),
                ],
              ),
            ),

            // Progress Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const SizedBox(height: 20),

                    // Quick Action Cards
                    Row(
                      children: [
                        Expanded(
                          child: _buildQuickActionCard(
                            icon: Icons.video_library_rounded,
                            title: 'Browse More',
                            subtitle: 'Find more videos',
                            color: AppColors.primary,
                            onTap: () {
                              if (widget.sourcePlatform == 'search') {
                                // Go back to Search & Discovery screen
                                Navigator.pushReplacementNamed(context, '/search');
                              }
                              // Check where to navigate
                            else if (widget.sourcePlatform == 'feed') {
                                // Go back to FeedScreen
                                Navigator.pushAndRemoveUntil(
                                  context,
                                  MaterialPageRoute(builder: (context) => const FeedScreen()),
                                      (route) => false,
                                );
                              } else {
                                String platformToNavigate = widget.sourcePlatform ?? widget.platformName;
                                // Go to platform screen
                                Navigator.pushAndRemoveUntil(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => PlatformContentScreen(
                                      platformName: platformToNavigate,
                                      platformId: _getPlatformId(platformToNavigate),
                                      platformColor: _getPlatformColor(platformToNavigate),
                                      platformIcon: _getPlatformIcon(platformToNavigate),
                                    ),
                                  ),
                                      (route) => false,
                                );
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildQuickActionCard(
                            icon: Icons.home_rounded,
                            title: 'Go Home',
                            subtitle: 'Back to main screen',
                            color: AppColors.secondary,
                            onTap: () {
                              Navigator.pushNamedAndRemoveUntil(
                                context,
                                '/home',
                                    (route) => false,
                              );
                            },
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 25),

                    // Download Details
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppColors.accent.withOpacity(0.1),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Download Details',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.accent,
                            ),
                          ),
                          const SizedBox(height: 15),

                          // Progress Bar
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: LinearProgressIndicator(
                              value: _progress,
                              minHeight: 12,
                              backgroundColor: Colors.grey[200],
                              valueColor: AlwaysStoppedAnimation<Color>(
                                _status == DownloadStatus.completed
                                    ? Colors.green
                                    : AppColors.primary,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${(_progress * 100).toStringAsFixed(0)}%',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                              Text(
                                _status == DownloadStatus.completed
                                    ? 'Complete'
                                    : _status == DownloadStatus.paused
                                    ? 'Paused'
                                    : 'In Progress',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 20),

                          // Stats Grid - FIXED
                          GridView.count(
                            crossAxisCount: 3,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            childAspectRatio: 1.0,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                            children: [
                              _buildStatCard('Speed', _speed, Icons.speed),
                              _buildStatCard('Downloaded', _downloaded, Icons.download),
                              _buildStatCard('Time Left', _timeRemaining, Icons.timer),
                            ],
                          ),

                          const SizedBox(height: 20),

                          // File Info
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.primary.withOpacity(0.1),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'File Information',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.accent,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  widget.contentTitle,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey[700],
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  'Platform: ${widget.platformName}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  widget.isDeviceStorage
                                      ? 'Location: ${widget.storagePath ?? "Device Storage"}'
                                      : 'Location: TapMate Downloads',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 25),

                    // Control Buttons
                    if (_status != DownloadStatus.completed)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.lightSurface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (_status == DownloadStatus.downloading)
                              OutlinedButton.icon(
                                onPressed: _pauseDownload,
                                icon: const Icon(Icons.pause, size: 18),
                                label: const Text('Pause'),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Colors.orange),
                                ),
                              )
                            else if (_status == DownloadStatus.paused)
                              ElevatedButton.icon(
                                onPressed: _resumeDownload,
                                icon: const Icon(Icons.play_arrow, size: 18),
                                label: const Text('Resume'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                ),
                              ),
                            const SizedBox(width: 15),
                            OutlinedButton.icon(
                              onPressed: _cancelDownload,
                              icon: const Icon(Icons.close, size: 18),
                              label: const Text('Cancel'),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.red),
                              ),
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
      ),

      // Floating Action Button
      floatingActionButton: _status == DownloadStatus.downloading
          ? FloatingActionButton.extended(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Download running in background'),
              backgroundColor: AppColors.primary,
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.download_rounded),
        label: Text('${(_progress * 100).toStringAsFixed(0)}%'),
      )
          : null,
    );
  }

  // Helper Functions
  String _getPlatformId(String platformName) {
    // Convert to lowercase and trim
    String name = platformName.toLowerCase().trim();

    switch (name) {
      case 'instagram': return 'instagram';
      case 'youtube': return 'youtube';
      case 'tiktok': return 'tiktok';
      case 'facebook': return 'facebook';
      case 'twitter': return 'twitter';
      case 'whatsapp': return 'whatsapp';
      case 'snapchat': return 'snapchat';
      case 'linkedin': return 'linkedin';
      case 'pinterest': return 'pinterest';
      case 'feed': return 'feed';
      default: return name; // Return as-is if not in the list
    }
  }
  Color _getPlatformColor(String platformName) {
    switch (platformName.toLowerCase()) {
      case 'instagram': return const Color(0xFFE4405F);
      case 'youtube': return const Color(0xFFFF0000);
      case 'tiktok': return const Color(0xFF000000);
      case 'facebook': return const Color(0xFF1877F2);
      case 'twitter': return const Color(0xFF1DA1F2);
      case 'whatsapp': return const Color(0xFF25D366);
      case 'feed': return AppColors.primary;
      default: return AppColors.primary;
    }
  }

  IconData _getPlatformIcon(String platformName) {
    switch (platformName.toLowerCase()) {
      case 'instagram': return Icons.camera_alt;
      case 'youtube': return Icons.play_circle_filled;
      case 'tiktok': return Icons.music_note;
      case 'facebook': return Icons.facebook;
      case 'twitter': return Icons.chat_bubble;
      case 'whatsapp': return Icons.chat;
      case 'feed': return Icons.home;
      default: return Icons.video_library;
    }
  }

  Widget _buildQuickActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.accent,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: AppColors.primary, size: 18),
          const SizedBox(height: 6),
          Text(
            title,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: AppColors.accent,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}



