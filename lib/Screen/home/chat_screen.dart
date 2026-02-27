import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tapmate/Screen/home/other_user_profile_screen.dart';
import 'package:tapmate/Screen/home/video_call_screen.dart';
import 'package:tapmate/Screen/services/chat_service.dart';
import '../../auth_provider.dart';
import '../../theme_provider.dart';
import 'package:tapmate/Screen/constants/app_colors.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';

class ChatScreen extends StatefulWidget {
  final String? initialChatId;
  final String? initialUserId;
  final String? initialUserName;
  final String? initialUserAvatar;

  const ChatScreen({
    super.key,
    this.initialChatId,
    this.initialUserId,
    this.initialUserName,
    this.initialUserAvatar,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late TabController _tabController;

  final ChatService _chatService = ChatService();

  String _currentChatId = "";
  String _currentUserId = "";
  Map<String, dynamic> _currentChatUser = {};
  List<Map<String, dynamic>> _chatUsers = [];
  bool _isLoading = true;

  bool _isEmojiPickerVisible = false;
  final FocusNode _messageFocusNode = FocusNode();

  // For calls tab
  int _missedCallsCount = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    if (widget.initialChatId != null && widget.initialUserId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _openChatWithUser(
          widget.initialChatId!,
          widget.initialUserId!,
          widget.initialUserName ?? 'User',
          widget.initialUserAvatar ?? '👤',
        );
      });
    } else {
      _initializeChat();
    }

    _messageFocusNode.addListener(() {
      if (_messageFocusNode.hasFocus) {
        setState(() {
          _isEmojiPickerVisible = false;
        });
      }
    });

