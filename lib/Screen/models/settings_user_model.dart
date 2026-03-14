// Screen/models/settings_user_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String fullName;
  final String email;
  final String username;
  final String profilePicUrl;
  final String? bio;
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
  final int followersCount;
  final int followingCount;
  final int postsCount;
  final DateTime lastBackup;
  final double storageUsed;
  final double storageTotal;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final List<String> blockedUsers;

  UserModel({
    required this.uid,
    required this.fullName,
    required this.email,
    required this.username,
    required this.profilePicUrl,
    this.bio,
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
    this.followersCount = 0,
    this.followingCount = 0,
    this.postsCount = 0,
    required this.lastBackup,
    this.storageUsed = 0.0,
    this.storageTotal = 25.0,
    required this.createdAt,
    this.updatedAt,
    this.blockedUsers = const [],
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    return UserModel(
      uid: doc.id,
      fullName: data['fullName'] ?? data['name'] ?? 'No Name',
      email: data['email'] ?? 'No Email',
      username: data['username'] ?? 'username',
      profilePicUrl: data['profilePic'] ?? data['profilePicUrl'] ?? '',
      bio: data['bio'],
      isPrivate: data['isPrivateAccount'] ?? data['isPrivate'] ?? false,
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
      followersCount: (data['followers'] as List?)?.length ?? 0,
      followingCount: (data['following'] as List?)?.length ?? 0,
      postsCount: (data['posts'] as List?)?.length ?? 0,
      lastBackup: (data['lastBackup'] as Timestamp?)?.toDate() ?? DateTime.now(),
      storageUsed: (data['storageUsed'] ?? 0.0).toDouble(),
      storageTotal: (data['storageTotal'] ?? 25.0).toDouble(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      blockedUsers: List<String>.from(data['blockedUsers'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'fullName': fullName,
      'email': email,
      'username': username,
      'profilePic': profilePicUrl,
      'bio': bio,
      'isPrivateAccount': isPrivate,
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
      'updatedAt': FieldValue.serverTimestamp(),
      'blockedUsers': blockedUsers,
    };
  }
}