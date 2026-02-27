import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:tapmate/Screen/services/dummy_data_service.dart';
import 'package:tapmate/theme_provider.dart';
import 'package:tapmate/utils/guide_manager.dart';
import 'package:tapmate/auth_provider.dart';
import 'package:tapmate/Screen/Auth/LoginScreen.dart';
import 'package:tapmate/Screen/home/follow_requests_screen.dart';

// ==================== USER MODEL ====================
class UserModel {
  final String uid;
  final String fullName;
  final String email;
  final String username;
  final String profilePicUrl;
  final String? bio;
  final int followersCount;
  final int followingCount;
  final bool isPrivate;

  UserModel({
    required this.uid,
    required this.fullName,
    required this.email,
    required this.username,
    required this.profilePicUrl,
    this.bio,
    this.followersCount = 0,
    this.followingCount = 0,
    this.isPrivate = false,
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return UserModel(
      uid: doc.id,
      fullName: data['fullName'] ?? data['name'] ?? 'No Name',
      email: data['email'] ?? 'No Email',
      username: data['username'] ?? 'username',
      profilePicUrl: data['profilePic'] ?? data['profile_pic_url'] ?? '',
      bio: data['bio'],
      followersCount: (data['followers'] as List?)?.length ?? 0,
      followingCount: (data['following'] as List?)?.length ?? 0,
      isPrivate: data['isPrivateAccount'] ?? data['is_private'] ?? false,
    );
  }
}

// ==================== FIREBASE SERVICE CLASS ====================
class SettingsFirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;

  firebase_auth.User? get currentUser => _auth.currentUser;

