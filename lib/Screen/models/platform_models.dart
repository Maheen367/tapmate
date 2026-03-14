// lib/Screen/models/platform_models.dart

enum DownloadStatus {
  downloading,
  paused,
  completed,
  failed,
  cancelled,
}

class PlatformSession {
  final String platformId;
  final String accessToken;
  final String refreshToken;
  final String userId;
  final String userName;
  final DateTime expiresAt;
  final Map<String, dynamic>? userData;

  PlatformSession({
    required this.platformId,
    required this.accessToken,
    required this.refreshToken,
    required this.userId,
    required this.userName,
    required this.expiresAt,
    this.userData,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  Map<String, dynamic> toJson() => {
    'platformId': platformId,
    'accessToken': accessToken,
    'refreshToken': refreshToken,
    'userId': userId,
    'userName': userName,
    'expiresAt': expiresAt.toIso8601String(),
    'userData': userData,
  };

  factory PlatformSession.fromJson(Map<String, dynamic> json) => PlatformSession(
    platformId: json['platformId'],
    accessToken: json['accessToken'],
    refreshToken: json['refreshToken'],
    userId: json['userId'],
    userName: json['userName'],
    expiresAt: DateTime.parse(json['expiresAt']),
    userData: json['userData'],
  );
}

class DownloadProgress {
  final String id;
  final String platformId;
  final String title;
  final String format;
  final String quality;
  DownloadStatus status;
  double progress;
  double speed;
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