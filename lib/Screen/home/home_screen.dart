import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuth, User;
import 'package:tapmate/Screen/constants/app_colors.dart';
import 'package:tapmate/Screen/home/tour_screen.dart';
import 'package:tapmate/Screen/utils/guide_manager.dart';
import 'package:tapmate/Screen/home/platform_selection_screen.dart';
import 'package:tapmate/auth_provider.dart' as myAuth;
import 'package:tapmate/theme_provider.dart';
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Variables for tutorial
  bool _showTutorial = false;
  int _currentStep = 0;
  bool _isLoading = true;

  // User data
  Map<String, dynamic> _userData = {};
  int _downloadsCount = 0;
  String _storageUsed = '0 GB';
  int _cloudUploads = 0;

  // Firebase
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<Map<String, dynamic>> _tutorialSteps = [
    {
      'title': '👤 Profile Icon',
      'message': 'Edit profile, see downloads & customize settings.',
      'position': 'top-right'
    },
    {
      'title': '📥 Download Dashboard',
      'message': 'Check download readiness and status.',
      'position': 'top-center'
    },
    {
      'title': '⬇️ Download Button',
      'message': 'Download videos from 10+ platforms.',
      'position': 'bottom-right'
    },
    {
      'title': '📊 Your Stats',
      'message': 'Track downloads, storage & cloud uploads.',
      'position': 'center'
    },
    {
      'title': '📁 Video Library',
      'message': 'Access & manage all downloaded videos.',
      'position': 'center-left'
    },
    {
      'title': '⚙️ Settings',
      'message': 'Customize app preferences & dark mode.',
      'position': 'center-right'
    },
    {
      'title': '📍 Navigation',
      'message': 'Switch between Home, Discover, Feed & Profile.',
      'position': 'bottom-center'
    },
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUserData();
      _checkAndShowTutorial();
    });
  }

  Future<void> _loadUserData() async {
    try {
      User? currentUser = _auth.currentUser;
      if (currentUser != null) {
        DocumentSnapshot userDoc = await _firestore
            .collection('users')
            .doc(currentUser.uid)
            .get();

        if (userDoc.exists) {
          Map<String, dynamic> data = userDoc.data() as Map<String, dynamic>? ?? {};
          setState(() {
            _userData = data;
            _downloadsCount = data['downloads_count'] ?? 247;
            _storageUsed = data['storage_used'] ?? '2.4 GB';
            _cloudUploads = data['cloud_uploads'] ?? 89;
          });
        }
      }
    } catch (e) {
      print('Error loading user data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

// Top par import add karo


// _checkAndShowTutorial method ko update karo:

  Future<void> _checkAndShowTutorial() async {
    final authProvider = Provider.of<myAuth.AuthProvider>(context, listen: false);

    if (authProvider.isGuest) {
      setState(() => _isLoading = false);
      return;
    }

    final userId = authProvider.userId;

    // Check if user has seen tutorial
    final hasUserCompleted = await GuideManager.hasUserCompletedGuide(userId);

    if (hasUserCompleted) {
      print('User has already seen tutorial - Skipping');
      setState(() => _isLoading = false);
      return;
    }

    print('First-time user - Showing tutorial');

    setState(() => _isLoading = false);

    // Wait for UI to render
    await Future.delayed(const Duration(milliseconds: 500));

    if (!mounted) return;

    // Show tour screen
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => TourScreen(
        onComplete: () async {
          Navigator.pop(context);
          await _markTutorialCompleted();
        },
      ),
    );
  }

  void _nextTutorialStep() {
    setState(() {
      if (_currentStep < _tutorialSteps.length - 1) {
        _currentStep++;
      } else {
        // Tutorial completed
        _showTutorial = false;
        _markTutorialCompleted();
      }
    });
  }

  void _skipTutorial() {
    setState(() {
      _showTutorial = false;
    });
    _markTutorialCompleted();
  }

  Future<void> _markTutorialCompleted() async {
    final authProvider = Provider.of<myAuth.AuthProvider>(context, listen: false);
    final userId = authProvider.userId;

    if (userId.isNotEmpty && userId != 'guest') {
      await GuideManager.completeGuideForUser(userId);
      print('Tutorial marked as completed for user: $userId');
    }
  }

  Widget _buildTutorialDialog() {
    if (!_showTutorial) return const SizedBox.shrink();

    final currentStep = _tutorialSteps[_currentStep];
    final position = currentStep['position'] as String;

    double top = 100;
    double left = 20;
    String arrowPosition = 'bottom';
    double arrowOffset = 20;

    switch (position) {
      case 'top-right':
        top = 80;
        left = MediaQuery.of(context).size.width - 240;
        arrowPosition = 'bottom';
        arrowOffset = 30;
        break;
      case 'top-center':
        top = 150;
        left = MediaQuery.of(context).size.width / 2 - 110;
        arrowPosition = 'bottom';
        arrowOffset = 110;
        break;
      case 'bottom-right':
        top = MediaQuery.of(context).size.height - 180;
        left = MediaQuery.of(context).size.width - 240;
        arrowPosition = 'left';
        arrowOffset = 50;
        break;
      case 'center':
        top = MediaQuery.of(context).size.height / 2 - 90;
        left = MediaQuery.of(context).size.width / 2 - 110;
        arrowPosition = 'bottom';
        arrowOffset = 110;
        break;
      case 'center-left':
        top = MediaQuery.of(context).size.height / 2 - 90;
        left = 20;
        arrowPosition = 'bottom';
        arrowOffset = 30;
        break;
      case 'center-right':
        top = MediaQuery.of(context).size.height / 2 - 90;
        left = MediaQuery.of(context).size.width - 240;
        arrowPosition = 'bottom';
        arrowOffset = 30;
        break;
      case 'bottom-center':
        top = MediaQuery.of(context).size.height - 150;
        left = MediaQuery.of(context).size.width / 2 - 110;
        arrowPosition = 'top';
        arrowOffset = 110;
        break;
    }

    return Positioned(
      top: top,
      left: left,
      child: Material(
        color: Colors.transparent,
        elevation: 8,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 240,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.lightSurface,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${_currentStep + 1}/${_tutorialSteps.length}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: _skipTutorial,
                        icon: const Icon(Icons.close, size: 18),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        color: Colors.grey,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    currentStep['title'],
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textMain,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    currentStep['message'],
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textMain,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _nextTutorialStep,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      child: Text(
                        _currentStep < _tutorialSteps.length - 1 ? 'Next →' : 'Get Started!',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Arrow
            if (arrowPosition == 'bottom')
              Positioned(
                bottom: -8,
                left: arrowOffset,
                child: Icon(Icons.arrow_drop_down, size: 24, color: AppColors.lightSurface),
              ),
            if (arrowPosition == 'top')
              Positioned(
                top: -8,
                left: arrowOffset,
                child: Transform.rotate(
                  angle: 3.14,
                  child: Icon(Icons.arrow_drop_down, size: 24, color: AppColors.lightSurface),
                ),
              ),
            if (arrowPosition == 'left')
              Positioned(
                left: -8,
                top: arrowOffset,
                child: Transform.rotate(
                  angle: 1.57,
                  child: Icon(Icons.arrow_drop_down, size: 24, color: AppColors.lightSurface),
                ),
              ),
            if (arrowPosition == 'right')
              Positioned(
                right: -8,
                top: arrowOffset,
                child: Transform.rotate(
                  angle: -1.57,
                  child: Icon(Icons.arrow_drop_down, size: 24, color: AppColors.lightSurface),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Helper method for guest users
  void showLockedFeatureDialog(BuildContext context, String feature, bool isDarkMode) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : AppColors.lightSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          '$feature Locked 🔒',
          style: TextStyle(
            color: isDarkMode ? AppColors.lightSurface : AppColors.accent,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sign up to unlock:',
              style: TextStyle(
                color: isDarkMode ? Colors.grey[300] : AppColors.accent,
              ),
            ),
            const SizedBox(height: 10),
            _buildFeatureItem('📥 Download videos from 10+ platforms'),
            _buildFeatureItem('👤 Create your profile & connect with others'),
            _buildFeatureItem('💬 Chat with the community'),
            _buildFeatureItem('☁️ Save videos to cloud storage'),
            _buildFeatureItem('📊 Track your download history'),
          ],
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    backgroundColor: isDarkMode ? Colors.grey[800] : Colors.grey[100],
                  ),
                  child: Text(
                    'Maybe Later',
                    style: TextStyle(
                      color: isDarkMode ? AppColors.lightSurface : AppColors.textMain,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/login');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text(
                    'Sign Up Now',
                    style: TextStyle(color: AppColors.lightSurface),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.check_circle, size: 16, color: Colors.green),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13),
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

    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.rosePink,
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.rosePink,
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      children: [
                        // Header
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                AppColors.accent,
                                AppColors.secondary,
                                AppColors.primary,
                              ],
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
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'TapMate',
                                        style: TextStyle(
                                          fontSize: 32,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.lightSurface,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      SizedBox(
                                        width: MediaQuery.of(context).size.width * 0.7,
                                        child: Text(
                                          'Download and share videos from any platform',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: AppColors.lightSurface.withOpacity(0.9),
                                            fontWeight: FontWeight.w500,
                                          ),
                                          maxLines: 2,
                                        ),
                                      ),
                                    ],
                                  ),
                                  // Profile Icon
                                  if (!isGuest)
                                    GestureDetector(
                                      onTap: () {
                                        Navigator.pushNamed(context, '/profile');
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: AppColors.lightSurface.withOpacity(0.15),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: AppColors.lightSurface.withOpacity(0.3),
                                            width: 2,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.person_rounded,
                                          color: AppColors.lightSurface,
                                          size: 24,
                                        ),
                                      ),
                                    )
                                  else
                                    GestureDetector(
                                      onTap: () => showLockedFeatureDialog(context, 'Profile', isDarkMode),
                                      child: Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: AppColors.lightSurface.withOpacity(0.15),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: AppColors.lightSurface.withOpacity(0.3),
                                            width: 2,
                                          ),
                                        ),
                                        child: Stack(
                                          children: [
                                            const Icon(
                                              Icons.person_rounded,
                                              color: AppColors.lightSurface,
                                              size: 24,
                                            ),
                                            Positioned(
                                              right: -2,
                                              top: -2,
                                              child: Icon(
                                                Icons.lock,
                                                color: AppColors.lightSurface,
                                                size: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 30),

                              // Ready to Download Card
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: AppColors.lightSurface.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: AppColors.lightSurface.withOpacity(0.25),
                                    width: 1.5,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: AppColors.lightSurface,
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: const Icon(
                                        Icons.download_rounded,
                                        color: AppColors.primary,
                                        size: 28,
                                      ),
                                    ),
                                    const SizedBox(width: 15),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Ready to Download',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.lightSurface,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            isGuest
                                                ? 'Sign up to unlock downloads'
                                                : 'Tap the floating button to start',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: AppColors.lightSurface.withOpacity(0.8),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Stats Section
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Row(
                            children: [
                              _buildEqualStatCard(
                                icon: Icons.download_done_rounded,
                                title: 'Total Downloads',
                                value: isGuest ? '0' : _downloadsCount.toString(),
                                color: AppColors.primary,
                                isGuest: isGuest,
                              ),
                              const SizedBox(width: 12),
                              _buildEqualStatCard(
                                icon: Icons.storage_rounded,
                                title: 'Storage Used',
                                value: isGuest ? '0 GB' : _storageUsed,
                                color: AppColors.secondary,
                                isGuest: isGuest,
                              ),
                              const SizedBox(width: 12),
                              _buildEqualStatCard(
                                icon: Icons.cloud_upload_rounded,
                                title: 'Cloud Uploads',
                                value: isGuest ? '0' : _cloudUploads.toString(),
                                color: AppColors.accent,
                                isGuest: isGuest,
                                isLocked: isGuest,
                              ),
                            ],
                          ),
                        ),

                        // Quick Actions Section
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Quick Actions',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.secondary,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildEqualQuickAction(
                                      icon: Icons.video_library_rounded,
                                      label: 'Library',
                                      subtitle: 'Manage your downloads',
                                      color: AppColors.primary,
                                      isLocked: isGuest,
                                      onTap: () {
                                        if (isGuest) {
                                          showLockedFeatureDialog(context, 'Library', isDarkMode);
                                        } else {
                                          Navigator.pushNamed(context, '/library');
                                        }
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _buildEqualQuickAction(
                                      icon: Icons.settings_rounded,
                                      label: 'Settings',
                                      subtitle: 'App preferences',
                                      color: AppColors.secondary,
                                      isLocked: false,
                                      onTap: () {
                                        Navigator.pushNamed(context, '/settings');
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 25),

                        // Recent Downloads Section
                        // Recent Downloads Section - FIXED VERSION
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 20),
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: isDarkMode ? const Color(0xFF1E1E1E) : AppColors.lightSurface,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.1),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.history_rounded, color: AppColors.primary, size: 24),
                                  const SizedBox(width: 10),
                                  Text(
                                    'Recent Downloads',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: isDarkMode ? AppColors.lightSurface : AppColors.secondary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              if (isGuest)
                                _buildEmptyState(
                                  icon: Icons.video_library_outlined,
                                  title: 'No downloads yet',
                                  subtitle: 'Sign up to start downloading videos!',
                                  isDarkMode: isDarkMode,
                                )
                              else
                                Column(
                                  children: [
                                    _buildDownloadItem('Video_001.mp4', '12 MB', Icons.video_file_rounded, isDarkMode),
                                    _buildDownloadItem('Short_Clip.mp4', '8 MB', Icons.movie_rounded, isDarkMode),
                                    _buildDownloadItem('Tutorial.mp4', '45 MB', Icons.school_rounded, isDarkMode),
                                    _buildDownloadItem('Music_Video.mp4', '32 MB', Icons.music_video_rounded, isDarkMode),
                                  ],
                                ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 80),
                      ],
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
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildNavItem(Icons.home_rounded, 'Home', true, context, isGuest, isDarkMode),
                      _buildNavItem(Icons.explore_rounded, 'Discover', false, context, isGuest, isDarkMode),
                      _buildNavItem(Icons.feed_rounded, 'Feed', false, context, isGuest, isDarkMode),
                      _buildNavItem(Icons.message_rounded, 'Message', false, context, isGuest, isDarkMode),
                      _buildNavItem(Icons.person_rounded, 'Profile', false, context, isGuest, isDarkMode),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Floating Action Button
          Positioned(
            right: 20,
            bottom: 100,
            child: FloatingActionButton(
              onPressed: () {
                if (isGuest) {
                  showLockedFeatureDialog(context, 'Download', isDarkMode);
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const PlatformSelectionScreen(),
                    ),
                  );
                }
              },
              backgroundColor: isGuest ? Colors.grey : AppColors.primary,
              foregroundColor: AppColors.lightSurface,
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Stack(
                children: [
                  const Icon(
                    Icons.download_rounded,
                    size: 28,
                  ),
                  if (isGuest)
                    const Positioned(
                      right: 0,
                      top: 0,
                      child: Icon(
                        Icons.lock,
                        size: 12,
                        color: Colors.white70,
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Tutorial Dialog
          _buildTutorialDialog(),
        ],
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isDarkMode,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          Icon(
            icon,
            size: 64,
            color: isDarkMode ? Colors.grey[600] : Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? AppColors.lightSurface : AppColors.accent,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEqualStatCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
    required bool isGuest,
    bool isLocked = false,
  }) {
    return Expanded(
      child: SizedBox(
        height: 130,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isLocked ? Colors.grey[100] : AppColors.lightSurface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
            border: Border.all(
              color: AppColors.accent.withOpacity(0.1),
            ),
          ),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      icon,
                      color: isLocked ? Colors.grey : color,
                      size: 20,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isLocked ? Colors.grey : color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
              if (isLocked)
                const Positioned(
                  top: 4,
                  right: 4,
                  child: Icon(
                    Icons.lock,
                    size: 14,
                    color: Colors.grey,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEqualQuickAction({
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required bool isLocked,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 140,
        decoration: BoxDecoration(
          color: isLocked ? Colors.grey[50] : color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isLocked ? Colors.grey.withOpacity(0.3) : color.withOpacity(0.2),
            width: 2,
          ),
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: isLocked ? Colors.grey[200] : color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          icon,
                          color: isLocked ? Colors.grey : color,
                          size: 20,
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: isLocked ? Colors.grey : color.withOpacity(0.6),
                        size: 14,
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: isLocked ? Colors.grey : AppColors.secondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (isLocked)
              const Positioned(
                top: 8,
                right: 8,
                child: Icon(
                  Icons.lock,
                  size: 16,
                  color: Colors.grey,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDownloadItem(String title, String size, IconData icon, bool isDarkMode) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF2C2C2C) : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: AppColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode ? AppColors.lightSurface : AppColors.textMain,
                  ),
                ),
                Text(
                  size,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'Completed',
              style: TextStyle(
                fontSize: 10,
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(
      IconData icon,
      String label,
      bool isActive,
      BuildContext context,
      bool isGuest,
      bool isDarkMode,
      ) {
    final isDisabled = isGuest && (label == 'Message' || label == 'Profile');

    return GestureDetector(
      onTap: isDisabled
          ? () {
        showLockedFeatureDialog(context, label, isDarkMode);
      }
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
      child: Opacity(
        opacity: isDisabled ? 0.5 : 1.0,
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
                if (isDisabled)
                  const Positioned(
                    right: -4,
                    top: -4,
                    child: Icon(
                      Icons.lock,
                      size: 12,
                      color: Colors.grey,
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
      ),
    );
  }
}