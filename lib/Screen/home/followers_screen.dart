import 'package:flutter/material.dart';
import 'package:tapmate/Screen/home/other_user_profile_screen.dart';
import 'package:tapmate/Screen/constants/app_colors.dart';

class FollowersScreen extends StatefulWidget {
  final List<Map<String, dynamic>> followers;
  final Function(Map<String, dynamic>) onUserTap;

  const FollowersScreen({
    super.key,
    required this.followers,
    required this.onUserTap,
  });

  @override
  State<FollowersScreen> createState() => _FollowersScreenState();
}

class _FollowersScreenState extends State<FollowersScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightSurface,
      appBar: AppBar(
        title: const Text('Followers'),
        backgroundColor: AppColors.lightSurface,
        foregroundColor: AppColors.accent,
        elevation: 0,
      ),
      body: widget.followers.isEmpty
          ? const Center(
        child: Text('No followers yet'),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: widget.followers.length,
        itemBuilder: (context, index) {
          final follower = widget.followers[index];
          return _buildFollowerItem(follower);
        },
      ),
    );
  }

  Widget _buildFollowerItem(Map<String, dynamic> follower) {
    return ListTile(
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: AppColors.primary.withOpacity(0.2),
        child: Text(
          follower['avatar'] ?? '👤',
          style: const TextStyle(fontSize: 20),
        ),
      ),
      title: Text(
        follower['name'] ?? 'Unknown',
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
      subtitle: Text(
        '${follower['mutual'] ?? '0'} mutual followers',
        style: const TextStyle(
          fontSize: 14,
          color: Colors.grey,
        ),
      ),
      trailing: ElevatedButton(
        onPressed: () {
          setState(() {
            follower['is_following'] = !(follower['is_following'] ?? false);
          });
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: follower['is_following'] ?? false ? Colors.grey[300] : AppColors.primary,
          foregroundColor: follower['is_following'] ?? false ? AppColors.textMain : AppColors.lightSurface,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: Text(
          follower['is_following'] ?? false ? 'Following' : 'Follow',
          style: const TextStyle(fontSize: 14),
        ),
      ),
      onTap: () => widget.onUserTap(follower),
    );
  }
}