  // Get current user data from Firestore
  Future<UserModel?> getCurrentUserData() async {
    try {
      if (currentUser == null) return null;

      DocumentSnapshot doc = await _firestore
          .collection('users')
          .doc(currentUser!.uid)
          .get();

      if (doc.exists) {
        return UserModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print('Error getting user data: $e');
      return null;
    }
  }

  // Load user settings from Firestore
  Future<Map<String, dynamic>> loadUserSettings() async {
    try {
      if (currentUser == null) return {};

      DocumentSnapshot doc = await _firestore
          .collection('users')
          .doc(currentUser!.uid)
          .get();

      if (doc.exists) {
        return doc.data() as Map<String, dynamic>;
      }
      return {};
    } catch (e) {
      print('Error loading settings: $e');
      return {};
    }
  }

  // Save user settings to Firestore
  Future<void> saveUserSettings(Map<String, dynamic> settings) async {
    try {
      if (currentUser == null) return;

      await _firestore
          .collection('users')
          .doc(currentUser!.uid)
          .set(settings, SetOptions(merge: true));
    } catch (e) {
      print('Error saving settings: $e');
      rethrow;
    }
  }

  // Update specific setting
  Future<void> updateSetting(String key, dynamic value) async {
    try {
      if (currentUser == null) return;

      await _firestore.collection('users').doc(currentUser!.uid).update({
        key: value,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating setting: $e');
      rethrow;
    }
  }

  // Get follow requests stream
  Stream<List<Map<String, dynamic>>> getFollowRequests() {
    if (currentUser == null) return Stream.value([]);

    return _firestore
        .collection('followRequests')
        .where('toUserId', isEqualTo: currentUser!.uid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .asyncMap((snapshot) async {
      List<Map<String, dynamic>> requests = [];

      for (var doc in snapshot.docs) {
        Map<String, dynamic> data = doc.data();

        DocumentSnapshot userDoc = await _firestore
            .collection('users')
            .doc(data['fromUserId'])
            .get();

        Map<String, dynamic> userData =
            userDoc.data() as Map<String, dynamic>? ?? {};

        requests.add({
          'id': doc.id,
          'userId': data['fromUserId'],
          'full_name': userData['fullName'] ?? 'Unknown',
          'username': userData['username'] ?? '',
          'avatar': userData['profilePic'] ?? userData['avatar'] ?? '👤',
          'profile_pic': userData['profilePic'] ?? '',
          'created_at': data['createdAt'],
        });
      }

      return requests;
    });
  }

  // Accept follow request
  Future<void> acceptFollowRequest(String requestId, String fromUserId) async {
    if (currentUser == null) return;

    try {
      WriteBatch batch = _firestore.batch();

      batch.update(_firestore.collection('followRequests').doc(requestId), {
        'status': 'accepted',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      batch.update(_firestore.collection('users').doc(currentUser!.uid), {
        'followers': FieldValue.arrayUnion([fromUserId]),
      });

      batch.update(_firestore.collection('users').doc(fromUserId), {
        'following': FieldValue.arrayUnion([currentUser!.uid]),
      });

      await batch.commit();
    } catch (e) {
      print('Error accepting follow request: $e');
      rethrow;
    }
  }

  // Reject follow request
  Future<void> rejectFollowRequest(String requestId) async {
    try {
      await _firestore.collection('followRequests').doc(requestId).update({
        'status': 'rejected',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error rejecting follow request: $e');
      rethrow;
    }
  }

  // Toggle private account
  Future<void> togglePrivateAccount(bool isPrivate) async {
    await updateSetting('isPrivateAccount', isPrivate);
  }

  // Perform backup
  Future<void> performBackup() async {
    if (currentUser == null) return;

    try {
      QuerySnapshot videos = await _firestore
          .collection('videos')
          .where('userId', isEqualTo: currentUser!.uid)
          .get();

      await _firestore.collection('backups').add({
        'userId': currentUser!.uid,
        'timestamp': FieldValue.serverTimestamp(),
        'videosCount': videos.docs.length,
        'status': 'completed',
        'backupSize': '${videos.docs.length * 150} MB',
      });

      await updateSetting('lastBackup', FieldValue.serverTimestamp());
      await updateSetting('backupSize', '${videos.docs.length * 150} MB');
    } catch (e) {
      print('Error performing backup: $e');
      rethrow;
    }
  }

  // Clear cache
  Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  // ==================== SUPPORT & ABOUT METHODS ====================
  // 1. Get FAQs from Firebase
  Stream<List<Map<String, dynamic>>> getFAQs() {
    return _firestore
        .collection('faqs')
        .orderBy('order', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data();
        return {
          'id': doc.id,
          'question': data['question'] ?? 'No question',
          'answer': data['answer'] ?? 'No answer',
          'category': data['category'] ?? 'general',
          'order': data['order'] ?? 0,
        };
      }).toList();
    });
  }

  // 2. Submit bug report to Firebase
  Future<void> submitBugReport({
    required String subject,
    required String description,
  }) async {
    if (currentUser == null) throw Exception('No user logged in');

    try {
      await _firestore.collection('bugReports').add({
        'userId': currentUser!.uid,
        'userEmail': currentUser!.email ?? 'No email',
        'userName': currentUser!.displayName ?? 'Unknown',
        'subject': subject,
        'description': description,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'pending',
        'deviceInfo': {
          'platform': 'Android',
          'version': '1.0.0',
        },
      });
    } catch (e) {
      print('Error submitting bug report: $e');
      rethrow;
    }
  }

  // 3. Get app info from Firebase
  Stream<Map<String, dynamic>> getAppInfo() {
    return _firestore
        .collection('appInfo')
        .doc('about')
        .snapshots()
        .map((doc) {
      if (!doc.exists) {
        return {
          'version': '1.0.0',
          'description': 'TapMate - Your all-in-one video downloader and social platform.',
          'developer': 'TapMate Team',
          'contactEmail': 'support@tapmate.com',
          'website': 'www.tapmate.com',
          'showAnnouncement': false,
          'announcement': '',
          'privacyPolicy': '''
Privacy Policy for TapMate

Last updated: ${DateTime.now().year}

Your privacy is important to us. This policy explains how we collect, use, and protect your information.

1. Information We Collect
   - Account information (name, email, profile)
   - Usage data and preferences
   - Videos you download or share

2. How We Use Your Information
   - To provide and improve our services
   - To personalize your experience
   - To communicate with you

3. Data Security
   We implement security measures to protect your data.

For full privacy policy, visit our website.
          ''',
        };
      }
      return doc.data() as Map<String, dynamic>;
    });
  }

  // 4. Submit support request
  Future<void> submitSupportRequest({
    required String email,
    required String message,
  }) async {
    try {
      await _firestore.collection('supportRequests').add({
        'userId': currentUser?.uid ?? 'guest',
        'userEmail': email,
        'userName': currentUser?.displayName ?? 'Guest User',
        'message': message,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'pending',
      });
    } catch (e) {
      print('Error submitting support request: $e');
      rethrow;
    }
  }

  // 5. Get latest app version
  Future<String> getLatestVersion() async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection('appInfo')
          .doc('version')
          .get();

      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        return data['latestVersion'] ?? '1.0.0';
      }
      return '1.0.0';
    } catch (e) {
      print('Error getting latest version: $e');
      return '1.0.0';
    }
  }
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final SettingsFirebaseService _firebaseService = SettingsFirebaseService();

  // User data from Firebase
  UserModel? _currentUser;

  // App Settings
  bool _notificationsEnabled = true;
  bool _darkMode = false;
  bool _dataSaver = false;
  bool _cloudSyncEnabled = false;
  bool _autoBackup = false;
  String _language = 'English';
  String _downloadQuality = '720p';
  String _storageLocation = 'Phone Storage';

  // ✅ NEW: Email Settings
  bool _emailNotifications = true;
  bool _marketingEmails = false;

  // Privacy Settings
  bool _isPrivateAccount = false;
  bool _showOnlineStatus = true;
  bool _allowTagging = true;
  bool _allowComments = true;
  bool _showActivity = true;

  // Storage Data
  double _storageUsed = 0.0;
  double _storageTotal = 25.0;

  // Backup info
  String _lastBackup = 'Not backed up';
  String _backupSize = '0 MB';

  // Follow requests from Firebase
  List<Map<String, dynamic>> _followRequests = [];
  int _pendingRequestsCount = 0;

  // Loading state
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadSettingsData();
    _setupFollowRequestsListener();
  }

  // Load current user data
  Future<void> _loadUserData() async {
    try {
      final user = await _firebaseService.getCurrentUserData();
      if (mounted) {
        setState(() {
          _currentUser = user;
        });
      }
    } catch (e) {
      print('Error loading user data: $e');
    }
  }

  // Load settings from Firebase
  Future<void> _loadSettingsData() async {
    setState(() => _isLoading = true);

    try {
      Map<String, dynamic> firebaseSettings = await _firebaseService
          .loadUserSettings();

      if (firebaseSettings.isNotEmpty) {
        setState(() {
          _notificationsEnabled =
              firebaseSettings['notificationsEnabled'] ?? true;
          _darkMode = firebaseSettings['darkMode'] ?? false;
          _dataSaver = firebaseSettings['dataSaver'] ?? false;
          _cloudSyncEnabled = firebaseSettings['cloudSyncEnabled'] ?? false;
          _autoBackup = firebaseSettings['autoBackup'] ?? false;
          _language = firebaseSettings['language'] ?? 'English';
          _downloadQuality = firebaseSettings['downloadQuality'] ?? '720p';
          _storageLocation =
              firebaseSettings['storageLocation'] ?? 'Phone Storage';

          // ✅ NEW: Load email settings
          _emailNotifications = firebaseSettings['emailNotifications'] ?? true;
          _marketingEmails = firebaseSettings['marketingEmails'] ?? false;

          _isPrivateAccount = firebaseSettings['isPrivateAccount'] ?? false;
          _showOnlineStatus = firebaseSettings['showOnlineStatus'] ?? true;
          _allowTagging = firebaseSettings['allowTagging'] ?? true;
          _allowComments = firebaseSettings['allowComments'] ?? true;
          _showActivity = firebaseSettings['showActivity'] ?? true;
          _storageUsed = (firebaseSettings['storageUsed'] ?? 0.0).toDouble();
          _storageTotal = (firebaseSettings['storageTotal'] ?? 25.0).toDouble();

          if (firebaseSettings['lastBackup'] != null) {
            Timestamp timestamp = firebaseSettings['lastBackup'];
            _lastBackup = _formatBackupTime(timestamp.toDate());
          }

          _backupSize = firebaseSettings['backupSize'] ?? '0 MB';
        });
      } else {
        _loadDummyData();
      }
    } catch (e) {
      print('Error loading from Firebase: $e');
      _loadDummyData();
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Fallback to dummy data
  void _loadDummyData() {
    final user = DummyDataService.currentUser;
    setState(() {
      _isPrivateAccount = user['is_private'] ?? false;
      final posts = DummyDataService.getUserPosts();
      _storageUsed = (posts.length * 0.4).toDouble();
      if (posts.isNotEmpty) {
        final newestPost = posts.reduce(
              (a, b) => a['created_at'].toString().contains('hour') ? a : b,
        );
        _lastBackup = newestPost['created_at'];
        _backupSize = '${(posts.length * 150).toString()} MB';
      }
    });
  }

  // Setup follow requests listener
  void _setupFollowRequestsListener() {
    _firebaseService.getFollowRequests().listen((requests) {
      if (mounted) {
        setState(() {
          _followRequests = requests;
          _pendingRequestsCount = requests.length;
        });
      }
    });
  }

  // Toggle private account with Firebase
  void _togglePrivateAccount(bool value) async {
    setState(() => _isPrivateAccount = value);

    try {
      await _firebaseService.togglePrivateAccount(value);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              value
                  ? 'Account is now private. New followers must request to follow you.'
                  : 'Account is now public. Anyone can follow you and see your posts.',
            ),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      }

      if (value && _pendingRequestsCount > 0 && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showPendingRequestsDialog();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update privacy: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Update setting in Firebase
  Future<void> _updateSetting(String key, dynamic value) async {
    try {
      await _firebaseService.updateSetting(key, value);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;
    final pendingRequestsCount = _pendingRequestsCount;
    final authProvider = Provider.of<AuthProvider>(context);

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final scaffoldBackgroundColor = theme.scaffoldBackgroundColor;

    // Sync dark mode with provider
    if (_darkMode != isDarkMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _darkMode = isDarkMode;
          });
        }
      });
    }

    // Show loading indicator
    if (_isLoading) {
      return Scaffold(
        backgroundColor: scaffoldBackgroundColor,
        body: Center(
          child: CircularProgressIndicator(color: colorScheme.primary),
        ),
      );
    }

    return Scaffold(
      backgroundColor: scaffoldBackgroundColor,
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
                  colors: [
                    colorScheme.tertiary ?? colorScheme.secondary,
                    colorScheme.secondary,
                    colorScheme.primary,
                  ],
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
                boxShadow: [
                  BoxShadow(
                    color: (colorScheme.tertiary ?? colorScheme.secondary)
                        .withOpacity(0.3),
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
                      'Settings',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (_isPrivateAccount)
                    Container(
                      margin: const EdgeInsets.only(right: 10),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.lock, size: 14, color: Colors.white),
                          const SizedBox(width: 4),
                          Text(
                            'Private',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  CircleAvatar(
                    radius: 20,
                    backgroundImage:
                    _currentUser?.profilePicUrl != null &&
                        _currentUser!.profilePicUrl.isNotEmpty
                        ? NetworkImage(_currentUser!.profilePicUrl)
                        : null,
                    child:
                    _currentUser?.profilePicUrl == null ||
                        _currentUser!.profilePicUrl.isEmpty
                        ? Text(_currentUser?.fullName[0] ?? 'U')
                        : null,
                  ),
                ],
              ),
            ),

            // Settings Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildUserInfoCard(theme, colorScheme),

                    const SizedBox(height: 25),

                    // Account Section
                    _buildSectionTitle('Account', colorScheme),
                    _buildSettingsCard(
                      theme: theme,
                      children: [
                        _buildSettingsTile(
                          icon: Icons.person_outline,
                          title: 'Edit Profile',
                          subtitle: 'Change your profile information',
                          theme: theme,
                          onTap: () {
                            Navigator.pushNamed(context, '/profile');
                          },
                        ),
                        const Divider(),
                        _buildSettingsTile(
                          icon: Icons.group_add,
                          title: 'Follow Requests',
                          subtitle: pendingRequestsCount > 0
                              ? '$pendingRequestsCount pending requests'
                              : 'No pending requests',
                          theme: theme,
                          onTap: () {
                            if (pendingRequestsCount > 0) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                  const FollowRequestsScreen(),
                                ),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text(
                                    'No pending follow requests',
                                  ),
                                  backgroundColor: colorScheme.primary,
                                ),
                              );
                            }
                          },
                          badgeCount: pendingRequestsCount,
                        ),
                        const Divider(),
                        _buildSettingsTile(
                          icon: Icons.email_outlined,
                          title: 'Email Settings',
                          subtitle: 'Manage email preferences',
                          theme: theme,
                          onTap: () {
                            _showEmailSettingsDialog(theme);
                          },
                        ),
                        const Divider(),
                        _buildSettingsTile(
                          icon: Icons.security_outlined,
                          title: 'Privacy & Security',
                          subtitle: 'Control your privacy settings',
                          theme: theme,
                          onTap: () {
                            _showPrivacySettingsDialog(theme);
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 25),

                    // Cloud & Backup Section
                    _buildSectionTitle('Cloud & Backup', colorScheme),
                    _buildSettingsCard(
                      theme: theme,
                      children: [
                        _buildSettingsTile(
                          icon: Icons.cloud_queue,
                          title: 'Cloud Storage',
                          subtitle:
                          '${_storageUsed.toStringAsFixed(1)} GB used of $_storageTotal GB',
                          theme: theme,
                          onTap: () {
                            _showStorageDetails(theme);
                          },
                        ),
                        const Divider(),
                        _buildSettingsTile(
                          icon: Icons.backup,
                          title: 'Last Backup',
                          subtitle: _lastBackup,
                          theme: theme,
                          onTap: () {
                            _showBackupInfoDialog(theme);
                          },
                        ),
                        const Divider(),
                        _buildSwitchTile(
                          icon: Icons.cloud_sync,
                          title: 'Auto Backup',
                          subtitle: 'Automatically backup content',
                          value: _autoBackup,
                          theme: theme,
                          onChanged: (value) async {
                            setState(() => _autoBackup = value);
                            await _updateSetting('autoBackup', value);
                            if (value && mounted) {
                              _showAutoBackupInfoDialog(theme);
                            }
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 25),

                    // Download Settings
                    _buildSectionTitle('Download Settings', colorScheme),
                    _buildSettingsCard(
                      theme: theme,
                      children: [
                        _buildSettingsTile(
                          icon: Icons.hd_outlined,
                          title: 'Video Quality',
                          subtitle: _downloadQuality,
                          theme: theme,
                          onTap: () {
                            _showQualitySelector(theme);
                          },
                        ),
                        const Divider(),
                        _buildSettingsTile(
                          icon: Icons.folder_open,
                          title: 'Storage Location',
                          subtitle: _storageLocation,
                          theme: theme,
                          onTap: () {
                            _showStorageLocationSelector(theme);
                          },
                        ),
                        const Divider(),
                        _buildSwitchTile(
                          icon: Icons.data_saver_off,
                          title: 'Data Saver Mode',
                          subtitle: 'Reduce mobile data usage',
                          value: _dataSaver,
                          theme: theme,
                          onChanged: (value) async {
                            setState(() => _dataSaver = value);
                            await _updateSetting('dataSaver', value);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    value
                                        ? 'Data saver enabled'
                                        : 'Data saver disabled',
                                  ),
                                  backgroundColor: colorScheme.primary,
                                ),
                              );
                            }
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 25),

                    // App Settings
                    _buildSectionTitle('App Settings', colorScheme),
                    _buildSettingsCard(
                      theme: theme,
                      children: [
                        _buildSwitchTile(
                          icon: Icons.notifications_outlined,
                          title: 'Push Notifications',
                          subtitle: 'Receive app notifications',
                          value: _notificationsEnabled,
                          theme: theme,
                          onChanged: (value) async {
                            setState(() => _notificationsEnabled = value);
                            await _updateSetting('notificationsEnabled', value);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    value
                                        ? 'Notifications enabled'
                                        : 'Notifications disabled',
                                  ),
                                  backgroundColor: colorScheme.primary,
                                ),
                              );
                            }
                          },
                        ),
                        const Divider(),
                        _buildSwitchTile(
                          icon: Icons.dark_mode_outlined,
                          title: 'Dark Mode',
                          subtitle: 'Switch to dark theme',
                          value: _darkMode,
                          theme: theme,
                          onChanged: (value) {
                            setState(() => _darkMode = value);
                            themeProvider.toggleDarkMode(value);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    value
                                        ? 'Dark mode enabled'
                                        : 'Dark mode disabled',
                                  ),
                                  backgroundColor: colorScheme.primary,
                                ),
                              );
                            }
                          },
                        ),
                        const Divider(),
                        _buildSettingsTile(
                          icon: Icons.language,
                          title: 'Language',
                          subtitle: _language,
                          theme: theme,
                          onTap: () {
                            _showLanguageSelector(theme);
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 25),

                    // App Tour Section
                    _buildSectionTitle('App Tour', colorScheme),
                    _buildSettingsCard(
                      theme: theme,
                      children: [
                        _buildSettingsTile(
                          icon: Icons.tour_outlined,
                          title: 'Take Tour Again',
                          subtitle: 'Restart the guided onboarding tour',
                          theme: theme,
                          onTap: () {
                            _showRestartTourDialog(theme, authProvider);
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 25),

                    // Support & About
                    _buildSectionTitle('Support & About', colorScheme),
                    _buildSettingsCard(
                      theme: theme,
                      children: [
                        _buildSettingsTile(
                          icon: Icons.help_outline,
                          title: 'Help Center',
                          subtitle: 'Get help with TapMate',
                          theme: theme,
                          onTap: () {
                            _showHelpCenterDialog(theme);
                          },
                        ),
                        const Divider(),
                        _buildSettingsTile(
                          icon: Icons.bug_report_outlined,
                          title: 'Report a Bug',
                          subtitle: 'Report issues or bugs',
                          theme: theme,
                          onTap: () {
                            _showBugReportDialog(theme);
                          },
                        ),
                        const Divider(),
                        _buildSettingsTile(
                          icon: Icons.info_outline,
                          title: 'About TapMate',
                          subtitle: 'Version 1.0.0',
                          theme: theme,
                          onTap: () {
                            _showAboutDialog(theme);
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 25),

                    // Clear Data Section
                    _buildSectionTitle('Data Management', colorScheme),
                    _buildSettingsCard(
                      theme: theme,
                      children: [
                        _buildSettingsTile(
                          icon: Icons.delete_outline,
                          title: 'Clear Cache',
                          subtitle: 'Free up storage space',
                          theme: theme,
                          onTap: () {
                            _showClearCacheDialog(theme);
                          },
                        ),
                        const Divider(),
                        _buildSettingsTile(
                          icon: Icons.refresh,
                          title: 'Reset Settings',
                          subtitle: 'Restore default settings',
                          theme: theme,
                          onTap: () {
                            _showResetSettingsDialog(theme);
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 30),

                    // Logout Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          _showLogoutDialog(theme, authProvider);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.logout, size: 20),
                        label: const Text(
                          'Log Out',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // User Info Card with Firebase data
  Widget _buildUserInfoCard(ThemeData theme, ColorScheme colorScheme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.cardTheme.color ?? theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.primary.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(
              theme.brightness == Brightness.dark ? 0.3 : 0.1,
            ),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          CircleAvatar(
            radius: 35,
            backgroundImage:
            _currentUser?.profilePicUrl != null &&
                _currentUser!.profilePicUrl.isNotEmpty
                ? NetworkImage(_currentUser!.profilePicUrl)
                : null,
            child:
            _currentUser?.profilePicUrl == null ||
                _currentUser!.profilePicUrl.isEmpty
                ? Text(
              _currentUser?.fullName[0] ?? 'U',
              style: const TextStyle(fontSize: 20),
            )
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _currentUser?.fullName ?? 'Your Name',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: colorScheme.primary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  _currentUser?.email ?? 'yourname@email.com',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${_currentUser?.followersCount ?? 0} followers',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${_currentUser?.followingCount ?? 0} following',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary,
                          ),
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
    );
  }

  Widget _buildSectionTitle(String title, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildSettingsCard({
    required ThemeData theme,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: theme.cardTheme.color ?? theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.dividerColor.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(
              theme.brightness == Brightness.dark ? 0.3 : 0.1,
            ),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required ThemeData theme,
    required VoidCallback onTap,
    int badgeCount = 0,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: theme.colorScheme.primary, size: 22),
      ),
      title: Text(
        title,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.onSurface,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurface.withOpacity(0.7),
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (badgeCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.error,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                badgeCount.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          const SizedBox(width: 8),
          Icon(
            Icons.chevron_right_rounded,
            color: theme.colorScheme.onSurface.withOpacity(0.5),
            size: 22,
          ),
        ],
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ThemeData theme,
    required ValueChanged<bool> onChanged,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: theme.colorScheme.primary, size: 22),
      ),
      title: Text(
        title,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.onSurface,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurface.withOpacity(0.7),
        ),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: theme.colorScheme.primary,
        trackColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return theme.colorScheme.primary.withOpacity(0.5);
          }
          return theme.dividerColor;
        }),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    );
  }

  // ========== DIALOG METHODS ==========

  void _showPendingRequestsDialog() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.dialogBackgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.group_add, color: colorScheme.primary),
            const SizedBox(width: 10),
            Text(
              'Pending Follow Requests',
              style: theme.textTheme.titleLarge?.copyWith(
                color: colorScheme.onSurface,
              ),
            ),
          ],
        ),
        // ✅ FIX: Use SingleChildScrollView for content
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: _followRequests.isEmpty
                ? Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'No pending follow requests.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
            )
                : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    'You have ${_followRequests.length} pending follow request(s).',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ..._followRequests
                    .map(
                      (request) => ListTile(
                    leading: CircleAvatar(
                      backgroundImage: request['profile_pic'] != null
                          ? NetworkImage(request['profile_pic'])
                          : null,
                      child: request['profile_pic'] == null
                          ? Text(request['avatar'] ?? '👤')
                          : null,
                    ),
                    title: Text(request['full_name']),
                    subtitle: Text('@${request['username']}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.check,
                            color: Colors.green,
                          ),
                          onPressed: () async {
                            Navigator.pop(context);
                            try {
                              await _firebaseService
                                  .acceptFollowRequest(
                                request['id'],
                                request['userId'],
                              );
                              if (mounted) {
                                ScaffoldMessenger.of(
                                  context,
                                ).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Accepted ${request['full_name']}',
                                    ),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              }
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(
                                  context,
                                ).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Failed to accept: $e',
                                    ),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          },
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.close,
                            color: Colors.red,
                          ),
                          onPressed: () async {
                            Navigator.pop(context);
                            try {
                              await _firebaseService
                                  .rejectFollowRequest(request['id']);
                              if (mounted) {
                                ScaffoldMessenger.of(
                                  context,
                                ).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Rejected ${request['full_name']}',
                                    ),
                                    backgroundColor:
                                    theme.colorScheme.error,
                                  ),
                                );
                              }
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(
                                  context,
                                ).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Failed to reject: $e',
                                    ),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                )
                    .toList(),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
          if (_followRequests.isNotEmpty)
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const FollowRequestsScreen(),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.primary,
              ),
              child: const Text('Manage All'),
            ),
        ],
      ),
    );
  }

  void _showPrivacySettingsDialog(ThemeData theme) {
    final colorScheme = theme.colorScheme;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: theme.dialogBackgroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Privacy Settings',
            style: theme.textTheme.titleLarge?.copyWith(
              color: colorScheme.onSurface,
            ),
          ),
          // ✅ FIX: Already has SingleChildScrollView - keep it
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SwitchListTile(
                  title: Text(
                    'Private Account',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: colorScheme.onSurface,
                    ),
                  ),
                  subtitle: Text(
                    _isPrivateAccount
                        ? 'Only approved followers can see your posts'
                        : 'Anyone can follow you and see your posts',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                  value: _isPrivateAccount,
                  onChanged: (value) {
                    setState(() => this._isPrivateAccount = value);
                    _togglePrivateAccount(value);
                  },
                  activeColor: colorScheme.primary,
                ),
                const Divider(),
                SwitchListTile(
                  title: Text(
                    'Show Online Status',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: colorScheme.onSurface,
                    ),
                  ),
                  subtitle: Text(
                    'Show when you\'re online',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                  value: _showOnlineStatus,
                  onChanged: (value) async {
                    setState(() => this._showOnlineStatus = value);
                    await _updateSetting('showOnlineStatus', value);
                  },
                  activeColor: colorScheme.primary,
                ),
                const Divider(),
                SwitchListTile(
                  title: Text(
                    'Allow Tagging',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: colorScheme.onSurface,
                    ),
                  ),
                  subtitle: Text(
                    'Allow others to tag you in posts',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                  value: _allowTagging,
                  onChanged: (value) async {
                    setState(() => _allowTagging = value);
                    await _updateSetting('allowTagging', value);
                  },
                  activeColor: colorScheme.primary,
                ),
                const Divider(),
                SwitchListTile(
                  title: Text(
                    'Allow Comments',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: colorScheme.onSurface,
                    ),
                  ),
                  subtitle: Text(
                    'Allow comments on your posts',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                  value: _allowComments,
                  onChanged: (value) async {
                    setState(() => _allowComments = value);
                    await _updateSetting('allowComments', value);
                  },
                  activeColor: colorScheme.primary,
                ),
                const Divider(),
                SwitchListTile(
                  title: Text(
                    'Show Activity',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: colorScheme.onSurface,
                    ),
                  ),
                  subtitle: Text(
                    'Show your likes and comments',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                  value: _showActivity,
                  onChanged: (value) async {
                    setState(() => _showActivity = value);
                    await _updateSetting('showActivity', value);
                  },
                  activeColor: colorScheme.primary,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }

  void _showStorageDetails(ThemeData theme) {
    final posts = DummyDataService.getUserPosts();
    final videosGB = (posts.length * 0.4);
    final cacheGB = 0.2;
    final colorScheme = theme.colorScheme;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.dialogBackgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Storage Usage',
          style: theme.textTheme.titleLarge?.copyWith(
            color: colorScheme.onSurface,
          ),
        ),
        // ✅ FIX: Add SingleChildScrollView
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStorageDetailRow('Videos', videosGB, theme),
              _buildStorageDetailRow('App Cache', cacheGB, theme),
              _buildStorageDetailRow('Other Data', 0.1, theme),

              const SizedBox(height: 20),

              LinearProgressIndicator(
                value: _storageUsed / _storageTotal,
                backgroundColor: colorScheme.surfaceVariant,
                valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
                minHeight: 10,
                borderRadius: BorderRadius.circular(5),
              ),

              const SizedBox(height: 10),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Available',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                  Text(
                    '${_storageTotal - _storageUsed} GB',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close', style: TextStyle(color: colorScheme.primary)),
          ),
        ],
      ),
    );
  }

  Widget _buildStorageDetailRow(String label, double size, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface,
            ),
          ),
          Text(
            '${size.toStringAsFixed(1)} GB',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  void _showBackupInfoDialog(ThemeData theme) {
    final colorScheme = theme.colorScheme;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.dialogBackgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.backup, color: colorScheme.primary),
            const SizedBox(width: 10),
            Text(
              'Backup Information',
              style: theme.textTheme.titleLarge?.copyWith(
                color: colorScheme.onSurface,
              ),
            ),
          ],
        ),
        // ✅ FIX: Add SingleChildScrollView
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildBackupInfoItem('Last Backup', _lastBackup, theme),
              _buildBackupInfoItem('Backup Size', _backupSize, theme),
              _buildBackupInfoItem(
                'Items Backed Up',
                '${DummyDataService.getUserPosts().length} videos',
                theme,
              ),
              _buildBackupInfoItem(
                'Cloud Storage',
                '${_storageTotal} GB Total',
                theme,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _performBackup(theme);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primary,
            ),
            child: const Text('Backup Now'),
          ),
        ],
      ),
    );
  }

  Widget _buildBackupInfoItem(String label, String value, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _performBackup(ThemeData theme) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: theme.dialogBackgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 80,
              width: 80,
              child: CircularProgressIndicator(
                strokeWidth: 4,
                valueColor: AlwaysStoppedAnimation<Color>(
                  theme.colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Creating Backup...',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'This may take a few moments',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );

    try {
      await _firebaseService.performBackup();

      if (mounted) {
        Navigator.pop(context); // Close loading dialog

        setState(() {
          _lastBackup = 'Just now';
          _backupSize = '${(DummyDataService.getUserPosts().length * 150)} MB';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Backup completed successfully!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Backup failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showAutoBackupInfoDialog(ThemeData theme) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.dialogBackgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Auto Backup',
          style: theme.textTheme.titleLarge?.copyWith(
            color: theme.colorScheme.onSurface,
          ),
        ),
        content: Text(
          'When enabled, TapMate will automatically backup your videos and settings daily when connected to Wi-Fi.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.7),
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  void _showQualitySelector(ThemeData theme) {
    final qualities = ['360p', '480p', '720p', '1080p'];

    showModalBottomSheet(
      context: context,
      backgroundColor: theme.dialogBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Select Video Quality',
              style: theme.textTheme.titleLarge?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 20),
            ...qualities
                .map((quality) => _buildQualityOption(quality, theme))
                .toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildQualityOption(String quality, ThemeData theme) {
    final isSelected = _downloadQuality == quality;
    return ListTile(
      title: Text(
        quality,
        style: theme.textTheme.titleMedium?.copyWith(
          color: theme.colorScheme.onSurface,
        ),
      ),
      subtitle: Text(
        _getQualityDescription(quality),
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurface.withOpacity(0.7),
        ),
      ),
      trailing: isSelected
          ? Icon(Icons.check, color: theme.colorScheme.primary)
          : null,
      onTap: () async {
        setState(() => _downloadQuality = quality);
        await _updateSetting('downloadQuality', quality);
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Video quality set to $quality'),
              backgroundColor: theme.colorScheme.primary,
            ),
          );
        }
      },
    );
  }

  String _getQualityDescription(String quality) {
    switch (quality) {
      case '360p':
        return 'Low quality, small file size';
      case '480p':
        return 'Standard definition';
      case '720p':
        return 'HD quality (recommended)';
      case '1080p':
        return 'Full HD, large file size';
      default:
        return 'Recommended quality';
    }
  }

  void _showStorageLocationSelector(ThemeData theme) {
    final locations = ['Phone Storage', 'SD Card', 'Cloud Storage'];

    showModalBottomSheet(
      context: context,
      backgroundColor: theme.dialogBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Select Storage Location',
              style: theme.textTheme.titleLarge?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 20),
            ...locations
                .map((location) => _buildLocationOption(location, theme))
                .toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationOption(String location, ThemeData theme) {
    final isSelected = _storageLocation == location;
    return ListTile(
      title: Text(
        location,
        style: theme.textTheme.titleMedium?.copyWith(
          color: theme.colorScheme.onSurface,
        ),
      ),
      subtitle: Text(
        _getLocationDescription(location),
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurface.withOpacity(0.7),
        ),
      ),
      trailing: isSelected
          ? Icon(Icons.check, color: theme.colorScheme.primary)
          : null,
      onTap: () async {
        setState(() => _storageLocation = location);
        await _updateSetting('storageLocation', location);
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Storage location set to $location'),
              backgroundColor: theme.colorScheme.primary,
            ),
          );
        }
      },
    );
  }

  String _getLocationDescription(String location) {
    switch (location) {
      case 'Phone Storage':
        return 'Save to device internal storage';
      case 'SD Card':
        return 'Save to external SD card';
      case 'Cloud Storage':
        return 'Save to cloud (requires internet)';
      default:
        return 'Internal device storage';
    }
  }

  void _showLanguageSelector(ThemeData theme) {
    final languages = [
      {'name': 'English', 'code': 'en'},
      {'name': 'Spanish', 'code': 'es'},
      {'name': 'French', 'code': 'fr'},
      {'name': 'German', 'code': 'de'},
      {'name': 'Arabic', 'code': 'ar'},
      {'name': 'Urdu', 'code': 'ur'},
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: theme.dialogBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Select Language',
              style: theme.textTheme.titleLarge?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),

            // ✅ FIX: Expanded + ListView (best solution)
            Expanded(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: languages.length,
                itemBuilder: (context, index) {
                  final lang = languages[index];
                  return _buildLanguageOption(lang['name']!, theme);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageOption(String language, ThemeData theme) {
    final isSelected = _language == language;
    return ListTile(
      title: Text(
        language,
        style: theme.textTheme.titleMedium?.copyWith(
          color: theme.colorScheme.onSurface,
        ),
      ),
      trailing: isSelected
          ? Icon(Icons.check, color: theme.colorScheme.primary)
          : null,
      onTap: () async {
        setState(() => _language = language);
        await _updateSetting('language', language);
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Language set to $language'),
              backgroundColor: theme.colorScheme.primary,
            ),
          );
        }
      },
    );
  }


  // ✅ FIXED: Email Settings Dialog with Firebase Connection
  void _showEmailSettingsDialog(ThemeData theme) {
    final colorScheme = theme.colorScheme;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: theme.dialogBackgroundColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Email Settings',
            style: theme.textTheme.titleLarge?.copyWith(
              color: colorScheme.onSurface,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SwitchListTile(
                  title: Text(
                    'Email Notifications',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: colorScheme.onSurface,
                    ),
                  ),
                  subtitle: Text(
                    'Receive email updates about your account',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                  value: _emailNotifications,
                  onChanged: (value) async {
                    setState(() => this._emailNotifications = value);
                    await _updateSetting('emailNotifications', value);

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(value
                            ? 'Email notifications enabled'
                            : 'Email notifications disabled'),
                        backgroundColor: colorScheme.primary,
                      ),
                    );
                  },
                  activeColor: colorScheme.primary,
                ),
                const Divider(),
                SwitchListTile(
                  title: Text(
                    'Marketing Emails',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: colorScheme.onSurface,
                    ),
                  ),
                  subtitle: Text(
                    'Receive promotional offers and updates',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                  value: _marketingEmails,
                  onChanged: (value) async {
                    setState(() => this._marketingEmails = value);
                    await _updateSetting('marketingEmails', value);

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(value
                            ? 'Marketing emails enabled'
                            : 'Marketing emails disabled'),
                        backgroundColor: colorScheme.primary,
                      ),
                    );
                  },
                  activeColor: colorScheme.primary,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }



















