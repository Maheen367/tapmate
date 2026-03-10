import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart'; //
import 'format_selection_dialog.dart';
import 'dart:io';
import 'package:tapmate/Screen/constants/app_colors.dart';


class StorageSelectionDialog extends StatefulWidget {
  final String platformName;
  final String contentId;
  final String contentTitle;
  final Function(String? path, String format, String quality) onDeviceStorageSelected;
  final Function(String format, String quality) onAppStorageSelected;

  const StorageSelectionDialog({
    super.key,
    required this.platformName,
    required this.contentId,
    required this.contentTitle,
    required this.onDeviceStorageSelected,
    required this.onAppStorageSelected,
  });

  @override
  State<StorageSelectionDialog> createState() => _StorageSelectionDialogState();
}

class _StorageSelectionDialogState extends State<StorageSelectionDialog> {
  bool _isSelectingPath = false;

  Future<void> _selectDevicePath() async {
    if (!mounted) return;

    setState(() {
      _isSelectingPath = true;
    });

    // ✅ FIXED: Changed to Map<String, dynamic>
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => FormatSelectionDialog(
        contentTitle: widget.contentTitle,
      ),
    );

    if (result != null && mounted) {
      // ✅ FIXED: Safe access with null checks
      final format = result['format']?.toString() ?? 'Video';
      final quality = result['quality']?.toString() ?? '1080p';

      // Now select storage path
      await _selectPathAfterFormat(format, quality);
    } else {
      if (mounted) {
        setState(() {
          _isSelectingPath = false;
        });
      }
    }
  }

  // ✅ UPDATED FUNCTION: FIXED VERSION
  Future<void> _selectPathAfterFormat(String format, String quality) async {
    try {
      // First try to use FilePicker to select a file (extract directory)
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
        dialogTitle: 'Select a location to save your download',
      );

      if (result != null && result.files.single.path != null) {
        String filePath = result.files.single.path!;
        String directory = filePath.substring(0, filePath.lastIndexOf('/'));

        // ✅ Close dialog and pass data
        Navigator.pop(context); // Close storage dialog
        widget.onDeviceStorageSelected(directory, format, quality);
      } else {
        // User cancelled - use default downloads directory
        if (mounted) {
          setState(() {
            _isSelectingPath = false;
          });

          // Try to get downloads directory
          try {
            final Directory? downloadsDir = await getExternalStorageDirectory();
            if (downloadsDir != null) {
              Navigator.pop(context);
              widget.onDeviceStorageSelected('${downloadsDir.path}/TapMate_Downloads', format, quality);
            } else {
              // Fallback to app directory
              final Directory appDir = await getApplicationDocumentsDirectory();
              Navigator.pop(context);
              widget.onDeviceStorageSelected('${appDir.path}/Downloads', format, quality);
            }
          } catch (e) {
            // Final fallback
            Navigator.pop(context);
            widget.onDeviceStorageSelected('/storage/emulated/0/Download/TapMate', format, quality);
          }
        }
      }
    } catch (e) {
      // Handle all errors gracefully
      if (mounted) {
        setState(() {
          _isSelectingPath = false;
        });

        // Show simple confirmation for default path
        bool useDefault = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Download Location'),
            content: const Text(
              'Unable to select custom location.\n\n'
                  'Use default download folder?\n'
                  '/storage/emulated/0/Download/TapMate',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Use Default'),
              ),
            ],
          ),
        ) ?? false;

        if (useDefault) {
          Navigator.pop(context);
          widget.onDeviceStorageSelected('/storage/emulated/0/Download/TapMate', format, quality);
        }
      }
    }
  }

  void _handleAppStorage() async {
    // ✅ FIXED: Changed to Map<String, dynamic>
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => FormatSelectionDialog(
        contentTitle: widget.contentTitle,
      ),
    );

    if (result != null) {
      // ✅ FIXED: Safe access with null checks
      final format = result['format']?.toString() ?? 'Video';
      final quality = result['quality']?.toString() ?? '1080p';

      // ✅ Close BOTH dialogs and pass data
      Navigator.pop(context); // Close storage dialog
      widget.onAppStorageSelected(format, quality);
    } else {
      // User cancelled format selection
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Format selection cancelled'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        return !_isSelectingPath;
      },
      child: Dialog(
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
                      Icons.download_rounded,
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
                          'Select Storage',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.accent,
                          ),
                        ),
                        Text(
                          'Choose where to save ${widget.platformName} content',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),

              // Device Storage Option
              _buildStorageOption(
                icon: Icons.phone_android,
                title: 'Device Storage',
                subtitle: 'Save to your device storage',
                color: AppColors.primary,
                onTap: _isSelectingPath ? null : _selectDevicePath,
                isLoading: _isSelectingPath,
              ),

              const SizedBox(height: 15),

              // App Storage Option
              _buildStorageOption(
                icon: Icons.folder,
                title: 'App Storage',
                subtitle: 'Save to TapMate downloads folder',
                color: AppColors.secondary,
                onTap: _handleAppStorage,
                isLoading: false,
              ),

              const SizedBox(height: 20),

              // Cancel Button
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: _isSelectingPath ? null : () => Navigator.pop(context),
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStorageOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback? onTap,
    required bool isLoading,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withOpacity(0.2),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: color,
                size: 24,
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
                      color: AppColors.accent,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            if (isLoading)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              )
            else
              Icon(
                Icons.arrow_forward_ios,
                color: color,
                size: 18,
              ),
          ],
        ),
      ),
    );
  }
}

