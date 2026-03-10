// lib/models/post_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class PostModel {
  final String id;
  final String userId;
  final String userName;
  final String? userProfilePic;
  final String caption;
  final String thumbnailUrl;
  final String? videoUrl;
  final DateTime createdAt;
  final int likes;
  final int comments;
  final bool isVideo;

  PostModel({
    required this.id,
    required this.userId,
    required this.userName,
    this.userProfilePic,
    required this.caption,
    required this.thumbnailUrl,
    this.videoUrl,
    required this.createdAt,
    this.likes = 0,
    this.comments = 0,
    this.isVideo = false,
  });

  factory PostModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return PostModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? '',
      userProfilePic: data['userProfilePic'],
      caption: data['caption'] ?? '',
      thumbnailUrl: data['thumbnailUrl'] ?? '',
      videoUrl: data['videoUrl'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      likes: data['likes'] ?? 0,
      comments: data['comments'] ?? 0,
      isVideo: data['isVideo'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'userProfilePic': userProfilePic,
      'caption': caption,
      'thumbnailUrl': thumbnailUrl,
      'videoUrl': videoUrl,
      'createdAt': FieldValue.serverTimestamp(),
      'likes': likes,
      'comments': comments,
      'isVideo': isVideo,
    };
  }
}