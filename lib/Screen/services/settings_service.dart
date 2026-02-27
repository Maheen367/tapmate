// lib/services/settings_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';

class SettingsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // 1. GET USER SETTINGS
  Stream<UserModel?> getUserSettings() {
    User? currentUser = _auth.currentUser;
    if (currentUser == null) return Stream.value(null);

    return _firestore
        .collection('users')
        .doc(currentUser.uid)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return null;
      return UserModel.fromFirestore(doc);
    });
  }

  // 2. UPDATE USER SETTINGS
  Future<void> updateUserSettings(Map<String, dynamic> updates) async {
    User? currentUser = _auth.currentUser;
    if (currentUser == null) throw Exception('No user logged in');

    try {
      updates['updatedAt'] = FieldValue.serverTimestamp();
      await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .update(updates);
    } catch (e) {
      print('Error updating settings: $e');
      rethrow;
    }
  }

  // 3. TOGGLE PRIVATE ACCOUNT
  Future<void> togglePrivateAccount(bool isPrivate) async {
    await updateUserSettings({'isPrivate': isPrivate});

    // Update follow requests status in Firebase
    if (isPrivate) {
      // Logic for private account
    }
  }

  // 4. GET STORAGE USAGE
  Future<Map<String, double>> getStorageUsage() async {
    User? currentUser = _auth.currentUser;
    if (currentUser == null) throw Exception('No user logged in');

    try {
      // Get user's videos
      QuerySnapshot videos = await _firestore
          .collection('videos')
          .where('userId', isEqualTo: currentUser.uid)
          .get();

      double videosSize = 0.0;
      for (var doc in videos.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        videosSize += (data['size'] ?? 0.0).toDouble();
      }

      // Get cache size from local storage
      double cacheSize = 0.2; // Example: 0.2 GB

      return {
        'videos': videosSize,
        'cache': cacheSize,
        'total': videosSize + cacheSize,
      };
    } catch (e) {
      print('Error getting storage usage: $e');
      rethrow;
    }
  }

  // 5. PERFORM BACKUP
  Future<void> performBackup() async {
    User? currentUser = _auth.currentUser;
    if (currentUser == null) throw Exception('No user logged in');

    try {
      // Get user's videos
      QuerySnapshot videos = await _firestore
          .collection('videos')
          .where('userId', isEqualTo: currentUser.uid)
          .get();

      // Create backup record
      await _firestore.collection('backups').add({
        'userId': currentUser.uid,
        'timestamp': FieldValue.serverTimestamp(),
        'videosCount': videos.docs.length,
        'status': 'completed',
      });

      // Update last backup time
      await updateUserSettings({
        'lastBackup': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error performing backup: $e');
      rethrow;
    }
  }

  // 6. CLEAR CACHE
  Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    // Update storage usage in Firebase
    User? currentUser = _auth.currentUser;
    if (currentUser != null) {
      await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .update({
        'storageUsed': FieldValue.increment(-0.2), // Reduce 0.2 GB
      });
    }
  }

  // 7. GET FOLLOW REQUESTS
  Stream<List<Map<String, dynamic>>> getFollowRequests() {
    User? currentUser = _auth.currentUser;
    if (currentUser == null) return Stream.value([]);

    return _firestore
        .collection('followRequests')
        .where('toUserId', isEqualTo: currentUser.uid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .asyncMap((snapshot) async {
      List<Map<String, dynamic>> requests = [];

      for (var doc in snapshot.docs) {
        Map<String, dynamic> data = doc.data();

        // Get requester info
        DocumentSnapshot userDoc = await _firestore
            .collection('users')
            .doc(data['fromUserId'])
            .get();

        Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>? ?? {};

        requests.add({
          'id': doc.id,
          'userId': data['fromUserId'],
          'fullName': userData['fullName'] ?? 'Unknown',
          'username': userData['username'] ?? '',
          'avatar': userData['profilePicUrl'] ?? '👤',
          'requestedAt': data['createdAt'],
        });
      }

      return requests;
    });
  }

  // 8. ACCEPT FOLLOW REQUEST
  Future<void> acceptFollowRequest(String requestId, String fromUserId) async {
    User? currentUser = _auth.currentUser;
    if (currentUser == null) return;

    try {
      WriteBatch batch = _firestore.batch();

      // Update request status
      DocumentReference requestRef = _firestore
          .collection('followRequests')
          .doc(requestId);
      batch.update(requestRef, {'status': 'accepted'});

      // Add to followers
      DocumentReference userRef = _firestore
          .collection('users')
          .doc(currentUser.uid);
      batch.update(userRef, {
        'followers': FieldValue.arrayUnion([fromUserId])
      });

      // Add to following of requester
      DocumentReference fromUserRef = _firestore
          .collection('users')
          .doc(fromUserId);
      batch.update(fromUserRef, {
        'following': FieldValue.arrayUnion([currentUser.uid])
      });

      await batch.commit();
    } catch (e) {
      print('Error accepting follow request: $e');
      rethrow;
    }
  }

  // 9. REJECT FOLLOW REQUEST
  Future<void> rejectFollowRequest(String requestId) async {
    try {
      await _firestore
          .collection('followRequests')
          .doc(requestId)
          .update({'status': 'rejected'});
    } catch (e) {
      print('Error rejecting follow request: $e');
      rethrow;
    }
  }

  // ==================== SUPPORT & ABOUT METHODS ====================
  // 10. GET FAQs FROM FIREBASE
  Stream<List<Map<String, dynamic>>> getFAQs() {
    return _firestore
        .collection('faqs')
        .orderBy('order', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data();
        return {
          'id': doc.id,
          'question': data['question'] ?? 'No question',
          'answer': data['answer'] ?? 'No answer',
          'category': data['category'] ?? 'general',
          'order': data['order'] ?? 0,
        };
      }).toList();
    });
  }

  // 11. SUBMIT BUG REPORT TO FIREBASE
  Future<void> submitBugReport({
    required String subject,
    required String description,
  }) async {
    User? currentUser = _auth.currentUser;
    if (currentUser == null) throw Exception('No user logged in');

    try {
      await _firestore.collection('bugReports').add({
        'userId': currentUser.uid,
        'userEmail': currentUser.email ?? 'No email',
        'userName': currentUser.displayName ?? 'Unknown',
        'subject': subject,
        'description': description,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'pending', // pending, inProgress, resolved, rejected
        'deviceInfo': {
          'platform': 'Android', // ya iOS
          'version': '1.0.0',
        },
      });

      // Optional: Send email to developer via Cloud Function
      // await _callCloudFunction('sendBugReportEmail', data: {...});
    } catch (e) {
      print('Error submitting bug report: $e');
      rethrow;
    }
  }

  // 12. GET APP INFO FROM FIREBASE
  Stream<Map<String, dynamic>> getAppInfo() {
    return _firestore
        .collection('appInfo')
        .doc('about')
        .snapshots()
        .map((doc) {
      if (!doc.exists) {
        return {
          'version': '1.0.0',
          'description': 'TapMate - Your all-in-one video downloader and social platform.',
          'developer': 'TapMate Team',
          'contactEmail': 'support@tapmate.com',
          'website': 'www.tapmate.com',
          'showAnnouncement': false,
          'announcement': '',
          'privacyPolicy': '''
Privacy Policy for TapMate

Last updated: ${DateTime.now().year}

Your privacy is important to us. This policy explains how we collect, use, and protect your information.

1. Information We Collect
   - Account information (name, email, profile)
   - Usage data and preferences
   - Videos you download or share

2. How We Use Your Information
   - To provide and improve our services
   - To personalize your experience
   - To communicate with you

3. Data Security
   We implement security measures to protect your data.

For full privacy policy, visit our website.
          ''',
        };
      }
      return doc.data() as Map<String, dynamic>;
    });
  }

  // 13. GET LATEST APP VERSION
  Future<String> getLatestVersion() async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection('appInfo')
          .doc('version')
          .get();

      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        return data['latestVersion'] ?? '1.0.0';
      }
      return '1.0.0';
    } catch (e) {
      print('Error getting latest version: $e');
      return '1.0.0';
    }
  }

  // 14. SUBMIT SUPPORT REQUEST
  Future<void> submitSupportRequest({
    required String email,
    required String message,
  }) async {
    User? currentUser = _auth.currentUser;

    try {
      await _firestore.collection('supportRequests').add({
        'userId': currentUser?.uid ?? 'guest',
        'userEmail': email,
        'userName': currentUser?.displayName ?? 'Guest User',
        'message': message,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'pending',
      });
    } catch (e) {
      print('Error submitting support request: $e');
      rethrow;
    }
  }

  // 15. GET CONTACT INFO
  Future<Map<String, String>> getContactInfo() async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection('appInfo')
          .doc('contact')
          .get();

      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        return {
          'email': data['email'] ?? 'support@tapmate.com',
          'phone': data['phone'] ?? '+1 234 567 890',
          'address': data['address'] ?? '123 TapMate Street, Digital City',
        };
      }
      return {
        'email': 'support@tapmate.com',
        'phone': '+1 234 567 890',
        'address': '123 TapMate Street, Digital City',
      };
    } catch (e) {
      print('Error getting contact info: $e');
      return {
        'email': 'support@tapmate.com',
        'phone': '+1 234 567 890',
        'address': '123 TapMate Street, Digital City',
      };
    }
  }
}