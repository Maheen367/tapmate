// lib/services/search_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class SearchService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // 1. SEARCH USERS by name or username
  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    if (query.trim().isEmpty) return [];

    try {
      String searchQuery = query.toLowerCase().trim();

      // Search by username (exact match starts with)
      QuerySnapshot usernameSnapshot = await _firestore
          .collection('users')
          .where('username', isGreaterThanOrEqualTo: searchQuery)
          .where('username', isLessThanOrEqualTo: searchQuery + '\uf8ff')
          .limit(20)
          .get();

      // Search by name
      QuerySnapshot nameSnapshot = await _firestore
          .collection('users')
          .where('name_lowercase', isGreaterThanOrEqualTo: searchQuery)
          .where('name_lowercase', isLessThanOrEqualTo: searchQuery + '\uf8ff')
          .limit(20)
          .get();

      // Combine results (remove duplicates)
      Set<String> userIds = {};
      List<Map<String, dynamic>> results = [];

      // Add username matches
      for (var doc in usernameSnapshot.docs) {
        if (!userIds.contains(doc.id)) {
          userIds.add(doc.id);
          Map<String, dynamic> userData = doc.data() as Map<String, dynamic>;
          results.add({
            'id': doc.id,
            ...userData,
            'type': 'user',
            'searchRelevance': 'username',
          });
        }
      }

      // Add name matches
      for (var doc in nameSnapshot.docs) {
        if (!userIds.contains(doc.id)) {
          userIds.add(doc.id);
          Map<String, dynamic> userData = doc.data() as Map<String, dynamic>;
          results.add({
            'id': doc.id,
            ...userData,
            'type': 'user',
            'searchRelevance': 'name',
          });
        }
      }

      return results;
    } catch (e) {
      print('Error searching users: $e');
      return [];
    }
  }

  // 2. SEARCH POSTS/VIDEOS
  Future<List<Map<String, dynamic>>> searchPosts(String query, {String? platform}) async {
    if (query.trim().isEmpty) return [];

    try {
      String searchQuery = query.toLowerCase().trim();

      // Build query
      Query postQuery = _firestore.collection('posts');

      // Apply platform filter
      if (platform != null && platform != 'All') {
        postQuery = postQuery.where('platform', isEqualTo: platform);
      }

      // Search in caption
      QuerySnapshot postSnapshot = await postQuery
          .where('caption_lowercase', isGreaterThanOrEqualTo: searchQuery)
          .where('caption_lowercase', isLessThanOrEqualTo: searchQuery + '\uf8ff')
          .orderBy('createdAt', descending: true)
          .limit(20)
          .get();

      // Get user details for each post
      List<Map<String, dynamic>> results = [];
      for (var doc in postSnapshot.docs) {
        Map<String, dynamic> postData = doc.data() as Map<String, dynamic>;

        // Get user info
        DocumentSnapshot userDoc = await _firestore
            .collection('users')
            .doc(postData['userId'])
            .get();

        Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>? ?? {};

        results.add({
          'id': doc.id,
          ...postData,
          'user_name': userData['name'] ?? 'Unknown',
          'user_username': userData['username'] ?? '',
          'user_profile_pic': userData['profilePic'] ?? userData['photoURL'] ?? '',
          'type': 'post',
        });
      }

      return results;
    } catch (e) {
      print('Error searching posts: $e');
      return [];
    }
  }

  // 3. GET TRENDING POSTS
  Future<List<Map<String, dynamic>>> getTrendingPosts() async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('posts')
          .orderBy('likes', descending: true)
          .limit(10)
          .get();

      List<Map<String, dynamic>> results = [];
      for (var doc in snapshot.docs) {
        Map<String, dynamic> postData = doc.data() as Map<String, dynamic>;

        DocumentSnapshot userDoc = await _firestore
            .collection('users')
            .doc(postData['userId'])
            .get();

        Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>? ?? {};

        results.add({
          'id': doc.id,
          ...postData,
          'user_name': userData['name'] ?? 'Unknown',
          'user_username': userData['username'] ?? '',
          'user_profile_pic': userData['profilePic'] ?? userData['photoURL'] ?? '',
          'type': 'post',
        });
      }

      return results;
    } catch (e) {
      print('Error getting trending posts: $e');
      return [];
    }
  }

  // 4. SAVE SEARCH HISTORY
  Future<void> saveSearchHistory(String query) async {
    try {
      User? user = _auth.currentUser;
      if (user == null) return;

      String userId = user.uid;

      // Check if this search already exists
      QuerySnapshot existing = await _firestore
          .collection('users')
          .doc(userId)
          .collection('searchHistory')
          .where('query', isEqualTo: query)
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty) {
        // Update existing search's timestamp
        await existing.docs.first.reference.update({
          'timestamp': FieldValue.serverTimestamp(),
        });
      } else {
        // Add new search history
        await _firestore
            .collection('users')
            .doc(userId)
            .collection('searchHistory')
            .add({
          'query': query,
          'timestamp': FieldValue.serverTimestamp(),
        });

        // Keep only last 20 searches
        QuerySnapshot oldSearches = await _firestore
            .collection('users')
            .doc(userId)
            .collection('searchHistory')
            .orderBy('timestamp', descending: true)
            .get();

        if (oldSearches.docs.length > 20) {
          // Delete oldest searches
          for (int i = 20; i < oldSearches.docs.length; i++) {
            await oldSearches.docs[i].reference.delete();
          }
        }
      }
    } catch (e) {
      print('Error saving search history: $e');
    }
  }

  // 5. GET USER SEARCH HISTORY
  Future<List<String>> getSearchHistory() async {
    try {
      User? user = _auth.currentUser;
      if (user == null) return [];

      QuerySnapshot snapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('searchHistory')
          .orderBy('timestamp', descending: true)
          .limit(10)
          .get();

      return snapshot.docs.map((doc) {
        return (doc.data() as Map<String, dynamic>)['query'] as String;
      }).toList();
    } catch (e) {
      print('Error getting search history: $e');
      return [];
    }
  }

  // 6. CLEAR SEARCH HISTORY
  Future<void> clearSearchHistory() async {
    try {
      User? user = _auth.currentUser;
      if (user == null) return;

      QuerySnapshot snapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('searchHistory')
          .get();

      for (var doc in snapshot.docs) {
        await doc.reference.delete();
      }
    } catch (e) {
      print('Error clearing search history: $e');
    }
  }

  // 7. DELETE SINGLE SEARCH ITEM
  Future<void> deleteSearchItem(String query) async {
    try {
      User? user = _auth.currentUser;
      if (user == null) return;

      QuerySnapshot snapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('searchHistory')
          .where('query', isEqualTo: query)
          .get();

      for (var doc in snapshot.docs) {
        await doc.reference.delete();
      }
    } catch (e) {
      print('Error deleting search item: $e');
    }
  }

  // 8. GET TRENDING SEARCHES (from analytics)
  Future<List<String>> getTrendingSearches() async {
    try {
      // You can implement this based on your needs
      // For now, return some default trending searches
      return [
        "Music Videos",
        "Gaming",
        "Cooking Tutorials",
        "Travel Vlogs",
        "Fitness",
        "Tech Reviews",
        "Comedy",
        "Education",
      ];
    } catch (e) {
      print('Error getting trending searches: $e');
      return [];
    }
  }

  // 9. GET CATEGORIES WITH COUNTS
  Future<List<Map<String, dynamic>>> getCategories() async {
    return [
      {'name': 'Music', 'icon': Icons.music_note, 'count': '1.2k'},
      {'name': 'Gaming', 'icon': Icons.sports_esports, 'count': '890k'},
      {'name': 'Education', 'icon': Icons.book, 'count': '650k'},
      {'name': 'Movies', 'icon': Icons.movie, 'count': '1.8k'},
      {'name': 'Fitness', 'icon': Icons.fitness_center, 'count': '540k'},
      {'name': 'Travel', 'icon': Icons.travel_explore, 'count': '720k'},
    ];
  }
}