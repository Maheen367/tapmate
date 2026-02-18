import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tapmate/Screen/Auth/LoginScreen.dart';
import 'package:tapmate/Screen/home/create_post_screen.dart';
import 'package:tapmate/Screen/home/edit_profile_screen.dart';
import 'package:tapmate/Screen/home/followers_screen.dart';
import 'package:tapmate/Screen/home/following_screen.dart';
import 'package:tapmate/Screen/home/post_detail_screen.dart'; // ✅ ADD THIS IMPORT
import 'package:tapmate/Screen/home/saved_posts_screen.dart';
import 'package:tapmate/Screen/home/other_user_profile_screen.dart';
import 'package:tapmate/Screen/services/dummy_data_service.dart';
import '../../auth_provider.dart';
import '../../theme_provider.dart';
import 'package:tapmate/Screen/constants/app_colors.dart';


class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isFollowing = false;

  // Data variables
  late Map<String, dynamic> _currentUser;
  int _postsCount = 0;
  int _followersCount = 0;
  int _followingCount = 0;

  // Posts data
  late List<Map<String, dynamic>> _posts;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadUserData();
  }

  void _loadUserData() {
    setState(() {
      _currentUser = DummyDataService.currentUser;
      _posts = DummyDataService.getFeedPosts();
      _postsCount = _currentUser['posts_count'] ?? 0;
      _followersCount = _currentUser['followers_count'] ?? 0;
      _followingCount = _currentUser['following_count'] ?? 0;
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isGuest = authProvider.isGuest;
    final isDarkMode = themeProvider.isDarkMode;

    if (isGuest) {
      return Scaffold(
        backgroundColor: isDarkMode ? const Color(0xFF121212) : AppColors.lightSurface,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.person_off_outlined,
                    size: 80,
                    color: AppColors.primary,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Sign In Required',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? AppColors.lightSurface : AppColors.accent,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Please sign in to access your profile and view your posts.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 30),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pushReplacementNamed(context, '/home');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                    ),
                    child: const Text(
                      'Go to Home',
                      style: TextStyle(
                        color: AppColors.lightSurface,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF121212) : AppColors.lightSurface,
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
                  const Expanded(
                    child: Text(
                      'Profile',
                      style: TextStyle(
                        color: AppColors.lightSurface,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.more_vert, color: AppColors.lightSurface),
                    onPressed: () {
                      _showProfileOptions();
                    },
                  ),
                ],
              ),
            ),

            // Profile Content
            Expanded(
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
                            // Profile Picture
                            Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.lightSurface,
                                  width: 4,
                                ),
                                image: DecorationImage(
                                  image: NetworkImage(_currentUser['profile_pic_url']),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            const SizedBox(width: 30),
                            // Stats - WITH CLICKABLE FUNCTIONALITY
                            Expanded(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: [
                                  // Posts
                                  GestureDetector(
                                    onTap: () {
                                      // Posts tab already shows posts
                                      _tabController.animateTo(0);
                                    },
                                    child: _buildStatColumn('Posts', _postsCount.toString(), isDarkMode),
                                  ),
                                  // Followers - CLICKABLE
                                  GestureDetector(
                                    onTap: () {
                                      final followers = DummyDataService.getUserFollowers(_currentUser['id']);
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => FollowersScreen(
                                            followers: followers,
                                            onUserTap: (user) {
                                              // Navigate to other user's profile
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) => OtherUserProfileScreen(
                                                    userId: user['id']?.toString() ?? '',
                                                    userName: user['name']?.toString() ?? 'Unknown',
                                                    userAvatar: user['avatar']?.toString() ?? '👤',
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      );
                                    },
                                    child: _buildStatColumn('Followers', _formatNumber(_followersCount), isDarkMode),
                                  ),
                                  // Following - CLICKABLE
                                  GestureDetector(
                                    onTap: () {
                                      final following = DummyDataService.getUserFollowing(_currentUser['id']);
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => FollowingScreen(
                                            following: following,
                                            onUserTap: (user) {
                                              // Navigate to other user's profile
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) => OtherUserProfileScreen(
                                                    userId: user['id']?.toString() ?? '',
                                                    userName: user['name']?.toString() ?? 'Unknown',
                                                    userAvatar: user['avatar']?.toString() ?? '👤',
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      );
                                    },
                                    child: _buildStatColumn('Following', _followingCount.toString(), isDarkMode),
                                  ),
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
                                _currentUser['full_name'] ?? 'Your Name',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: isDarkMode ? AppColors.lightSurface : AppColors.accent,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '@${_currentUser['username'] ?? 'yourusername'}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _currentUser['bio'] ?? 'No bio added yet',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isDarkMode ? Colors.grey[300] : AppColors.accent,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        // In the profile info section, after bio
                        if (_currentUser['is_private'] == true)
                          Container(
                            margin: const EdgeInsets.only(top: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: isDarkMode ? Colors.grey[800] : Colors.grey[100],
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.lock, size: 14, color: isDarkMode ? AppColors.lightSurface : Colors.grey[600]),
                                const SizedBox(width: 6),
                                Text(
                                  'Private Account',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDarkMode ? AppColors.lightSurface : Colors.grey[600],
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
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => EditProfileScreen()),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: const Text(
                                  'Edit Profile',
                                  style: TextStyle(
                                    color: AppColors.lightSurface,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            OutlinedButton(
                              onPressed: () {
                                _showShareProfile();
                              },
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: AppColors.primary, width: 2),
                                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: const Icon(Icons.share, color: AppColors.primary),
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
                        bottom: BorderSide(color: Colors.grey.withOpacity(0.1)),
                      ),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      labelColor: AppColors.primary,
                      unselectedLabelColor: isDarkMode ? Colors.grey[400] : Colors.grey,
                      indicatorColor: AppColors.primary,
                      tabs: const [
                        Tab(icon: Icon(Icons.grid_on)),
                        Tab(icon: Icon(Icons.play_circle_outline)),
                        Tab(icon: Icon(Icons.bookmark_border)),
                      ],
                    ),
                  ),

                  // Tab Content
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        // Posts Grid
                        _posts.isEmpty
                            ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.photo_library, size: 60, color: isDarkMode ? Colors.grey[600] : Colors.grey[300]),
                              const SizedBox(height: 20),
                              Text(
                                'No posts yet',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: isDarkMode ? AppColors.lightSurface : AppColors.accent,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Share your first video or photo',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isDarkMode ? Colors.grey[400] : Colors.grey[500],
                                ),
                              ),
                              const SizedBox(height: 20),
                              ElevatedButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) =>  CreatePostScreen()),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                ),
                                child: const Text(
                                  'Create First Post',
                                  style: TextStyle(color: AppColors.lightSurface),
                                ),
                              ),
                            ],
                          ),
                        )
                            : GridView.builder(
                          padding: const EdgeInsets.all(2),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 2,
                            mainAxisSpacing: 2,
                          ),
                          itemCount: _posts.length,
                          itemBuilder: (context, index) {
                            return _buildPostThumbnail(_posts[index], isDarkMode);
                          },
                        ),
                        // Videos/Reels
                        _posts.isEmpty
                            ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.video_library, size: 60, color: isDarkMode ? Colors.grey[600] : Colors.grey[300]),
                              const SizedBox(height: 20),
                              Text(
                                'No videos yet',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: isDarkMode ? AppColors.lightSurface : AppColors.accent,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        )
                            : GridView.builder(
                          padding: const EdgeInsets.all(2),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 2,
                            mainAxisSpacing: 2,
                          ),
                          itemCount: _posts.length,
                          itemBuilder: (context, index) {
                            return _buildVideoThumbnail(_posts[index], isDarkMode);
                          },
                        ),
                        // Saved/Bookmarks
                        DummyDataService.getSavedPosts().isEmpty
                            ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.bookmark_border, size: 60, color: isDarkMode ? Colors.grey[600] : Colors.grey[300]),
                              const SizedBox(height: 20),
                              Text(
                                'No saved posts',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: isDarkMode ? AppColors.lightSurface : AppColors.accent,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Save posts to view them here',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isDarkMode ? Colors.grey[400] : Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                        )
                            : GridView.builder(
                          padding: const EdgeInsets.all(2),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 2,
                            mainAxisSpacing: 2,
                          ),
                          itemCount: DummyDataService.getSavedPosts().length,
                          itemBuilder: (context, index) {
                            final post = DummyDataService.getSavedPosts()[index];
                            return _buildPostThumbnail(post, isDarkMode);
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // FLOATING CREATE POST BUTTON - AT BOTTOM
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: isDarkMode ? const Color(0xFF1E1E1E) : AppColors.lightSurface,
                border: Border(
                  top: BorderSide(color: Colors.grey.withOpacity(0.1)),
                ),
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) =>  CreatePostScreen()),
                    );
                  },
                  icon: const Icon(Icons.add_circle_outline, size: 22),
                  label: const Text(
                    'Create Post',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.lightSurface,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                ),
              ),
            ),

            // Bottom Navigation Bar
            Container(
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
                  _buildNavItem(Icons.home_rounded, 'Home', false, context, isDarkMode),
                  _buildNavItem(Icons.explore_rounded, 'Discover', false, context, isDarkMode),
                  _buildNavItem(Icons.feed_rounded, 'Feed', false, context, isDarkMode),
                  _buildNavItem(Icons.message_rounded, 'Message', false, context, isDarkMode),
                  _buildNavItem(Icons.person_rounded, 'Profile', true, context, isDarkMode),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, bool isActive, BuildContext context, bool isDarkMode) {
    return GestureDetector(
      onTap: () {
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
          Icon(
            icon,
            color: isActive ? AppColors.primary : (isDarkMode ? Colors.grey[600]! : Colors.grey),
            size: 24,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isActive ? AppColors.primary : (isDarkMode ? Colors.grey[600]! : Colors.grey),
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatColumn(String label, String value, bool isDarkMode) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isDarkMode ? AppColors.lightSurface : AppColors.accent,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: isDarkMode ? Colors.grey[400]! : Colors.grey[600]!,
          ),
        ),
      ],
    );
  }

  Widget _buildPostThumbnail(Map<String, dynamic> post, bool isDarkMode) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PostDetailScreen(postId: post['id']?.toString() ?? ''),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.withOpacity(0.1)),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Image from dummy data
            Image.network(
              post['thumbnail_url']?.toString() ?? 'https://picsum.photos/400/400',
              fit: BoxFit.cover,
            ),

            // Likes overlay
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

            // Comments overlay
            Positioned(
              bottom: 5,
              right: 5,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.textMain.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.comment, size: 12, color: AppColors.lightSurface),
                    const SizedBox(width: 4),
                    Text(
                      _formatNumber(post['comments_count'] ?? 0),
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
      ),
    );
  }

  Widget _buildVideoThumbnail(Map<String, dynamic> post, bool isDarkMode) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PostDetailScreen(postId: post['id']?.toString() ?? ''),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.withOpacity(0.1)),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              post['thumbnail_url']?.toString() ?? 'https://picsum.photos/400/400',
              fit: BoxFit.cover,
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
      ),
    );
  }

  String _formatNumber(int number) {
    if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }

  void _showProfileOptions() {
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
              leading: const Icon(Icons.edit, color: AppColors.primary),
              title: const Text('Edit Profile'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) =>  EditProfileScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.bookmark, color: AppColors.primary),
              title: const Text('Saved Posts'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => SavedPostsScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings, color: AppColors.primary),
              title: const Text('Settings'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/settings');
              },
            ),
            ListTile(
              leading: const Icon(Icons.archive, color: AppColors.primary),
              title: const Text('Archive'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Log Out', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _showLogoutDialog();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showShareProfile() {
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
              'Share Profile',
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
                _buildShareOption(Icons.link, 'Copy Link', () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Profile link copied!')),
                  );
                }),
                _buildShareOption(Icons.share, 'Share', () {
                  Navigator.pop(context);
                }),
                _buildShareOption(Icons.qr_code, 'QR Code', () {
                  Navigator.pop(context);
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

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Log Out'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              // Close dialog
              Navigator.pop(context);

              // Get auth provider and logout
              final authProvider = Provider.of<AuthProvider>(context, listen: false);
              authProvider.logout();

              // Navigate directly to LoginScreen
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
                    (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Log Out', style: TextStyle(color: AppColors.lightSurface)),
          ),
        ],
      ),
    );
  }
}

