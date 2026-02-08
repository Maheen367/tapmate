import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tapmate/Screen/services/dummy_data_service.dart';
import 'package:tapmate/theme_provider.dart';
import 'package:tapmate/utils/guide_manager.dart';
import 'package:tapmate/auth_provider.dart';
import 'package:tapmate/Screen/Auth/LoginScreen.dart';
import 'package:tapmate/Screen/home/follow_requests_screen.dart';
import 'package:tapmate/Screen/constants/app_colors.dart';


class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // App Settings
  bool _notificationsEnabled = true;
  bool _darkMode = false;
  bool _dataSaver = false;
  bool _cloudSyncEnabled = false;
  bool _autoBackup = false;
  String _language = 'English';
  String _downloadQuality = '720p';
  String _storageLocation = 'Phone Storage';

  // NEW: Privacy Settings
  bool _isPrivateAccount = false;
  bool _showOnlineStatus = true;
  bool _allowTagging = true;
  bool _allowComments = true;
  bool _showActivity = true;

  // Storage Data (from dummy service)
  double _storageUsed = 0.0;
  double _storageTotal = 25.0;

  // Backup info
  String _lastBackup = 'Not backed up';
  String _backupSize = '0 MB';

  @override
  void initState() {
    super.initState();
    _loadSettingsData();
  }

  void _loadSettingsData() {
    // Load from dummy data service
    final user = DummyDataService.currentUser;

    setState(() {
      // NEW: Load privacy settings
      _isPrivateAccount = user['is_private'] ?? false;

      // Calculate storage usage based on posts
      final posts = DummyDataService.getUserPosts();
      _storageUsed = (posts.length * 0.4).toDouble(); // 0.4 GB per post

      // Set last backup time (if any)
      if (posts.isNotEmpty) {
        final newestPost = posts.reduce((a, b) =>
        a['created_at'].toString().contains('hour') ? a : b
        );
        _lastBackup = newestPost['created_at'];
        _backupSize = '${(posts.length * 150).toString()} MB'; // 150MB per post approx
      }
    });
  }

  // NEW: Toggle private account
  void _togglePrivateAccount(bool value) {
    setState(() {
      _isPrivateAccount = value;
    });

    // Update in dummy data service
    DummyDataService.toggleAccountPrivacy(value);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          value
              ? 'Account is now private. New followers must request to follow you.'
              : 'Account is now public. Anyone can follow you and see your posts.',
        ),
        backgroundColor: AppColors.primary,
      ),
    );

    // Show follow requests if any
    if (value && DummyDataService.getPendingRequestsCount() > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showPendingRequestsDialog();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;
    final pendingRequestsCount = DummyDataService.getPendingRequestsCount(); // NEW

    // Sync local state with provider
    if (_darkMode != isDarkMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _darkMode = isDarkMode;
          });
        }
      });
    }

    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF121212) : Colors.white,
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
                  // NEW: Add private account badge
                  if (_isPrivateAccount)
                    Container(
                      margin: const EdgeInsets.only(right: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                    backgroundImage: NetworkImage(DummyDataService.currentUser['profile_pic_url']),
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
                    // User Info Section
                    _buildUserInfoCard(isDarkMode),

                    const SizedBox(height: 25),

                    // Account Section
                    _buildSectionTitle('Account', isDarkMode),
                    _buildSettingsCard(isDarkMode: isDarkMode, children: [
                      _buildSettingsTile(
                        icon: Icons.person_outline,
                        title: 'Edit Profile',
                        subtitle: 'Change your profile information',
                        isDarkMode: isDarkMode,
                        onTap: () {
                          Navigator.pushNamed(context, '/profile');
                        },
                      ),
                      const Divider(),
                      // NEW: Follow Requests Tile
                      _buildSettingsTile(
                        icon: Icons.group_add,
                        title: 'Follow Requests',
                        subtitle: pendingRequestsCount > 0
                            ? '$pendingRequestsCount pending requests'
                            : 'No pending requests',
                        isDarkMode: isDarkMode,
                        onTap: () {
                          if (pendingRequestsCount > 0) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const FollowRequestsScreen()),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text('No pending follow requests'),
                                backgroundColor: AppColors.primary,
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
                        isDarkMode: isDarkMode,
                        onTap: () {
                          _showEmailSettingsDialog(isDarkMode);
                        },
                      ),
                      const Divider(),
                      _buildSettingsTile(
                        icon: Icons.security_outlined,
                        title: 'Privacy & Security',
                        subtitle: 'Control your privacy settings',
                        isDarkMode: isDarkMode,
                        onTap: () {
                          _showPrivacySettingsDialog(isDarkMode);
                        },
                      ),
                    ]),

                    const SizedBox(height: 25),

                    // Cloud & Backup Section
                    _buildSectionTitle('Cloud & Backup', isDarkMode),
                    _buildSettingsCard(isDarkMode: isDarkMode, children: [
                      _buildSettingsTile(
                        icon: Icons.cloud_queue,
                        title: 'Cloud Storage',
                        subtitle: '${_storageUsed.toStringAsFixed(1)} GB used of $_storageTotal GB',
                        isDarkMode: isDarkMode,
                        onTap: () {
                          _showStorageDetails(isDarkMode);
                        },
                      ),
                      const Divider(),
                      _buildSettingsTile(
                        icon: Icons.backup,
                        title: 'Last Backup',
                        subtitle: _lastBackup,
                        isDarkMode: isDarkMode,
                        onTap: () {
                          _showBackupInfoDialog(isDarkMode);
                        },
                      ),
                      const Divider(),
                      _buildSwitchTile(
                        icon: Icons.cloud_sync,
                        title: 'Auto Backup',
                        subtitle: 'Automatically backup content',
                        value: _autoBackup,
                        isDarkMode: isDarkMode,
                        onChanged: (value) {
                          setState(() {
                            _autoBackup = value;
                          });
                          if (value) {
                            _showAutoBackupInfoDialog(isDarkMode);
                          }
                        },
                      ),
                    ]),

                    const SizedBox(height: 25),

                    // Download Settings
                    _buildSectionTitle('Download Settings', isDarkMode),
                    _buildSettingsCard(isDarkMode: isDarkMode, children: [
                      _buildSettingsTile(
                        icon: Icons.hd_outlined,
                        title: 'Video Quality',
                        subtitle: _downloadQuality,
                        isDarkMode: isDarkMode,
                        onTap: () {
                          _showQualitySelector(isDarkMode);
                        },
                      ),
                      const Divider(),
                      _buildSettingsTile(
                        icon: Icons.folder_open,
                        title: 'Storage Location',
                        subtitle: _storageLocation,
                        isDarkMode: isDarkMode,
                        onTap: () {
                          _showStorageLocationSelector(isDarkMode);
                        },
                      ),
                      const Divider(),
                      _buildSwitchTile(
                        icon: Icons.data_saver_off,
                        title: 'Data Saver Mode',
                        subtitle: 'Reduce mobile data usage',
                        value: _dataSaver,
                        isDarkMode: isDarkMode,
                        onChanged: (value) {
                          setState(() {
                            _dataSaver = value;
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(value ? 'Data saver enabled' : 'Data saver disabled'),
                              backgroundColor: AppColors.primary,
                            ),
                          );
                        },
                      ),
                    ]),

                    const SizedBox(height: 25),

                    // App Settings
                    _buildSectionTitle('App Settings', isDarkMode),
                    _buildSettingsCard(isDarkMode: isDarkMode, children: [
                      _buildSwitchTile(
                        icon: Icons.notifications_outlined,
                        title: 'Push Notifications',
                        subtitle: 'Receive app notifications',
                        value: _notificationsEnabled,
                        isDarkMode: isDarkMode,
                        onChanged: (value) {
                          setState(() {
                            _notificationsEnabled = value;
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(value ? 'Notifications enabled' : 'Notifications disabled'),
                              backgroundColor: AppColors.primary,
                            ),
                          );
                        },
                      ),
                      const Divider(),
                      _buildSwitchTile(
                        icon: Icons.dark_mode_outlined,
                        title: 'Dark Mode',
                        subtitle: 'Switch to dark theme',
                        value: _darkMode,
                        isDarkMode: isDarkMode,
                        onChanged: (value) {
                          setState(() {
                            _darkMode = value;
                          });
                          Provider.of<ThemeProvider>(context, listen: false).toggleDarkMode(value);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(value ? 'Dark mode enabled' : 'Dark mode disabled'),
                              backgroundColor: AppColors.primary,
                            ),
                          );
                        },
                      ),
                      const Divider(),
                      _buildSettingsTile(
                        icon: Icons.language,
                        title: 'Language',
                        subtitle: _language,
                        isDarkMode: isDarkMode,
                        onTap: () {
                          _showLanguageSelector(isDarkMode);
                        },
                      ),
                    ]),

                    const SizedBox(height: 25),

                    // App Tour Section
                    _buildSectionTitle('App Tour', isDarkMode),
                    _buildSettingsCard(isDarkMode: isDarkMode, children: [
                      _buildSettingsTile(
                        icon: Icons.tour_outlined,
                        title: 'Take Tour Again',
                        subtitle: 'Restart the guided onboarding tour',
                        isDarkMode: isDarkMode,
                        onTap: () {
                          _showRestartTourDialog(isDarkMode);
                        },
                      ),
                    ]),

                    const SizedBox(height: 25),

                    // Support & About
                    _buildSectionTitle('Support & About', isDarkMode),
                    _buildSettingsCard(isDarkMode: isDarkMode, children: [
                      _buildSettingsTile(
                        icon: Icons.help_outline,
                        title: 'Help Center',
                        subtitle: 'Get help with TapMate',
                        isDarkMode: isDarkMode,
                        onTap: () {
                          _showHelpCenterDialog(isDarkMode);
                        },
                      ),
                      const Divider(),
                      _buildSettingsTile(
                        icon: Icons.bug_report_outlined,
                        title: 'Report a Bug',
                        subtitle: 'Report issues or bugs',
                        isDarkMode: isDarkMode,
                        onTap: () {
                          _showBugReportDialog(isDarkMode);
                        },
                      ),
                      const Divider(),
                      _buildSettingsTile(
                        icon: Icons.info_outline,
                        title: 'About TapMate',
                        subtitle: 'Version 1.0.0',
                        isDarkMode: isDarkMode,
                        onTap: () {
                          _showAboutDialog(isDarkMode);
                        },
                      ),
                    ]),

                    const SizedBox(height: 25),

                    // Clear Data Section
                    _buildSectionTitle('Data Management', isDarkMode),
                    _buildSettingsCard(isDarkMode: isDarkMode, children: [
                      _buildSettingsTile(
                        icon: Icons.delete_outline,
                        title: 'Clear Cache',
                        subtitle: 'Free up storage space',
                        isDarkMode: isDarkMode,
                        onTap: () {
                          _showClearCacheDialog(isDarkMode);
                        },
                      ),
                      const Divider(),
                      _buildSettingsTile(
                        icon: Icons.refresh,
                        title: 'Reset Settings',
                        subtitle: 'Restore default settings',
                        isDarkMode: isDarkMode,
                        onTap: () {
                          _showResetSettingsDialog(isDarkMode);
                        },
                      ),
                    ]),

                    const SizedBox(height: 30),

                    // Logout Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          _showLogoutDialog(isDarkMode);
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

  Widget _buildUserInfoCard(bool isDarkMode) {
    final user = DummyDataService.currentUser;

    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(isDarkMode ? 0.3 : 0.1),
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
            backgroundImage: NetworkImage(user['profile_pic_url']),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user['full_name'] ?? 'Your Name',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : AppColors.accent,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  user['email'] ?? 'yourname@email.com',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Pro Member',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.edit_outlined,
              color: AppColors.primary,
              size: 22,
            ),
            onPressed: () {
              Navigator.pushNamed(context, '/edit-profile');
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: isDarkMode ? Colors.white : AppColors.accent,
        ),
      ),
    );
  }

  Widget _buildSettingsCard({required bool isDarkMode, required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDarkMode ? Colors.grey[800]! : Colors.grey[200]!,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(isDarkMode ? 0.3 : 0.1),
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
    required bool isDarkMode,
    required VoidCallback onTap,
    int badgeCount = 0, // NEW: Added badge count parameter
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: AppColors.primary, size: 22),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: isDarkMode ? Colors.white : AppColors.accent,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 13,
          color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (badgeCount > 0) // NEW: Show badge if count > 0
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red,
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
            color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
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
    required bool isDarkMode,
    required ValueChanged<bool> onChanged,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: AppColors.primary, size: 22),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: isDarkMode ? Colors.white : AppColors.accent,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 13,
          color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
        ),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: AppColors.primary,
        trackColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return AppColors.primary.withOpacity(0.5);
          }
          return Colors.grey[300];
        }),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    );
  }

  // ========== NEW DIALOG METHODS ==========

  void _showPendingRequestsDialog() {
    final pendingRequests = DummyDataService.pendingFollowRequests;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _darkMode ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.group_add, color: AppColors.primary),
            const SizedBox(width: 10),
            Text(
              'Pending Follow Requests',
              style: TextStyle(
                color: _darkMode ? Colors.white : AppColors.accent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: pendingRequests.isEmpty
            ? Text(
          'No pending follow requests.',
          style: TextStyle(
            color: _darkMode ? Colors.grey[300] : AppColors.accent,
          ),
        )
            : SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'You have ${pendingRequests.length} pending follow request(s).',
                style: TextStyle(
                  color: _darkMode ? Colors.grey[300] : AppColors.accent,
                ),
              ),
              const SizedBox(height: 16),
              ...pendingRequests.map((request) => ListTile(
                leading: CircleAvatar(
                  child: Text(request['avatar']),
                ),
                title: Text(request['full_name']),
                subtitle: Text('@${request['username']}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.check, color: Colors.green),
                      onPressed: () {
                        DummyDataService.acceptFollowRequest(request['id']);
                        setState(() {});
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Accepted ${request['full_name']}'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.red),
                      onPressed: () {
                        DummyDataService.rejectFollowRequest(request['id']);
                        setState(() {});
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Rejected ${request['full_name']}'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              )).toList(),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          if (pendingRequests.isNotEmpty)
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const FollowRequestsScreen()),
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              child: const Text('Manage All'),
            ),
        ],
      ),
    );
  }

  // UPDATED: Privacy settings dialog with private account toggle
  void _showPrivacySettingsDialog(bool isDarkMode) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Privacy Settings',
          style: TextStyle(
            color: isDarkMode ? Colors.white : AppColors.accent,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Private Account Toggle
              SwitchListTile(
                title: Text(
                  'Private Account',
                  style: TextStyle(color: isDarkMode ? Colors.white : AppColors.accent),
                ),
                subtitle: Text(
                  _isPrivateAccount
                      ? 'Only approved followers can see your posts'
                      : 'Anyone can follow you and see your posts',
                  style: TextStyle(color: isDarkMode ? Colors.grey[400] : Colors.grey[600]),
                ),
                value: _isPrivateAccount,
                onChanged: _togglePrivateAccount,
                activeColor: AppColors.primary,
              ),
              const Divider(),

              // Show Online Status
              SwitchListTile(
                title: Text(
                  'Show Online Status',
                  style: TextStyle(color: isDarkMode ? Colors.white : AppColors.accent),
                ),
                subtitle: Text(
                  'Show when you\'re online',
                  style: TextStyle(color: isDarkMode ? Colors.grey[400] : Colors.grey[600]),
                ),
                value: _showOnlineStatus,
                onChanged: (value) {
                  setState(() {
                    _showOnlineStatus = value;
                  });
                },
                activeColor: AppColors.primary,
              ),
              const Divider(),

              // Allow Tagging
              SwitchListTile(
                title: Text(
                  'Allow Tagging',
                  style: TextStyle(color: isDarkMode ? Colors.white : AppColors.accent),
                ),
                subtitle: Text(
                  'Allow others to tag you in posts',
                  style: TextStyle(color: isDarkMode ? Colors.grey[400] : Colors.grey[600]),
                ),
                value: _allowTagging,
                onChanged: (value) {
                  setState(() {
                    _allowTagging = value;
                  });
                },
                activeColor: AppColors.primary,
              ),
              const Divider(),

              // Allow Comments
              SwitchListTile(
                title: Text(
                  'Allow Comments',
                  style: TextStyle(color: isDarkMode ? Colors.white : AppColors.accent),
                ),
                subtitle: Text(
                  'Allow comments on your posts',
                  style: TextStyle(color: isDarkMode ? Colors.grey[400] : Colors.grey[600]),
                ),
                value: _allowComments,
                onChanged: (value) {
                  setState(() {
                    _allowComments = value;
                  });
                },
                activeColor: AppColors.primary,
              ),
              const Divider(),

              // Show Activity
              SwitchListTile(
                title: Text(
                  'Show Activity',
                  style: TextStyle(color: isDarkMode ? Colors.white : AppColors.accent),
                ),
                subtitle: Text(
                  'Show your likes and comments',
                  style: TextStyle(color: isDarkMode ? Colors.grey[400] : Colors.grey[600]),
                ),
                value: _showActivity,
                onChanged: (value) {
                  setState(() {
                    _showActivity = value;
                  });
                },
                activeColor: AppColors.primary,
              ),

              // Privacy Info Box
              Container(
                margin: const EdgeInsets.only(top: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _isPrivateAccount ? AppColors.primary.withOpacity(0.1) : Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _isPrivateAccount ? Colors.grey[300]! : AppColors.primary.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _isPrivateAccount ? Icons.lock : Icons.lock_open,
                      color: _isPrivateAccount ? AppColors.primary : Colors.grey,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _isPrivateAccount
                            ? 'When your account is private, only people you approve can see your posts and follow you.'
                            : 'When your account is public, anyone can see your posts and follow you.',
                        style: TextStyle(
                          fontSize: 12,
                          color: _isPrivateAccount ? AppColors.primary : Colors.grey[600],
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
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // ========== EXISTING DIALOG METHODS ==========

  void _showStorageDetails(bool isDarkMode) {
    final percentage = (_storageUsed / _storageTotal) * 100;
    final posts = DummyDataService.getUserPosts();
    final videosGB = (posts.length * 0.4);
    final cacheGB = 0.2;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Storage Usage',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : AppColors.accent,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStorageDetailRow('Videos', videosGB, isDarkMode),
            _buildStorageDetailRow('App Cache', cacheGB, isDarkMode),
            _buildStorageDetailRow('Other Data', 0.1, isDarkMode),

            const SizedBox(height: 20),

            // Progress bar
            LinearProgressIndicator(
              value: _storageUsed / _storageTotal,
              backgroundColor: isDarkMode ? Colors.grey[800] : Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              minHeight: 10,
              borderRadius: BorderRadius.circular(5),
            ),

            const SizedBox(height: 10),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Available',
                  style: TextStyle(
                    color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                    fontSize: 13,
                  ),
                ),
                Text(
                  '${_storageTotal - _storageUsed} GB',
                  style: TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Close',
              style: TextStyle(color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStorageDetailRow(String label, double size, bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: isDarkMode ? Colors.grey[300] : AppColors.accent,
              fontSize: 14,
            ),
          ),
          Text(
            '${size.toStringAsFixed(1)} GB',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  void _showBackupInfoDialog(bool isDarkMode) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.backup, color: AppColors.primary),
            const SizedBox(width: 10),
            Text(
              'Backup Information',
              style: TextStyle(
                color: isDarkMode ? Colors.white : AppColors.accent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildBackupInfoItem('Last Backup', _lastBackup, isDarkMode),
            _buildBackupInfoItem('Backup Size', _backupSize, isDarkMode),
            _buildBackupInfoItem('Items Backed Up', '${DummyDataService.getUserPosts().length} videos', isDarkMode),
            _buildBackupInfoItem('Cloud Storage', '${_storageTotal} GB Total', isDarkMode),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              _performBackup(isDarkMode);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Backup Now'),
          ),
        ],
      ),
    );
  }

  Widget _buildBackupInfoItem(String label, String value, bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: isDarkMode ? Colors.white : AppColors.accent,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  void _performBackup(bool isDarkMode) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 80,
              width: 80,
              child: CircularProgressIndicator(
                strokeWidth: 4,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Creating Backup...',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDarkMode ? Colors.white : AppColors.accent,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'This may take a few moments',
              style: TextStyle(
                color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );

    // Simulate backup process
    Future.delayed(const Duration(seconds: 2), () {
      Navigator.pop(context);
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
    });
  }

  void _showAutoBackupInfoDialog(bool isDarkMode) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Auto Backup',
          style: TextStyle(
            color: isDarkMode ? Colors.white : AppColors.accent,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'When enabled, TapMate will automatically backup your videos and settings daily when connected to Wi-Fi.',
          style: TextStyle(
            color: isDarkMode ? Colors.grey[300] : AppColors.accent,
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

  void _showQualitySelector(bool isDarkMode) {
    final qualities = ['360p', '480p', '720p', '1080p'];

    showModalBottomSheet(
      context: context,
      backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
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
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : AppColors.accent,
              ),
            ),
            const SizedBox(height: 20),
            ...qualities.map((quality) => _buildQualityOption(quality, isDarkMode)).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildQualityOption(String quality, bool isDarkMode) {
    final isSelected = _downloadQuality == quality;
    return ListTile(
      title: Text(
        quality,
        style: TextStyle(
          color: isDarkMode ? Colors.white : AppColors.accent,
          fontSize: 16,
        ),
      ),
      subtitle: Text(
        _getQualityDescription(quality),
        style: TextStyle(
          color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
          fontSize: 13,
        ),
      ),
      trailing: isSelected
          ? Icon(Icons.check, color: AppColors.primary)
          : null,
      onTap: () {
        setState(() {
          _downloadQuality = quality;
        });
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Video quality set to $quality'),
            backgroundColor: AppColors.primary,
          ),
        );
      },
    );
  }

  String _getQualityDescription(String quality) {
    switch (quality) {
      case '360p': return 'Low quality, small file size';
      case '480p': return 'Standard definition';
      case '720p': return 'HD quality (recommended)';
      case '1080p': return 'Full HD, large file size';
      default: return 'Recommended quality';
    }
  }

  void _showStorageLocationSelector(bool isDarkMode) {
    final locations = ['Phone Storage', 'SD Card', 'Cloud Storage'];

    showModalBottomSheet(
      context: context,
      backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
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
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : AppColors.accent,
              ),
            ),
            const SizedBox(height: 20),
            ...locations.map((location) => _buildLocationOption(location, isDarkMode)).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationOption(String location, bool isDarkMode) {
    final isSelected = _storageLocation == location;
    return ListTile(
      title: Text(
        location,
        style: TextStyle(
          color: isDarkMode ? Colors.white : AppColors.accent,
          fontSize: 16,
        ),
      ),
      subtitle: Text(
        _getLocationDescription(location),
        style: TextStyle(
          color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
          fontSize: 13,
        ),
      ),
      trailing: isSelected
          ? Icon(Icons.check, color: AppColors.primary)
          : null,
      onTap: () {
        setState(() {
          _storageLocation = location;
        });
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Storage location set to $location'),
            backgroundColor: AppColors.primary,
          ),
        );
      },
    );
  }

  String _getLocationDescription(String location) {
    switch (location) {
      case 'Phone Storage': return 'Save to device internal storage';
      case 'SD Card': return 'Save to external SD card';
      case 'Cloud Storage': return 'Save to cloud (requires internet)';
      default: return 'Internal device storage';
    }
  }

  void _showLanguageSelector(bool isDarkMode) {
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
      backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Select Language',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : AppColors.accent,
              ),
            ),
            const SizedBox(height: 20),
            ...languages.map((lang) => _buildLanguageOption(lang['name']!, isDarkMode)).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageOption(String language, bool isDarkMode) {
    final isSelected = _language == language;
    return ListTile(
      title: Text(
        language,
        style: TextStyle(
          color: isDarkMode ? Colors.white : AppColors.accent,
          fontSize: 16,
        ),
      ),
      trailing: isSelected
          ? Icon(Icons.check, color: AppColors.primary)
          : null,
      onTap: () {
        setState(() {
          _language = language;
        });
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Language set to $language'),
            backgroundColor: AppColors.primary,
          ),
        );
      },
    );
  }

  void _showEmailSettingsDialog(bool isDarkMode) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Email Settings',
          style: TextStyle(
            color: isDarkMode ? Colors.white : AppColors.accent,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SwitchListTile(
              title: Text(
                'Email Notifications',
                style: TextStyle(color: isDarkMode ? Colors.white : AppColors.accent),
              ),
              subtitle: Text(
                'Receive email updates',
                style: TextStyle(color: isDarkMode ? Colors.grey[400] : Colors.grey[600]),
              ),
              value: true,
              onChanged: (value) {},
              activeColor: AppColors.primary,
            ),
            SwitchListTile(
              title: Text(
                'Marketing Emails',
                style: TextStyle(color: isDarkMode ? Colors.white : AppColors.accent),
              ),
              subtitle: Text(
                'Receive promotional emails',
                style: TextStyle(color: isDarkMode ? Colors.grey[400] : Colors.grey[600]),
              ),
              value: false,
              onChanged: (value) {},
              activeColor: AppColors.primary,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showClearCacheDialog(bool isDarkMode) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.delete_outline, color: AppColors.primary),
            const SizedBox(width: 10),
            Text(
              'Clear Cache',
              style: TextStyle(
                color: isDarkMode ? Colors.white : AppColors.accent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Text(
          'This will clear temporary app data and free up 0.2 GB of storage. Your videos and settings will not be affected.',
          style: TextStyle(
            color: isDarkMode ? Colors.grey[300] : AppColors.accent,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
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
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  void _showResetSettingsDialog(bool isDarkMode) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            const SizedBox(width: 10),
            Text(
              'Reset Settings',
              style: TextStyle(
                color: isDarkMode ? Colors.white : AppColors.accent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Text(
          'This will reset all app settings to their default values. Your videos and account data will not be affected.',
          style: TextStyle(
            color: isDarkMode ? Colors.grey[300] : AppColors.accent,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _resetAllSettings();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Settings reset to default!'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  void _resetAllSettings() {
    setState(() {
      _notificationsEnabled = true;
      _dataSaver = false;
      _cloudSyncEnabled = false;
      _autoBackup = false;
      _downloadQuality = '720p';
      _storageLocation = 'Phone Storage';
      _language = 'English';

      // NEW: Reset privacy settings
      _isPrivateAccount = false;
      _showOnlineStatus = true;
      _allowTagging = true;
      _allowComments = true;
      _showActivity = true;

      // Update in dummy data
      DummyDataService.toggleAccountPrivacy(false);
    });
  }

  void _showHelpCenterDialog(bool isDarkMode) {
    final faqs = [
      {'q': 'How to download videos?', 'a': 'Tap the floating button when playing any video'},
      {'q': 'How to save to cloud?', 'a': 'Enable cloud sync in settings'},
      {'q': 'Can I share downloaded videos?', 'a': 'Yes, through the social feed'},
      {'q': 'Is it free?', 'a': 'Yes, basic features are free'},
    ];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Help Center',
          style: TextStyle(
            color: isDarkMode ? Colors.white : AppColors.accent,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: faqs.length,
            itemBuilder: (context, index) {
              return ExpansionTile(
                title: Text(
                  faqs[index]['q']!,
                  style: TextStyle(
                    color: isDarkMode ? Colors.white : AppColors.accent,
                    fontSize: 14,
                  ),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      faqs[index]['a']!,
                      style: TextStyle(
                        color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showBugReportDialog(bool isDarkMode) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Report a Bug',
          style: TextStyle(
            color: isDarkMode ? Colors.white : AppColors.accent,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: InputDecoration(
                labelText: 'Subject',
                labelStyle: TextStyle(color: isDarkMode ? Colors.grey[400] : AppColors.accent),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              maxLines: 4,
              decoration: InputDecoration(
                labelText: 'Description',
                labelStyle: TextStyle(color: isDarkMode ? Colors.grey[400] : AppColors.accent),
                border: const OutlineInputBorder(),
                hintText: 'Describe the issue in detail...',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Bug report submitted!'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog(bool isDarkMode) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.info_outline, color: AppColors.primary),
            const SizedBox(width: 10),
            Text(
              'About TapMate',
              style: TextStyle(
                color: isDarkMode ? Colors.white : AppColors.accent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Version: 1.0.0',
              style: TextStyle(
                color: isDarkMode ? Colors.grey[300] : AppColors.accent,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'TapMate - Your all-in-one video downloader and social platform. Download videos from YouTube, Instagram, TikTok and more, then share with friends!',
              style: TextStyle(
                color: isDarkMode ? Colors.grey[300] : AppColors.accent,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 15),
            Divider(color: isDarkMode ? Colors.grey[700] : Colors.grey[300]),
            const SizedBox(height: 10),
            Text(
              'Developed with ❤️ by TapMate Team',
              style: TextStyle(
                color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                fontSize: 13,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog(bool isDarkMode) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.logout, color: Colors.red),
            const SizedBox(width: 10),
            Text(
              'Log Out',
              style: TextStyle(
                color: isDarkMode ? Colors.white : AppColors.accent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to log out? You can sign back in anytime.',
          style: TextStyle(
            color: isDarkMode ? Colors.grey[300] : AppColors.accent,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: isDarkMode ? Colors.grey[400] : Colors.grey[600]),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              final authProvider = Provider.of<AuthProvider>(context, listen: false);
              authProvider.logout();
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
                    (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );
  }

  // Keep your existing _showRestartTourDialog method
  void _showRestartTourDialog(bool isDarkMode) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.tour_outlined, color: AppColors.primary, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Take Tour Again',
                style: TextStyle(
                  color: isDarkMode ? Colors.white : AppColors.accent,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'This will restart the guided onboarding tour. You\'ll see highlights for all key features of TapMate.',
          style: TextStyle(
            color: isDarkMode ? Colors.grey[300] : AppColors.accent,
            fontSize: 15,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: isDarkMode ? Colors.grey[400] : Colors.grey[600]),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final authProvider = Provider.of<AuthProvider>(context, listen: false);

              if (authProvider.isGuest) {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    title: Row(
                      children: [
                        const Icon(Icons.lock_outline, color: AppColors.primary),
                        const SizedBox(width: 10),
                        Text('Guests cannot take the tour', style: TextStyle(color: isDarkMode ? Colors.white : AppColors.accent)),
                      ],
                    ),
                    content: Text(
                      'Create an account to see the full guided tour and learn how to use TapMate.',
                      style: TextStyle(color: isDarkMode ? Colors.grey[300] : AppColors.accent),
                    ),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Maybe Later')),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const LoginScreen()),
                          );
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                        child: const Text('Sign Up', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                );
                return;
              }

              final userId = authProvider.userId;
              await GuideManager.resetGuideForUser(userId);

              if (context.mounted) {
                Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
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

