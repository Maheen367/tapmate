// lib/services/platform_downloader.dart
import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'platform_auth_service.dart';

class PlatformDownloader {
  static final PlatformDownloader _instance = PlatformDownloader._internal();
  factory PlatformDownloader() => _instance;
  PlatformDownloader._internal();

  // Current download progress
  final Map<String, DownloadProgress> _downloads = {};

  // Stream for download progress
  final _progressController = StreamController<DownloadProgress>.broadcast();
  Stream<DownloadProgress> get progressStream => _progressController.stream;

  // 📥 Download video from platform
  Future<DownloadResult> downloadVideo({
    required String platformId,
    required String videoUrl,
    required String videoTitle,
    required String format,
    required String quality,
    String? customPath,
  }) async {
    // Check permissions
    if (!await _checkStoragePermission()) {
      return DownloadResult(
        success: false,
        message: 'Storage permission denied',
      );
    }

    // Get auth token if needed
    String? token;
    if (_requiresAuth(platformId)) {
      token = await PlatformAuthService().getAuthToken(platformId);
      if (token == null) {
        return DownloadResult(
          success: false,
          message: 'Not authenticated to $platformId',
        );
      }
    }

    // Generate download ID
    final downloadId = '${platformId}_${DateTime.now().millisecondsSinceEpoch}';

    // Get download directory
    final downloadDir = await _getDownloadDirectory(platformId, customPath);
    if (!await downloadDir.exists()) {
      await downloadDir.create(recursive: true);
    }

    // Generate filename
    final filename = _generateFilename(videoTitle, format, quality);
    final filePath = '${downloadDir.path}/$filename';

    try {
      // Start download
      final progress = DownloadProgress(
        id: downloadId,
        platformId: platformId,
        title: videoTitle,
        format: format,
        quality: quality,
        status: DownloadStatus.downloading,
        progress: 0,
        speed: 0,
        downloadedBytes: 0,
        totalBytes: 0,
        filePath: filePath,
      );

      _downloads[downloadId] = progress;
      _progressController.add(progress);

      // TODO: Implement actual download based on platform
      // This is where you'd use platform-specific APIs

      // For YouTube: youtube_explode_dart
      // For Instagram: custom scraping with auth
      // For TikTok: tiktok_api

      // Simulate download for now
      return await _simulateDownload(downloadId, filePath);

    } catch (e) {
      return DownloadResult(
        success: false,
        message: 'Download failed: ${e.toString()}',
      );
    }
  }

  // 🎯 Simulate download (replace with real implementation)
  Future<DownloadResult> _simulateDownload(String downloadId, String filePath) async {
    final totalSteps = 100;
    for (int i = 0; i <= totalSteps; i++) {
      await Future.delayed(const Duration(milliseconds: 50));

      if (_downloads.containsKey(downloadId)) {
        final progress = _downloads[downloadId]!;
        progress.progress = i / totalSteps;
        progress.downloadedBytes = (i / totalSteps * 1024 * 1024 * 10).toInt(); // 10 MB total
        progress.totalBytes = 1024 * 1024 * 10;
        progress.speed = 2.5; // MB/s

        _progressController.add(progress);
      }
    }

    // Mark as completed
    if (_downloads.containsKey(downloadId)) {
      final progress = _downloads[downloadId]!;
      progress.status = DownloadStatus.completed;
      progress.progress = 1.0;
      _progressController.add(progress);
    }

    // Create dummy file
    final file = File(filePath);
    await file.writeAsString('Dummy video content for $downloadId');

    return DownloadResult(
      success: true,
      message: 'Download completed',
      filePath: filePath,
      fileSize: 1024 * 1024 * 10,
    );
  }

  // 🔐 Check if platform requires auth
  bool _requiresAuth(String platformId) {
    final authRequired = ['youtube', 'instagram', 'facebook', 'tiktok'];
    return authRequired.contains(platformId);
  }

  // 📁 Get download directory
  Future<Directory> _getDownloadDirectory(String platformId, String? customPath) async {
    if (customPath != null && customPath.isNotEmpty) {
      return Directory(customPath);
    }

    // Use app's download directory
    final appDir = await getApplicationDocumentsDirectory();
    return Directory('${appDir.path}/TapMate_Downloads/$platformId');
  }

  // 📝 Generate filename
  String _generateFilename(String title, String format, String quality) {
    final cleanTitle = title.replaceAll(RegExp(r'[^\w\s]'), '');
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return '${cleanTitle}_${quality}_$timestamp.$format';
  }

  // ✅ Check storage permission
  Future<bool> _checkStoragePermission() async {
    if (Platform.isAndroid) {
      final status = await Permission.storage.request();
      return status.isGranted;
    }
    return true; // iOS handles differently
  }

  // Pause download
  void pauseDownload(String downloadId) {
    if (_downloads.containsKey(downloadId)) {
      _downloads[downloadId]!.status = DownloadStatus.paused;
      _progressController.add(_downloads[downloadId]!);
    }
  }

  // Resume download
  void resumeDownload(String downloadId) {
    if (_downloads.containsKey(downloadId)) {
      _downloads[downloadId]!.status = DownloadStatus.downloading;
      _progressController.add(_downloads[downloadId]!);
      // TODO: Resume actual download
    }
  }

  // Cancel download
  void cancelDownload(String downloadId) {
    if (_downloads.containsKey(downloadId)) {
      _downloads[downloadId]!.status = DownloadStatus.cancelled;
      _progressController.add(_downloads[downloadId]!);
      _downloads.remove(downloadId);

      // Delete partial file
      final file = File(_downloads[downloadId]?.filePath ?? '');
      if (file.existsSync()) {
        file.deleteSync();
      }
    }
  }

  void dispose() {
    _progressController.close();
  }
}

// Models
class DownloadProgress {
  final String id;
  final String platformId;
  final String title;
  final String format;
  final String quality;
  DownloadStatus status;
  double progress;
  double speed; // MB/s
  int downloadedBytes;
  int totalBytes;
  final String filePath;

  DownloadProgress({
    required this.id,
    required this.platformId,
    required this.title,
    required this.format,
    required this.quality,
    required this.status,
    required this.progress,
    required this.speed,
    required this.downloadedBytes,
    required this.totalBytes,
    required this.filePath,
  });
}

enum DownloadStatus {
  downloading,
  paused,
  completed,
  failed,
  cancelled,
}

class DownloadResult {
  final bool success;
  final String message;
  final String? filePath;
  final int? fileSize;

  DownloadResult({
    required this.success,
    required this.message,
    this.filePath,
    this.fileSize,
  });
}