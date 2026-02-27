// lib/services/follow_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FollowService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Follow a user
  Future<void> followUser(String targetUserId) async {
    User? currentUser = _auth.currentUser;
    if (currentUser == null) throw Exception('Not logged in');

    final batch = _firestore.batch();

    // Add to current user's following
    DocumentReference followingRef = _firestore
        .collection('users')
        .doc(currentUser.uid)
        .collection('following')
        .doc(targetUserId);

    batch.set(followingRef, {
      'followedAt': FieldValue.serverTimestamp(),
    });

    // Add to target user's followers
    DocumentReference followersRef = _firestore
        .collection('users')
        .doc(targetUserId)
        .collection('followers')
        .doc(currentUser.uid);

    batch.set(followersRef, {
      'followedAt': FieldValue.serverTimestamp(),
    });

    // Update counts
    batch.update(
      _firestore.collection('users').doc(currentUser.uid),
      {'following_count': FieldValue.increment(1)},
    );

    batch.update(
      _firestore.collection('users').doc(targetUserId),
      {'followers_count': FieldValue.increment(1)},
    );

    await batch.commit();
  }

  // Unfollow a user
  Future<void> unfollowUser(String targetUserId) async {
    User? currentUser = _auth.currentUser;
    if (currentUser == null) throw Exception('Not logged in');

    final batch = _firestore.batch();

    // Remove from following
    batch.delete(
      _firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('following')
          .doc(targetUserId),
    );

    // Remove from followers
    batch.delete(
      _firestore
          .collection('users')
          .doc(targetUserId)
          .collection('followers')
          .doc(currentUser.uid),
    );

    // Update counts
    batch.update(
      _firestore.collection('users').doc(currentUser.uid),
      {'following_count': FieldValue.increment(-1)},
    );

    batch.update(
      _firestore.collection('users').doc(targetUserId),
      {'followers_count': FieldValue.increment(-1)},
    );

    await batch.commit();
  }

  // Check if following
  Future<bool> isFollowing(String targetUserId) async {
    User? currentUser = _auth.currentUser;
    if (currentUser == null) return false;

    DocumentSnapshot doc = await _firestore
        .collection('users')
        .doc(currentUser.uid)
        .collection('following')
        .doc(targetUserId)
        .get();

    return doc.exists;
  }
}