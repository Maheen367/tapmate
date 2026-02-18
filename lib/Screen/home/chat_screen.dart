import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:tapmate/Screen/home/other_user_profile_screen.dart';
import 'package:tapmate/Screen/home/video_call_screen.dart';
import 'package:tapmate/Screen/services/dummy_data_service.dart';
import '../../auth_provider.dart';
import '../../theme_provider.dart';
import 'package:tapmate/Screen/constants/app_colors.dart';
// Theme Colors


class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late TabController _tabController;

  String _currentChatUserId = "";
  late Map<String, dynamic> _currentChatUser;
  List<Map<String, dynamic>> _chatUsers = [];
  List<Map<String, dynamic>> _chatRequests = [];
  Map<String, bool> _typingStatus = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadChats();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _loadChats() {
    setState(() {
      _chatUsers = DummyDataService.getChatUsersList();
      _chatRequests = [
        {
          'id': '6',
          'name': 'New User',
          'username': 'new_user123',
          'mutual_friends': 5,
          'time': '2h ago',
          'avatar': '👤',
          'icon': Icons.person_add,
        },
        {
          'id': '7',
          'name': 'Unknown User',
          'username': 'unknown_user',
          'mutual_friends': 2,
          'time': '1d ago',
          'avatar': '👤',
          'icon': Icons.person_outline,
        },
      ];

      // Initialize typing status
      for (var user in _chatUsers) {
        _typingStatus[user['id']] = false;
      }
    });
  }

  void _openChat(Map<String, dynamic> user) {
    setState(() {
      _currentChatUserId = user['id'];
      _currentChatUser = user;
    });

    // Auto-scroll to bottom
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _goBackToChatList() {
    setState(() {
      _currentChatUserId = "";
    });
  }

  void _sendMessage() {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    // Add message using DummyDataService
    DummyDataService.addMessage(_currentChatUserId, message);

    // Update local state
    setState(() {
      _chatUsers = DummyDataService.getChatUsersList();
    });

    _messageController.clear();
    _scrollToBottom();

    // Simulate typing indicator
    _simulateTyping();
  }

  void _simulateTyping() {
    setState(() {
      _typingStatus[_currentChatUserId] = true;
    });

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _typingStatus[_currentChatUserId] = false;
        });
        _scrollToBottom();
      }
    });
  }

  void _deleteMessage(int index, String userId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Message'),
        content: const Text('Are you sure you want to delete this message?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              // In real app, this would delete from database
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Message deleted'),
                  backgroundColor: Colors.red,
                ),
              );
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: AppColors.lightSurface)),
          ),
        ],
      ),
    );
  }

  void _copyMessage(String message) {
    Clipboard.setData(ClipboardData(text: message));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Message copied to clipboard'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _forwardMessage(Map<String, dynamic> message) {
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
              'Forward Message',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 200,
              child: ListView.builder(
                itemCount: _chatUsers.length,
                itemBuilder: (context, index) {
                  final user = _chatUsers[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.primary.withOpacity(0.2),
                      child: Text(
                        user['avatar'] ?? '👤',
                        style: const TextStyle(fontSize: 20),
                      ),
                    ),
                    title: Text(user['name']),
                    subtitle: Text(user['username'] ?? ''),
                    onTap: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Message forwarded to ${user['name']}'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _viewUserProfile(String userId) {
    final user = DummyDataService.getUserById(userId);
    if (user != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => OtherUserProfileScreen(
            userId: userId,
            userName: user['full_name'] ?? user['name'] ?? 'Unknown',
            userAvatar: user['avatar'] ?? '👤',
          ),
        ),
      );
    }
  }

  void _startVideoCall() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VideoCallScreen(
          userName: _currentChatUser['name'],
          userAvatar: _currentChatUser['avatar'] ?? '👤',
        ),
      ),
    );
  }

  void _startVoiceCall() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Voice Call'),
        content: Text('Calling ${_currentChatUser['name']}...'),
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
                  content: Text('Connected to ${_currentChatUser['name']}'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Answer', style: TextStyle(color: AppColors.lightSurface)),
          ),
        ],
      ),
    );
  }

  void _showUserOptions() {
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
              leading: Icon(Icons.videocam, color: AppColors.primary, size: 28),
              title: const Text('Video Call', style: TextStyle(fontSize: 16)),
              onTap: () {
                Navigator.pop(context);
                _startVideoCall();
              },
            ),
            ListTile(
              leading: Icon(Icons.call, color: Colors.green, size: 28),
              title: const Text('Voice Call', style: TextStyle(fontSize: 16)),
              onTap: () {
                Navigator.pop(context);
                _startVoiceCall();
              },
            ),
            const Divider(),
            ListTile(
              leading: Icon(Icons.block, color: Colors.red, size: 28),
              title: const Text('Block User', style: TextStyle(fontSize: 16, color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _blockUser();
              },
            ),
            ListTile(
              leading: Icon(Icons.report, color: Colors.orange, size: 28),
              title: const Text('Report User', style: TextStyle(fontSize: 16)),
              onTap: () {
                Navigator.pop(context);
                _reportUser();
              },
            ),
            ListTile(
              leading: Icon(Icons.notifications_off, color: AppColors.primary, size: 28),
              title: const Text('Mute Notifications', style: TextStyle(fontSize: 16)),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Notifications muted')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _blockUser() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Block User'),
        content: Text('Are you sure you want to block ${_currentChatUser['name']}?'),
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
                  content: Text('${_currentChatUser['name']} has been blocked'),
                  backgroundColor: Colors.red,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Block', style: TextStyle(color: AppColors.lightSurface)),
          ),
        ],
      ),
    );
  }

  void _reportUser() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Report User'),
        content: const Text('Please select a reason for reporting this user.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Report submitted successfully'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Submit Report', style: TextStyle(color: AppColors.lightSurface)),
          ),
        ],
      ),
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _acceptRequest(int index) {
    setState(() {
      final request = _chatRequests[index];
      _chatRequests.removeAt(index);

      // Add to chat users
      final newUser = {
        'id': request['id'],
        'name': request['name'],
        'username': request['username'],
        'last_message': 'You are now connected',
        'time': 'Just now',
        'icon': Icons.person,
        'is_online': true,
        'unread_count': 0,
        'avatar': request['avatar'],
      };

      _chatUsers.add(newUser);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${request['name']} added to your chats'),
          backgroundColor: Colors.green,
        ),
      );
    });
  }

  void _declineRequest(int index) {
    setState(() {
      final request = _chatRequests[index];
      _chatRequests.removeAt(index);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Request from ${request['name']} declined'),
          backgroundColor: Colors.red,
        ),
      );
    });
  }

  void _clearConversation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Conversation'),
        content: const Text('Are you sure you want to clear all messages in this conversation?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              // In real app, this would clear from database
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Conversation cleared'),
                  backgroundColor: Colors.green,
                ),
              );
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Clear', style: TextStyle(color: AppColors.lightSurface)),
          ),
        ],
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

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isGuest = authProvider.isGuest;
    final isDarkMode = themeProvider.isDarkMode;

    if (isGuest) {
      return _buildGuestView(isDarkMode);
    }

    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF121212) : AppColors.lightSurface,
      body: SafeArea(
        child: Column(
          children: [
            // HEADER
            _buildHeader(isDarkMode),

            // TABS (when in chat list)
            if (_currentChatUserId.isEmpty)
              Container(
                decoration: BoxDecoration(
                  color: isDarkMode ? const Color(0xFF1E1E1E) : AppColors.lightSurface,
                  border: Border(
                    bottom: BorderSide(color: Colors.grey.withOpacity(0.1)),
                  ),
                ),
                child: TabBar(
                  controller: _tabController,
                  labelColor: AppColors.primary,
                  unselectedLabelColor: isDarkMode ? Colors.grey[400]! : Colors.grey,
                  indicatorColor: AppColors.primary,
                  tabs: const [
                    Tab(text: 'Chats'),
                    Tab(text: 'Requests'),
                    Tab(text: 'Calls'),
                  ],
                ),
              ),

            // BODY
            Expanded(
              child: _currentChatUserId.isEmpty
                  ? _buildChatListView(isDarkMode)
                  : _buildChatDetailView(isDarkMode),
            ),

            // BOTTOM NAVIGATION
            SafeArea(
              top: false,
              child: Container(
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
                    _buildNavItem(Icons.message_rounded, 'Message', true, context, isDarkMode),
                    _buildNavItem(Icons.person_rounded, 'Profile', false, context, isDarkMode),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGuestView(bool isDarkMode) {
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
                  Icons.lock_outline,
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
                  'Please sign in to access messages and chat with other users.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: isDarkMode ? Colors.grey[400]! : Colors.grey[600]!,
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

  Widget _buildHeader(bool isDarkMode) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
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
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.lightSurface),
            onPressed: () {
              if (_currentChatUserId.isNotEmpty) {
                _goBackToChatList();
              } else {
                Navigator.pushReplacementNamed(context, '/home');
              }
            },
          ),
          Expanded(
            child: Row(
              children: [
                if (_currentChatUserId.isNotEmpty)
                  GestureDetector(
                    onTap: () => _viewUserProfile(_currentChatUserId),
                    child: CircleAvatar(
                      radius: 20,
                      backgroundColor: AppColors.lightSurface,
                      child: Text(
                        _currentChatUser['avatar'] ?? '👤',
                        style: const TextStyle(fontSize: 20),
                      ),
                    ),
                  ),
                if (_currentChatUserId.isNotEmpty) const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _currentChatUserId.isEmpty ? "Messages" : _currentChatUser['name'],
                        style: const TextStyle(
                          color: AppColors.lightSurface,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (_currentChatUserId.isNotEmpty)
                        Text(
                          _currentChatUser['is_online'] == true ? 'Online' : 'Last seen recently',
                          style: const TextStyle(
                            color: Color(0xE6FFFFFF),
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_currentChatUserId.isEmpty)
            IconButton(
              icon: const Icon(Icons.search, color: AppColors.lightSurface),
              onPressed: () {
                // Search functionality
              },
            )
          else
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: AppColors.lightSurface),
              onSelected: (value) {
                if (value == 'video_call') {
                  _startVideoCall();
                } else if (value == 'voice_call') {
                  _startVoiceCall();
                } else if (value == 'clear_chat') {
                  _clearConversation();
                } else if (value == 'block') {
                  _blockUser();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'video_call',
                  child: Row(
                    children: [
                      Icon(Icons.videocam, color: AppColors.primary),
                      SizedBox(width: 10),
                      Text('Video Call'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'voice_call',
                  child: Row(
                    children: [
                      Icon(Icons.call, color: Colors.green),
                      SizedBox(width: 10),
                      Text('Voice Call'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'clear_chat',
                  child: Row(
                    children: [
                      Icon(Icons.delete, color: Colors.red),
                      SizedBox(width: 10),
                      Text('Clear Chat'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'block',
                  child: Row(
                    children: [
                      Icon(Icons.block, color: Colors.red),
                      SizedBox(width: 10),
                      Text('Block User'),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildChatListView(bool isDarkMode) {
    return TabBarView(
      controller: _tabController,
      children: [
        // CHATS TAB
        _buildChatsTab(isDarkMode),

        // REQUESTS TAB
        _buildRequestsTab(isDarkMode),

        // CALLS TAB
        _buildCallsTab(isDarkMode),
      ],
    );
  }

  Widget _buildChatsTab(bool isDarkMode) {
    final filteredUsers = _chatUsers.where((user) {
      return user['name'].toString().toLowerCase().contains(_searchController.text.toLowerCase()) ||
          (user['username'] ?? '').toString().toLowerCase().contains(_searchController.text.toLowerCase());
    }).toList();

    return Column(
      children: [
        // Search Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
            decoration: BoxDecoration(
              color: isDarkMode ? const Color(0xFF2C2C2C) : AppColors.lightSurface,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(isDarkMode ? 0.2 : 0.1),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(Icons.search, color: AppColors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: "Search conversations...",
                      hintStyle: TextStyle(
                        color: isDarkMode ? Colors.grey[500]! : Colors.grey[600]!,
                      ),
                      border: InputBorder.none,
                    ),
                    style: TextStyle(
                      color: isDarkMode ? AppColors.lightSurface : AppColors.textMain,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Chat list
        Expanded(
          child: filteredUsers.isEmpty
              ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.chat_bubble_outline,
                  size: 80,
                  color: isDarkMode ? Colors.grey[600]! : Colors.grey[300]!,
                ),
                const SizedBox(height: 20),
                Text(
                  'No conversations',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? AppColors.lightSurface : AppColors.accent,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Start a conversation with someone!',
                  style: TextStyle(
                    color: isDarkMode ? Colors.grey[400]! : Colors.grey[600]!,
                  ),
                ),
              ],
            ),
          )
              : ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: filteredUsers.length,
            itemBuilder: (context, index) {
              final user = filteredUsers[index];
              final messages = DummyDataService.getChatMessagesForUser(user['id']);
              final lastMessage = messages.isNotEmpty ? messages.last : null;

              return _buildChatListItem(user, lastMessage, isDarkMode);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildChatListItem(Map<String, dynamic> user, Map<String, dynamic>? lastMessage, bool isDarkMode) {
    return GestureDetector(
      onTap: () => _openChat(user),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF2C2C2C) : AppColors.lightSurface,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(isDarkMode ? 0.2 : 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.primary.withOpacity(0.2),
                  child: Text(
                    user['avatar']?.toString() ?? '👤',
                    style: const TextStyle(fontSize: 24),
                  ),
                ),
                if (user['is_online'] == true)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDarkMode ? const Color(0xFF2C2C2C) : AppColors.lightSurface,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        user['name']?.toString() ?? 'Unknown',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? AppColors.lightSurface : AppColors.accent,
                        ),
                      ),
                      Text(
                        user['time']?.toString() ?? '',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDarkMode ? Colors.grey[400]! : Colors.grey[600]!,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    lastMessage?['message']?.toString() ??
                        user['last_message']?.toString() ?? 'Start a conversation',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDarkMode ? Colors.grey[300]! : Colors.grey[700]!,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if ((user['unread_count'] ?? 0) > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  user['unread_count'].toString(),
                  style: const TextStyle(
                    color: AppColors.lightSurface,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestsTab(bool isDarkMode) {
    return _chatRequests.isEmpty
        ? Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.person_add_disabled,
            size: 80,
            color: isDarkMode ? Colors.grey[600]! : Colors.grey[300]!,
          ),
          const SizedBox(height: 20),
          Text(
            'No pending requests',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? AppColors.lightSurface : AppColors.accent,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'When you receive a request, it will appear here',
            style: TextStyle(
              color: isDarkMode ? Colors.grey[400]! : Colors.grey[600]!,
            ),
          ),
        ],
      ),
    )
        : ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _chatRequests.length,
      itemBuilder: (context, index) {
        final request = _chatRequests[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDarkMode ? const Color(0xFF2C2C2C) : AppColors.lightSurface,
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(isDarkMode ? 0.2 : 0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: AppColors.primary.withOpacity(0.2),
                child: Icon(
                  request['icon'] as IconData? ?? Icons.person,
                  size: 24,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request['name']?.toString() ?? 'Unknown',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? AppColors.lightSurface : AppColors.accent,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${request['mutual_friends']} mutual friends',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDarkMode ? Colors.grey[300]! : Colors.grey[600]!,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _acceptRequest(index),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                            child: const Text('Accept'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _declineRequest(index),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              side: BorderSide(color: Colors.grey),
                            ),
                            child: Text(
                              'Decline',
                              style: TextStyle(
                                color: isDarkMode ? Colors.grey[300]! : Colors.grey[700]!,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Text(
                request['time']?.toString() ?? '',
                style: TextStyle(
                  fontSize: 12,
                  color: isDarkMode ? Colors.grey[400]! : Colors.grey[600]!,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCallsTab(bool isDarkMode) {
    final List<Map<String, dynamic>> callHistory = [
      {
        'name': 'John Doe',
        'type': 'outgoing',
        'time': 'Today, 10:30 AM',
        'duration': '5:24',
        'avatar': '👤',
        'color': Colors.green,
      },
      {
        'name': 'Sarah Smith',
        'type': 'incoming',
        'time': 'Yesterday, 3:15 PM',
        'duration': '12:45',
        'avatar': '👩',
        'color': Colors.blue,
      },
      {
        'name': 'Mike Johnson',
        'type': 'missed',
        'time': '2 days ago',
        'duration': 'Missed',
        'avatar': '🧑',
        'color': Colors.red,
      },
    ];

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: callHistory.length,
      itemBuilder: (context, index) {
        final call = callHistory[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDarkMode ? const Color(0xFF2C2C2C) : AppColors.lightSurface,
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(isDarkMode ? 0.2 : 0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: (call['color'] as Color).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  call['type'] == 'outgoing' ? Icons.call_made :
                  call['type'] == 'incoming' ? Icons.call_received : Icons.call_missed,
                  color: call['color'] as Color,
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      call['name'] as String,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? AppColors.lightSurface : AppColors.accent,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      (call['type'] as String).toUpperCase(),
                      style: TextStyle(
                        fontSize: 12,
                        color: call['color'] as Color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    call['time'] as String,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDarkMode ? Colors.grey[400]! : Colors.grey[600]!,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    call['duration'] as String,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDarkMode ? Colors.grey[400]! : Colors.grey[600]!,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildChatDetailView(bool isDarkMode) {
    final messages = DummyDataService.getChatMessagesForUser(_currentChatUserId);
    final isTyping = _typingStatus[_currentChatUserId] ?? false;

    return Column(
      children: [
        // Typing indicator
        if (isTyping)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: isDarkMode ? const Color(0xFF2C2C2C) : Colors.grey[100],
            child: Row(
              children: [
                Text(
                  '${_currentChatUser['name']} is typing...',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDarkMode ? Colors.grey[400]! : Colors.grey[600]!,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),

        // Messages list
        Expanded(
          child: messages.isEmpty
              ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.chat_bubble_outline,
                  size: 80,
                  color: isDarkMode ? Colors.grey[600]! : Colors.grey[300]!,
                ),
                const SizedBox(height: 20),
                Text(
                  'No messages yet',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? AppColors.lightSurface : AppColors.accent,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Send a message to start the conversation!',
                  style: TextStyle(
                    color: isDarkMode ? Colors.grey[400]! : Colors.grey[600]!,
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () {
                    _messageController.text = 'Hi there! 👋';
                    _sendMessage();
                  },
                  icon: const Icon(Icons.waving_hand),
                  label: const Text('Say Hello'),
                ),
              ],
            ),
          )
              : ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            itemCount: messages.length,
            itemBuilder: (context, index) {
              final message = messages[index];
              final isSent = message['sender_id'] == 'current_user';

              return _buildMessageBubble(message, isSent, isDarkMode, index);
            },
          ),
        ),

        // Message input
        _buildMessageInput(isDarkMode),
      ],
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> message, bool isSent, bool isDarkMode, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: isSent ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isSent)
            GestureDetector(
              onTap: () => _viewUserProfile(message['sender_id']),
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                child: CircleAvatar(
                  radius: 16,
                  backgroundColor: AppColors.primary.withOpacity(0.2),
                  child: Text(
                    _currentChatUser['avatar']?.toString() ?? '👤',
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ),
            ),
          Flexible(
            child: GestureDetector(
              onLongPress: () {
                showModalBottomSheet(
                  context: context,
                  builder: (_) => Container(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
                          leading: Icon(Icons.content_copy, color: AppColors.primary),
                          title: const Text('Copy'),
                          onTap: () {
                            _copyMessage(message['message'].toString());
                            Navigator.pop(context);
                          },
                        ),
                        ListTile(
                          leading: Icon(Icons.share, color: AppColors.primary),
                          title: const Text('Forward'),
                          onTap: () {
                            _forwardMessage(message);
                            Navigator.pop(context);
                          },
                        ),
                        ListTile(
                          leading: Icon(Icons.delete, color: Colors.red),
                          title: const Text('Delete', style: TextStyle(color: Colors.red)),
                          onTap: () {
                            _deleteMessage(index, _currentChatUserId);
                            Navigator.pop(context);
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.75,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isSent
                      ? AppColors.primary
                      : (isDarkMode ? const Color(0xFF2C2C2C) : Colors.grey[100]!),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.textMain.withOpacity(0.1),
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      message['message'].toString(),
                      style: TextStyle(
                        color: isSent ? AppColors.lightSurface : (isDarkMode ? AppColors.lightSurface : AppColors.textMain),
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          message['time'].toString(),
                          style: TextStyle(
                            color: isSent ? AppColors.lightSurface.withOpacity(0.7) : Colors.grey[500]!,
                            fontSize: 10,
                          ),
                        ),
                        if (isSent)
                          Row(
                            children: [
                              const SizedBox(width: 4),
                              Icon(
                                message['is_read'] == true ? Icons.done_all : Icons.done,
                                size: 12,
                                color: message['is_read'] == true ? Colors.blue : AppColors.lightSurface.withOpacity(0.7),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageInput(bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF2C2C2C) : AppColors.lightSurface,
        border: Border(
          top: BorderSide(color: Colors.grey.withOpacity(0.1)),
        ),
      ),
      child: Row(
        children: [
          // Emoji button
          IconButton(
            icon: Icon(Icons.emoji_emotions_outlined, color: AppColors.primary),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Emoji picker coming soon'),
                  backgroundColor: Colors.blue,
                ),
              );
            },
          ),

          // Attach button
          PopupMenuButton<String>(
            icon: Icon(Icons.attach_file, color: AppColors.primary),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'photo',
                child: Row(
                  children: [
                    Icon(Icons.photo, color: AppColors.primary),
                    SizedBox(width: 10),
                    Text('Photo & Video'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'camera',
                child: Row(
                  children: [
                    Icon(Icons.camera_alt, color: AppColors.primary),
                    SizedBox(width: 10),
                    Text('Camera'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'document',
                child: Row(
                  children: [
                    Icon(Icons.insert_drive_file, color: AppColors.primary),
                    SizedBox(width: 10),
                    Text('Document'),
                  ],
                ),
              ),
            ],
            onSelected: (value) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('$value attachment selected'),
                  backgroundColor: Colors.green,
                ),
              );
            },
          ),

          // Message input field
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.grey[100],
                borderRadius: BorderRadius.circular(25),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: "Type a message...",
                        hintStyle: TextStyle(
                          color: isDarkMode ? Colors.grey[500]! : Colors.grey[600]!,
                        ),
                        border: InputBorder.none,
                      ),
                      style: TextStyle(
                        color: isDarkMode ? AppColors.lightSurface : AppColors.textMain,
                      ),
                      maxLines: null,
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),

                  // Voice message button
                  IconButton(
                    icon: Icon(Icons.mic_none, color: AppColors.primary),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Voice message feature coming soon'),
                          backgroundColor: Colors.blue,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          // Send button
          const SizedBox(width: 12),
          Container(
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.send, color: AppColors.lightSurface),
              onPressed: _sendMessage,
            ),
          ),
        ],
      ),
    );
  }
}

