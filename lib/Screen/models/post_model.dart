// lib/models/post_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class PostModel {
  final String id;
  final String userId;
  final String caption;
  final String thumbnailUrl;
  final String? videoUrl;
  final String platform;
  final int likes;
  final int comments;
  final int shares;
  final bool isVideo;
  final String duration;
  final DateTime createdAt;
  final bool canDownload;

  PostModel({
    required this.id,
    required this.userId,
    required this.caption,
    required this.thumbnailUrl,
    this.videoUrl,
    required this.platform,
    this.likes = 0,
    this.comments = 0,
    this.shares = 0,
    this.isVideo = false,
    this.duration = '0:00',
    required this.createdAt,
    this.canDownload = true, required String caption_lowercase,
  });

  factory PostModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    return PostModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      caption: data['caption'] ?? '',
      caption_lowercase: (data['caption'] ?? '').toString().toLowerCase(),
      thumbnailUrl: data['thumbnailUrl'] ?? '',
      videoUrl: data['videoUrl'],
      platform: data['platform'] ?? 'Unknown',
      likes: data['likes'] ?? 0,
      comments: data['comments'] ?? 0,
      shares: data['shares'] ?? 0,
      isVideo: data['isVideo'] ?? false,
      duration: data['duration'] ?? '0:00',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      canDownload: data['canDownload'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'caption': caption,
      'caption_lowercase': caption.toLowerCase(),
      'thumbnailUrl': thumbnailUrl,
      'videoUrl': videoUrl,
      'platform': platform,
      'likes': likes,
      'comments': comments,
      'shares': shares,
      'isVideo': isVideo,
      'duration': duration,
      'createdAt': createdAt,
      'canDownload': canDownload,
    };
  }
}