void _showClearCacheDialog(ThemeData theme) {
    final colorScheme = theme.colorScheme;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.dialogBackgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.delete_outline, color: colorScheme.primary),
            const SizedBox(width: 10),
            Text(
              'Clear Cache',
              style: theme.textTheme.titleLarge?.copyWith(
                color: colorScheme.onSurface,
              ),
            ),
          ],
        ),
        // ✅ FIX: Already has simple Text - no overflow issue
        content: Text(
          'This will clear temporary app data and free up 0.2 GB of storage. Your videos and settings will not be affected.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurface.withOpacity(0.7),
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);

              try {
                await _firebaseService.clearCache();

                if (mounted) {
                  setState(() {
                    if (_storageUsed > 0.2) {
                      _storageUsed -= 0.2;
                    } else {
                      _storageUsed = 0.0;
                    }
                  });

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Cache cleared successfully!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to clear cache: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primary,
            ),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  void _showResetSettingsDialog(ThemeData theme) {
    final colorScheme = theme.colorScheme;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.dialogBackgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.orange),
            const SizedBox(width: 10),
            Text(
              'Reset Settings',
              style: theme.textTheme.titleLarge?.copyWith(
                color: colorScheme.onSurface,
              ),
            ),
          ],
        ),
        content: Text(
          'This will reset all app settings to their default values. Your videos and account data will not be affected.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurface.withOpacity(0.7),
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _resetAllSettings();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Settings reset to default!'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  Future<void> _resetAllSettings() async {
    Map<String, dynamic> defaultSettings = {
      'notificationsEnabled': true,
      'dataSaver': false,
      'cloudSyncEnabled': false,
      'autoBackup': false,
      'downloadQuality': '720p',
      'storageLocation': 'Phone Storage',
      'language': 'English',
      'isPrivateAccount': false,
      'showOnlineStatus': true,
      'allowTagging': true,
      'allowComments': true,
      'showActivity': true,
      'storageUsed': _storageUsed,
      'storageTotal': _storageTotal,
    };

    try {
      await _firebaseService.saveUserSettings(defaultSettings);

      if (mounted) {
        setState(() {
          _notificationsEnabled = true;
          _dataSaver = false;
          _cloudSyncEnabled = false;
          _autoBackup = false;
          _downloadQuality = '720p';
          _storageLocation = 'Phone Storage';
          _language = 'English';
          _isPrivateAccount = false;
          _showOnlineStatus = true;
          _allowTagging = true;
          _allowComments = true;
          _showActivity = true;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to reset settings: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showHelpCenterDialog(ThemeData theme) {
    final colorScheme = theme.colorScheme;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.dialogBackgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.help_outline, color: colorScheme.primary),
            const SizedBox(width: 10),
            Text(
              'Help Center',
              style: theme.textTheme.titleLarge?.copyWith(
                color: colorScheme.onSurface,
              ),
            ),
          ],
        ),
        // ✅ FIX: Already has SingleChildScrollView inside
        content: Container(
          width: double.maxFinite,
          height: 400,
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: _firebaseService.getFAQs(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, color: Colors.red, size: 50),
                      const SizedBox(height: 10),
                      Text('Error loading FAQs'),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                );
              }

              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final faqs = snapshot.data!;

              if (faqs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.question_answer_outlined,
                        color: colorScheme.primary.withOpacity(0.5),
                        size: 60,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'No FAQs available',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                );
              }

              // Group FAQs by category
              Map<String, List<Map<String, dynamic>>> categorized = {};
              for (var faq in faqs) {
                String category = faq['category'] ?? 'General';
                if (!categorized.containsKey(category)) {
                  categorized[category] = [];
                }
                categorized[category]!.add(faq);
              }

              return ListView.builder(
                shrinkWrap: true,
                itemCount: categorized.length,
                itemBuilder: (context, categoryIndex) {
                  String category = categorized.keys.elementAt(categoryIndex);
                  List<Map<String, dynamic>> categoryFAQs =
                  categorized[category]!;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (categoryIndex > 0) const SizedBox(height: 10),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          category,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      ...categoryFAQs.map(
                            (faq) => Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          color: theme.cardTheme.color ?? theme.cardColor,
                          child: ExpansionTile(
                            title: Text(
                              faq['question'],
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: colorScheme.onSurface,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Text(
                                  faq['answer'],
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: colorScheme.onSurface.withOpacity(
                                      0.8,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _showContactSupportDialog(theme);
            },
            icon: const Icon(Icons.support_agent),
            label: const Text('Contact Support'),
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  // New: Contact Support Dialog
  void _showContactSupportDialog(ThemeData theme) {
    final colorScheme = theme.colorScheme;
    final emailController = TextEditingController();
    final messageController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.dialogBackgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.support_agent, color: colorScheme.primary),
            const SizedBox(width: 10),
            Text(
              'Contact Support',
              style: theme.textTheme.titleLarge?.copyWith(
                color: colorScheme.onSurface,
              ),
            ),
          ],
        ),
        // ✅ FIX: Add SingleChildScrollView
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: emailController,
                decoration: InputDecoration(
                  labelText: 'Your Email',
                  hintText: _currentUser?.email ?? 'Enter your email',
                  prefixIcon: Icon(
                    Icons.email_outlined,
                    color: colorScheme.primary,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 15),
              TextField(
                controller: messageController,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: 'Message',
                  hintText: 'Describe your issue...',
                  prefixIcon: Icon(
                    Icons.message_outlined,
                    color: colorScheme.primary,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (messageController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a message'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              Navigator.pop(context);

              // ✅ FIX: Add mounted check
              if (!mounted) return;

              try {
                await _firebaseService.submitSupportRequest(
                  email: emailController.text.isNotEmpty
                      ? emailController.text
                      : (_currentUser?.email ?? 'No email'),
                  message: messageController.text,
                );

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Support request sent successfully!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to send: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primary,
            ),
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }

  void _showBugReportDialog(ThemeData theme) {
    final colorScheme = theme.colorScheme;
    final subjectController = TextEditingController();
    final descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.dialogBackgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.bug_report_outlined, color: colorScheme.primary),
            const SizedBox(width: 10),
            Text(
              'Report a Bug',
              style: theme.textTheme.titleLarge?.copyWith(
                color: colorScheme.onSurface,
              ),
            ),
          ],
        ),
        // ✅ FIX: Add SingleChildScrollView
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: subjectController,
                decoration: InputDecoration(
                  labelText: 'Subject',
                  hintText: 'Brief summary of the issue',
                  prefixIcon: Icon(Icons.title, color: colorScheme.primary),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: descriptionController,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: 'Description',
                  hintText:
                  'Describe the issue in detail...\nWhat were you doing?\nWhat did you expect to happen?',
                  prefixIcon: Icon(Icons.description, color: colorScheme.primary),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 16,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Your app version and device info will be sent automatically to help us fix the issue.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (subjectController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a subject'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              if (descriptionController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a description'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              Navigator.pop(context);

              // ✅ FIX: Add mounted check
              if (!mounted) return;

              try {
                await _firebaseService.submitBugReport(
                  subject: subjectController.text,
                  description: descriptionController.text,
                );

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Bug report submitted successfully!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to submit: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primary,
            ),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog(ThemeData theme) {
    final colorScheme = theme.colorScheme;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.dialogBackgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.info_outline, color: colorScheme.primary),
            const SizedBox(width: 10),
            Text(
              'About TapMate',
              style: theme.textTheme.titleLarge?.copyWith(
                color: colorScheme.onSurface,
              ),
            ),
          ],
        ),
        // ✅ FIX: Use SingleChildScrollView instead of fixed height
        content: Container(
          width: double.maxFinite,
          constraints: BoxConstraints(maxHeight: 400), // Optional max height
          child: StreamBuilder<Map<String, dynamic>>(
            stream: _firebaseService.getAppInfo(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline, color: Colors.red, size: 40),
                      const SizedBox(height: 10),
                      Text('Error loading app info'),
                    ],
                  ),
                );
              }

              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final appInfo = snapshot.data!;
              final showAnnouncement = appInfo['showAnnouncement'] ?? false;

              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // App Logo/Icon
                    Center(
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.video_library,
                          size: 40,
                          color: colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),

                    // Version Info
                    _buildAboutInfoRow(
                      Icons.tag,
                      'Version',
                      appInfo['version'] ?? '1.0.0',
                      theme,
                    ),
                    const SizedBox(height: 8),

                    // Description
                    _buildAboutInfoRow(
                      Icons.description,
                      'About',
                      appInfo['description'] ?? 'TapMate App',
                      theme,
                      isDescription: true,
                    ),
                    const SizedBox(height: 8),

                    // Developer
                    _buildAboutInfoRow(
                      Icons.code,
                      'Developer',
                      appInfo['developer'] ?? 'TapMate Team',
                      theme,
                    ),
                    const SizedBox(height: 8),

                    // Contact Email
                    if (appInfo['contactEmail'] != null)
                      _buildAboutInfoRow(
                        Icons.email,
                        'Contact',
                        appInfo['contactEmail'],
                        theme,
                      ),
                    const SizedBox(height: 8),

                    // Website
                    if (appInfo['website'] != null)
                      _buildAboutInfoRow(
                        Icons.language,
                        'Website',
                        appInfo['website'],
                        theme,
                      ),

                    if (showAnnouncement && appInfo['announcement'] != null) ...[
                      const SizedBox(height: 15),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: colorScheme.primary.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.campaign,
                              color: colorScheme.primary,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                appInfo['announcement'],
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 15),
                    Divider(color: colorScheme.outline),
                    const SizedBox(height: 10),

                    Center(
                      child: Text(
                        '© ${DateTime.now().year} TapMate',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _showPrivacyPolicyDialog(theme);
            },
            icon: const Icon(Icons.privacy_tip),
            label: const Text('Privacy Policy'),
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  // Helper for About dialog rows
  Widget _buildAboutInfoRow(
      IconData icon,
      String label,
      String value,
      ThemeData theme, {
        bool isDescription = false,
      }) {
    return Row(
      crossAxisAlignment: isDescription
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 16, color: theme.colorScheme.primary),
        const SizedBox(width: 12),
        SizedBox(
          width: 70,
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: isDescription ? FontWeight.normal : FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  // Privacy Policy Dialog
  void _showPrivacyPolicyDialog(ThemeData theme) {
    final colorScheme = theme.colorScheme;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.dialogBackgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.privacy_tip, color: colorScheme.primary),
            const SizedBox(width: 10),
            Text(
              'Privacy Policy',
              style: theme.textTheme.titleLarge?.copyWith(
                color: colorScheme.onSurface,
              ),
            ),
          ],
        ),
        // ✅ FIX: Use SingleChildScrollView instead of fixed height
        content: Container(
          width: double.maxFinite,
          constraints: BoxConstraints(maxHeight: 300),
          child: StreamBuilder<Map<String, dynamic>>(
            stream: _firebaseService.getAppInfo(),
            builder: (context, snapshot) {
              final privacyPolicy =
                  snapshot.data?['privacyPolicy'] ??
                      '''
              Privacy Policy for TapMate

              Last updated: ${DateTime.now().year}

              Your privacy is important to us. This policy explains how we collect, use, and protect your information.

              1. Information We Collect
                 - Account information (name, email, profile)
                 - Usage data and preferences
                 - Videos you download or share

              2. How We Use Your Information
                 - To provide and improve our services
                 - To personalize your experience
                 - To communicate with you

              3. Data Security
                 We implement security measures to protect your data.

              For full privacy policy, visit our website.
            ''';

              return SingleChildScrollView(
                child: Text(
                  privacyPolicy,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.8),
                    height: 1.5,
                  ),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              // Open website
              // You can add url_launcher here
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Opening privacy policy page...')),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primary,
            ),
            child: const Text('Read Full Policy'),
          ),
        ],
      ),
    );
  }

  String _formatBackupTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
    } else {
      return 'Just now';
    }
  }

  void _showLogoutDialog(ThemeData theme, AuthProvider authProvider) {
    final colorScheme = theme.colorScheme;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.dialogBackgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.logout, color: Colors.red),
            const SizedBox(width: 10),
            Text(
              'Log Out',
              style: theme.textTheme.titleLarge?.copyWith(
                color: colorScheme.onSurface,
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to log out? You can sign back in anytime.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurface.withOpacity(0.7),
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: colorScheme.onSurface.withOpacity(0.7)),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);

              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('isLoggedIn', false);
              await prefs.setBool('isNewUser', true);

              await authProvider.logout();

              if (mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                      (route) => false,
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );
  }

  void _showRestartTourDialog(ThemeData theme, AuthProvider authProvider) {
    final colorScheme = theme.colorScheme;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.dialogBackgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.tour_outlined, color: colorScheme.primary, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Take Tour Again',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: colorScheme.onSurface,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'This will restart the guided onboarding tour. You\'ll see highlights for all key features of TapMate.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurface.withOpacity(0.7),
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: colorScheme.onSurface.withOpacity(0.7)),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);

              if (authProvider.isGuest) {
                if (mounted) {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: theme.dialogBackgroundColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      title: Row(
                        children: [
                          Icon(Icons.lock_outline, color: colorScheme.primary),
                          const SizedBox(width: 10),
                          Text(
                            'Guests cannot take the tour',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                      content: Text(
                        'Create an account to see the full guided tour and learn how to use TapMate.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Maybe Later'),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const LoginScreen(),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colorScheme.primary,
                          ),
                          child: const Text(
                            'Sign Up',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return;
              }

              final userId = authProvider.userId;
              await GuideManager.resetGuideForUser(userId);

              if (mounted) {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/home',
                      (route) => false,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Start Tour',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}