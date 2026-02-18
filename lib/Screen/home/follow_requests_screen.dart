import 'package:flutter/material.dart';
import 'package:tapmate/Screen/home/other_user_profile_screen.dart';
import 'package:tapmate/Screen/services/dummy_data_service.dart';
import 'package:tapmate/Screen/constants/app_colors.dart';
// Theme Colors
class FollowRequestsScreen extends StatefulWidget {
  const FollowRequestsScreen({super.key});

  @override
  State<FollowRequestsScreen> createState() => _FollowRequestsScreenState();
}

class _FollowRequestsScreenState extends State<FollowRequestsScreen> {
  List<Map<String, dynamic>> _pendingRequests = [];

  @override
  void initState() {
    super.initState();
    _loadPendingRequests();
  }

  void _loadPendingRequests() {
    setState(() {
      _pendingRequests = DummyDataService.pendingFollowRequests;
    });
  }

  void _acceptRequest(String userId, String userName) {
    DummyDataService.acceptFollowRequest(userId);
    setState(() {
      _pendingRequests.removeWhere((req) => req['id'] == userId);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Accepted $userName'),
        backgroundColor: Colors.green,
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            // Undo accept (would need more complex logic in real app)
          },
        ),
      ),
    );
  }

  void _rejectRequest(String userId, String userName) {
    DummyDataService.rejectFollowRequest(userId);
    setState(() {
      _pendingRequests.removeWhere((req) => req['id'] == userId);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Rejected $userName'),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Follow Requests'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.lightSurface,
      ),
      body: _pendingRequests.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.group, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 20),
            const Text(
              'No pending requests',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'When someone requests to follow your private account, it will appear here.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
          ],
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _pendingRequests.length,
        itemBuilder: (context, index) {
          final request = _pendingRequests[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            elevation: 2,
            child: ListTile(
              leading: CircleAvatar(
                radius: 25,
                backgroundColor: AppColors.primary.withOpacity(0.1),
                child: Text(
                  request['avatar'] ?? '👤',
                  style: const TextStyle(fontSize: 24),
                ),
              ),
              title: Text(
                request['full_name'] ?? 'Unknown User',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '@${request['username'] ?? 'user'}',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  Text(
                    request['time'] ?? '',
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  ),
                ],
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton(
                    onPressed: () => _rejectRequest(
                      request['id'],
                      request['full_name'] ?? 'User',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.lightSurface,
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                    child: const Text('Delete'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => _acceptRequest(
                      request['id'],
                      request['full_name'] ?? 'User',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                    child: const Text('Accept', style: TextStyle(color: AppColors.lightSurface)),
                  ),
                ],
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => OtherUserProfileScreen(
                      userId: request['id'] ?? '',
                      userName: request['full_name'] ?? 'Unknown',
                      userAvatar: request['avatar'] ?? '👤',
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

