// lib/services/settings_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';


import '../models/settings_user_model.dart';

class SettingsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;

  Stream<UserModel?> getUserSettingsStream() {
    if (currentUser == null) return Stream.value(null);
    return _firestore
        .collection('users')
        .doc(currentUser!.uid)
        .snapshots()
        .map((doc) => doc.exists ? UserModel.fromFirestore(doc) : null);
  }

  Future<UserModel?> getUserSettings() async {
    if (currentUser == null) return null;
    try {
      final doc = await _firestore.collection('users').doc(currentUser!.uid).get();
      return doc.exists ? UserModel.fromFirestore(doc) : null;
    } catch (e) {
      print('Error getting user settings: $e');
      return null;
    }
  }

  Future<void> updateUserSettings(Map<String, dynamic> updates) async {
    if (currentUser == null) throw Exception('No user logged in');
    try {
      updates['updatedAt'] = FieldValue.serverTimestamp();
      await _firestore.collection('users').doc(currentUser!.uid).update(updates);
    } catch (e) {
      print('Error updating settings: $e');
      rethrow;
    }
  }

  // ==================== BLOCKED USERS ====================
  Stream<List<Map<String, dynamic>>> getBlockedUsersStream() {
    if (currentUser == null) return Stream.value([]);

    return _firestore
        .collection('users')
        .doc(currentUser!.uid)
        .snapshots()
        .asyncMap((doc) async {
      if (!doc.exists) return [];

      final data = doc.data() as Map<String, dynamic>;
      final blockedIds = List<String>.from(data['blockedUsers'] ?? []);
      if (blockedIds.isEmpty) return [];

      List<Map<String, dynamic>> blockedUsers = [];
      for (String userId in blockedIds) {
        try {
          final userDoc = await _firestore.collection('users').doc(userId).get();
          if (userDoc.exists) {
            final userData = userDoc.data() as Map<String, dynamic>;
            blockedUsers.add({
              'uid': userId,
              'fullName': userData['fullName'] ?? 'Unknown',
              'username': userData['username'] ?? '',
              'profilePic': userData['profilePic'] ?? '',
              'blockedAt': data['blockedAt_$userId'] ?? Timestamp.now(),
            });
          }
        } catch (e) {
          print('Error fetching blocked user $userId: $e');
        }
      }
      return blockedUsers;
    });
  }

  // ==================== COMPLETE BLOCK USER ====================
  Future<void> blockUser(String userId) async {
    if (currentUser == null) throw Exception('No user logged in');

    try {
      final currentUserRef = _firestore.collection('users').doc(currentUser!.uid);
      final otherUserRef = _firestore.collection('users').doc(userId);

      await _firestore.runTransaction((transaction) async {
        final currentUserDoc = await transaction.get(currentUserRef);
        final otherUserDoc = await transaction.get(otherUserRef);

        if (!currentUserDoc.exists || !otherUserDoc.exists) return;

        final currentUserData = currentUserDoc.data() as Map<String, dynamic>;

        List<String> blocked = List<String>.from(currentUserData['blockedUsers'] ?? []);

        if (!blocked.contains(userId)) {
          blocked.add(userId);

          // Update blocked users list
          transaction.update(currentUserRef, {
            'blockedUsers': blocked,
            'blockedAt_$userId': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });

          // Remove from followers/following
          transaction.update(currentUserRef, {
            'followers': FieldValue.arrayRemove([userId]),
            'following': FieldValue.arrayRemove([userId]),
          });

          // Remove from other user's followers/following
          transaction.update(otherUserRef, {
            'followers': FieldValue.arrayRemove([currentUser!.uid]),
            'following': FieldValue.arrayRemove([currentUser!.uid]),
          });
        }
      });

      // Delete all chat messages between users
      await _deleteChatMessages(userId);

      print('✅ User $userId blocked successfully');

    } catch (e) {
      print('❌ Error blocking user: $e');
      rethrow;
    }
  }

  // ==================== DELETE CHAT MESSAGES ====================
  Future<void> _deleteChatMessages(String otherUserId) async {
    if (currentUser == null) return;

    try {
      // Find chat between these two users
      QuerySnapshot chats = await _firestore
          .collection('chats')
          .where('participants', arrayContains: currentUser!.uid)
          .get();

      for (var chatDoc in chats.docs) {
        final chatData = chatDoc.data() as Map<String, dynamic>;
        final participants = List<String>.from(chatData['participants'] ?? []);

        // Agar chat sirf in dono users ke beech hai
        if (participants.contains(otherUserId) && participants.length == 2) {
          // Delete all messages in this chat
          QuerySnapshot messages = await chatDoc.reference
              .collection('messages')
              .get();

          WriteBatch batch = _firestore.batch();
          for (var msg in messages.docs) {
            batch.delete(msg.reference);
          }
          await batch.commit();

          // Update chat to show it's blocked
          await chatDoc.reference.update({
            'isBlocked': true,
            'blockedBy': currentUser!.uid,
            'blockedAt': FieldValue.serverTimestamp(),
          });
        }
      }

    } catch (e) {
      print('Error deleting messages: $e');
    }
  }

  Future<void> unblockUser(String userId) async {
    if (currentUser == null) throw Exception('No user logged in');
    try {
      final userRef = _firestore.collection('users').doc(currentUser!.uid);
      await _firestore.runTransaction((transaction) async {
        final doc = await transaction.get(userRef);
        if (!doc.exists) return;
        final data = doc.data() as Map<String, dynamic>;
        List<String> blocked = List<String>.from(data['blockedUsers'] ?? []);
        if (blocked.contains(userId)) {
          blocked.remove(userId);
          transaction.update(userRef, {
            'blockedUsers': blocked,
            'updatedAt': FieldValue.serverTimestamp(),
          });
          transaction.update(userRef, {'blockedAt_$userId': FieldValue.delete()});
        }
      });
    } catch (e) {
      print('Error unblocking user: $e');
      rethrow;
    }
  }

  // ==================== STORAGE USAGE ====================
  Future<Map<String, double>> getStorageUsage() async {
    if (currentUser == null) throw Exception('No user logged in');
    try {
      QuerySnapshot videos = await _firestore
          .collection('videos')
          .where('userId', isEqualTo: currentUser!.uid)
          .get();

      double videosSize = 0.0;
      for (var doc in videos.docs) {
        final data = doc.data() as Map<String, dynamic>;
        videosSize += (data['fileSize'] ?? 0.0).toDouble();
      }

      final prefs = await SharedPreferences.getInstance();
      double cacheSize = prefs.getDouble('cacheSize') ?? 0.2;

      videosSize = videosSize / (1024 * 1024 * 1024);
      return {'videos': videosSize, 'cache': cacheSize, 'total': videosSize + cacheSize};
    } catch (e) {
      return {'videos': 0.0, 'cache': 0.2, 'total': 0.2};
    }
  }

  // ==================== BACKUP ====================
  Future<void> performBackup() async {
    if (currentUser == null) throw Exception('No user logged in');
    try {
      QuerySnapshot videos = await _firestore
          .collection('videos')
          .where('userId', isEqualTo: currentUser!.uid)
          .get();

      double totalSize = 0.0;
      for (var video in videos.docs) {
        final data = video.data() as Map<String, dynamic>;
        totalSize += (data['fileSize'] ?? 0.0).toDouble();
      }

      await _firestore.collection('backups').add({
        'userId': currentUser!.uid,
        'timestamp': FieldValue.serverTimestamp(),
        'videosCount': videos.docs.length,
        'status': 'completed',
      });

      await updateUserSettings({
        'lastBackup': FieldValue.serverTimestamp(),
        'storageUsed': totalSize / (1024 * 1024 * 1024),
      });
    } catch (e) {
      print('Error performing backup: $e');
      rethrow;
    }
  }

  // ==================== CLEAR CACHE ====================
  Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      await prefs.setDouble('cacheSize', 0.0);
    } catch (e) {
      print('Error clearing cache: $e');
      rethrow;
    }
  }

  // ==================== FOLLOW REQUESTS ====================
  Stream<List<Map<String, dynamic>>> getFollowRequests() {
    if (currentUser == null) return Stream.value([]);

    return _firestore
        .collection('followRequests')
        .where('toUserId', isEqualTo: currentUser!.uid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .asyncMap((snapshot) async {
      List<Map<String, dynamic>> requests = [];

      for (var doc in snapshot.docs) {
        Map<String, dynamic> data = doc.data();
        final userDoc = await _firestore.collection('users').doc(data['fromUserId']).get();
        Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>? ?? {};

        requests.add({
          'id': doc.id,
          'userId': data['fromUserId'],
          'fullName': userData['fullName'] ?? 'Unknown',
          'username': userData['username'] ?? '',
          'profilePic': userData['profilePic'] ?? '',
          'requestedAt': data['createdAt'],
        });
      }
      return requests;
    });
  }

  Future<void> acceptFollowRequest(String requestId, String fromUserId) async {
    if (currentUser == null) return;
    try {
      WriteBatch batch = _firestore.batch();
      batch.update(_firestore.collection('followRequests').doc(requestId), {'status': 'accepted'});
      batch.update(_firestore.collection('users').doc(currentUser!.uid), {
        'followers': FieldValue.arrayUnion([fromUserId])
      });
      batch.update(_firestore.collection('users').doc(fromUserId), {
        'following': FieldValue.arrayUnion([currentUser!.uid])
      });
      await batch.commit();
    } catch (e) {
      print('Error accepting follow request: $e');
      rethrow;
    }
  }

  Future<void> rejectFollowRequest(String requestId) async {
    try {
      await _firestore.collection('followRequests').doc(requestId).update({'status': 'rejected'});
    } catch (e) {
      print('Error rejecting follow request: $e');
      rethrow;
    }
  }

  // ==================== SUPPORT & ABOUT ====================
  Stream<List<Map<String, dynamic>>> getFAQs() {
    return _firestore.collection('faqs').orderBy('order').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data();
        return {
          'id': doc.id,
          'question': data['question'] ?? 'No question',
          'answer': data['answer'] ?? 'No answer',
          'category': data['category'] ?? 'general',
        };
      }).toList();
    });
  }

  Future<void> submitBugReport({required String subject, required String description}) async {
    if (currentUser == null) throw Exception('No user logged in');
    try {
      await _firestore.collection('bugReports').add({
        'userId': currentUser!.uid,
        'userEmail': currentUser!.email ?? 'No email',
        'subject': subject,
        'description': description,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'pending',
      });
    } catch (e) {
      print('Error submitting bug report: $e');
      rethrow;
    }
  }

  Future<void> submitSupportRequest({required String email, required String message}) async {
    try {
      await _firestore.collection('supportRequests').add({
        'userId': currentUser?.uid ?? 'guest',
        'userEmail': email,
        'message': message,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'pending',
      });
    } catch (e) {
      print('Error submitting support request: $e');
      rethrow;
    }
  }

  Stream<Map<String, dynamic>> getAppInfo() {
    return _firestore.collection('appInfo').doc('about').snapshots().map((doc) {
      if (!doc.exists) {
        return {
          'version': '1.0.0',
          'description': 'TapMate - Video downloader and social platform.',
          'developer': 'TapMate Team',
          'contactEmail': 'support@tapmate.com',
          'website': 'www.tapmate.com',
          'showAnnouncement': false,
        };
      }
      return doc.data() as Map<String, dynamic>;
    });
  }

  Future<void> togglePrivateAccount(bool isPrivate) async {
    await updateUserSettings({'isPrivateAccount': isPrivate});
  }
}