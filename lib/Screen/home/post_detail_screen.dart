// lib/Screen/home/post_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tapmate/Screen/constants/app_colors.dart';
import 'package:tapmate/Screen/home/other_user_profile_screen.dart';
import 'package:tapmate/Screen/home/comments_screen.dart';

class PostDetailScreen extends StatefulWidget {
  final String postId;

  const PostDetailScreen({super.key, required this.postId});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isLoading = true;
  bool _isLiked = false;
  int _likesCount = 0;
  int _commentsCount = 0;
  Map<String, dynamic> _postData = {};
  Map<String, dynamic> _userData = {};

  @override
  void initState() {
    super.initState();
    _loadPostData();
  }

  Future<void> _loadPostData() async {
    setState(() => _isLoading = true);

    try {
      // Load post data
      DocumentSnapshot postDoc = await _firestore
          .collection('posts')
          .doc(widget.postId)
          .get();

      if (!postDoc.exists) {
        throw Exception('Post not found');
      }

      _postData = postDoc.data() as Map<String, dynamic>;
      _likesCount = _postData['likes'] ?? 0;
      _commentsCount = _postData['comments'] ?? 0;

      // Load user data (post owner)
      DocumentSnapshot userDoc = await _firestore
          .collection('users')
          .doc(_postData['userId'])
          .get();

      if (userDoc.exists) {
        _userData = userDoc.data() as Map<String, dynamic>;
      }

      // Check if current user liked this post
      String? currentUserId = _auth.currentUser?.uid;
      if (currentUserId != null) {
        DocumentSnapshot likeDoc = await _firestore
            .collection('posts')
            .doc(widget.postId)
            .collection('likes')
            .doc(currentUserId)
            .get();

        _isLiked = likeDoc.exists;
      }

    } catch (e) {
      print('Error loading post: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading post: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // 🔥 LIKE FUNCTIONALITY
  Future<void> _toggleLike() async {
    String? currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;

    setState(() {
      _isLiked = !_isLiked;
      _likesCount += _isLiked ? 1 : -1;
    });

    try {
      if (_isLiked) {
        // Add like
        await _firestore
            .collection('posts')
            .doc(widget.postId)
            .collection('likes')
            .doc(currentUserId)
            .set({
          'userId': currentUserId,
          'likedAt': FieldValue.serverTimestamp(),
        });

        // Update post likes count
        await _firestore
            .collection('posts')
            .doc(widget.postId)
            .update({
          'likes': FieldValue.increment(1),
        });
      } else {
        // Remove like
        await _firestore
            .collection('posts')
            .doc(widget.postId)
            .collection('likes')
            .doc(currentUserId)
            .delete();

        // Update post likes count
        await _firestore
            .collection('posts')
            .doc(widget.postId)
            .update({
          'likes': FieldValue.increment(-1),
        });
      }
    } catch (e) {
      print('Error toggling like: $e');
      // Revert on error
      if (mounted) {
        setState(() {
          _isLiked = !_isLiked;
          _likesCount += _isLiked ? 1 : -1;
        });
      }
    }
  }

  // 🔥 COMMENT FUNCTIONALITY
  void _openComments() async {
    // Navigate to comments screen
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CommentsScreen(
          postId: widget.postId,
          contentTitle: _postData['caption'] ?? 'Post',
          initialCommentCount: _commentsCount,
        ),
      ),
    );

    // If comment was added, reload comments count
    if (result == true) {
      _loadPostData();
    }
  }

  // 🔥 SHARE FUNCTIONALITY
  void _sharePost() {
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

            // Share to Feed
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.feed, color: AppColors.primary),
              ),
              title: const Text('Share to Feed'),
              subtitle: const Text('Share this post to your feed'),
              onTap: () {
                Navigator.pop(context);
                _shareToFeed();
              },
            ),

            // Share via...
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.share, color: Colors.green),
              ),
              title: const Text('Share via...'),
              subtitle: const Text('Share with other apps'),
              onTap: () {
                Navigator.pop(context);
                _shareViaOtherApps();
              },
            ),

            // Copy Link
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.link, color: Colors.blue),
              ),
              title: const Text('Copy Link'),
              subtitle: const Text('Copy post link to clipboard'),
              onTap: () {
                Navigator.pop(context);
                _copyPostLink();
              },
            ),

            // Download (if user's own post)
            if (_postData['userId'] == _auth.currentUser?.uid)
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.download, color: Colors.orange),
                ),
                title: const Text('Download'),
                subtitle: const Text('Save post to device'),
                onTap: () {
                  Navigator.pop(context);
                  _downloadPost();
                },
              ),
          ],
        ),
      ),
    );
  }

  // Share to Feed (create a repost)
  Future<void> _shareToFeed() async {
    String? currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;

    try {
      // Create a share/repost document
      await _firestore.collection('shares').add({
        'originalPostId': widget.postId,
        'sharedByUserId': currentUserId,
        'sharedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Post shared to your feed!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error sharing post: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sharing post: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Share via other apps
  void _shareViaOtherApps() {
    // TODO: Implement share using share_plus package
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Share via other apps - Coming soon!'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  // Copy post link
  void _copyPostLink() {
    // TODO: Implement copy link
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Post link copied to clipboard!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  // Download post
  void _downloadPost() {
    // TODO: Implement download functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Download feature coming soon!'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  // 🔥 MORE OPTIONS (3 dots menu)
  void _showMoreOptions() {
    bool isMyPost = _postData['userId'] == _auth.currentUser?.uid;

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
                leading: const Icon(Icons.edit, color: AppColors.primary),
                title: const Text('Edit Post'),
                onTap: () {
                  Navigator.pop(context);
                  _editPost();
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Delete Post', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _deletePost();
                },
              ),
            ] else ...[
              ListTile(
                leading: const Icon(Icons.person_add, color: AppColors.primary),
                title: const Text('Follow User'),
                onTap: () {
                  Navigator.pop(context);
                  _followUser();
                },
              ),
              ListTile(
                leading: const Icon(Icons.block, color: Colors.red),
                title: const Text('Block User', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _blockUser();
                },
              ),
              ListTile(
                leading: const Icon(Icons.flag, color: Colors.orange),
                title: const Text('Report Post'),
                onTap: () {
                  Navigator.pop(context);
                  _reportPost();
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _editPost() async {
    // TODO: Implement edit post
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Edit feature coming soon!'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  Future<void> _deletePost() async {
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
              Navigator.pop(context); // Close dialog

              try {
                await _firestore.collection('posts').doc(widget.postId).delete();

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Post deleted successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  Navigator.pop(context); // Go back to profile
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error deleting post: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _followUser() async {
    String? currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;

    try {
      // Add to following
      await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('following')
          .doc(_postData['userId'])
          .set({
        'followedAt': FieldValue.serverTimestamp(),
      });

      // Update follower count
      await _firestore
          .collection('users')
          .doc(_postData['userId'])
          .update({
        'followers_count': FieldValue.increment(1),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Following ${_userData['name']}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error following user: $e');
    }
  }

  Future<void> _blockUser() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Block User'),
        content: Text('Are you sure you want to block ${_userData['name']}?'),
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
                  content: Text('${_userData['name']} has been blocked'),
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

  Future<void> _reportPost() async {
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
              // TODO: Implement report functionality
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Post reported. Thank you for your feedback.'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Report'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Post')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.lightSurface,
      body: SafeArea(
        child: Column(
          children: [
            // Header with more options
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.more_vert),
                    onPressed: _showMoreOptions,  // 🔥 3 dots menu
                  ),
                ],
              ),
            ),

            // Post Content
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // User Info (clickable)
                    ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppColors.primary.withOpacity(0.2),
                        backgroundImage: _userData['profile_pic'] != null && _userData['profile_pic'].isNotEmpty
                            ? NetworkImage(_userData['profile_pic'])
                            : null,
                        child: _userData['profile_pic'] == null || _userData['profile_pic'].isEmpty
                            ? Text(
                          _userData['name']?[0] ?? 'U',
                          style: const TextStyle(color: AppColors.primary),
                        )
                            : null,
                      ),
                      title: Text(
                        _userData['name'] ?? 'Unknown',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        _formatDate(_postData['createdAt']),
                        style: const TextStyle(fontSize: 12),
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => OtherUserProfileScreen(
                              userId: _postData['userId'],
                              userName: _userData['name'] ?? 'User',
                              userAvatar: _userData['avatar'] ?? '👤',
                            ),
                          ),
                        );
                      },
                    ),

                    // Media
                    Container(
                      height: 300,
                      width: double.infinity,
                      color: Colors.grey[200],
                      child: _postData['isVideo'] == true
                          ? Stack(
                        alignment: Alignment.center,
                        children: [
                          Image.network(
                            _postData['thumbnailUrl'] ?? '',
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: 300,
                            errorBuilder: (context, error, stack) {
                              return Container(
                                color: Colors.grey[300],
                                child: const Center(
                                  child: Icon(Icons.broken_image, size: 50),
                                ),
                              );
                            },
                          ),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.play_arrow,
                              color: Colors.white,
                              size: 40,
                            ),
                          ),
                        ],
                      )
                          : Image.network(
                        _postData['thumbnailUrl'] ?? '',
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: 300,
                        errorBuilder: (context, error, stack) {
                          return Container(
                            color: Colors.grey[300],
                            child: const Center(
                              child: Icon(Icons.broken_image, size: 50),
                            ),
                          );
                        },
                      ),
                    ),

                    // Caption
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        _postData['caption'] ?? '',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),

                    // 🔥 THREE BUTTONS: Like, Comment, Share
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          // Like Button
                          Expanded(
                            child: TextButton.icon(
                              onPressed: _toggleLike,
                              icon: Icon(
                                _isLiked ? Icons.favorite : Icons.favorite_border,
                                color: _isLiked ? Colors.red : AppColors.primary,
                              ),
                              label: Text(
                                _isLiked ? 'Liked' : 'Like',
                                style: TextStyle(
                                  color: _isLiked ? Colors.red : AppColors.primary,
                                ),
                              ),
                            ),
                          ),

                          // Comment Button
                          Expanded(
                            child: TextButton.icon(
                              onPressed: _openComments,
                              icon: Icon(Icons.comment_outlined, color: AppColors.primary),
                              label: Text(
                                'Comment',
                                style: TextStyle(color: AppColors.primary),
                              ),
                            ),
                          ),

                          // Share Button
                          Expanded(
                            child: TextButton.icon(
                              onPressed: _sharePost,
                              icon: Icon(Icons.share_outlined, color: AppColors.primary),
                              label: Text(
                                'Share',
                                style: TextStyle(color: AppColors.primary),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Likes and Comments count
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          Text(
                            '$_likesCount likes',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 20),
                          Text(
                            '$_commentsCount comments',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),

                    const Divider(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'Recently';
    if (timestamp is Timestamp) {
      DateTime date = timestamp.toDate();
      return '${date.day}/${date.month}/${date.year}';
    }
    return 'Recently';
  }
}