    // Listen to missed calls
    _chatService.getUnreadMissedCallsCount().listen((count) {
      setState(() {
        _missedCallsCount = count;
      });
    });
  }

  void _openChatWithUser(
      String chatId,
      String userId,
      String userName,
      String userAvatar,
      ) {
    setState(() {
      _currentChatId = chatId;
      _currentUserId = userId;
      _currentChatUser = {
        'chatId': chatId,
        'userId': userId,
        'name': userName,
        'avatar': userAvatar,
        'profilePic': null,
      };
      _isLoading = false;
    });

    _chatService.markMessagesAsRead(chatId);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    _tabController.dispose();
    _messageFocusNode.dispose();

    _chatService.updateOnlineStatus(false);
    super.dispose();
  }

  Future<void> _initializeChat() async {
    await _chatService.updateOnlineStatus(true);
    setState(() => _isLoading = false);
  }

  void _openChat(Map<String, dynamic> user) {
    setState(() {
      _currentChatId = user['chatId'];
      _currentUserId = user['userId'];
      _currentChatUser = user;
    });

    _chatService.markMessagesAsRead(_currentChatId);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
  }

  void _goBackToChatList() {
    setState(() {
      _currentChatId = "";
      _currentUserId = "";
      _currentChatUser = {};
      _isEmojiPickerVisible = false;
    });
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty || _currentChatId.isEmpty) return;

    try {
      await _chatService.sendMessage(_currentChatId, message);
      _messageController.clear();
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send message: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _toggleEmojiPicker() {
    setState(() {
      _isEmojiPickerVisible = !_isEmojiPickerVisible;
    });
    if (_isEmojiPickerVisible) {
      SystemChannels.textInput.invokeMethod('TextInput.hide');
      _messageFocusNode.unfocus();
    } else {
      FocusScope.of(context).requestFocus(_messageFocusNode);
    }
  }

  void _onEmojiSelected(Emoji emoji) {
    setState(() {
      _messageController.text = _messageController.text + emoji.emoji;
    });
  }

  void _onBackspacePressed() {
    setState(() {
      String text = _messageController.text;
      if (text.isNotEmpty) {
        _messageController.text = text.substring(0, text.length - 1);
      }
    });
  }

  void _deleteMessage(String messageId) {
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
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _chatService.deleteMessage(_currentChatId, messageId);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Message deleted'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to delete message: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text(
              'Delete',
              style: TextStyle(color: AppColors.lightSurface),
            ),
          ),
        ],
      ),
    );
  }

  void _copyMessage(String message) {
    Clipboard.setData(ClipboardData(text: message));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Message copied to clipboard'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _forwardMessage(Map<String, dynamic> message) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        height: 400,
        child: Column(
          children: [
            const Text(
              'Forward Message',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: _chatService.getChats(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final users = snapshot.data!
                      .where((u) => u['userId'] != _currentUserId)
                      .toList();

                  return ListView.builder(
                    itemCount: users.length,
                    itemBuilder: (context, index) {
                      final user = users[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.primary.withOpacity(0.2),
                          backgroundImage: user['profilePic'] != null
                              ? NetworkImage(user['profilePic'])
                              : null,
                          child: user['profilePic'] == null
                              ? Text(
                            user['avatar'] ?? '👤',
                            style: const TextStyle(fontSize: 20),
                          )
                              : null,
                        ),
                        title: Text(user['name'] ?? 'Unknown'),
                        subtitle: Text('@${user['username'] ?? 'username'}'),
                        onTap: () async {
                          Navigator.pop(context);
                          try {
                            await _chatService.forwardMessage(
                              _currentChatId,
                              message['id'],
                              user['userId'],
                            );
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Message forwarded to ${user['name']}',
                                  ),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Failed to forward message: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
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
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OtherUserProfileScreen(
          userId: userId,
          userName: _currentChatUser['name'] ?? 'User',
          userAvatar: _currentChatUser['avatar'] ?? '👤',
        ),
      ),
    );
  }

  void _startVideoCall() async {
    await _chatService.logCall(
      otherUserId: _currentUserId,
      callType: 'video',
      callStatus: 'completed',
      duration: 120,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VideoCallScreen(
          userName: _currentChatUser['name'] ?? 'User',
          userAvatar: _currentChatUser['avatar'] ?? '👤',
        ),
      ),
    );
  }

  void _startVoiceCall() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Voice Call'),
        content: Text('Calling ${_currentChatUser['name'] ?? 'User'}...'),
        actions: [
          TextButton(
            onPressed: () {
              _chatService.logCall(
                otherUserId: _currentUserId,
                callType: 'voice',
                callStatus: 'missed',
              );
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _chatService.logCall(
                otherUserId: _currentUserId,
                callType: 'voice',
                callStatus: 'completed',
                duration: 180,
              );
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Connected to ${_currentChatUser['name'] ?? 'User'}'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text(
              'Answer',
              style: TextStyle(color: AppColors.lightSurface),
            ),
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
              title: const Text(
                'Block User',
                style: TextStyle(fontSize: 16, color: Colors.red),
              ),
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
              leading: Icon(
                Icons.notifications_off,
                color: AppColors.primary,
                size: 28,
              ),
              title: const Text(
                'Mute Notifications',
                style: TextStyle(fontSize: 16),
              ),
              onTap: () {
                Navigator.pop(context);
                _muteNotifications();
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
        content: Text(
          'Are you sure you want to block ${_currentChatUser['name'] ?? 'this user'}?',
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
                await _chatService.blockUser(_currentUserId);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${_currentChatUser['name'] ?? 'User'} has been blocked'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
                _goBackToChatList();
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to block user: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text(
              'Block',
              style: TextStyle(color: AppColors.lightSurface),
            ),
          ),
        ],
      ),
    );
  }

  void _reportUser() {
    String? selectedReason;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Report User'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Please select a reason for reporting this user:'),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedReason,
                hint: const Text('Select reason'),
                items: const [
                  DropdownMenuItem(value: 'spam', child: Text('Spam')),
                  DropdownMenuItem(value: 'harassment', child: Text('Harassment')),
                  DropdownMenuItem(value: 'inappropriate', child: Text('Inappropriate content')),
                  DropdownMenuItem(value: 'fake', child: Text('Fake account')),
                  DropdownMenuItem(value: 'other', child: Text('Other')),
                ],
                onChanged: (value) {
                  setState(() => selectedReason = value);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (selectedReason == null) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please select a reason'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                  }
                  return;
                }

                Navigator.pop(context);
                try {
                  await _chatService.reportUser(
                    _currentUserId,
                    reason: selectedReason,
                  );
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Report submitted successfully'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to submit report: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text(
                'Submit Report',
                style: TextStyle(color: AppColors.lightSurface),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _muteNotifications() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mute Notifications'),
        content: const Text('Mute notifications for this chat for 7 days?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _chatService.muteChat(_currentChatId, mute: true);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Notifications muted for 7 days'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to mute notifications: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text(
              'Mute',
              style: TextStyle(color: AppColors.lightSurface),
            ),
          ),
        ],
      ),
    );
  }

  void _clearConversation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Conversation'),
        content: const Text(
          'Are you sure you want to clear all messages in this conversation?',
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
                await _chatService.clearConversation(_currentChatId);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Conversation cleared'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to clear conversation: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text(
              'Clear',
              style: TextStyle(color: AppColors.lightSurface),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== REQUEST HANDLERS ====================

  void _acceptRequest(String requestId, String senderId) async {
    try {
      await _chatService.acceptFriendRequest(requestId, senderId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Friend request accepted'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to accept request: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _rejectRequest(String requestId) async {
    try {
      await _chatService.rejectFriendRequest(requestId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Friend request rejected'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to reject request: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _sendFriendRequest(String userId) async {
    try {
      await _chatService.sendFriendRequest(userId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Friend request sent'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send request: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ==================== CALL HANDLERS ====================

  void _markMissedCallsAsRead() async {
    await _chatService.markMissedCallsAsRead();
    setState(() {
      _missedCallsCount = 0;
    });
  }

  void _callUser(String userId, String userName, String callType) async {
    if (callType == 'video') {
      await _chatService.logCall(
        otherUserId: userId,
        callType: 'video',
        callStatus: 'completed',
        duration: 120,
      );
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => VideoCallScreen(
            userName: userName,
            userAvatar: '👤',
          ),
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Voice Call'),
          content: Text('Calling $userName...'),
          actions: [
            TextButton(
              onPressed: () {
                _chatService.logCall(
                  otherUserId: userId,
                  callType: 'voice',
                  callStatus: 'missed',
                );
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _chatService.logCall(
                  otherUserId: userId,
                  callType: 'voice',
                  callStatus: 'completed',
                  duration: 180,
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Connected to $userName'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text('Answer'),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildNavItem(
      IconData icon,
      String label,
      bool isActive,
      BuildContext context,
      bool isDarkMode,
      ) {
    return GestureDetector(
      onTap: () {
        if (label == 'Home') {
          Navigator.pushReplacementNamed(context, '/home');
        } else if (label == 'Discover') {
          Navigator.pushReplacementNamed(context, '/search');
        } else if (label == 'Feed') {
          Navigator.pushReplacementNamed(context, '/feed');
        } else if (label == 'Message') {
          // Already on chat
        } else if (label == 'Profile') {
          Navigator.pushReplacementNamed(context, '/profile');
        }
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: isActive
                ? AppColors.primary
                : (isDarkMode ? Colors.grey[600]! : Colors.grey),
            size: 24,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isActive
                  ? AppColors.primary
                  : (isDarkMode ? Colors.grey[600]! : Colors.grey),
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

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: isDarkMode
            ? const Color(0xFF121212)
            : AppColors.lightSurface,
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(isDarkMode),
              if (_currentChatId.isEmpty)
                Container(
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? const Color(0xFF1E1E1E)
                        : AppColors.lightSurface,
                    border: Border(
                      bottom: BorderSide(color: Colors.grey.withOpacity(0.1)),
                    ),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    labelColor: AppColors.primary,
                    unselectedLabelColor: isDarkMode
                        ? Colors.grey[400]!
                        : Colors.grey,
                    indicatorColor: AppColors.primary,
                    tabs: [
                      const Tab(text: 'Chats'),
                      const Tab(text: 'Requests'),
                      Tab(
                        child: Stack(
                          children: [
                            const Text('Calls'),
                            if (_missedCallsCount > 0)
                              Positioned(
                                right: -8,
                                top: -8,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(
                                    _missedCallsCount.toString(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: _currentChatId.isEmpty
                    ? TabBarView(
                  controller: _tabController,
                  children: [
                    _buildChatsTab(isDarkMode),
                    _buildRequestsTab(isDarkMode),
                    _buildCallsTab(isDarkMode),
                  ],
                )
                    : _buildChatDetailView(isDarkMode),
              ),
              if (_currentChatId.isEmpty)
                SafeArea(
                  top: false,
                  child: Container(
                    height: 70,
                    decoration: BoxDecoration(
                      color: isDarkMode
                          ? const Color(0xFF1E1E1E)
                          : AppColors.lightSurface,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, -2),
                        ),
                      ],
                      border: Border.all(color: Colors.grey.withOpacity(0.1)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildNavItem(
                          Icons.home_rounded,
                          'Home',
                          false,
                          context,
                          isDarkMode,
                        ),
                        _buildNavItem(
                          Icons.explore_rounded,
                          'Discover',
                          false,
                          context,
                          isDarkMode,
                        ),
                        _buildNavItem(
                          Icons.feed_rounded,
                          'Feed',
                          false,
                          context,
                          isDarkMode,
                        ),
                        _buildNavItem(
                          Icons.message_rounded,
                          'Message',
                          true,
                          context,
                          isDarkMode,
                        ),
                        _buildNavItem(
                          Icons.person_rounded,
                          'Profile',
                          false,
                          context,
                          isDarkMode,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGuestView(bool isDarkMode) {
    return Scaffold(
      backgroundColor: isDarkMode
          ? const Color(0xFF121212)
          : AppColors.lightSurface,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock_outline, size: 80, color: AppColors.primary),
                const SizedBox(height: 20),
                Text(
                  'Sign In Required',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode
                        ? AppColors.lightSurface
                        : AppColors.accent,
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 40,
                      vertical: 14,
                    ),
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
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: AppColors.lightSurface,
            ),
            onPressed: () {
              if (_currentChatId.isNotEmpty) {
                setState(() {
                  _isEmojiPickerVisible = false;
                });
                _goBackToChatList();
              } else {
                Navigator.pushReplacementNamed(context, '/home');
              }
            },
          ),
          Expanded(
            child: Row(
              children: [
                if (_currentChatId.isNotEmpty)
                  GestureDetector(
                    onTap: () => _viewUserProfile(_currentUserId),
                    child: CircleAvatar(
                      radius: 20,
                      backgroundColor: AppColors.lightSurface,
                      backgroundImage: _currentChatUser['profilePic'] != null
                          ? NetworkImage(_currentChatUser['profilePic'])
                          : null,
                      child: _currentChatUser['profilePic'] == null
                          ? Text(
                        _currentChatUser['avatar'] ?? '👤',
                        style: const TextStyle(fontSize: 20),
                      )
                          : null,
                    ),
                  ),
                if (_currentChatId.isNotEmpty) const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _currentChatId.isEmpty
                            ? "Messages"
                            : _currentChatUser['name'] ?? 'User',
                        style: const TextStyle(
                          color: AppColors.lightSurface,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (_currentChatId.isNotEmpty)
                        StreamBuilder<DocumentSnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('users')
                              .doc(_currentUserId)
                              .snapshots(),
                          builder: (context, snapshot) {
                            bool isOnline = false;
                            if (snapshot.hasData && snapshot.data!.exists) {
                              var data = snapshot.data!.data() as Map<String, dynamic>?;
                              if (data != null && data.containsKey('isOnline')) {
                                isOnline = data['isOnline'] ?? false;
                              }
                            }
                            return Text(
                              isOnline ? 'Online' : 'Offline',
                              style: const TextStyle(
                                color: Color(0xE6FFFFFF),
                                fontSize: 12,
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_currentChatId.isEmpty)
            IconButton(
              icon: const Icon(Icons.search, color: AppColors.lightSurface),
              onPressed: () {
                Navigator.pushNamed(context, '/search');
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
                } else if (value == 'mute') {
                  _muteNotifications();
                } else if (value == 'report') {
                  _reportUser();
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
                  value: 'mute',
                  child: Row(
                    children: [
                      Icon(Icons.notifications_off, color: AppColors.primary),
                      SizedBox(width: 10),
                      Text('Mute Notifications'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'clear_chat',
                  child: Row(
                    children: [
                      Icon(Icons.delete_sweep, color: Colors.orange),
                      SizedBox(width: 10),
                      Text('Clear Chat'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'report',
                  child: Row(
                    children: [
                      Icon(Icons.flag, color: Colors.orange),
                      SizedBox(width: 10),
                      Text('Report User'),
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

  Widget _buildChatsTab(bool isDarkMode) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
            decoration: BoxDecoration(
              color: isDarkMode
                  ? const Color(0xFF2C2C2C)
                  : AppColors.lightSurface,
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
                        color: isDarkMode
                            ? Colors.grey[500]!
                            : Colors.grey[600]!,
                      ),
                      border: InputBorder.none,
                    ),
                    style: TextStyle(
                      color: isDarkMode
                          ? AppColors.lightSurface
                          : AppColors.textMain,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : StreamBuilder<List<Map<String, dynamic>>>(
            stream: _chatService.getChats(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error, size: 60, color: Colors.red),
                      const SizedBox(height: 10),
                      Text('Error: ${snapshot.error}'),
                    ],
                  ),
                );
              }

              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              List<Map<String, dynamic>> chats = snapshot.data!;

              if (_searchController.text.isNotEmpty) {
                chats = chats.where((chat) {
                  return chat['name'].toString().toLowerCase().contains(
                    _searchController.text.toLowerCase(),
                  ) ||
                      chat['username'].toString().toLowerCase().contains(
                        _searchController.text.toLowerCase(),
                      );
                }).toList();
              }

              if (chats.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.chat_bubble_outline,
                        size: 80,
                        color: isDarkMode
                            ? Colors.grey[600]!
                            : Colors.grey[300]!,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        _searchController.text.isNotEmpty
                            ? 'No conversations found'
                            : 'No conversations yet',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode
                              ? AppColors.lightSurface
                              : AppColors.accent,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _searchController.text.isNotEmpty
                            ? 'Try a different search term'
                            : 'Start a conversation with someone!',
                        style: TextStyle(
                          color: isDarkMode
                              ? Colors.grey[400]!
                              : Colors.grey[600]!,
                        ),
                      ),
                      if (_searchController.text.isEmpty) ...[
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: () =>
                              Navigator.pushNamed(context, '/search'),
                          icon: const Icon(Icons.search),
                          label: const Text('Find People to Chat'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                itemCount: chats.length,
                itemBuilder: (context, index) {
                  final chat = chats[index];
                  return _buildChatListItem(chat, isDarkMode);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildChatListItem(Map<String, dynamic> chat, bool isDarkMode) {
    return GestureDetector(
      onTap: () => _openChat(chat),
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
                  backgroundImage: chat['profilePic'] != null
                      ? NetworkImage(chat['profilePic'])
                      : null,
                  child: chat['profilePic'] == null
                      ? Text(
                    chat['avatar']?.toString() ?? '👤',
                    style: const TextStyle(fontSize: 24),
                  )
                      : null,
                ),
                if (chat['is_online'] == true)
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
                          color: isDarkMode
                              ? const Color(0xFF2C2C2C)
                              : AppColors.lightSurface,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                if (chat['is_muted'] == true)
                  Positioned(
                    left: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.8),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.notifications_off,
                        size: 10,
                        color: Colors.white,
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
                      Expanded(
                        child: Text(
                          chat['name']?.toString() ?? 'Unknown',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDarkMode
                                ? AppColors.lightSurface
                                : AppColors.accent,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (chat['last_message_time'] != null)
                        Text(
                          _formatTime(chat['last_message_time']),
                          style: TextStyle(
                            fontSize: 12,
                            color: isDarkMode
                                ? Colors.grey[400]!
                                : Colors.grey[600]!,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          chat['last_message']?.toString() ?? 'No messages yet',
                          style: TextStyle(
                            fontSize: 14,
                            color: isDarkMode
                                ? Colors.grey[300]!
                                : Colors.grey[700]!,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if ((chat['unread_count'] ?? 0) > 0)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            chat['unread_count'].toString(),
                            style: const TextStyle(
                              color: AppColors.lightSurface,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestsTab(bool isDarkMode) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _chatService.getPendingRequests(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error, size: 60, color: Colors.red),
                const SizedBox(height: 10),
                Text('Error: ${snapshot.error}'),
              ],
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final requests = snapshot.data!;

        if (requests.isEmpty) {
          return Center(
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
                  'When someone sends you a friend request, it will appear here',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isDarkMode ? Colors.grey[400]! : Colors.grey[600]!,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final request = requests[index];
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
                    radius: 30,
                    backgroundColor: AppColors.primary.withOpacity(0.2),
                    backgroundImage: request['profilePic'] != null
                        ? NetworkImage(request['profilePic'])
                        : null,
                    child: request['profilePic'] == null
                        ? Text(
                      request['avatar'] ?? '👤',
                      style: const TextStyle(fontSize: 24),
                    )
                        : null,
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          request['name'] ?? 'Unknown',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDarkMode
                                ? AppColors.lightSurface
                                : AppColors.accent,
                          ),
                        ),
                        if (request['username'] != null)
                          Text(
                            '@${request['username']}',
                            style: TextStyle(
                              fontSize: 14,
                              color: isDarkMode
                                  ? Colors.grey[400]!
                                  : Colors.grey[600]!,
                            ),
                          ),
                        if (request['bio'] != null && request['bio'].isNotEmpty)
                          Text(
                            request['bio'],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDarkMode
                                  ? Colors.grey[500]!
                                  : Colors.grey[700]!,
                            ),
                          ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () => _acceptRequest(
                                  request['request_id'],
                                  request['sender_id'],
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                ),
                                child: const Text('Accept'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => _rejectRequest(
                                  request['request_id'],
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.red,
                                  side: const BorderSide(color: Colors.red),
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                ),
                                child: const Text('Reject'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCallsTab(bool isDarkMode) {
    return Column(
      children: [
        if (_missedCallsCount > 0)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.red.withOpacity(0.1),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.call_missed, color: Colors.red, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      '$_missedCallsCount missed calls',
                      style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: _markMissedCallsAsRead,
                  child: const Text('Mark as read'),
                ),
              ],
            ),
          ),
        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: _chatService.getCallHistory(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error, size: 60, color: Colors.red),
                      const SizedBox(height: 10),
                      Text('Error: ${snapshot.error}'),
                    ],
                  ),
                );
              }

              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final calls = snapshot.data!;

              if (calls.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.call_end,
                        size: 80,
                        color: isDarkMode ? Colors.grey[600]! : Colors.grey[300]!,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'No call history',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? AppColors.lightSurface : AppColors.accent,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Your call history will appear here',
                        style: TextStyle(
                          color: isDarkMode ? Colors.grey[400]! : Colors.grey[600]!,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: calls.length,
                itemBuilder: (context, index) {
                  final call = calls[index];
                  return _buildCallListItem(call, isDarkMode);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCallListItem(Map<String, dynamic> call, bool isDarkMode) {
    IconData callIcon;
    Color callColor;
    String statusText = '';

    if (call['call_type'] == 'video') {
      callIcon = Icons.videocam;
    } else {
      callIcon = Icons.call;
    }

    if (call['call_status'] == 'missed') {
      callColor = Colors.red;
      statusText = 'Missed';
    } else if (call['call_status'] == 'rejected') {
      callColor = Colors.orange;
      statusText = 'Rejected';
    } else {
      callColor = Colors.green;
      statusText = 'Completed';
    }

    String direction = call['is_outgoing'] ? 'Outgoing' : 'Incoming';
    String duration = call['duration'] > 0
        ? _chatService.formatDuration(call['duration'])
        : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF2C2C2C) : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 25,
            backgroundColor: AppColors.primary.withOpacity(0.2),
            backgroundImage: call['profilePic'] != null
                ? NetworkImage(call['profilePic'])
                : null,
            child: call['profilePic'] == null
                ? Text(
              call['avatar'] ?? '👤',
              style: const TextStyle(fontSize: 20),
            )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  call['name'] ?? 'Unknown',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode
                        ? AppColors.lightSurface
                        : AppColors.accent,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      callIcon,
                      size: 14,
                      color: callColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$direction • $statusText',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDarkMode
                            ? Colors.grey[400]!
                            : Colors.grey[600]!,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatCallTime(call['timestamp']),
                style: TextStyle(
                  fontSize: 11,
                  color: isDarkMode
                      ? Colors.grey[500]!
                      : Colors.grey[600]!,
                ),
              ),
              if (duration.isNotEmpty)
                Text(
                  duration,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDarkMode
                        ? Colors.grey[500]!
                        : Colors.grey[600]!,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChatDetailView(bool isDarkMode) {
    return Column(
      children: [
        Expanded(
          flex: 1,  // Messages list ko 1 part
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: _chatService.getMessages(_currentChatId),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final messages = snapshot.data!;

              if (messages.isEmpty) {
                return Center(
                  child: SingleChildScrollView(  // ✅ Fix overflow
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 80,
                          color: isDarkMode
                              ? Colors.grey[600]!
                              : Colors.grey[300]!,
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'No messages yet',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDarkMode
                                ? AppColors.lightSurface
                                : AppColors.accent,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Send a message to start the conversation!',
                          style: TextStyle(
                            color: isDarkMode
                                ? Colors.grey[400]!
                                : Colors.grey[600]!,
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
                  ),
                );
              }

              WidgetsBinding.instance.addPostFrameCallback((_) {
                _scrollToBottom();
              });

              return ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final message = messages[index];
                  final isSent = message['is_sent'] == true;

                  return _buildMessageBubble(
                    message,
                    isSent,
                    isDarkMode,
                    index,
                  );
                },
              );
            },
          ),
        ),

        // ✅ Fix: Input field ko fixed height do
        Container(
          child: _buildMessageInput(isDarkMode),
        ),

        // ✅ Fix: Emoji picker ko exact height do
        if (_isEmojiPickerVisible)
          Container(
            height: 300,  // Fixed height
            color: isDarkMode ? const Color(0xFF2C2C2C) : Colors.white,
            child: EmojiPicker(
              onEmojiSelected: (Category? category, Emoji emoji) {
                _onEmojiSelected(emoji);
              },
              onBackspacePressed: _onBackspacePressed,
              config: const Config(),
            ),
          ),
      ],
    );
  }

  Widget _buildMessageBubble(
      Map<String, dynamic> message,
      bool isSent,
      bool isDarkMode,
      int index,
      ) {
    if (message['is_deleted'] == true && !isSent) {
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Container(
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
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? const Color(0xFF2C2C2C)
                      : Colors.grey[300]!,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'This message was deleted',
                  style: TextStyle(
                    fontStyle: FontStyle.italic,
                    color: isDarkMode ? Colors.grey[400]! : Colors.grey[600]!,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: isSent
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          if (!isSent)
            GestureDetector(
              onTap: () => _viewUserProfile(message['sender_id']),
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                child: CircleAvatar(
                  radius: 16,
                  backgroundColor: AppColors.primary.withOpacity(0.2),
                  backgroundImage: _currentChatUser['profilePic'] != null
                      ? NetworkImage(_currentChatUser['profilePic'])
                      : null,
                  child: _currentChatUser['profilePic'] == null
                      ? Text(
                    _currentChatUser['avatar']?.toString() ?? '👤',
                    style: const TextStyle(fontSize: 14),
                  )
                      : null,
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
                          leading: Icon(
                            Icons.content_copy,
                            color: AppColors.primary,
                          ),
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
                        if (isSent)
                          ListTile(
                            leading: Icon(Icons.delete, color: Colors.red),
                            title: const Text(
                              'Delete',
                              style: TextStyle(color: Colors.red),
                            ),
                            onTap: () {
                              _deleteMessage(message['id']);
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: isSent
                      ? AppColors.primary
                      : (isDarkMode
                      ? const Color(0xFF2C2C2C)
                      : Colors.grey[100]!),
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
                    if (message['is_forwarded'] == true)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            Icon(
                              Icons.share,
                              size: 12,
                              color: isSent
                                  ? Colors.white70
                                  : Colors.grey[500],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Forwarded',
                              style: TextStyle(
                                fontSize: 10,
                                color: isSent
                                    ? Colors.white70
                                    : Colors.grey[500],
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ),
                    Text(
                      message['message'].toString(),
                      style: TextStyle(
                        color: isSent
                            ? AppColors.lightSurface
                            : (isDarkMode
                            ? AppColors.lightSurface
                            : AppColors.textMain),
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
                            color: isSent
                                ? AppColors.lightSurface.withOpacity(0.7)
                                : Colors.grey[500]!,
                            fontSize: 10,
                          ),
                        ),
                        if (isSent) ...[
                          const SizedBox(width: 4),
                          if (message['is_read'] == true)
                            const Icon(
                              Icons.done_all,
                              size: 12,
                              color: Colors.blue,
                            )
                          else if (message['is_delivered'] == true)
                            const Icon(
                              Icons.done_all,
                              size: 12,
                              color: Colors.grey,
                            )
                          else
                            const Icon(
                              Icons.done,
                              size: 12,
                              color: Colors.grey,
                            ),
                        ],
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
        border: Border(top: BorderSide(color: Colors.grey.withOpacity(0.1))),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              _isEmojiPickerVisible ? Icons.keyboard : Icons.emoji_emotions_outlined,
              color: AppColors.primary,
            ),
            onPressed: _toggleEmojiPicker,
          ),
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
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('$value attachment selected'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
          ),
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
                      focusNode: _messageFocusNode,
                      decoration: InputDecoration(
                        hintText: "Type a message...",
                        hintStyle: TextStyle(
                          color: isDarkMode
                              ? Colors.grey[500]!
                              : Colors.grey[600]!,
                        ),
                        border: InputBorder.none,
                      ),
                      style: TextStyle(
                        color: isDarkMode
                            ? AppColors.lightSurface
                            : AppColors.textMain,
                      ),
                      maxLines: null,
                      onSubmitted: (_) => _sendMessage(),
                      onTap: () {
                        if (_isEmojiPickerVisible) {
                          setState(() {
                            _isEmojiPickerVisible = false;
                          });
                        }
                      },
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.mic_none, color: AppColors.primary),
                    onPressed: () {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Voice message feature coming soon'),
                            backgroundColor: Colors.blue,
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
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

  String _formatTime(Timestamp timestamp) {
    DateTime date = timestamp.toDate();
    DateTime now = DateTime.now();

    if (date.day == now.day &&
        date.month == now.month &&
        date.year == now.year) {
      return '${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } else if (date.day == now.day - 1 &&
        date.month == now.month &&
        date.year == now.year) {
      return 'Yesterday';
    } else {
      return '${date.day}/${date.month}';
    }
  }

  String _formatCallTime(Timestamp? timestamp) {
    if (timestamp == null) return '';

    DateTime date = timestamp.toDate();
    DateTime now = DateTime.now();

    if (date.day == now.day &&
        date.month == now.month &&
        date.year == now.year) {
      return 'Today, ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } else if (date.day == now.day - 1 &&
        date.month == now.month &&
        date.year == now.year) {
      return 'Yesterday, ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}