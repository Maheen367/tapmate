// lib/services/search_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class SearchService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Cache for user data to reduce Firestore reads
  final Map<String, Map<String, dynamic>> _userCache = {};
  final Map<String, DateTime> _cacheTimestamps = {};
  final Duration _cacheDuration = const Duration(minutes: 5);

  // 1. SEARCH USERS by name or username
  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    if (query.trim().isEmpty) return [];

    try {
      String searchQuery = query.toLowerCase().trim();

      // Search by username
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

      // Track search analytics
      await _trackSearch(query, 'user');

      return results;
    } catch (e) {
      print('Error searching users: $e');
      return [];
    }
  }

  // 2. SEARCH POSTS/VIDEOS with pagination support
  Future<List<Map<String, dynamic>>> searchPosts(String query, {String? platform}) async {
    if (query.trim().isEmpty) return [];

    try {
      String searchQuery = query.toLowerCase().trim();

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

      // Get user details for each post (with caching)
      List<Map<String, dynamic>> results = [];
      for (var doc in postSnapshot.docs) {
        Map<String, dynamic> postData = doc.data() as Map<String, dynamic>;

        // Get user info from cache or firestore
        Map<String, dynamic> userData = await _getCachedUserData(postData['userId']);

        results.add({
          'id': doc.id,
          ...postData,
          'user_name': userData['name'] ?? 'Unknown',
          'user_username': userData['username'] ?? '',
          'user_profile_pic': userData['profilePic'] ?? userData['photoURL'] ?? '',
          'type': 'post',
        });
      }

      // Track search analytics
      await _trackSearch(query, 'post', platform: platform);

      return results;
    } catch (e) {
      print('Error searching posts: $e');
      return [];
    }
  }

  // 3. GET TRENDING POSTS (improved algorithm)
  Future<List<Map<String, dynamic>>> getTrendingPosts() async {
    try {
      // Get posts from last 7 days
      DateTime weekAgo = DateTime.now().subtract(const Duration(days: 7));

      QuerySnapshot snapshot = await _firestore
          .collection('posts')
          .where('createdAt', isGreaterThan: Timestamp.fromDate(weekAgo))
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get();

      List<Map<String, dynamic>> posts = [];

      for (var doc in snapshot.docs) {
        Map<String, dynamic> postData = doc.data() as Map<String, dynamic>;

        // Get user data from cache
        Map<String, dynamic> userData = await _getCachedUserData(postData['userId']);

        // Calculate trending score
        int likes = postData['likes'] ?? 0;
        int comments = postData['comments'] ?? 0;
        int shares = postData['shares'] ?? 0;

        Timestamp? createdAt = postData['createdAt'] as Timestamp?;
        double recencyBonus = 0;
        if (createdAt != null) {
          int hoursAgo = DateTime.now().difference(createdAt.toDate()).inHours;
          recencyBonus = (24 / (hoursAgo + 1)) * 10; // More recent = higher score
        }

        double trendingScore = likes + (comments * 2) + (shares * 3) + recencyBonus;

        posts.add({
          'id': doc.id,
          ...postData,
          'user_name': userData['name'] ?? 'Unknown',
          'user_username': userData['username'] ?? '',
          'user_profile_pic': userData['profilePic'] ?? userData['photoURL'] ?? '',
          'trendingScore': trendingScore,
          'type': 'post',
        });
      }

      // Sort by trending score and return top 10
      posts.sort((a, b) => b['trendingScore'].compareTo(a['trendingScore']));
      return posts.take(10).toList();

    } catch (e) {
      print('Error getting trending posts: $e');
      return [];
    }
  }

  // 4. GET TRENDING SEARCHES (from analytics)
  Future<List<String>> getTrendingSearches() async {
    try {
      // Get searches from last 24 hours
      DateTime yesterday = DateTime.now().subtract(const Duration(days: 1));

      QuerySnapshot snapshot = await _firestore
          .collection('search_analytics')
          .where('timestamp', isGreaterThan: Timestamp.fromDate(yesterday))
          .orderBy('timestamp', descending: false)
          .limit(100)
          .get();

      // Count occurrences
      Map<String, int> searchCounts = {};
      for (var doc in snapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        String query = data['query'] as String;
        searchCounts[query] = (searchCounts[query] ?? 0) + 1;
      }

      // Sort by count and return top 8
      var sortedSearches = searchCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      if (sortedSearches.isEmpty) {
        return _getDefaultTrendingSearches();
      }

      return sortedSearches.take(8).map((e) => e.key).toList();

    } catch (e) {
      print('Error getting trending searches: $e');
      return _getDefaultTrendingSearches();
    }
  }

  // 5. GET CATEGORIES WITH REAL COUNTS
  Future<List<Map<String, dynamic>>> getCategories() async {
    try {
      List<Map<String, dynamic>> categories = [
        {'name': 'Music', 'icon': Icons.music_note, 'tag': 'music', 'color': Colors.purple},
        {'name': 'Gaming', 'icon': Icons.sports_esports, 'tag': 'gaming', 'color': Colors.blue},
        {'name': 'Education', 'icon': Icons.book, 'tag': 'education', 'color': Colors.green},
        {'name': 'Movies', 'icon': Icons.movie, 'tag': 'movies', 'color': Colors.red},
        {'name': 'Fitness', 'icon': Icons.fitness_center, 'tag': 'fitness', 'color': Colors.orange},
        {'name': 'Travel', 'icon': Icons.travel_explore, 'tag': 'travel', 'color': Colors.teal},
        {'name': 'Comedy', 'icon': Icons.theaters, 'tag': 'comedy', 'color': Colors.amber},
        {'name': 'Tech', 'icon': Icons.computer, 'tag': 'tech', 'color': Colors.indigo},
      ];

      // Get real counts from posts
      for (var category in categories) {
        try {
          QuerySnapshot countSnapshot = await _firestore
              .collection('posts')
              .where('category', isEqualTo: category['tag'])
              .where('createdAt', isGreaterThan: Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 30))))
              .limit(1000)
              .get();

          int count = countSnapshot.docs.length;
          category['count'] = _formatCount(count);
          category['rawCount'] = count;
        } catch (e) {
          // If category field doesn't exist, use sample data
          category['count'] = _getSampleCount(category['name']);
          category['rawCount'] = 1000;
        }
      }

      return categories;

    } catch (e) {
      print('Error getting categories: $e');
      return _getDefaultCategories();
    }
  }

  // 6. SAVE SEARCH HISTORY (existing)
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
        await existing.docs.first.reference.update({
          'timestamp': FieldValue.serverTimestamp(),
        });
      } else {
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
          for (int i = 20; i < oldSearches.docs.length; i++) {
            await oldSearches.docs[i].reference.delete();
          }
        }
      }
    } catch (e) {
      print('Error saving search history: $e');
    }
  }

  // 7. GET USER SEARCH HISTORY (existing)
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

  // 8. CLEAR SEARCH HISTORY (existing)
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

  // 9. DELETE SINGLE SEARCH ITEM (existing)
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

  // 10. GET SUGGESTIONS (new)
  Future<List<String>> getSearchSuggestions(String query) async {
    if (query.trim().isEmpty) return [];

    try {
      String searchQuery = query.toLowerCase().trim();

      // Get from trending searches that match
      QuerySnapshot snapshot = await _firestore
          .collection('search_analytics')
          .where('query', isGreaterThanOrEqualTo: searchQuery)
          .where('query', isLessThanOrEqualTo: searchQuery + '\uf8ff')
          .orderBy('query')
          .limit(5)
          .get();

      Set<String> suggestions = {};
      for (var doc in snapshot.docs) {
        suggestions.add((doc.data() as Map<String, dynamic>)['query'] as String);
      }

      return suggestions.toList();

    } catch (e) {
      print('Error getting suggestions: $e');
      return [];
    }
  }

  // 11. GET POST BY ID (new)
  Future<Map<String, dynamic>?> getPostById(String postId) async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection('posts')
          .doc(postId)
          .get();

      if (!doc.exists) return null;

      Map<String, dynamic> postData = doc.data() as Map<String, dynamic>;
      Map<String, dynamic> userData = await _getCachedUserData(postData['userId']);

      return {
        'id': doc.id,
        ...postData,
        'user_name': userData['name'] ?? 'Unknown',
        'user_username': userData['username'] ?? '',
        'user_profile_pic': userData['profilePic'] ?? userData['photoURL'] ?? '',
      };

    } catch (e) {
      print('Error getting post: $e');
      return null;
    }
  }

  // 12. GET USER BY ID (new)
  Future<Map<String, dynamic>?> getUserById(String userId) async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection('users')
          .doc(userId)
          .get();

      if (!doc.exists) return null;

      return {
        'id': doc.id,
        ...doc.data() as Map<String, dynamic>,
      };

    } catch (e) {
      print('Error getting user: $e');
      return null;
    }
  }

  // ========== PRIVATE HELPER METHODS ==========

  // Track search for analytics
  Future<void> _trackSearch(String query, String type, {String? platform}) async {
    try {
      if (query.trim().isEmpty) return;

      await _firestore.collection('search_analytics').add({
        'query': query.toLowerCase().trim(),
        'type': type,
        'platform': platform,
        'timestamp': FieldValue.serverTimestamp(),
        'userId': _auth.currentUser?.uid ?? 'anonymous',
      });

      // Update trending counts (daily aggregate)
      String today = DateTime.now().toIso8601String().split('T')[0];
      await _firestore
          .collection('trending_searches')
          .doc(today)
          .collection('searches')
          .doc(query.toLowerCase().trim())
          .set({
        'query': query.toLowerCase().trim(),
        'count': FieldValue.increment(1),
        'lastSearched': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

    } catch (e) {
      print('Error tracking search: $e');
    }
  }

  // Get cached user data
  Future<Map<String, dynamic>> _getCachedUserData(String userId) async {
    // Check cache
    if (_userCache.containsKey(userId)) {
      DateTime timestamp = _cacheTimestamps[userId] ?? DateTime.now();
      if (DateTime.now().difference(timestamp) < _cacheDuration) {
        return _userCache[userId]!;
      }
    }

    try {
      // Fetch from Firestore
      DocumentSnapshot userDoc = await _firestore
          .collection('users')
          .doc(userId)
          .get();

      Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>? ?? {};

      // Update cache
      _userCache[userId] = userData;
      _cacheTimestamps[userId] = DateTime.now();

      return userData;

    } catch (e) {
      print('Error fetching user data: $e');
      return {};
    }
  }

  // Format count (e.g., 1500 -> 1.5k)
  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}k';
    }
    return count.toString();
  }

  // Sample count for categories
  String _getSampleCount(String category) {
    Map<String, String> sampleCounts = {
      'Music': '1.2k',
      'Gaming': '890k',
      'Education': '650k',
      'Movies': '1.8k',
      'Fitness': '540k',
      'Travel': '720k',
      'Comedy': '930k',
      'Tech': '410k',
    };
    return sampleCounts[category] ?? '1.0k';
  }

  // Default categories fallback
  List<Map<String, dynamic>> _getDefaultCategories() {
    return [
      {'name': 'Music', 'icon': Icons.music_note, 'count': '1.2k', 'color': Colors.purple},
      {'name': 'Gaming', 'icon': Icons.sports_esports, 'count': '890k', 'color': Colors.blue},
      {'name': 'Education', 'icon': Icons.book, 'count': '650k', 'color': Colors.green},
      {'name': 'Movies', 'icon': Icons.movie, 'count': '1.8k', 'color': Colors.red},
      {'name': 'Fitness', 'icon': Icons.fitness_center, 'count': '540k', 'color': Colors.orange},
      {'name': 'Travel', 'icon': Icons.travel_explore, 'count': '720k', 'color': Colors.teal},
    ];
  }

  // Default trending searches fallback
  List<String> _getDefaultTrendingSearches() {
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
  }
}