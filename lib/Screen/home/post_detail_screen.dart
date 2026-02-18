import 'package:flutter/material.dart';
import 'package:tapmate/Screen/home/other_user_profile_screen.dart';
import 'package:tapmate/Screen/services/dummy_data_service.dart';
import 'package:tapmate/Screen/constants/app_colors.dart';


class PostDetailScreen extends StatefulWidget {
  final String postId;

  const PostDetailScreen({super.key, required this.postId});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  late Map<String, dynamic> _post;
  bool _isLiked = false;
  int _likeCount = 0;
  List<Map<String, dynamic>> _comments = [];
  final TextEditingController _commentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadPostData();
    _loadComments();
  }

  void _loadPostData() {
    final allPosts = DummyDataService.allPosts;
    final post = allPosts.firstWhere(
          (p) => p['id'] == widget.postId,
      orElse: () => allPosts.first,
    );

    setState(() {
      _post = post;
      _isLiked = post['is_liked'] ?? false;
      _likeCount = post['likes_count'] ?? 0;
    });
  }

  void _loadComments() {
    setState(() {
      _comments = [
        {
          'id': '1',
          'user_id': '2',
          'user_name': 'Sarah Smith',
          'user_avatar': '👩',
          'comment': 'This is amazing! 😍',
          'time': '2h ago',
          'likes': 12,
          'is_liked': false,
        },
        {
          'id': '2',
          'user_id': '3',
          'user_name': 'Mike Johnson',
          'user_avatar': '🧑',
          'comment': 'Great content! Keep it up 👍',
          'time': '3h ago',
          'likes': 8,
          'is_liked': true,
        },
        {
          'id': '3',
          'user_id': '4',
          'user_name': 'Emma Wilson',
          'user_avatar': '👱‍♀️',
          'comment': 'I love this! Can you make more?',
          'time': '5h ago',
          'likes': 15,
          'is_liked': false,
        },
      ];
    });
  }

  void _toggleLike() {
    setState(() {
      _isLiked = !_isLiked;
      _likeCount = _isLiked ? _likeCount + 1 : _likeCount - 1;
    });
  }

  void _addComment() {
    final comment = _commentController.text.trim();
    if (comment.isEmpty) return;

    final newComment = {
      'id': '${_comments.length + 1}',
      'user_id': 'current_user',
      'user_name': 'You',
      'user_avatar': '👤',
      'comment': comment,
      'time': 'Just now',
      'likes': 0,
      'is_liked': false,
    };

    setState(() {
      _comments.insert(0, newComment);
      _commentController.clear();
    });

    // Update post comments count
    setState(() {
      _post['comments_count'] = (_post['comments_count'] ?? 0) + 1;
    });
  }

  void _viewUserProfile(String userId) {
    final user = DummyDataService.getUserById(userId);
    if (user != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => OtherUserProfileScreen(
            userId: userId,
            userName: user['full_name'] ?? user['name'] ?? 'Unknown',
            userAvatar: user['avatar'] ?? '👤',
          ),
        ),
      );
    }
  }

  void _downloadVideo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Download Video'),
        content: const Text('This video will be downloaded to your device.'),
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
                  content: Text('Download started...'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
            ),
            child: const Text('Download', style: TextStyle(color: AppColors.lightSurface)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: AppColors.lightSurface,
        body: SafeArea(
          child: Column(
              children: [
          // Header
          Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.lightSurface,
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                blurRadius: 5,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: AppColors.accent),
                onPressed: () => Navigator.pop(context),
              ),
              GestureDetector(
                onTap: () => _viewUserProfile(_post['user_id']),
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.primary.withOpacity(0.2),
                  child: Text(
                    _post['user_avatar'] ?? '👤',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _post['user_name'] ?? 'Unknown',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      _post['created_at'] ?? '',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.more_vert, color: AppColors.accent),
                onPressed: () {
                  _showPostOptions();
                },
              ),
            ],
          ),
        ),

        // Post Image/Video
        Expanded(
            child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                  // Media
                  AspectRatio(
                  aspectRatio: 1,
                  child: Image.network(
                    _post['thumbnail_url'] ?? 'https://picsum.photos/400/400',
                    fit: BoxFit.cover,
                  ),
                ),

                // Action Buttons
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          IconButton(
                            icon: Icon(
                              _isLiked ? Icons.favorite : Icons.favorite_border,
                              color: _isLiked ? Colors.red : AppColors.accent,
                              size: 28,
                            ),
                            onPressed: _toggleLike,
                          ),
                          IconButton(
                            icon: const Icon(Icons.comment, color: AppColors.accent, size: 28),
                            onPressed: () {
                              // Scroll to comment section
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.share, color: AppColors.accent, size: 28),
                            onPressed: () {
                              _sharePost();
                            },
                          ),
                        ],
                      ),
                      if (_post['can_download'] == true)
                        IconButton(
                          icon: const Icon(Icons.download, color: AppColors.accent, size: 28),
                          onPressed: _downloadVideo,
                        ),
                    ],
                  ),
                ),

                // Likes and Caption
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$_likeCount likes',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      RichText(
                        text: TextSpan(
                          style: const TextStyle(color: AppColors.textMain, fontSize: 14),
                          children: [
                            TextSpan(
                              text: _post['user_name'] ?? 'User',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            TextSpan(
                              text: ' ${_post['caption'] ?? ''}',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _post['created_at'] ?? '',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),

                // Comments Section
                Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(
                    'Comments (${_comments.length})',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: AppColors.accent,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _comments.isEmpty
                        ? const Center(
                      child: Text(
                        'No comments yet',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                        : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _comments.length,
                        itemBuilder: (context, index) {
                          return _buildCommentItem(_comments[index]);
                        }),
                          ],
                          ),
                          ),
                          ],
                          ),
                          ),
                          ),

                          // Add Comment Input
                          Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                          color: AppColors.lightSurface,
                          border: Border(top: BorderSide(color: Colors.grey[300]!)),
                          ),
                          child: Row(
                          children: [
                          Expanded(
                          child: TextField(
                          controller: _commentController,
                          decoration: InputDecoration(
                          hintText: 'Add a comment...',
                          hintStyle: TextStyle(color: Colors.grey[600]),
                          border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(25),
                          borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Colors.grey[100],
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                          onSubmitted: (_) => _addComment(),
                          ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                          icon: Icon(Icons.send, color: AppColors.primary),
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

                        Widget _buildCommentItem(Map<String, dynamic> comment) {
                return Container(
                margin: const EdgeInsets.only(bottom: 12),
                child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                GestureDetector(
                onTap: () => _viewUserProfile(comment['user_id']),
                child: CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.primary.withOpacity(0.2),
                child: Text(
                comment['user_avatar'] ?? '👤',
                style: const TextStyle(fontSize: 16),
                ),
                ),
                ),
                const SizedBox(width: 12),
                Expanded(
                child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                Text(
                comment['user_name'] ?? 'User',
                style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                ),
                ),
                const SizedBox(height: 4),
                Text(
                comment['comment'] ?? '',
                style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 4),
                Row(
                children: [
                Text(
                comment['time'] ?? '',
                style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                ),
                ),
                const SizedBox(width: 16),
                GestureDetector(
                onTap: () {
                // Like comment
                },
                child: Text(
                'Like',
                style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                ),
                ),
                ),
                const SizedBox(width: 16),
                GestureDetector(
                onTap: () {
                // Reply to comment
                },
                child: Text(
                'Reply',
                style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
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

                    void _showPostOptions() {
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
            ListTile(
            leading: const Icon(Icons.save_alt, color: AppColors.primary),
            title: const Text('Save Post'),
            onTap: () {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Post saved!')),
            );
            },
            ),
            ListTile(
            leading: const Icon(Icons.copy, color: AppColors.primary),
            title: const Text('Copy Link'),
            onTap: () {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Link copied!')),
            );
            },
            ),
            ListTile(
            leading: const Icon(Icons.qr_code, color: AppColors.primary),
            title: const Text('QR Code'),
            onTap: () {
            Navigator.pop(context);
            // Show QR code
            },
            ),
            const Divider(),
            ListTile(
            leading: const Icon(Icons.report, color: Colors.orange),
            title: const Text('Report Post'),
            onTap: () {
            Navigator.pop(context);
            _showReportDialog();
            },
            ),
            ],
            ),
            ),
            );
            }

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
        Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
        _buildShareOption(Icons.message, 'Message', () {
        Navigator.pop(context);
        Navigator.pushNamed(context, '/chat');
        }),
        _buildShareOption(Icons.share, 'Share', () {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Shared!')),
        );
        }),
        _buildShareOption(Icons.copy, 'Copy Link', () {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Link copied!')),
        );
        }),
        ],
        ),
        ],
        ),
        ),
        );
        }

            Widget _buildShareOption(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
    onTap: onTap,
    child: Column(
    children: [
    Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
    color: AppColors.primary.withOpacity(0.1),
    shape: BoxShape.circle,
    ),
    child: Icon(icon, color: AppColors.primary, size: 28),
    ),
    const SizedBox(height: 8),
    Text(
    label,
    style: const TextStyle(
    fontSize: 12,
    color: AppColors.accent,
    ),
    ),
    ],
    ),
    );
    }

        void _showReportDialog() {
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
                  const SnackBar(content: Text('Report submitted. Thank you.')),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
              ),
              child: const Text('Submit', style: TextStyle(color: AppColors.lightSurface)),
            ),
          ],
        ),
      );
    }
  }

