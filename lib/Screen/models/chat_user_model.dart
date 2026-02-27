// lib/models/chat_user_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class ChatUserModel {
  final String id;
  final String name;
  final String username;
  final String? avatar;
  final String? profilePic;
  final bool isOnline;
  final DateTime? lastSeen;
  final String lastMessage;
  final DateTime? lastMessageTime;
  final int unreadCount;

  ChatUserModel({
    required this.id,
    required this.name,
    required this.username,
    this.avatar,
    this.profilePic,
    this.isOnline = false,
    this.lastSeen,
    this.lastMessage = '',
    this.lastMessageTime,
    this.unreadCount = 0,
  });

  factory ChatUserModel.fromFirestore(DocumentSnapshot doc, {
    String lastMessage = '',
    DateTime? lastMessageTime,
    int unreadCount = 0,
  }) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    return ChatUserModel(
      id: doc.id,
      name: data['name'] ?? 'Unknown',
      username: data['username'] ?? '',
      avatar: data['avatar'] ?? data['profilePic'],
      profilePic: data['profilePic'],
      isOnline: data['isOnline'] ?? false,
      lastSeen: (data['lastSeen'] as Timestamp?)?.toDate(),
      lastMessage: lastMessage,
      lastMessageTime: lastMessageTime,
      unreadCount: unreadCount,
    );
  }
}