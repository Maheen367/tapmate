import 'package:flutter/material.dart';
import 'package:tapmate/Screen/home/chat_screen.dart';
import 'package:tapmate/Screen/services/dummy_data_service.dart';

import 'package:tapmate/Screen/constants/app_colors.dart';

class OtherUserProfileScreen extends StatefulWidget {
  final String userId;
  final String userName;
  final String userAvatar;

  const OtherUserProfileScreen({
    super.key,
    required this.userId,
    required this.userName,
    required this.userAvatar,
  });

  @override
  State<OtherUserProfileScreen> createState() => _OtherUserProfileScreenState();
}

class _OtherUserProfileScreenState extends State<OtherUserProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isFollowing = false;

  // User data
  late Map<String, dynamic> _userData;
  List<Map<String, dynamic>> _userPosts = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadUserData();
  }

  void _loadUserData() {
    // Get user from dummy data
    final user = DummyDataService.getUserById(widget.userId);

    setState(() {
      _userData = user ?? {
        'id': widget.userId,
        'full_name': widget.userName,
        'username': '@${widget.userName.toLowerCase().replaceAll(' ', '')}',
        'avatar': widget.userAvatar,
        'bio': 'This is a user bio',
        'posts_count': 12,
        'followers_count': 345,
        'following_count': 123,
        'is_following': false,
        'is_private': false,
      };

      _userPosts = _userData['is_private'] == true && !_isFollowing
          ? []
          : DummyDataService.getPostsByUser(widget.userId);

      _isFollowing = _userData['is_following'] ?? false;
    });
  }

  void _toggleFollow() {
    setState(() {
      _isFollowing = !_isFollowing;
      if (_isFollowing) {
        _userData['followers_count'] = (_userData['followers_count'] ?? 0) + 1;
        if (_userData['is_private'] == true) {
          _userPosts = DummyDataService.getPostsByUser(widget.userId);
        }
      } else {
        _userData['followers_count'] = (_userData['followers_count'] ?? 0) - 1;
        if (_userData['is_private'] == true) {
          _userPosts = [];
        }
      }
      _userData['is_following'] = _isFollowing;

      DummyDataService.toggleFollow(widget.userId);
    });
  }

  void _sendMessage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ChatScreen(),
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
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
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: AppColors.lightSurface),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Text(
                      widget.userName,
                      style: const TextStyle(
                        color: AppColors.lightSurface,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.more_vert, color: AppColors.lightSurface),
                    onPressed: () {
                      _showUserOptions();
                    },
                  ),
                ],
              ),
            ),

            // Profile Content
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // Profile Info Section
                    Container(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          // Profile Picture and Stats
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 50,
                                backgroundColor: AppColors.primary.withOpacity(0.2),
                                child: Text(
                                  widget.userAvatar,
                                  style: const TextStyle(fontSize: 40),
                                ),
                              ),
                              const SizedBox(width: 30),
                              Expanded(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                                  children: [
                                    _buildStatColumn('Posts', _userData['posts_count'].toString()),
                                    _buildStatColumn('Followers', _formatNumber(_userData['followers_count'] ?? 0)),
                                    _buildStatColumn('Following', _userData['following_count'].toString()),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          // Username and Bio
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.userName,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.accent,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _userData['username'] ?? '@user',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _userData['bio'] ?? 'No bio available',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: AppColors.accent,
                                    height: 1.5,
                                  ),
                                ),
                                if (_userData['is_private'] == true)
                                  Container(
                                    margin: const EdgeInsets.only(top: 8),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[100],
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.lock, size: 14, color: Colors.grey[600]),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Private Account',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          // Action Buttons
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: _toggleFollow,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _isFollowing ? Colors.grey[300] : AppColors.primary,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  child: Text(
                                    _isFollowing ? 'Following' : 'Follow',
                                    style: TextStyle(
                                      color: _isFollowing ? AppColors.textMain : AppColors.lightSurface,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              OutlinedButton(
                                onPressed: _sendMessage,
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: AppColors.primary, width: 2),
                                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: const Icon(Icons.message, color: AppColors.primary),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Tabs
                    Container(
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: Colors.grey[200]!),
                        ),
                      ),
                      child: TabBar(
                        controller: _tabController,
                        labelColor: AppColors.primary,
                        unselectedLabelColor: Colors.grey,
                        indicatorColor: AppColors.primary,
                        tabs: const [
                          Tab(icon: Icon(Icons.grid_on)),
                          Tab(icon: Icon(Icons.play_circle_outline)),
                        ],
                      ),
                    ),

                    // Tab Content
                    SizedBox(
                      height: 300,
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          // Posts Grid
                          _userPosts.isEmpty
                              ? _buildEmptyState(
                            icon: Icons.photo_library,
                            message: _userData['is_private'] == true && !_isFollowing
                                ? 'This account is private\nFollow to see their posts'
                                : 'No posts yet',
                          )
                              : GridView.builder(
                            padding: const EdgeInsets.all(2),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 2,
                              mainAxisSpacing: 2,
                            ),
                            itemCount: _userPosts.length,
                            itemBuilder: (context, index) {
                              return _buildPostThumbnail(_userPosts[index]);
                            },
                          ),
                          // Videos
                          _userPosts.isEmpty
                              ? _buildEmptyState(
                            icon: Icons.video_library,
                            message: _userData['is_private'] == true && !_isFollowing
                                ? 'This account is private\nFollow to see their videos'
                                : 'No videos yet',
                          )
                              : GridView.builder(
                            padding: const EdgeInsets.all(2),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 2,
                              mainAxisSpacing: 2,
                            ),
                            itemCount: _userPosts.length,
                            itemBuilder: (context, index) {
                              return _buildVideoThumbnail(_userPosts[index]);
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState({required IconData icon, required String message}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 60, color: Colors.grey[300]),
          const SizedBox(height: 20),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatColumn(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.accent,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildPostThumbnail(Map<String, dynamic> post) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            post['thumbnail_url'] ?? 'https://picsum.photos/400/400',
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                color: Colors.grey[200],
                child: const Icon(Icons.error, color: Colors.grey),
              );
            },
          ),
          Positioned(
            bottom: 5,
            left: 5,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.textMain.withOpacity(0.7),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  const Icon(Icons.favorite, size: 12, color: AppColors.lightSurface),
                  const SizedBox(width: 4),
                  Text(
                    _formatNumber(post['likes_count'] ?? 0),
                    style: const TextStyle(
                      color: AppColors.lightSurface,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoThumbnail(Map<String, dynamic> post) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            post['thumbnail_url'] ?? 'https://picsum.photos/400/400',
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                color: Colors.grey[200],
                child: const Icon(Icons.error, color: Colors.grey),
              );
            },
          ),
          Center(
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.textMain.withOpacity(0.6),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.play_arrow, color: AppColors.lightSurface, size: 30),
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

  void _showUserOptions() {
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
              leading: const Icon(Icons.block, color: Colors.red),
              title: const Text('Block User', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _showBlockDialog();
              },
            ),
            ListTile(
              leading: const Icon(Icons.report, color: Colors.orange),
              title: const Text('Report User'),
              onTap: () {
                Navigator.pop(context);
                _showReportDialog();
              },
            ),
            ListTile(
              leading: const Icon(Icons.share, color: AppColors.primary),
              title: const Text('Share Profile'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Profile link copied!')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showBlockDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Block User'),
        content: Text('Are you sure you want to block ${widget.userName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${widget.userName} has been blocked')),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Block', style: TextStyle(color: AppColors.lightSurface)),
          ),
        ],
      ),
    );
  }

  void _showReportDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Report User'),
        content: const Text('Please select a reason for reporting this user.'),
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

