// lib/Screen/home/comments_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tapmate/Screen/constants/app_colors.dart';

class CommentsScreen extends StatefulWidget {
  final String postId;  // Changed from contentTitle
  final String contentTitle;
  final int initialCommentCount;

  const CommentsScreen({
    super.key,
    required this.postId,  // Add this
    required this.contentTitle,
    required this.initialCommentCount,
  });

  @override
  State<CommentsScreen> createState() => _CommentsScreenState();
}

class _CommentsScreenState extends State<CommentsScreen> {
  final TextEditingController _commentController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<Map<String, dynamic>> _comments = [];
  bool _isLoading = true;
  int _commentCount = 0;

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  Future<void> _loadComments() async {
    setState(() => _isLoading = true);

    try {
      QuerySnapshot commentsSnapshot = await _firestore
          .collection('posts')
          .doc(widget.postId)
          .collection('comments')
          .orderBy('createdAt', descending: true)
          .get();

      List<Map<String, dynamic>> loadedComments = [];

      for (var doc in commentsSnapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

        // Get user info for each comment
        DocumentSnapshot userDoc = await _firestore
            .collection('users')
            .doc(data['userId'])
            .get();

        Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>? ?? {};

        loadedComments.add({
          'id': doc.id,
          'userId': data['userId'],
          'user': userData['name'] ?? 'Unknown User',
          'avatar': userData['avatar'] ?? '👤',
          'profilePic': userData['profile_pic'] ?? '',
          'comment': data['comment'],
          'time': _formatTime(data['createdAt']),
          'likes': data['likes'] ?? 0,
          'isLiked': false, // You can implement like functionality later
        });
      }

      setState(() {
        _comments = loadedComments;
        _commentCount = _comments.length;
        _isLoading = false;
      });

      // Update comment count in post
      await _firestore.collection('posts').doc(widget.postId).update({
        'comments': _commentCount,
      });

    } catch (e) {
      print('Error loading comments: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _addComment() async {
    if (_commentController.text.trim().isEmpty) return;

    String commentText = _commentController.text.trim();
    String? userId = _auth.currentUser?.uid;

    if (userId == null) return;

    try {
      // Get current user info
      DocumentSnapshot userDoc = await _firestore
          .collection('users')
          .doc(userId)
          .get();

      Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>? ?? {};

      // Add comment to Firestore
      await _firestore
          .collection('posts')
          .doc(widget.postId)
          .collection('comments')
          .add({
        'userId': userId,
        'comment': commentText,
        'createdAt': FieldValue.serverTimestamp(),
        'likes': 0,
      });

      _commentController.clear();

      // Reload comments
      await _loadComments();

    } catch (e) {
      print('Error adding comment: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to add comment: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _toggleLike(String commentId, int currentLikes, bool isLiked) async {
    String? userId = _auth.currentUser?.uid;
    if (userId == null) return;

    try {
      if (isLiked) {
        // Unlike
        await _firestore
            .collection('posts')
            .doc(widget.postId)
            .collection('comments')
            .doc(commentId)
            .collection('likes')
            .doc(userId)
            .delete();

        await _firestore
            .collection('posts')
            .doc(widget.postId)
            .collection('comments')
            .doc(commentId)
            .update({
          'likes': FieldValue.increment(-1),
        });
      } else {
        // Like
        await _firestore
            .collection('posts')
            .doc(widget.postId)
            .collection('comments')
            .doc(commentId)
            .collection('likes')
            .doc(userId)
            .set({
          'userId': userId,
          'likedAt': FieldValue.serverTimestamp(),
        });

        await _firestore
            .collection('posts')
            .doc(widget.postId)
            .collection('comments')
            .doc(commentId)
            .update({
          'likes': FieldValue.increment(1),
        });
      }

      // Reload comments to update UI
      await _loadComments();

    } catch (e) {
      print('Error toggling like: $e');
    }
  }

  String _formatTime(dynamic timestamp) {
    if (timestamp == null) return 'Just now';
    if (timestamp is Timestamp) {
      DateTime date = timestamp.toDate();
      DateTime now = DateTime.now();

      if (date.day == now.day && date.month == now.month && date.year == now.year) {
        // Today - show time
        return '${date.hour}:${date.minute.toString().padLeft(2, '0')}';
      } else if (date.day == now.day - 1 && date.month == now.month && date.year == now.year) {
        // Yesterday
        return 'Yesterday';
      } else {
        // Other days
        return '${date.day}/${date.month}';
      }
    }
    return 'Just now';
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String? currentUserId = _auth.currentUser?.uid;

    return Scaffold(
      backgroundColor: AppColors.lightSurface,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.accent, AppColors.secondary, AppColors.primary],
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(25),
                  bottomRight: Radius.circular(25),
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: AppColors.lightSurface),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Comments',
                          style: TextStyle(
                            color: AppColors.lightSurface,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '$_commentCount comments',
                          style: TextStyle(
                            color: AppColors.lightSurface.withOpacity(0.9),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Comments List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _comments.isEmpty
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.comment_outlined,
                      size: 80,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'No comments yet',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Be the first to comment!',
                      style: TextStyle(
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              )
                  : ListView.builder(
                padding: const EdgeInsets.all(20),
                itemCount: _comments.length,
                itemBuilder: (context, index) {
                  return _buildCommentItem(_comments[index], currentUserId);
                },
              ),
            ),

            // Comment Input
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: AppColors.lightSurface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: AppColors.primary.withOpacity(0.2),
                    child: const Text('👤', style: TextStyle(fontSize: 18)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      decoration: InputDecoration(
                        hintText: 'Add a comment...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(25),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      ),
                      maxLines: null,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _addComment(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton(
                    icon: const Icon(Icons.send, color: AppColors.primary),
                    onPressed: _addComment,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentItem(Map<String, dynamic> comment, String? currentUserId) {
    bool isLiked = comment['isLiked'] ?? false;
    bool isMyComment = comment['userId'] == currentUserId;

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.primary.withOpacity(0.2),
            backgroundImage: comment['profilePic'] != null && comment['profilePic'].isNotEmpty
                ? NetworkImage(comment['profilePic'])
                : null,
            child: comment['profilePic'] == null || comment['profilePic'].isEmpty
                ? Text(
              comment['avatar'] as String,
              style: const TextStyle(fontSize: 18),
            )
                : null,
          ),
          const SizedBox(width: 12),

          // Comment content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      comment['user'] as String,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.accent,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      comment['time'] as String,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  comment['comment'] as String,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.accent,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    // Like button
                    GestureDetector(
                      onTap: () => _toggleLike(
                        comment['id'],
                        comment['likes'],
                        isLiked,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isLiked ? Icons.favorite : Icons.favorite_border,
                            size: 16,
                            color: isLiked ? Colors.red : Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            comment['likes'].toString(),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 15),

                    // Reply button (optional)
                    if (!isMyComment)
                      GestureDetector(
                        onTap: () {
                          _commentController.text = '@${comment['user']} ';
                          FocusScope.of(context).requestFocus(FocusNode());
                        },
                        child: Text(
                          'Reply',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
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
}