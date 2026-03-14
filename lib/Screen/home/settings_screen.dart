// screens/settings_screen.dart (TOP PAR YEH IMPORTS LAGAO)
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';

// ✅ YEH TUMHARI USER MODEL FILE
import '../../auth_provider.dart';
import '../../theme_provider.dart';
import '../../utils/settings_provider.dart';
import '../Auth/LoginScreen.dart';
import '../models/settings_user_model.dart';
import '../services/cloudinary_settingservice.dart';
import '../utils/guide_manager.dart';
import 'blocked_users_screen.dart';
import 'follow_requests_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final CloudinaryService _cloudinary = CloudinaryService();

  bool _notificationsEnabled = true;
  bool _darkMode = false;
  bool _dataSaver = false;
  bool _autoBackup = false;
  String _language = 'English';
  String _downloadQuality = '720p';
  String _storageLocation = 'Phone Storage';
  bool _emailNotifications = true;
  bool _marketingEmails = false;
  bool _isPrivateAccount = false;
  bool _showOnlineStatus = true;
  bool _allowTagging = true;
  bool _allowComments = true;
  bool _showActivity = true;

  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cloudinary.init();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<SettingsProvider>(context, listen: false).init();
      _syncWithProvider();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncWithProvider();
  }

  void _syncWithProvider() {
    final provider = Provider.of<SettingsProvider>(context);
    final user = provider.userSettings;

    if (user != null) {
      setState(() {
        _notificationsEnabled = user.notificationsEnabled;
        _darkMode = user.darkMode;
        _dataSaver = user.dataSaver;
        _language = user.language;
        _downloadQuality = user.downloadQuality;
        _storageLocation = user.storageLocation;
        _isPrivateAccount = user.isPrivate;
        _showOnlineStatus = user.showOnlineStatus;
        _allowTagging = user.allowTagging;
        _allowComments = user.allowComments;
        _showActivity = user.showActivity;

        _fullNameController.text = user.fullName;
        _bioController.text = user.bio ?? '';
        _usernameController.text = user.username;
      });
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _bioController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _updateSetting(String key, dynamic value) async {
    final provider = Provider.of<SettingsProvider>(context, listen: false);
    final success = await provider.updateSettings({key: value});
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Setting updated'), backgroundColor: Colors.green, duration: Duration(seconds: 1)),
      );
    }
  }

  Future<void> _togglePrivateAccount(bool value) async {
    setState(() => _isPrivateAccount = value);
    try {
      await Provider.of<SettingsProvider>(context, listen: false).togglePrivateAccount(value);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(value ? 'Account is now private' : 'Account is now public')),
        );
      }
    } catch (e) {
      setState(() => _isPrivateAccount = !value);
    }
  }

  Future<void> _changeProfilePicture() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, maxWidth: 500, maxHeight: 500, imageQuality: 80);

    if (pickedFile != null) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: Theme.of(context).dialogBackgroundColor,
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            CircularProgressIndicator(),
            SizedBox(height: 20),
            Text('Uploading to Cloudinary...'),
          ]),
        ),
      );

      try {
        final user = Provider.of<SettingsProvider>(context, listen: false).userSettings;
        if (user == null) return;

        final imageUrl = await _cloudinary.uploadProfilePicture(File(pickedFile.path), user.uid);

        if (imageUrl != null && mounted) {
          await Provider.of<SettingsProvider>(context, listen: false).updateSettings({'profilePic': imageUrl});
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Profile picture updated!'), backgroundColor: Colors.green),
          );
        } else {
          if (mounted) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Upload failed'), backgroundColor: Colors.red),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _updateProfile() async {
    final provider = Provider.of<SettingsProvider>(context, listen: false);
    final user = provider.userSettings;
    if (user == null) return;

    Map<String, dynamic> updates = {};
    if (_fullNameController.text != user.fullName) updates['fullName'] = _fullNameController.text;
    if (_bioController.text != user.bio) updates['bio'] = _bioController.text;

    if (updates.isNotEmpty) {
      await provider.updateSettings(updates);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Profile updated'), backgroundColor: Colors.green),
        );
      }
    } else {
      Navigator.pop(context);
    }
  }

  String _getOptimizedProfileUrl(String? url, {int size = 100}) {
    if (url == null || url.isEmpty) return '';
    return _cloudinary.getCircularImageUrl(url, size: size);
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_darkMode != themeProvider.isDarkMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _darkMode = themeProvider.isDarkMode);
      });
    }

    if (settingsProvider.isLoading && settingsProvider.userSettings == null) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: Center(child: CircularProgressIndicator(color: colorScheme.primary)),
      );
    }

    final user = settingsProvider.userSettings;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(theme, colorScheme, user, settingsProvider.blockedUsersCount),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (user != null) _buildUserInfoCard(theme, colorScheme, user),
                    SizedBox(height: 25),
                    _buildSectionTitle('Account', colorScheme),
                    _buildSettingsCard(
                      theme: theme,
                      children: [
                        _buildSettingsTile(
                          icon: Icons.person_outline,
                          title: 'Edit Profile',
                          subtitle: 'Change your profile information',
                          theme: theme,
                          onTap: () => _showEditProfileDialog(theme, user),
                        ),
                        Divider(),
                        _buildSettingsTile(
                          icon: Icons.group_add,
                          title: 'Follow Requests',
                          subtitle: settingsProvider.pendingRequestsCount > 0
                              ? '${settingsProvider.pendingRequestsCount} pending'
                              : 'No pending requests',
                          theme: theme,
                          onTap: () {
                            if (settingsProvider.pendingRequestsCount > 0) {
                              Navigator.push(context, MaterialPageRoute(builder: (_) => FollowRequestsScreen()));
                            }
                          },
                          badgeCount: settingsProvider.pendingRequestsCount,
                        ),
                        Divider(),
                        _buildSettingsTile(
                          icon: Icons.block_outlined,
                          title: 'Blocked Users',
                          subtitle: settingsProvider.blockedUsersCount > 0
                              ? '${settingsProvider.blockedUsersCount} blocked'
                              : 'No blocked users',
                          theme: theme,
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => BlockedUsersScreen())),
                          badgeCount: settingsProvider.blockedUsersCount,
                        ),
                        Divider(),
                        _buildSettingsTile(
                          icon: Icons.email_outlined,
                          title: 'Email Settings',
                          subtitle: 'Manage email preferences',
                          theme: theme,
                          onTap: () => _showEmailSettingsDialog(theme),
                        ),
                        Divider(),
                        _buildSettingsTile(
                          icon: Icons.security_outlined,
                          title: 'Privacy & Security',
                          subtitle: 'Control your privacy settings',
                          theme: theme,
                          onTap: () => _showPrivacySettingsDialog(theme),
                        ),
                      ],
                    ),
                    SizedBox(height: 25),
                    _buildSectionTitle('Cloud & Backup', colorScheme),
                    _buildSettingsCard(
                      theme: theme,
                      children: [
                        _buildSettingsTile(
                          icon: Icons.cloud_queue,
                          title: 'Cloud Storage',
                          subtitle: '${settingsProvider.storageUsage['total']?.toStringAsFixed(1) ?? '0.0'} GB used',
                          theme: theme,
                          onTap: () => _showStorageDetails(theme, settingsProvider),
                        ),
                        Divider(),
                        _buildSettingsTile(
                          icon: Icons.backup,
                          title: 'Last Backup',
                          subtitle: user != null ? _formatBackupTime(user.lastBackup) : 'Never',
                          theme: theme,
                          onTap: () => _showBackupInfoDialog(theme, user, settingsProvider),
                        ),
                        Divider(),
                        _buildSwitchTile(
                          icon: Icons.cloud_sync,
                          title: 'Auto Backup',
                          subtitle: 'Automatically backup content',
                          value: _autoBackup,
                          theme: theme,
                          onChanged: (value) async {
                            setState(() => _autoBackup = value);
                            await _updateSetting('autoBackup', value);
                          },
                        ),
                      ],
                    ),
                    SizedBox(height: 25),
                    _buildSectionTitle('Download Settings', colorScheme),
                    _buildSettingsCard(
                      theme: theme,
                      children: [
                        _buildSettingsTile(
                          icon: Icons.hd_outlined,
                          title: 'Video Quality',
                          subtitle: _downloadQuality,
                          theme: theme,
                          onTap: () => _showQualitySelector(theme),
                        ),
                        Divider(),
                        _buildSettingsTile(
                          icon: Icons.folder_open,
                          title: 'Storage Location',
                          subtitle: _storageLocation,
                          theme: theme,
                          onTap: () => _showStorageLocationSelector(theme),
                        ),
                        Divider(),
                        _buildSwitchTile(
                          icon: Icons.data_saver_off,
                          title: 'Data Saver Mode',
                          subtitle: 'Reduce mobile data usage',
                          value: _dataSaver,
                          theme: theme,
                          onChanged: (value) async {
                            setState(() => _dataSaver = value);
                            await _updateSetting('dataSaver', value);
                          },
                        ),
                      ],
                    ),
                    SizedBox(height: 25),
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
                          },
                        ),
                        Divider(),
                        _buildSwitchTile(
                          icon: Icons.dark_mode_outlined,
                          title: 'Dark Mode',
                          subtitle: 'Switch to dark theme',
                          value: _darkMode,
                          theme: theme,
                          onChanged: (value) {
                            setState(() => _darkMode = value);
                            themeProvider.toggleDarkMode(value);
                          },
                        ),
                        Divider(),
                        _buildSettingsTile(
                          icon: Icons.language,
                          title: 'Language',
                          subtitle: _language,
                          theme: theme,
                          onTap: () => _showLanguageSelector(theme),
                        ),
                      ],
                    ),
                    SizedBox(height: 25),
                    _buildSectionTitle('Support & About', colorScheme),
                    _buildSettingsCard(
                      theme: theme,
                      children: [
                        _buildSettingsTile(
                          icon: Icons.help_outline,
                          title: 'Help Center',
                          subtitle: 'Get help with TapMate',
                          theme: theme,
                          onTap: () => _showHelpCenterDialog(theme, settingsProvider),
                        ),
                        Divider(),
                        _buildSettingsTile(
                          icon: Icons.bug_report_outlined,
                          title: 'Report a Bug',
                          subtitle: 'Report issues or bugs',
                          theme: theme,
                          onTap: () => _showBugReportDialog(theme, settingsProvider),
                        ),
                        Divider(),
                        _buildSettingsTile(
                          icon: Icons.info_outline,
                          title: 'About TapMate',
                          subtitle: 'Version 1.0.0',
                          theme: theme,
                          onTap: () => _showAboutDialog(theme, settingsProvider),
                        ),
                      ],
                    ),
                    SizedBox(height: 25),
                    _buildSectionTitle('Data Management', colorScheme),
                    _buildSettingsCard(
                      theme: theme,
                      children: [
                        _buildSettingsTile(
                          icon: Icons.delete_outline,
                          title: 'Clear Cache',
                          subtitle: 'Free up storage space',
                          theme: theme,
                          onTap: () => _showClearCacheDialog(theme, settingsProvider),
                        ),
                        Divider(),
                        _buildSettingsTile(
                          icon: Icons.refresh,
                          title: 'Reset Settings',
                          subtitle: 'Restore default settings',
                          theme: theme,
                          onTap: () => _showResetSettingsDialog(theme, settingsProvider),
                        ),
                      ],
                    ),
                    SizedBox(height: 30),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _showLogoutDialog(theme, authProvider),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: Icon(Icons.logout, size: 20),
                        label: Text('Log Out', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, ColorScheme colorScheme, UserModel? user, int blockedCount) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colorScheme.tertiary ?? colorScheme.secondary, colorScheme.secondary, colorScheme.primary],
        ),
        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
      ),
      child: Row(
        children: [
          IconButton(icon: Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
          Expanded(child: Text('Settings', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold))),
          if (_isPrivateAccount)
            Container(
              margin: EdgeInsets.only(right: 10),
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
              child: Row(children: [Icon(Icons.lock, size: 14, color: Colors.white), SizedBox(width: 4), Text('Private', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))]),
            ),
          GestureDetector(
            onTap: _changeProfilePicture,
            child: CircleAvatar(
              radius: 20,
              backgroundImage: user?.profilePicUrl != null && user!.profilePicUrl.isNotEmpty
                  ? NetworkImage(_getOptimizedProfileUrl(user.profilePicUrl, size: 80))
                  : null,
              child: user?.profilePicUrl == null || user!.profilePicUrl.isEmpty ? Text(user?.fullName[0] ?? 'U', style: TextStyle(color: Colors.white)) : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserInfoCard(ThemeData theme, ColorScheme colorScheme, UserModel user) {
    return Container(
      decoration: BoxDecoration(
        color: theme.cardTheme.color ?? theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.primary.withOpacity(0.2), width: 1),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          GestureDetector(
            onTap: _changeProfilePicture,
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 35,
                  backgroundImage: user.profilePicUrl.isNotEmpty ? NetworkImage(_getOptimizedProfileUrl(user.profilePicUrl, size: 140)) : null,
                  child: user.profilePicUrl.isEmpty ? Text(user.fullName[0], style: TextStyle(fontSize: 20)) : null,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: EdgeInsets.all(4),
                    decoration: BoxDecoration(color: colorScheme.primary, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                    child: Icon(Icons.camera_alt, size: 16, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.fullName, style: theme.textTheme.titleLarge?.copyWith(color: colorScheme.primary), maxLines: 1, overflow: TextOverflow.ellipsis),
                SizedBox(height: 4),
                Text('@${user.username}', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.7))),
                SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildStatChip('${user.followersCount} followers', colorScheme),
                      SizedBox(width: 8),
                      _buildStatChip('${user.followingCount} following', colorScheme),
                      SizedBox(width: 8),
                      _buildStatChip('${user.postsCount} videos', colorScheme),
                    ],
                  ),
                ),
                if (user.profilePicUrl.contains('cloudinary.com'))
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('✨ Cloudinary CDN', style: TextStyle(fontSize: 10, color: colorScheme.primary, fontWeight: FontWeight.w500)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(String label, ColorScheme colorScheme) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: colorScheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: colorScheme.primary)),
    );
  }

  Widget _buildSectionTitle(String title, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: colorScheme.primary)),
    );
  }

  Widget _buildSettingsCard({required ThemeData theme, required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: theme.cardTheme.color ?? theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withOpacity(0.3), width: 1),
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
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(color: theme.colorScheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: theme.colorScheme.primary, size: 22),
      ),
      title: Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.7))),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (badgeCount > 0)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: theme.colorScheme.error, borderRadius: BorderRadius.circular(10)),
              child: Text(badgeCount.toString(), style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          SizedBox(width: 8),
          Icon(Icons.chevron_right_rounded, color: theme.colorScheme.onSurface.withOpacity(0.5), size: 22),
        ],
      ),
      onTap: onTap,
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
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(color: theme.colorScheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: theme.colorScheme.primary, size: 22),
      ),
      title: Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle),
      trailing: Switch(value: value, onChanged: onChanged, activeColor: theme.colorScheme.primary),
    );
  }

  // Dialog Methods
  void _showEditProfileDialog(ThemeData theme, UserModel? user) {
    if (user == null) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.dialogBackgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Edit Profile'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: _fullNameController, decoration: InputDecoration(labelText: 'Full Name', border: OutlineInputBorder())),
              SizedBox(height: 15),
              TextField(controller: _usernameController, decoration: InputDecoration(labelText: 'Username', border: OutlineInputBorder())),
              SizedBox(height: 15),
              TextField(controller: _bioController, maxLines: 3, decoration: InputDecoration(labelText: 'Bio', border: OutlineInputBorder(), alignLabelWithHint: true)),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel')),
          ElevatedButton(onPressed: _updateProfile, child: Text('Save')),
        ],
      ),
    );
  }

  void _showPrivacySettingsDialog(ThemeData theme) {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: theme.dialogBackgroundColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Privacy Settings'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SwitchListTile(
                  title: Text('Private Account'),
                  subtitle: Text(_isPrivateAccount ? 'Only approved followers can see your posts' : 'Anyone can follow you'),
                  value: _isPrivateAccount,
                  onChanged: _togglePrivateAccount,
                  activeColor: theme.colorScheme.primary,
                ),
                Divider(),
                SwitchListTile(
                  title: Text('Show Online Status'),
                  value: _showOnlineStatus,
                  onChanged: (value) async {
                    setState(() => this._showOnlineStatus = value);
                    await _updateSetting('showOnlineStatus', value);
                  },
                  activeColor: theme.colorScheme.primary,
                ),
                Divider(),
                SwitchListTile(
                  title: Text('Allow Tagging'),
                  value: _allowTagging,
                  onChanged: (value) async {
                    setState(() => _allowTagging = value);
                    await _updateSetting('allowTagging', value);
                  },
                  activeColor: theme.colorScheme.primary,
                ),
                Divider(),
                SwitchListTile(
                  title: Text('Allow Comments'),
                  value: _allowComments,
                  onChanged: (value) async {
                    setState(() => _allowComments = value);
                    await _updateSetting('allowComments', value);
                  },
                  activeColor: theme.colorScheme.primary,
                ),
              ],
            ),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text('Close'))],
        ),
      ),
    );
  }

  void _showEmailSettingsDialog(ThemeData theme) {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: theme.dialogBackgroundColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Email Settings'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SwitchListTile(
                  title: Text('Email Notifications'),
                  value: _emailNotifications,
                  onChanged: (value) async {
                    setState(() => this._emailNotifications = value);
                    await _updateSetting('emailNotifications', value);
                  },
                  activeColor: theme.colorScheme.primary,
                ),
                Divider(),
                SwitchListTile(
                  title: Text('Marketing Emails'),
                  value: _marketingEmails,
                  onChanged: (value) async {
                    setState(() => this._marketingEmails = value);
                    await _updateSetting('marketingEmails', value);
                  },
                  activeColor: theme.colorScheme.primary,
                ),
              ],
            ),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text('Close'))],
        ),
      ),
    );
  }

  void _showStorageDetails(ThemeData theme, SettingsProvider provider) {
    final total = provider.storageUsage['total'] ?? 0.0;
    final videos = provider.storageUsage['videos'] ?? 0.0;
    final cache = provider.storageUsage['cache'] ?? 0.2;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.dialogBackgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Storage Usage'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildStorageDetailRow('Videos', videos, theme),
            _buildStorageDetailRow('Cache', cache, theme),
            SizedBox(height: 20),
            LinearProgressIndicator(
              value: total / 25.0,
              backgroundColor: theme.colorScheme.surfaceVariant,
              valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
              minHeight: 10,
            ),
            SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Available'),
                Text('${(25.0 - total).toStringAsFixed(1)} GB', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text('Close'))],
      ),
    );
  }

  Widget _buildStorageDetailRow(String label, double size, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label), Text('${size.toStringAsFixed(1)} GB', style: TextStyle(fontWeight: FontWeight.bold))]),
    );
  }

  void _showBackupInfoDialog(ThemeData theme, UserModel? user, SettingsProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.dialogBackgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Backup Information'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildBackupInfoItem('Last Backup', user != null ? _formatBackupTime(user.lastBackup) : 'Never', theme),
            _buildBackupInfoItem('Backup Size', '${provider.storageUsage['videos']?.toStringAsFixed(1) ?? '0.0'} GB', theme),
            _buildBackupInfoItem('Items Backed Up', '${user?.postsCount ?? 0} videos', theme),
            _buildBackupInfoItem('Cloud Storage', '25 GB Total', theme),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Close')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await provider.performBackup();
              if (success && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Backup completed!'), backgroundColor: Colors.green));
              }
            },
            child: Text('Backup Now'),
          ),
        ],
      ),
    );
  }

  Widget _buildBackupInfoItem(String label, String value, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: TextStyle(color: Colors.grey)), Text(value, style: TextStyle(fontWeight: FontWeight.w600))]),
    );
  }

  void _showQualitySelector(ThemeData theme) {
    final qualities = ['360p', '480p', '720p', '1080p'];
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.dialogBackgroundColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Select Video Quality', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 20),
            ...qualities.map((quality) => _buildQualityOption(quality, theme)).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildQualityOption(String quality, ThemeData theme) {
    final isSelected = _downloadQuality == quality;
    return ListTile(
      title: Text(quality),
      subtitle: Text(_getQualityDescription(quality)),
      trailing: isSelected ? Icon(Icons.check, color: theme.colorScheme.primary) : null,
      onTap: () async {
        setState(() => _downloadQuality = quality);
        await _updateSetting('downloadQuality', quality);
        if (mounted) Navigator.pop(context);
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

  void _showStorageLocationSelector(ThemeData theme) {
    final locations = ['Phone Storage', 'SD Card', 'Cloud Storage'];
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.dialogBackgroundColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Select Storage Location', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 20),
            ...locations.map((location) => _buildLocationOption(location, theme)).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationOption(String location, ThemeData theme) {
    final isSelected = _storageLocation == location;
    return ListTile(
      title: Text(location),
      subtitle: Text(_getLocationDescription(location)),
      trailing: isSelected ? Icon(Icons.check, color: theme.colorScheme.primary) : null,
      onTap: () async {
        setState(() => _storageLocation = location);
        await _updateSetting('storageLocation', location);
        if (mounted) Navigator.pop(context);
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        height: MediaQuery.of(context).size.height * 0.6,
        child: Column(
          children: [
            Text('Select Language', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
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
      title: Text(language),
      trailing: isSelected ? Icon(Icons.check, color: theme.colorScheme.primary) : null,
      onTap: () async {
        setState(() => _language = language);
        await _updateSetting('language', language);
        if (mounted) Navigator.pop(context);
      },
    );
  }

  void _showClearCacheDialog(ThemeData theme, SettingsProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.dialogBackgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Clear Cache'),
        content: Text('This will clear temporary app data and free up storage space.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await provider.clearCache();
              if (success && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Cache cleared!'), backgroundColor: Colors.green));
              }
            },
            child: Text('Clear'),
          ),
        ],
      ),
    );
  }

  void _showResetSettingsDialog(ThemeData theme, SettingsProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.dialogBackgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Reset Settings'),
        content: Text('Reset all app settings to default values?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await provider.resetSettings();
              if (success && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Settings reset!'), backgroundColor: Colors.green));
                _syncWithProvider();
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: Text('Reset'),
          ),
        ],
      ),
    );
  }

  void _showHelpCenterDialog(ThemeData theme, SettingsProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.dialogBackgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Help Center'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: provider.settingsService.getFAQs(), // ✅ FIXED: settingsService public hai
            builder: (context, snapshot) {
              if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
              if (!snapshot.hasData) return Center(child: CircularProgressIndicator());
              final faqs = snapshot.data!;
              if (faqs.isEmpty) return Center(child: Text('No FAQs available'));
              return ListView.builder(
                itemCount: faqs.length,
                itemBuilder: (context, index) {
                  final faq = faqs[index];
                  return Card(
                    child: ExpansionTile(
                      title: Text(faq['question'], style: TextStyle(fontWeight: FontWeight.w600)),
                      children: [Padding(padding: const EdgeInsets.all(16), child: Text(faq['answer']))],
                    ),
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Close')),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _showContactSupportDialog(theme, provider);
            },
            icon: Icon(Icons.support_agent),
            label: Text('Contact Support'),
          ),
        ],
      ),
    );
  }

  void _showContactSupportDialog(ThemeData theme, SettingsProvider provider) {
    final emailController = TextEditingController(text: provider.userSettings?.email);
    final messageController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.dialogBackgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Contact Support'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: emailController, decoration: InputDecoration(labelText: 'Email', border: OutlineInputBorder())),
              SizedBox(height: 15),
              TextField(controller: messageController, maxLines: 4, decoration: InputDecoration(labelText: 'Message', border: OutlineInputBorder())),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (messageController.text.isEmpty) return;
              Navigator.pop(context);
              await provider.submitSupportRequest(email: emailController.text, message: messageController.text);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Support request sent!'), backgroundColor: Colors.green));
              }
            },
            child: Text('Send'),
          ),
        ],
      ),
    );
  }

  void _showBugReportDialog(ThemeData theme, SettingsProvider provider) {
    final subjectController = TextEditingController();
    final descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.dialogBackgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Report a Bug'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: subjectController, decoration: InputDecoration(labelText: 'Subject', border: OutlineInputBorder())),
              SizedBox(height: 15),
              TextField(controller: descriptionController, maxLines: 4, decoration: InputDecoration(labelText: 'Description', border: OutlineInputBorder())),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (subjectController.text.isEmpty || descriptionController.text.isEmpty) return;
              Navigator.pop(context);
              await provider.submitBugReport(subject: subjectController.text, description: descriptionController.text);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Bug report submitted!'), backgroundColor: Colors.green));
              }
            },
            child: Text('Submit'),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog(ThemeData theme, SettingsProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.dialogBackgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('About TapMate'),
        content: Container(
          width: double.maxFinite,
          constraints: BoxConstraints(maxHeight: 400),
          child: StreamBuilder<Map<String, dynamic>>(
            stream: provider.settingsService.getAppInfo(), // ✅ FIXED: settingsService public hai
            builder: (context, snapshot) {
              if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
              if (!snapshot.hasData) return Center(child: CircularProgressIndicator());

              final appInfo = snapshot.data!;
              return SingleChildScrollView(
                child: Column(
                  children: [
                    Center(
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(color: theme.colorScheme.primary.withOpacity(0.1), shape: BoxShape.circle),
                        child: Icon(Icons.video_library, size: 40, color: theme.colorScheme.primary),
                      ),
                    ),
                    SizedBox(height: 15),
                    _buildAboutInfoRow('Version', appInfo['version'] ?? '1.0.0'),
                    _buildAboutInfoRow('Developer', appInfo['developer'] ?? 'TapMate Team'),
                    _buildAboutInfoRow('Contact', appInfo['contactEmail'] ?? 'support@tapmate.com'),
                    if (appInfo['showAnnouncement'] == true)
                      Padding(padding: const EdgeInsets.all(8.0), child: Text(appInfo['announcement'] ?? '', style: TextStyle(fontWeight: FontWeight.bold))),
                    SizedBox(height: 10),
                    Text('Images delivered via Cloudinary CDN', style: TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic)),
                  ],
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Close')),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _showPrivacyPolicyDialog(theme, provider);
            },
            icon: Icon(Icons.privacy_tip),
            label: Text('Privacy Policy'),
          ),
        ],
      ),
    );
  }

  Widget _buildAboutInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [SizedBox(width: 70, child: Text(label, style: TextStyle(color: Colors.grey))), Expanded(child: Text(value))]),
    );
  }

  void _showPrivacyPolicyDialog(ThemeData theme, SettingsProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.dialogBackgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Privacy Policy'),
        content: Container(
          width: double.maxFinite,
          constraints: BoxConstraints(maxHeight: 300),
          child: StreamBuilder<Map<String, dynamic>>(
            stream: provider.settingsService.getAppInfo(), // ✅ FIXED: settingsService public hai
            builder: (context, snapshot) {
              final policy = snapshot.data?['privacyPolicy'] ?? 'Privacy policy not available.';
              return SingleChildScrollView(child: Text(policy));
            },
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text('Close'))],
      ),
    );
  }

  void _showLogoutDialog(ThemeData theme, AuthProvider authProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.dialogBackgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Log Out'),
        content: Text('Are you sure you want to log out?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('isLoggedIn', false);
              await prefs.setBool('isNewUser', true);
              await authProvider.logout();
              if (mounted) {
                Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => LoginScreen()), (route) => false);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Log Out'),
          ),
        ],
      ),
    );
  }

  void _showRestartTourDialog(ThemeData theme, AuthProvider authProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.dialogBackgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Take Tour Again'),
        content: Text('Restart the guided onboarding tour?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              if (authProvider.isGuest) {
                _showGuestTourDialog(theme);
                return;
              }
              await GuideManager.resetGuideForUser(authProvider.userId);
              if (mounted) {
                Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
              }
            },
            child: Text('Start Tour'),
          ),
        ],
      ),
    );
  }

  void _showGuestTourDialog(ThemeData theme) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Sign Up Required'),
        content: Text('Create an account to take the full tour.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Later')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => LoginScreen()));
            },
            child: Text('Sign Up'),
          ),
        ],
      ),
    );
  }

  String _formatBackupTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);
    if (difference.inDays > 0) return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    if (difference.inHours > 0) return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    if (difference.inMinutes > 0) return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
    return 'Just now';
  }
}