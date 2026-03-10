import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuth, User;
import 'package:tapmate/Screen/Auth/LoginScreen.dart';
import 'package:tapmate/Screen/home/create_post_screen.dart';
import 'package:tapmate/Screen/home/edit_profile_screen.dart';
import 'package:tapmate/Screen/home/followers_screen.dart';
import 'package:tapmate/Screen/home/following_screen.dart';
import 'package:tapmate/Screen/home/post_detail_screen.dart';
import 'package:tapmate/Screen/home/saved_posts_screen.dart';
import 'package:tapmate/Screen/home/other_user_profile_screen.dart';
import 'package:tapmate/Screen/constants/app_colors.dart';
import 'package:tapmate/auth_provider.dart' as myAuth;
import 'package:tapmate/theme_provider.dart';

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isFollowing = false;
  bool _isLoading = true;
  String? _error;

  // Data variables
  Map<String, dynamic> _userData = {};
  List<Map<String, dynamic>> _posts = [];
  List<Map<String, dynamic>> _savedPosts = [];

  // Counts
  int _postsCount = 0;
  int _followersCount = 0;
  int _followingCount = 0;

  // Firebase
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadUserData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      User? currentUser = _auth.currentUser;
      if (currentUser == null) {
        setState(() {
          _isLoading = false;
          _error = 'No user logged in';
        });
        return;
      }

      print('Loading user data for: ${currentUser.uid}');

      // Get user document from Firestore
      DocumentSnapshot userDoc = await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .get();

      if (userDoc.exists) {
        // Safely extract data with null checks
        Map<String, dynamic> data = userDoc.data() as Map<String, dynamic>? ?? {};

        setState(() {
          _userData = {
            'id': currentUser.uid,
            'email': currentUser.email ?? '',
            'name': data['name'] ?? currentUser.displayName ?? 'User',
            'username': data['username'] ?? currentUser.email?.split('@').first ?? 'user',
            'bio': data['bio'] ?? 'No bio added yet',
            'profile_pic': data['profile_pic'] ?? '',
            'phone': data['phone'] ?? '',
            'gender': data['gender'] ?? '',
            'dob': data['dob'] ?? '',
            'posts_count': data['posts_count'] ?? 0,
            'followers_count': data['followers_count'] ?? 0,
            'following_count': data['following_count'] ?? 0,
            'is_private': data['is_private'] ?? false,
            'createdAt': data['createdAt'],
          };

          _postsCount = _userData['posts_count'];
          _followersCount = _userData['followers_count'];
          _followingCount = _userData['following_count'];
        });

        print('✅ User data loaded successfully');
        print('Bio: ${_userData['bio']}');

        // Load user posts
        await _loadUserPosts(currentUser.uid);
        // Load saved posts
        await _loadSavedPosts(currentUser.uid);
      } else {
        print('User document not found, creating...');
        // Create user document if it doesn't exist
        await _createUserDocument(currentUser);
        await _loadUserData(); // Retry
      }
    } catch (e) {
      print('❌ Error loading user data: $e');
      setState(() {
        _error = 'Failed to load profile: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _createUserDocument(User user) async {
    try {
      print('Creating user document for: ${user.uid}');

      Map<String, dynamic> userData = {
        'name': user.displayName ?? 'User',
        'email': user.email ?? '',
        'username': user.email?.split('@').first ?? 'user',
        'bio': 'No bio added yet',  // ← DEFAULT VALUE
        'profile_pic': '',
        'phone': '',
        'gender': '',
        'posts_count': 0,
        'followers_count': 0,
        'following_count': 0,
        'is_private': false,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await _firestore.collection('users').doc(user.uid).set(userData);
      print('✅ User document created successfully');
    } catch (e) {
      print('❌ Error creating user document: $e');
    }
  }

  // user_profile_screen.dart mein yeh method replace karo

  Future<void> _loadUserPosts(String userId) async {
    try {
      QuerySnapshot postsSnapshot = await _firestore
          .collection('posts')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(20)
          .get();

      setState(() {
        _posts = postsSnapshot.docs.map((doc) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          return {
            'id': doc.id,
            'userId': data['userId'] ?? '',
            'caption': data['caption'] ?? '',
            'thumbnail': data['thumbnailUrl'] ?? '',
            'videoUrl': data['videoUrl'],
            'likes': data['likes'] ?? 0,
            'comments': data['comments'] ?? 0,
            'isVideo': data['isVideo'] ?? false,
            'createdAt': data['createdAt'],
          };
        }).toList();
      });
    } catch (e) {
      print('Error loading posts: $e');
    }
  }

  Future<void> _loadSavedPosts(String userId) async {
    try {
      QuerySnapshot savedSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('saved_posts')
          .orderBy('savedAt', descending: true)
          .get();

      List<Map<String, dynamic>> savedList = [];
      for (var doc in savedSnapshot.docs) {
        // Get the actual post data
        String postId = doc['postId'];
        DocumentSnapshot postDoc = await _firestore
            .collection('posts')
            .doc(postId)
            .get();

        if (postDoc.exists) {
          Map<String, dynamic> postData = postDoc.data() as Map<String, dynamic>? ?? {};
          savedList.add({
            'id': postId,
            'userId': postData['userId'] ?? '',
            'title': postData['title'] ?? '',
            'thumbnail': postData['thumbnail'] ?? '',
            'likes': postData['likes'] ?? 0,
            'comments': postData['comments'] ?? 0,
          });
        }
      }

      setState(() {
        _savedPosts = savedList;
      });
    } catch (e) {
      print('Error loading saved posts: $e');
    }
  }

  Future<void> _logout() async {
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
            onPressed: () async {
              Navigator.pop(context); // Close dialog

              final authProvider = Provider.of<myAuth.AuthProvider>(context, listen: false);
              await authProvider.logout();

              if (mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                      (route) => false,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Log Out', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  String _getInitials(String name) {
    if (name.isEmpty) return 'U';
    List<String> parts = name.split(' ');
    if (parts.length > 1) {
      return parts[0][0] + parts[1][0];
    }
    return name[0];
  }

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }

  Widget _buildProfilePicture() {
    if (_userData['profile_pic'] != null && _userData['profile_pic'].toString().isNotEmpty) {
      return Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white,
            width: 3,
          ),
          image: DecorationImage(
            image: NetworkImage(_userData['profile_pic']),
            fit: BoxFit.cover,
          ),
        ),
      );
    } else {
      return Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [AppColors.primary, AppColors.secondary],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(
            color: Colors.white,
            width: 3,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Center(
          child: Text(
            _getInitials(_userData['name'] ?? ''),
            style: const TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      );
    }
  }

  Widget _buildStatColumn(String label, String value, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white
                  : AppColors.accent,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.grey[400]
                  : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostThumbnail(Map<String, dynamic> post) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PostDetailScreen(postId: post['id']),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.withOpacity(0.2)),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Thumbnail image
            if (post['thumbnail'] != null && post['thumbnail'].toString().isNotEmpty)
              Image.network(
                post['thumbnail'],
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey[300],
                    child: const Icon(Icons.broken_image, color: Colors.grey),
                  );
                },
              )
            else
              Container(
                color: Colors.grey[300],
                child: const Icon(Icons.image, color: Colors.grey),
              ),

            // Likes count
            Positioned(
              bottom: 5,
              left: 5,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.favorite, size: 12, color: Colors.white),
                    const SizedBox(width: 4),
                    Text(
                      _formatNumber(post['likes'] ?? 0),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Comments count
            Positioned(
              bottom: 5,
              right: 5,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.comment, size: 12, color: Colors.white),
                    const SizedBox(width: 4),
                    Text(
                      _formatNumber(post['comments'] ?? 0),
                      style: const TextStyle(
                        color: Colors.white,
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

  Widget _buildVideoThumbnail(Map<String, dynamic> post) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PostDetailScreen(postId: post['id']),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.withOpacity(0.2)),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (post['thumbnail'] != null && post['thumbnail'].toString().isNotEmpty)
              Image.network(
                post['thumbnail'],
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey[300],
                    child: const Icon(Icons.video_library, color: Colors.grey),
                  );
                },
              )
            else
              Container(
                color: Colors.grey[300],
                child: const Icon(Icons.video_library, color: Colors.grey),
              ),

            Center(
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_arrow,
                  color: Colors.white,
                  size: 30,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message, IconData icon) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 60,
            color: isDark ? Colors.grey[600] : Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 16,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  void _showProfileOptions() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: isDark ? const Color(0xFF2C2C2C) : Colors.white,
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
                  MaterialPageRoute(
                    builder: (context) => EditProfileScreen(userData: _userData),
                  ),
                ).then((value) {
                  if (value == true) {
                    _loadUserData();
                  }
                });
              },
            ),
            ListTile(
              leading: const Icon(Icons.bookmark, color: AppColors.primary),
              title: const Text('Saved Posts'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SavedPostsScreen(),
                  ),
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
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Log Out', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _logout();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showShareProfile() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: isDark ? const Color(0xFF2C2C2C) : Colors.white,
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
                  // Implement share functionality
                }),
                _buildShareOption(Icons.qr_code, 'QR Code', () {
                  Navigator.pop(context);
                  // Show QR code
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

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<myAuth.AuthProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isGuest = authProvider.isGuest;
    final isDarkMode = themeProvider.isDarkMode;

    // Guest mode UI
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
                      color: isDarkMode ? Colors.white : AppColors.accent,
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
                        color: Colors.white,
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

    // Loading state
    if (_isLoading) {
      return Scaffold(
        backgroundColor: isDarkMode ? const Color(0xFF121212) : AppColors.lightSurface,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 20),
              Text(
                'Loading profile...',
                style: TextStyle(
                  color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Error state
    if (_error != null) {
      return Scaffold(
        backgroundColor: isDarkMode ? const Color(0xFF121212) : AppColors.lightSurface,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 60, color: Colors.red),
              const SizedBox(height: 20),
              Text(
                _error!,
                style: const TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _loadUserData,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    // Main profile UI - FIXED BOTTOM OVERFLOW
    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF121212) : AppColors.lightSurface,
      body: SafeArea(
        child: Column(
          children: [
            // Header with gradient - FIXED HEIGHT
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
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Expanded(
                    child: Text(
                      'Profile',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.more_vert, color: Colors.white),
                    onPressed: _showProfileOptions,
                  ),
                ],
              ),
            ),

            // Profile Content - TAKES REMAINING SPACE
            Expanded(
              child: Column(
                children: [
                  // Profile Info Section - FIXED
                  Container(
                    padding: const EdgeInsets.all(15),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Profile Picture and Stats Row
                        Row(
                          children: [
                            // Profile Picture
                            _buildProfilePicture(),
                            const SizedBox(width: 5),

                            // Stats
                            Expanded(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: [
                                  // Posts
                                  _buildStatColumn(
                                    'Posts',
                                    _formatNumber(_postsCount),
                                        () => _tabController.animateTo(0),
                                  ),

                                  // Followers
                                  _buildStatColumn(
                                    'Followers',
                                    _formatNumber(_followersCount),
                                        () async {
                                      // Navigate to followers screen
                                    },
                                  ),

                                  // Following
                                  _buildStatColumn(
                                    'Following',
                                    _formatNumber(_followingCount),
                                        () async {
                                      // Navigate to following screen
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 25),

                        // Username and Bio
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _userData['name'] ?? 'Your Name',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: isDarkMode ? Colors.white : AppColors.accent,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '@${_userData['username'] ?? 'username'}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _userData['bio'] ?? 'No bio added yet',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isDarkMode ? Colors.grey[300] : AppColors.textMain,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Private account badge
                        if (_userData['is_private'] == true)
                          Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: isDarkMode ? Colors.grey[800] : Colors.grey[100],
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.lock,
                                  size: 14,
                                  color: isDarkMode ? Colors.white : Colors.grey[600],
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Private Account',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDarkMode ? Colors.white : Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // Action Buttons
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () async {
                                  final result = await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => EditProfileScreen(userData: _userData),
                                    ),
                                  );
                                  if (result == true) {
                                    _loadUserData();
                                  }
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
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            OutlinedButton(
                              onPressed: _showShareProfile,
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

                  // Tabs - FIXED
                  Container(
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: isDarkMode ? Colors.grey[800]! : Colors.grey.withOpacity(0.1),
                        ),
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

                  // Tab Content - EXPANDED
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        // Posts Grid
                        _posts.isEmpty
                            ? _buildEmptyState('No posts yet', Icons.photo_library)
                            : GridView.builder(
                          padding: const EdgeInsets.all(2),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 2,
                            mainAxisSpacing: 2,
                          ),
                          itemCount: _posts.length,
                          itemBuilder: (context, index) {
                            return _buildPostThumbnail(_posts[index]);
                          },
                        ),

                        // Videos/Reels
                        _posts.isEmpty
                            ? _buildEmptyState('No videos yet', Icons.video_library)
                            : GridView.builder(
                          padding: const EdgeInsets.all(2),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 2,
                            mainAxisSpacing: 2,
                          ),
                          itemCount: _posts.length,
                          itemBuilder: (context, index) {
                            return _buildVideoThumbnail(_posts[index]);
                          },
                        ),

                        // Saved Posts
                        _savedPosts.isEmpty
                            ? _buildEmptyState('No saved posts', Icons.bookmark_border)
                            : GridView.builder(
                          padding: const EdgeInsets.all(2),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 2,
                            mainAxisSpacing: 2,
                          ),
                          itemCount: _savedPosts.length,
                          itemBuilder: (context, index) {
                            return _buildPostThumbnail(_savedPosts[index]);
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Create Post Button - FIXED BOTTOM
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
                border: Border(
                  top: BorderSide(
                    color: isDarkMode ? Colors.grey[800]! : Colors.grey.withOpacity(0.1),
                  ),
                ),
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => CreatePostScreen()),
                    ).then((_) => _loadUserData());
                  },
                  icon: const Icon(Icons.add_circle_outline, size: 22),
                  label: const Text(
                    'Create Post',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),

            // Bottom Navigation - FIXED
            Container(
              height: 70,
              decoration: BoxDecoration(
                color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildNavItem(Icons.home_rounded, 'Home', false),
                  _buildNavItem(Icons.explore_rounded, 'Discover', false),
                  _buildNavItem(Icons.feed_rounded, 'Feed', false),
                  _buildNavItem(Icons.message_rounded, 'Message', false),
                  _buildNavItem(Icons.person_rounded, 'Profile', true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, bool isActive) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
          // Already on profile
        }
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: isActive
                ? AppColors.primary
                : (isDark ? Colors.grey[600] : Colors.grey),
            size: 24,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isActive
                  ? AppColors.primary
                  : (isDark ? Colors.grey[600] : Colors.grey),
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}