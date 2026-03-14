// lib/Screen/home/platform_content_screen.dart
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:tapmate/Screen/services/platform_downloader.dart';
import 'package:tapmate/Screen/services/platform_auth_service.dart';
import 'storage_selection_dialog.dart';
import 'download_progress_screen.dart';
import 'package:tapmate/Screen/constants/app_colors.dart';

class PlatformContentScreen extends StatefulWidget {
  final String platformName;
  final String platformId;
  final Color platformColor;
  final IconData platformIcon;
  final PlatformSession? platformSession;

  const PlatformContentScreen({
    super.key,
    required this.platformName,
    required this.platformId,
    required this.platformColor,
    required this.platformIcon,
    this.platformSession,
  });

  @override
  State<PlatformContentScreen> createState() => _PlatformContentScreenState();
}

class _PlatformContentScreenState extends State<PlatformContentScreen> with SingleTickerProviderStateMixin {
  String? _selectedContentId;
  bool _isContentSelected = false;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  final List<Map<String, dynamic>> _contentItems = [
    {
      'id': '1',
      'title': 'Amazing Dance Video',
      'thumbnail': '🎬',
      'duration': '2:34',
      'views': '1.2M',
      'url': 'https://youtube.com/watch?v=123',
    },
    {
      'id': '2',
      'title': 'Cooking Tutorial',
      'thumbnail': '👨‍🍳',
      'duration': '5:12',
      'views': '856K',
      'url': 'https://youtube.com/watch?v=456',
    },
    {
      'id': '3',
      'title': 'Travel Vlog',
      'thumbnail': '✈️',
      'duration': '8:45',
      'views': '2.1M',
      'url': 'https://youtube.com/watch?v=789',
    },
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

// In platform_content_screen.dart - Fix the StorageSelectionDialog call

  void _showStorageSelectionDialog() {
    if (_selectedContentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a content first'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final selectedContent = _contentItems.firstWhere(
          (item) => item['id'] == _selectedContentId,
      orElse: () => _contentItems[0],
    );

    showDialog(
      context: context,
      builder: (context) => StorageSelectionDialog(
        platformName: widget.platformName,           // String
        contentId: _selectedContentId!,              // String
        contentTitle: selectedContent['title'],      // String
        onDeviceStorageSelected: (path, format, quality) {
          // Close dialog
          Navigator.pop(context);

          // Start download with device storage
          _startDownload(
            path: path,
            format: format,
            quality: quality,
            content: selectedContent,
          );
        },
        onAppStorageSelected: (format, quality) {
          // Close dialog
          Navigator.pop(context);

          // Start download with app storage
          _startDownload(
            format: format,
            quality: quality,
            content: selectedContent,
          );
        },
      ),
    );
  }
  Future<void> _startDownload({
    String? path,
    required String format,
    required String quality,
    required Map<String, dynamic> content,
  }) async {
    final downloader = PlatformDownloader();

    // Show downloading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    final result = await downloader.downloadVideo(
      platformId: widget.platformId,
      videoUrl: content['url'],
      videoTitle: content['title'],
      format: format,
      quality: quality,
      customPath: path,
    );

    if (!mounted) return;

    // Close loading dialog
    Navigator.pop(context);

    if (result.success) {
      // Navigate to progress screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DownloadProgressScreen(
            platformName: widget.platformName,
            contentTitle: '${content['title']} ($format - $quality)',
            storagePath: path,
            isDeviceStorage: path != null,
            fromPlatformScreen: true,
            sourcePlatform: widget.platformId,
            // Remove platformId and downloadId
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ ${result.message}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightSurface,
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                // Professional Header
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.accent,
                        AppColors.secondary,
                        AppColors.primary,
                      ],
                    ),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(30),
                      bottomRight: Radius.circular(30),
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
                          const SizedBox(width: 12),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => Navigator.pushNamedAndRemoveUntil(
                                context,
                                '/home',
                                    (route) => false,
                              ),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(25),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.3),
                                  ),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.home, color: Colors.white, size: 18),
                                    SizedBox(width: 6),
                                    Text(
                                      'TapMate',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // User profile indicator
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withOpacity(0.3),
                              ),
                            ),
                            child: FaIcon(
                              widget.platformIcon,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              shape: BoxShape.circle,
                            ),
                            child: FaIcon(
                              widget.platformIcon,
                              color: Colors.white,
                              size: 30,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.platformName,
                                  style: const TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Browse and download content',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.white.withOpacity(0.9),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (widget.platformSession != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.green),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.check_circle, color: Colors.green, size: 14),
                                  SizedBox(width: 4),
                                  Text(
                                    'Connected',
                                    style: TextStyle(color: Colors.green, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Content Grid
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Trending Now',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: AppColors.accent,
                          ),
                        ),
                        const SizedBox(height: 16),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                            childAspectRatio: 0.75,
                          ),
                          itemCount: _contentItems.length,
                          itemBuilder: (context, index) {
                            final item = _contentItems[index];
                            final isSelected = _selectedContentId == item['id'];

                            if (isSelected) {
                              _animationController.forward();
                            }

                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  if (_selectedContentId != item['id']) {
                                    _animationController.reset();
                                    _animationController.forward();
                                  }
                                  _selectedContentId = item['id'];
                                  _isContentSelected = true;
                                });
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                curve: Curves.easeInOut,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isSelected
                                        ? widget.platformColor
                                        : Colors.grey.withOpacity(0.2),
                                    width: isSelected ? 3 : 1,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: isSelected
                                          ? widget.platformColor.withOpacity(0.3)
                                          : Colors.grey.withOpacity(0.1),
                                      blurRadius: isSelected ? 15 : 5,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Thumbnail
                                    Expanded(
                                      child: Container(
                                        width: double.infinity,
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors: [
                                              widget.platformColor.withOpacity(0.3),
                                              widget.platformColor.withOpacity(0.1),
                                            ],
                                          ),
                                          borderRadius: const BorderRadius.only(
                                            topLeft: Radius.circular(20),
                                            topRight: Radius.circular(20),
                                          ),
                                        ),
                                        child: Center(
                                          child: Text(
                                            item['thumbnail'],
                                            style: const TextStyle(fontSize: 50),
                                          ),
                                        ),
                                      ),
                                    ),
                                    // Content Info
                                    Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item['title'],
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: isSelected
                                                  ? widget.platformColor
                                                  : AppColors.accent,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                item['duration'],
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey[600],
                                                ),
                                              ),
                                              Text(
                                                item['views'],
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey[600],
                                                ),
                                              ),
                                            ],
                                          ),
                                          if (isSelected) ...[
                                            const SizedBox(height: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 4,
                                              ),
                                              decoration: BoxDecoration(
                                                color: widget.platformColor.withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: Text(
                                                'Selected',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: widget.platformColor,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Floating Action Button with Animation
          if (_isContentSelected)
            Positioned(
              right: 20,
              bottom: 20,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: FloatingActionButton.extended(
                  onPressed: _showStorageSelectionDialog,
                  backgroundColor: widget.platformColor,
                  foregroundColor: Colors.white,
                  elevation: 8,
                  icon: const Icon(Icons.download_rounded, size: 24),
                  label: const Text(
                    'Download',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}