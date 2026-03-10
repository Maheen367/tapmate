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
      print('📥 Loading post: ${widget.postId}');

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

      print('✅ Post loaded: ${_postData['caption']}');

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
      print('❌ Error loading post: $e');
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

  Future<void> _toggleLike() async {
    // ... like functionality
  }

  void _openComments() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CommentsScreen(
          postId: widget.postId,
          contentTitle: _postData['caption'] ?? 'Post',
          initialCommentCount: _commentsCount,
        ),
      ),
    ).then((_) => _loadPostData());
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
            // Header
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
                    onPressed: () {},
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
                    // User Info
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

                    // Action Buttons
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
                              onPressed: () {},
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

                    // Stats
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