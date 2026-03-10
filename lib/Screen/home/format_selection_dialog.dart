import 'package:flutter/material.dart';

import 'package:tapmate/Screen/constants/app_colors.dart';

class FormatSelectionDialog extends StatefulWidget {
  final String contentTitle;

  const FormatSelectionDialog({
    super.key,
    required this.contentTitle,
  });

  @override
  State<FormatSelectionDialog> createState() => _FormatSelectionDialogState();
}

class _FormatSelectionDialogState extends State<FormatSelectionDialog> {
  String _selectedFormat = 'Video'; // Video or Audio
  String _selectedQuality = '1080p'; // For video: 1080p, 720p, 480p, 360p | For audio: MP3, AAC

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.lightSurface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.secondary, AppColors.primary],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.video_settings,
                    color: AppColors.lightSurface,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Select Format & Quality',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.accent,
                        ),
                      ),
                      Text(
                        widget.contentTitle,
                        style: TextStyle(
                          fontSize: 13,
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
            const SizedBox(height: 30),

            // Format Selection (Video/Audio)
            const Text(
              'Format',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.accent,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildFormatOption(
                    'Video',
                    Icons.videocam,
                    _selectedFormat == 'Video',
                        () => setState(() {
                      _selectedFormat = 'Video';
                      _selectedQuality = '1080p';
                    }),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildFormatOption(
                    'Audio',
                    Icons.music_note,
                    _selectedFormat == 'Audio',
                        () => setState(() {
                      _selectedFormat = 'Audio';
                      _selectedQuality = 'MP3';
                    }),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Quality Selection
            Text(
              _selectedFormat == 'Video' ? 'Video Quality' : 'Audio Quality',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.accent,
              ),
            ),
            const SizedBox(height: 12),
            if (_selectedFormat == 'Video')
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _buildQualityChip('1080p', Icons.high_quality),
                  _buildQualityChip('720p', Icons.hd),
                  _buildQualityChip('480p', Icons.video_library),
                  _buildQualityChip('360p', Icons.video_call),
                ],
              )
            else
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _buildQualityChip('MP3', Icons.music_note),
                  _buildQualityChip('AAC', Icons.audiotrack),
                ],
              ),

            const SizedBox(height: 30),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context, null), // ✅ Return null
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey[300]!),
                      ),
                    ),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () {
                      // ✅ Return data as Map
                      Navigator.pop(context, {
                        'format': _selectedFormat,
                        'quality': _selectedQuality,
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.lightSurface,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Continue',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormatOption(
      String label,
      IconData icon,
      bool isSelected,
      VoidCallback onTap,
      ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withOpacity(0.1)
              : Colors.grey[50],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? AppColors.primary : Colors.grey[600],
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? AppColors.primary : Colors.grey[700],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQualityChip(String quality, IconData icon) {
    final isSelected = _selectedQuality == quality;
    return InkWell(
      onTap: () => setState(() => _selectedQuality = quality),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary
              : Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? AppColors.lightSurface : Colors.grey[600],
            ),
            const SizedBox(width: 6),
            Text(
              quality,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? AppColors.lightSurface : Colors.grey[700],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

