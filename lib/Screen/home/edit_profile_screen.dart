import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tapmate/Screen/services/dummy_data_service.dart';
import 'package:tapmate/auth_provider.dart';
import 'package:tapmate/Screen/constants/app_colors.dart';

// Local Theme Colors - Avoid confl32);

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  bool _isPrivate = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  void _loadUserData() {
    final user = DummyDataService.currentUser;
    setState(() {
      _nameController.text = user['full_name'] ?? '';
      _usernameController.text = user['username'] ?? '';
      _bioController.text = user['bio'] ?? '';
      _isPrivate = user['is_private'] ?? false;
    });
  }

  void _saveChanges() {
    // In real app, save to backend
    // For dummy data, update locally
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile updated successfully')),
    );

    // Show follow requests dialog if turning account private
    if (_isPrivate && DummyDataService.getPendingFollowRequests().isNotEmpty) {
      _showPendingRequestsDialog();
    }

    Navigator.pop(context);
  }

  void _showPendingRequestsDialog() {
    final pendingRequests = DummyDataService.getPendingFollowRequests();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pending Follow Requests'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'You have ${pendingRequests.length} pending follow request(s).',
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 16),
              ...pendingRequests.map((request) => ListTile(
                leading: CircleAvatar(
                  child: Text(request['avatar'] ?? '👤'),
                ),
                title: Text(request['full_name'] ?? 'Unknown'),
                subtitle: Text('@${request['username'] ?? 'user'}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.check, color: Colors.green),
                      onPressed: () {
                        // Accept follow request
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Accepted ${request['full_name'] ?? 'User'}')),
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.red),
                      onPressed: () {
                        // Reject follow request
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Rejected ${request['full_name'] ?? 'User'}')),
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
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final isGuest = authProvider.isGuest;

    if (isGuest) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Edit Profile'),
        ),
        body: Center(
          child: Text(
            'Please sign in to edit profile',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        actions: [
          TextButton(
            onPressed: _saveChanges,
            child: const Text('Save', style: TextStyle(color: AppColors.lightSurface)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Picture
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: AppColors.primary.withOpacity(0.1),
                    backgroundImage: NetworkImage(DummyDataService.currentUser['profile_pic_url']),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.edit, color: AppColors.lightSurface, size: 20),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: const Text(
                'Change Photo',
                style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w500),
              ),
            ),
            const SizedBox(height: 30),

            // Name
            const Text(
              'Full Name',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                hintText: 'Enter your full name',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Username
            const Text(
              'Username',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _usernameController,
              decoration: InputDecoration(
                hintText: 'Enter username',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                prefixText: '@',
              ),
            ),
            const SizedBox(height: 20),

            // Bio
            const Text(
              'Bio',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _bioController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Tell something about yourself...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 30),

            // PRIVACY SETTINGS SECTION
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Privacy Settings',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.accent,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Private Account Toggle
                  Row(
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Private Account',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Only approved followers can see your posts',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _isPrivate,
                        onChanged: (value) {
                          setState(() {
                            _isPrivate = value;
                          });
                        },
                        activeColor: AppColors.primary,
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Privacy Info
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _isPrivate ? AppColors.primary.withOpacity(0.1) : Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _isPrivate ? Icons.lock : Icons.lock_open,
                          color: _isPrivate ? AppColors.primary : Colors.grey,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _isPrivate
                                ? 'Your account is private. New followers must request to follow you.'
                                : 'Your account is public. Anyone can see your posts.',
                            style: TextStyle(
                              fontSize: 14,
                              color: _isPrivate ? AppColors.primary : Colors.grey[600],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Show pending requests button (if any)
                  if (_isPrivate && DummyDataService.getPendingFollowRequests().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: ElevatedButton.icon(
                        onPressed: _showPendingRequestsDialog,
                        icon: const Icon(Icons.group_add),
                        label: Text(
                          'View ${DummyDataService.getPendingFollowRequests().length} Pending Requests',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.secondary,
                          foregroundColor: AppColors.lightSurface,
                          minimumSize: const Size(double.infinity, 50),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

