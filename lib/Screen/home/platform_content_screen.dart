import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'storage_selection_dialog.dart';
import 'download_progress_screen.dart';
import 'package:tapmate/Screen/constants/app_colors.dart';

class PlatformContentScreen extends StatefulWidget {
  final String platformName;
  final String platformId;
  final Color platformColor;
  final IconData platformIcon;

  const PlatformContentScreen({
    super.key,
    required this.platformName,
    required this.platformId,
    required this.platformColor,
    required this.platformIcon,
  });

  @override
  State<PlatformContentScreen> createState() => _PlatformContentScreenState();
}

class _PlatformContentScreenState extends State<PlatformContentScreen> {
  String? _selectedContentId;
  bool _isContentSelected = false;

  // Sample content items
  final List<Map<String, dynamic>> _contentItems = [
    {
      'id': '1',
      'title': 'Amazing Dance Video',
      'thumbnail': '🎬',
      'duration': '2:34',
      'views': '1.2M',
    },
    {
      'id': '2',
      'title': 'Cooking Tutorial',
      'thumbnail': '👨‍🍳',
      'duration': '5:12',
      'views': '856K',
    },
    {
      'id': '3',
      'title': 'Travel Vlog',
      'thumbnail': '✈️',
      'duration': '8:45',
      'views': '2.1M',
    },
    {
      'id': '4',
      'title': 'Music Video',
      'thumbnail': '🎵',
      'duration': '3:20',
      'views': '3.5M',
    },
    {
      'id': '5',
      'title': 'Gaming Highlights',
      'thumbnail': '🎮',
      'duration': '10:15',
      'views': '1.8M',
    },
    {
      'id': '6',
      'title': 'Fitness Workout',
      'thumbnail': '💪',
      'duration': '15:30',
      'views': '945K',
    },
  ];

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
        platformName: widget.platformName,
        contentId: _selectedContentId!,
        contentTitle: selectedContent['title'] as String,
        onDeviceStorageSelected: (path, format, quality) {
          Navigator.pop(context); // Storage dialog close
          _handleDeviceStorageDownload(path, format, quality, selectedContent);
        },
        onAppStorageSelected: (format, quality) {
          Navigator.pop(context); // Storage dialog close
          _handleAppStorageDownload(format, quality, selectedContent);
        },
      ),
    );
  }


  void _handleDeviceStorageDownload(String? path, String format, String quality, Map<String, dynamic> content) {
    if (path != null && path.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DownloadProgressScreen(
            platformName: widget.platformName,
            contentTitle: '${content['title']} ($format - $quality)',
            storagePath: path,
            isDeviceStorage: true,
            fromPlatformScreen: true,
            sourcePlatform: widget.platformId, // Make sure this is the actual platform ID (e.g., 'instagram', 'youtube')
          ),
        ),
      );
    }
  }

  void _handleAppStorageDownload(String format, String quality, Map<String, dynamic> content) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DownloadProgressScreen(
          platformName: widget.platformName,
          contentTitle: '${content['title']} ($format - $quality)',
          storagePath: null,
          isDeviceStorage: false,
          fromPlatformScreen: true,
          sourcePlatform: widget.platformId, // Make sure this is the actual platform ID
        ),
      ),
    );
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
                // Header - FIXED
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
                          // Back Button - FIXED
                          IconButton(
                            icon: const Icon(Icons.arrow_back, color: AppColors.lightSurface),
                            onPressed: () {
                              Navigator.pop(context); // Simple pop
                            },
                          ),
                          // Home Button - FIXED
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                Navigator.pushNamedAndRemoveUntil(
                                  context,
                                  '/home',
                                      (route) => false,
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: AppColors.lightSurface.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: AppColors.lightSurface.withOpacity(0.3),
                                    width: 1.5,
                                  ),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.home, color: AppColors.lightSurface, size: 18),
                                    SizedBox(width: 6),
                                    Text(
                                      'TapMate',
                                      style: TextStyle(
                                        color: AppColors.lightSurface,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          // Platform Icon
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.lightSurface.withOpacity(0.15),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.lightSurface.withOpacity(0.3),
                                width: 2,
                              ),
                            ),
                            child: FaIcon(
                              widget.platformIcon,
                              color: AppColors.lightSurface,
                              size: 24,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 15),
                      Text(
                        widget.platformName,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: AppColors.lightSurface,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Browse and download content',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.lightSurface.withOpacity(0.9),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                // Content List
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
                            crossAxisSpacing: 15,
                            mainAxisSpacing: 15,
                            childAspectRatio: 0.75,
                          ),
                          itemCount: _contentItems.length,
                          itemBuilder: (context, index) {
                            final item = _contentItems[index];
                            final isSelected = _selectedContentId == item['id'];
                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedContentId = item['id'];
                                  _isContentSelected = true;
                                });
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  color: AppColors.lightSurface,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isSelected
                                        ? AppColors.primary
                                        : AppColors.accent.withOpacity(0.1),
                                    width: isSelected ? 2.5 : 1,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: isSelected
                                          ? AppColors.primary.withOpacity(0.2)
                                          : Colors.grey.withOpacity(0.1),
                                      blurRadius: isSelected ? 10 : 5,
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
                                            topLeft: Radius.circular(16),
                                            topRight: Radius.circular(16),
                                          ),
                                        ),
                                        child: Center(
                                          child: Text(
                                            item['thumbnail'] as String,
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
                                            item['title'] as String,
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: isSelected
                                                  ? AppColors.primary
                                                  : AppColors.accent,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 6),
                                          Row(
                                            mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                item['duration'] as String,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey[600],
                                                ),
                                              ),
                                              Text(
                                                item['views'] as String,
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
                                                  horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: AppColors.primary.withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: const Text(
                                                'Selected',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: AppColors.primary,
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

          // Floating Action Button
          if (_isContentSelected)
            Positioned(
              right: 20,
              bottom: 20,
              child: FloatingActionButton.extended(
                onPressed: _showStorageSelectionDialog,
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.lightSurface,
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
        ],
      ),
    );
  }
}

