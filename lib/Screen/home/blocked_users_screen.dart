// screens/blocked_users_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../utils/settings_provider.dart';


class BlockedUsersScreen extends StatefulWidget {
  const BlockedUsersScreen({super.key});

  @override
  State<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends State<BlockedUsersScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final provider = Provider.of<SettingsProvider>(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Blocked Users', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(bottom: Radius.circular(20))),
        actions: [
          if (provider.blockedUsers.isNotEmpty)
            IconButton(icon: const Icon(Icons.info_outline), onPressed: () => _showInfoDialog(context, theme)),
        ],
      ),
      body: provider.isLoading && provider.blockedUsers.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : provider.blockedUsers.isEmpty
          ? _buildEmptyState(theme, colorScheme)
          : Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[100],
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 18, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'You have blocked ${provider.blockedUsers.length} user${provider.blockedUsers.length > 1 ? 's' : ''}. Tap to unblock.',
                    style: TextStyle(color: Colors.grey[700], fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: provider.blockedUsers.length,
              itemBuilder: (context, index) {
                final user = provider.blockedUsers[index];
                return _buildBlockedUserTile(context, user, provider);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme, ColorScheme colorScheme) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(color: colorScheme.primary.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(Icons.block_outlined, size: 60, color: colorScheme.primary.withOpacity(0.5)),
            ),
            const SizedBox(height: 24),
            Text('No blocked users', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'When you block someone, they will appear here. Blocked users cannot interact with you.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey[600], height: 1.5),
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Go Back'),
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBlockedUserTile(BuildContext context, Map<String, dynamic> user, SettingsProvider provider) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Stack(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundImage: user['profilePic'] != null && user['profilePic'].isNotEmpty ? NetworkImage(user['profilePic']) : null,
              backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
              child: user['profilePic'] == null
                  ? Text(user['fullName'][0].toUpperCase(), style: TextStyle(fontSize: 20, color: theme.colorScheme.primary))
                  : null,
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(color: Colors.red, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                child: const Icon(Icons.block, size: 10, color: Colors.white),
              ),
            ),
          ],
        ),
        title: Text(user['fullName'], style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('@${user['username']}', style: TextStyle(color: Colors.grey[600])),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 12, color: Colors.grey[500]),
                const SizedBox(width: 4),
                Text(_formatDate(user['blockedAt']), style: TextStyle(color: Colors.grey[500], fontSize: 12)),
              ],
            ),
          ],
        ),
        trailing: TextButton.icon(
          onPressed: () => _unblockUser(context, user['uid'], user['fullName'], provider),
          icon: const Icon(Icons.block_outlined, size: 18),
          label: const Text('Unblock'),
          style: TextButton.styleFrom(
            foregroundColor: Colors.red,
            backgroundColor: Colors.red.withOpacity(0.1),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          ),
        ),
        onTap: () => _showUserDetails(context, user, provider),
      ),
    );
  }

  Future<void> _unblockUser(BuildContext context, String userId, String fullName, SettingsProvider provider) async {
    final shouldUnblock = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).dialogBackgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Unblock User?'),
        content: Text('$fullName will be able to interact with you again.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text('Unblock')),
        ],
      ),
    );

    if (shouldUnblock == true) {
      await provider.unblockUser(userId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$fullName unblocked'), backgroundColor: Colors.green));
      }
    }
  }

  void _showUserDetails(BuildContext context, Map<String, dynamic> user, SettingsProvider provider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            CircleAvatar(
              radius: 50,
              backgroundImage: user['profilePic'] != null && user['profilePic'].isNotEmpty ? NetworkImage(user['profilePic']) : null,
              child: user['profilePic'] == null ? Text(user['fullName'][0], style: const TextStyle(fontSize: 30)) : null,
            ),
            const SizedBox(height: 16),
            Text(user['fullName'], style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            Text('@${user['username']}', style: TextStyle(color: Colors.grey[600])),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _unblockUser(context, user['uid'], user['fullName'], provider);
                },
                icon: const Icon(Icons.block_outlined),
                label: const Text('Unblock User'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showInfoDialog(BuildContext context, ThemeData theme) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.dialogBackgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('About Blocked Users'),
        content: const Text(
          'Blocked users cannot:\n• View your profile\n• Send you messages\n• Follow you\n• See your posts\n\nThey won\'t be notified.',
          style: TextStyle(height: 1.5),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Got it'))],
      ),
    );
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'Unknown';
    try {
      if (timestamp is Timestamp) {
        final date = timestamp.toDate();
        return '${date.day}/${date.month}/${date.year}';
      }
      return 'Unknown';
    } catch (e) {
      return 'Unknown';
    }
  }
}