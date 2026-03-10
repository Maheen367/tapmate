// lib/Screen/home/feed_screen.dart (COMPLETE FIREBASE VERSION)

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:tapmate/Screen/Auth/LoginScreen.dart';
import 'package:tapmate/Screen/home/comments_screen.dart';
import 'package:tapmate/Screen/home/download_progress_screen.dart';
import 'package:tapmate/Screen/home/other_user_profile_screen.dart';
import 'package:tapmate/Screen/home/storage_selection_dialog.dart';
import 'package:tapmate/Screen/services/media_service.dart';
import '../../auth_provider.dart';
import '../../theme_provider.dart';
import 'package:tapmate/Screen/constants/app_colors.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final MediaService _mediaService = MediaService();

  List<Map<String, dynamic>> _feedItems = [];
  bool _isLoading = false;
  String? _lastVisible;

  @override
  void initState() {
    super.initState();
    _loadFeedItems();
  }

  Future<void> _loadFeedItems() async {
    setState(() => _isLoading = true);

    try {
      QuerySnapshot postsSnapshot = await _firestore
          .collection('posts')
          .orderBy('createdAt', descending: true)
          .limit(10)
          .get();

      List<Map<String, dynamic>> posts = [];

      for (var doc in postsSnapshot.docs) {
        Map<String, dynamic> postData = doc.data() as Map<String, dynamic>;

        // Get user data for each post
        DocumentSnapshot userDoc = await _firestore
            .collection('users')
            .doc(postData['userId'])
            .get();

        Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>? ?? {};

        // Check if current user liked this post
        String? currentUserId = _auth.currentUser?.uid;
        bool isLiked = false;
        if (currentUserId != null) {
          DocumentSnapshot likeDoc = await _firestore
              .collection('posts')
              .doc(doc.id)
              .collection('likes')
              .doc(currentUserId)
              .get();
          isLiked = likeDoc.exists;
        }

        posts.add({
          'id': doc.id,
          'user_id': postData['userId'],
          'user_name': userData['name'] ?? 'Unknown User',
          'user_profile_pic': userData['profile_pic'] ?? '',
          'caption': postData['caption'] ?? '',
          'thumbnail_url': postData['thumbnailUrl'] ?? '',
          'video_url': postData['videoUrl'],
          'platform': postData['platform'] ?? 'TapMate',
          'created_at': _formatDate(postData['createdAt']),
          'timestamp': postData['createdAt'],
          'likes_count': postData['likes'] ?? 0,
          'comments_count': postData['comments'] ?? 0,
          'is_video': postData['isVideo'] ?? false,
          'is_liked': isLiked,
          'can_download': true,
        });
      }

      setState(() {
        _feedItems = posts;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading feed: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleLike(int index) async {
    String? currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;

    String postId = _feedItems[index]['id'];
    bool isLiked = _feedItems[index]['is_liked'] ?? false;

    // Optimistic update
    setState(() {
      _feedItems[index]['is_liked'] = !isLiked;
      _feedItems[index]['likes_count'] =
          (_feedItems[index]['likes_count'] as int) + (isLiked ? -1 : 1);
    });

    try {
      if (isLiked) {
        // Unlike
        await _firestore
            .collection('posts')
            .doc(postId)
            .collection('likes')
            .doc(currentUserId)
            .delete();

        await _firestore
            .collection('posts')
            .doc(postId)
            .update({
          'likes': FieldValue.increment(-1),
        });
      } else {
        // Like
        await _firestore
            .collection('posts')
            .doc(postId)
            .collection('likes')
            .doc(currentUserId)
            .set({
          'userId': currentUserId,
          'likedAt': FieldValue.serverTimestamp(),
        });

        await _firestore
            .collection('posts')
            .doc(postId)
            .update({
          'likes': FieldValue.increment(1),
        });
      }
    } catch (e) {
      // Revert on error
      setState(() {
        _feedItems[index]['is_liked'] = isLiked;
        _feedItems[index]['likes_count'] =
            (_feedItems[index]['likes_count'] as int) + (isLiked ? 1 : -1);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _viewUserProfile(String userId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OtherUserProfileScreen(
          userId: userId,
          userName: '', // Will be loaded from Firestore
          userAvatar: '👤',
        ),
      ),
    );
  }

  void _sharePost(Map<String, dynamic> post) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Share Post',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.accent,
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.share, color: Colors.blue, size: 28),
              title: const Text('Share via...', style: TextStyle(fontSize: 16)),
              onTap: () {
                Navigator.pop(context);
                _shareViaOtherApps(post);
              },
            ),
            ListTile(
              leading: const Icon(Icons.link, color: Colors.green, size: 28),
              title: const Text('Copy Link', style: TextStyle(fontSize: 16)),
              onTap: () {
                Navigator.pop(context);
                _copyPostLink(post['id']);
              },
            ),
            ListTile(
              leading: const Icon(Icons.download, color: AppColors.primary, size: 28),
              title: const Text('Download & Share', style: TextStyle(fontSize: 16)),
              onTap: () {
                Navigator.pop(context);
                _downloadContent(post);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _shareViaOtherApps(Map<String, dynamic> post) {
    // TODO: Implement using share_plus package
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Share feature coming soon!'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  void _copyPostLink(String postId) {
    // TODO: Implement deep linking
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Post link copied: post_$postId'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _downloadContent(Map<String, dynamic> content) {
    showDialog(
      context: context,
      builder: (context) => StorageSelectionDialog(
        platformName: content['platform'],
        contentId: content['id'],
        contentTitle: content['caption'],
        onDeviceStorageSelected: (path, format, quality) {
          Navigator.pop(context);
          _startDownload(content, path, format, quality, true);
        },
        onAppStorageSelected: (format, quality) {
          Navigator.pop(context);
          _startDownload(content, null, format, quality, false);
        },
      ),
    );
  }

  void _startDownload(Map<String, dynamic> content, String? path, String format, String quality, bool isDeviceStorage) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DownloadProgressScreen(
          platformName: content['platform'],
          contentTitle: '${content['caption']} ($format - $quality)',
          storagePath: path,
          isDeviceStorage: isDeviceStorage,
          fromPlatformScreen: false,
          sourcePlatform: 'feed',
        ),
      ),
    );
  }

  void _showPostOptions(Map<String, dynamic> post) {
    bool isMyPost = post['user_id'] == _auth.currentUser?.uid;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isMyPost) ...[
              ListTile(
                leading: Icon(Icons.edit, color: AppColors.primary, size: 28),
                title: Text('Edit Post', style: TextStyle(fontSize: 16)),
                onTap: () {
                  Navigator.pop(context);
                  _editPost(post);
                },
              ),
              ListTile(
                leading: Icon(Icons.delete, color: Colors.red, size: 28),
                title: Text('Delete Post', style: TextStyle(fontSize: 16, color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _deletePost(post);
                },
              ),
            ] else ...[
              ListTile(
                leading: Icon(Icons.person_add, color: AppColors.primary, size: 28),
                title: Text('Follow User', style: TextStyle(fontSize: 16)),
                onTap: () {
                  Navigator.pop(context);
                  _followUser(post['user_id']);
                },
              ),
              ListTile(
                leading: Icon(Icons.block, color: Colors.red, size: 28),
                title: Text('Block User', style: TextStyle(fontSize: 16, color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _blockUser(post);
                },
              ),
              const Divider(),
              ListTile(
                leading: Icon(Icons.report, color: Colors.orange, size: 28),
                title: Text('Report Post', style: TextStyle(fontSize: 16, color: Colors.orange)),
                onTap: () {
                  Navigator.pop(context);
                  _reportPost(post);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _editPost(Map<String, dynamic> post) {
    // TODO: Implement edit post
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Edit feature coming soon!'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  void _deletePost(Map<String, dynamic> post) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Post'),
        content: const Text('Are you sure you want to delete this post?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);

              try {
                await _firestore.collection('posts').doc(post['id']).delete();

                // Update local list
                setState(() {
                  _feedItems.removeWhere((item) => item['id'] == post['id']);
                });

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Post deleted successfully'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error deleting post: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _followUser(String userId) async {
    String? currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;

    try {
      // Add to following
      await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('following')
          .doc(userId)
          .set({
        'followedAt': FieldValue.serverTimestamp(),
      });

      // Update follower count
      await _firestore
          .collection('users')
          .doc(userId)
          .update({
        'followers_count': FieldValue.increment(1),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('User followed successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error following user: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _blockUser(Map<String, dynamic> post) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Block User'),
        content: Text('Are you sure you want to block this user?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Implement block functionality
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('User blocked'),
                  backgroundColor: Colors.red,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Block'),
          ),
        ],
      ),
    );
  }

  void _reportPost(Map<String, dynamic> post) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Report Post'),
        content: const Text('Please select a reason for reporting this post.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Post reported. Thank you for your feedback.'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Report'),
          ),
        ],
      ),
    );
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'Recently';
    if (timestamp is Timestamp) {
      DateTime date = timestamp.toDate();
      DateTime now = DateTime.now();

      if (date.day == now.day && date.month == now.month && date.year == now.year) {
        return 'Today';
      } else if (date.day == now.day - 1 && date.month == now.month && date.year == now.year) {
        return 'Yesterday';
      } else {
        return '${date.day}/${date.month}/${date.year}';
      }
    }
    return 'Recently';
  }

  Widget _buildNavItem(IconData icon, String label, bool isActive, BuildContext context, bool isGuest, bool isDarkMode) {
    final bool isLocked = isGuest && (label == 'Message' || label == 'Profile');

    return GestureDetector(
      onTap: isLocked
          ? () => _showGuestFeatureDialog(label)
          : () {
        if (label == 'Home') {
          Navigator.pushReplacementNamed(context, '/home');
        } else if (label == 'Discover') {
          Navigator.pushReplacementNamed(context, '/search');
        } else if (label == 'Feed') {
          Navigator.pushReplacementNamed(context, '/feed');
        } else if (label == 'Message') {
          Navigator.pushReplacementNamed(context, '/chat');
        } else if (label == 'Profile') {
          Navigator.pushReplacementNamed(context, '/profile');
        }
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            children: [
              Icon(
                icon,
                color: isActive ? AppColors.primary : (isDarkMode ? Colors.grey[600] : Colors.grey),
                size: 24,
              ),
              if (isLocked)
                Positioned(
                  top: -2,
                  right: -2,
                  child: Container(
                    padding: const EdgeInsets.all(1),
                    decoration: BoxDecoration(
                      color: isDarkMode ? AppColors.textMain : AppColors.lightSurface,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.lock,
                      size: 10,
                      color: Colors.orange,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isActive ? AppColors.primary : (isDarkMode ? Colors.grey[600] : Colors.grey),
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  void _showGuestFeatureDialog(String feature) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$feature Locked'),
        content: Text('Sign up to $feature and interact with posts.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Later'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Sign Up', style: TextStyle(color: AppColors.lightSurface)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);

    final isGuest = authProvider.isGuest;
    final isDarkMode = themeProvider.isDarkMode;

    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF121212) : AppColors.lightSurface,
      body: SafeArea(
        child: Column(
          children: [
            // HEADER
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                horizontal: 20,
                vertical: isGuest ? 15 : 20,
              ),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.accent, AppColors.secondary, AppColors.primary],
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accent.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              isGuest ? 'Community Feed' : 'Your Feed',
                              style: const TextStyle(
                                color: AppColors.lightSurface,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isGuest
                                  ? 'Sign up to interact with posts'
                                  : 'Discover content from your network',
                              style: const TextStyle(
                                color: Color(0xE6FFFFFF),
                                fontSize: 13,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!isGuest)
                            IconButton(
                              icon: const Icon(Icons.search, color: AppColors.lightSurface, size: 22),
                              onPressed: () {
                                Navigator.pushNamed(context, '/search');
                              },
                              tooltip: 'Search',
                            ),
                          IconButton(
                            icon: Icon(
                              isGuest ? Icons.info_outline : Icons.add_circle_outline,
                              color: AppColors.lightSurface,
                              size: 22,
                            ),
                            onPressed: () {
                              if (isGuest) {
                                _showGuestInfo();
                              } else {
                                Navigator.pushNamed(context, '/create-post');
                              }
                            },
                            tooltip: isGuest ? 'Info' : 'Create Post',
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (isGuest) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0x26FFFFFF),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.lock_open, size: 14, color: AppColors.lightSurface),
                          const SizedBox(width: 6),
                          const Text(
                            'Guest Mode',
                            style: TextStyle(
                              color: AppColors.lightSurface,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: _showSignUpPrompt,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.lightSurface,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text(
                                'Upgrade',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Feed Content
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadFeedItems,
                color: AppColors.primary,
                child: _isLoading
                    ? Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                )
                    : _feedItems.isEmpty
                    ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.feed_outlined,
                        size: 80,
                        color: isDarkMode ? Colors.grey[400] : Colors.grey[300],
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'No posts yet',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? AppColors.lightSurface : AppColors.accent,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        isGuest
                            ? 'Sign up to see content from the community'
                            : 'Follow people to see their posts here',
                        style: TextStyle(
                          color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                )
                    : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _feedItems.length,
                  itemBuilder: (context, index) {
                    return _buildFeedItem(_feedItems[index], index, isGuest, isDarkMode);
                  },
                ),
              ),
            ),

            // Bottom Navigation Bar
            SafeArea(
              top: false,
              child: Container(
                height: 70,
                decoration: BoxDecoration(
                  color: isDarkMode ? const Color(0xFF1E1E1E) : AppColors.lightSurface,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    ),
                  ],
                  border: Border.all(
                    color: Colors.grey.withOpacity(0.1),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildNavItem(Icons.home_rounded, 'Home', false, context, isGuest, isDarkMode),
                    _buildNavItem(Icons.explore_rounded, 'Discover', false, context, isGuest, isDarkMode),
                    _buildNavItem(Icons.feed_rounded, 'Feed', true, context, isGuest, isDarkMode),
                    _buildNavItem(Icons.message_rounded, 'Message', false, context, isGuest, isDarkMode),
                    _buildNavItem(Icons.person_rounded, 'Profile', false, context, isGuest, isDarkMode),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeedItem(Map<String, dynamic> item, int index, bool isGuest, bool isDarkMode) {
    final isLiked = item['is_liked'] ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E1E1E) : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.accent.withOpacity(0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(isDarkMode ? 0.2 : 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => _viewUserProfile(item['user_id']),
                  child: CircleAvatar(
                    radius: 25,
                    backgroundImage: item['user_profile_pic'].isNotEmpty
                        ? NetworkImage(item['user_profile_pic'])
                        : null,
                    child: item['user_profile_pic'].isEmpty
                        ? Text(
                      item['user_name'][0].toUpperCase(),
                      style: const TextStyle(fontSize: 20),
                    )
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: () => _viewUserProfile(item['user_id']),
                        child: Text(
                          item['user_name'],
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDarkMode ? AppColors.lightSurface : AppColors.accent,
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: _getPlatformColor(item['platform']).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              item['platform'],
                              style: TextStyle(
                                fontSize: 10,
                                color: _getPlatformColor(item['platform']),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            item['created_at'],
                            style: TextStyle(
                              fontSize: 12,
                              color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.more_vert, color: isDarkMode ? Colors.grey[400] : AppColors.accent),
                  onPressed: () => _showPostOptions(item),
                ),
              ],
            ),
          ),

          // Post Caption
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              item['caption'],
              style: TextStyle(
                fontSize: 14,
                color: isDarkMode ? Colors.grey[300] : AppColors.accent,
                height: 1.5,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Content Thumbnail
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CommentsScreen(
                    postId: item['id'],  // 🔥 FIXED: Added postId
                    contentTitle: item['caption'],
                    initialCommentCount: item['comments_count'],
                  ),
                ),
              );
            },
            child: Container(
              height: 250,
              width: double.infinity,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Post Image
                  Image.network(
                    item['thumbnail_url'],
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        color: AppColors.primary.withOpacity(0.1),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primary,
                          ),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: AppColors.primary.withOpacity(0.2),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.videocam, size: 40, color: AppColors.primary),
                              const SizedBox(height: 10),
                              Text(
                                'Video Preview',
                                style: TextStyle(color: AppColors.primary),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),

                  // Video overlay
                  if (item['is_video'] == true)
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.textMain.withOpacity(0.6),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.play_arrow,
                          color: AppColors.lightSurface,
                          size: 40,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Stats and Actions
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              children: [
                // Stats row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.favorite, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          _formatNumber(item['likes_count']),
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Icon(Icons.comment, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          _formatNumber(item['comments_count']),
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Action buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    // Like button
                    Expanded(
                      child: TextButton.icon(
                        onPressed: isGuest
                            ? () => _showGuestFeatureDialog('Like posts')
                            : () => _toggleLike(index),
                        icon: Icon(
                          isLiked ? Icons.favorite : Icons.favorite_border,
                          color: isLiked ? Colors.red : AppColors.primary,
                          size: 20,
                        ),
                        label: Text(
                          isLiked ? 'Liked' : 'Like',
                          style: TextStyle(
                            color: isLiked ? Colors.red : AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),

                    // Comment button
                    Expanded(
                      child: TextButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => CommentsScreen(
                                postId: item['id'],  // 🔥 FIXED: Added postId
                                contentTitle: item['caption'],
                                initialCommentCount: item['comments_count'],
                              ),
                            ),
                          );
                        },
                        icon: Icon(Icons.comment_outlined, color: AppColors.primary, size: 20),
                        label: Text(
                          'Comment',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),

                    // Share button
                    Expanded(
                      child: TextButton.icon(
                        onPressed: () => _sharePost(item),
                        icon: Icon(Icons.share_outlined, color: AppColors.primary, size: 20),
                        label: Text(
                          'Share',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatNumber(int number) {
    if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }

  Color _getPlatformColor(String platform) {
    switch (platform.toLowerCase()) {
      case 'youtube':
        return const Color(0xFFFF0000);
      case 'tiktok':
        return const Color(0xFF000000);
      case 'instagram':
        return const Color(0xFFE4405F);
      default:
        return AppColors.primary;
    }
  }

  void _showGuestInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Guest Mode'),
        content: const Text(
          'You are browsing in guest mode. Sign up to:\n\n'
              '• Like and comment on posts\n'
              '• Download videos\n'
              '• Share posts\n'
              '• Follow users\n'
              '• Create your own posts',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Sign Up', style: TextStyle(color: AppColors.lightSurface)),
          ),
        ],
      ),
    );
  }

  void _showSignUpPrompt() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person_add, size: 60, color: AppColors.primary),
            const SizedBox(height: 20),
            const Text(
              'Join TapMate Community',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.accent,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Sign up to unlock all features and start interacting!',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginScreen()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  'Sign Up Free',
                  style: TextStyle(color: AppColors.lightSurface, fontSize: 16),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.primary),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(
                  'Continue as Guest',
                  style: TextStyle(color: AppColors.primary),
                ),
              ),
            ),
            SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
          ],
        ),
      ),
    );
  }
}