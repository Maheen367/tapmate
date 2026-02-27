// lib/models/user_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String fullName;
  final String email;
  final String username;
  final String profilePicUrl;
  final bool isPrivate;
  final bool isOnline;
  final bool notificationsEnabled;
  final bool darkMode;
  final bool dataSaver;
  final String language;
  final String downloadQuality;
  final String storageLocation;
  final bool showOnlineStatus;
  final bool allowTagging;
  final bool allowComments;
  final bool showActivity;
  final DateTime lastBackup;
  final double storageUsed;
  final double storageTotal;
  final DateTime createdAt;
  final DateTime? updatedAt;

  UserModel({
    required this.uid,
    required this.fullName,
    required this.email,
    required this.username,
    required this.profilePicUrl,
    this.isPrivate = false,
    this.isOnline = false,
    this.notificationsEnabled = true,
    this.darkMode = false,
    this.dataSaver = false,
    this.language = 'English',
    this.downloadQuality = '720p',
    this.storageLocation = 'Phone Storage',
    this.showOnlineStatus = true,
    this.allowTagging = true,
    this.allowComments = true,
    this.showActivity = true,
    required this.lastBackup,
    this.storageUsed = 0.0,
    this.storageTotal = 25.0,
    required this.createdAt,
    this.updatedAt,
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      uid: doc.id,
      fullName: data['fullName'] ?? '',
      email: data['email'] ?? '',
      username: data['username'] ?? '',
      profilePicUrl: data['profilePicUrl'] ?? '',
      isPrivate: data['isPrivate'] ?? false,
      isOnline: data['isOnline'] ?? false,
      notificationsEnabled: data['notificationsEnabled'] ?? true,
      darkMode: data['darkMode'] ?? false,
      dataSaver: data['dataSaver'] ?? false,
      language: data['language'] ?? 'English',
      downloadQuality: data['downloadQuality'] ?? '720p',
      storageLocation: data['storageLocation'] ?? 'Phone Storage',
      showOnlineStatus: data['showOnlineStatus'] ?? true,
      allowTagging: data['allowTagging'] ?? true,
      allowComments: data['allowComments'] ?? true,
      showActivity: data['showActivity'] ?? true,
      lastBackup: (data['lastBackup'] as Timestamp?)?.toDate() ?? DateTime.now(),
      storageUsed: (data['storageUsed'] ?? 0.0).toDouble(),
      storageTotal: (data['storageTotal'] ?? 25.0).toDouble(),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'fullName': fullName,
      'email': email,
      'username': username,
      'profilePicUrl': profilePicUrl,
      'isPrivate': isPrivate,
      'isOnline': isOnline,
      'notificationsEnabled': notificationsEnabled,
      'darkMode': darkMode,
      'dataSaver': dataSaver,
      'language': language,
      'downloadQuality': downloadQuality,
      'storageLocation': storageLocation,
      'showOnlineStatus': showOnlineStatus,
      'allowTagging': allowTagging,
      'allowComments': allowComments,
      'showActivity': showActivity,
      'lastBackup': Timestamp.fromDate(lastBackup),
      'storageUsed': storageUsed,
      'storageTotal': storageTotal,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : FieldValue.serverTimestamp(),
    };
  }
}