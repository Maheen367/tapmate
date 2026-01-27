import 'package:flutter/material.dart';

class DummyDataService {
  // Current user data with private account option
  static Map<String, dynamic> get currentUser {
    return {
      'id': 'current_user',
      'full_name': 'Your Name',
      'username': '@yourusername',
      'email': 'user@example.com',
      'profile_pic_url': 'https://picsum.photos/200',
      'bio': 'This is your bio. Edit it to tell others about yourself!',
      'posts_count': 12,
      'followers_count': 345,
      'following_count': 123,
      'is_verified': false,
      'is_private': false, // NEW: Private account status
      'pending_follow_requests': [], // NEW: List of pending follow requests
    };
  }

  // All users data with private account option
  static List<Map<String, dynamic>> get allUsers {
    return [
      {
        'id': '1',
        'full_name': 'John Doe',
        'username': '@johndoe',
        'profile_pic_url': 'https://picsum.photos/200?random=1',
        'avatar': '👤',
        'bio': 'Tech enthusiast & content creator',
        'posts_count': 24,
        'followers_count': 1250,
        'following_count': 450,
        'is_following': true,
        'is_online': true,
        'is_private': false,
      },
      {
        'id': '2',
        'full_name': 'Sarah Smith',
        'username': '@sarahsmith',
        'profile_pic_url': 'https://picsum.photos/200?random=2',
        'avatar': '👩',
        'bio': 'Fitness trainer & nutrition expert',
        'posts_count': 18,
        'followers_count': 890,
        'following_count': 320,
        'is_following': false,
        'is_online': false,
        'is_private': true, // This account is private
      },
      {
        'id': '3',
        'full_name': 'Mike Johnson',
        'username': '@mikejohnson',
        'profile_pic_url': 'https://picsum.photos/200?random=3',
        'avatar': '🧑',
        'bio': 'Travel blogger & photographer',
        'posts_count': 56,
        'followers_count': 2300,
        'following_count': 780,
        'is_following': true,
        'is_online': false,
        'is_private': false,
      },
      {
        'id': '4',
        'full_name': 'Emma Wilson',
        'username': '@emmawilson',
        'profile_pic_url': 'https://picsum.photos/200?random=4',
        'avatar': '👱‍♀️',
        'bio': 'Food vlogger & chef',
        'posts_count': 32,
        'followers_count': 1500,
        'following_count': 560,
        'is_following': false,
        'is_online': true,
        'is_private': false,
      },
      {
        'id': '5',
        'full_name': 'Alex Brown',
        'username': '@alexbrown',
        'profile_pic_url': 'https://picsum.photos/200?random=5',
        'avatar': '👨',
        'bio': 'Music producer & DJ',
        'posts_count': 45,
        'followers_count': 2100,
        'following_count': 670,
        'is_following': true,
        'is_online': true,
        'is_private': true, // This account is private
      },
    ];
  }

  // Pending follow requests for current user (GETTER)
  static List<Map<String, dynamic>> get pendingFollowRequests {
    return [
      {
        'id': '6',
        'full_name': 'Robert Chen',
        'username': '@robertchen',
        'avatar': '👨‍💼',
        'profile_pic_url': 'https://picsum.photos/200?random=10',
        'time': '2 hours ago',
      },
      {
        'id': '7',
        'full_name': 'Lisa Wong',
        'username': '@lisawong',
        'avatar': '👩‍💻',
        'profile_pic_url': 'https://picsum.photos/200?random=11',
        'time': '1 day ago',
      },
      {
        'id': '8',
        'full_name': 'David Miller',
        'username': '@davidm',
        'avatar': '👨‍🎓',
        'profile_pic_url': 'https://picsum.photos/200?random=12',
        'time': '3 days ago',
      },
    ];
  }

  // Get pending follow requests (METHOD version - for calling)
  static List<Map<String, dynamic>> getPendingFollowRequests() {
    return pendingFollowRequests;
  }

  // Posts data
  static List<Map<String, dynamic>> get allPosts {
    return [
      {
        'id': '1',
        'user_id': '1',
        'user_name': 'John Doe',
        'user_avatar': '👤',
        'user_profile_pic': 'https://picsum.photos/200?random=1',
        'caption': 'Amazing sunset at the beach! 🌅 #sunset #beach #vacation',
        'thumbnail_url': 'https://picsum.photos/400/400?random=1',
        'video_url': 'https://example.com/video1.mp4',
        'likes_count': 1245,
        'comments_count': 89,
        'shares_count': 45,
        'is_video': false,
        'platform': 'YouTube',
        'created_at': '2h ago',
        'duration': '8:45',
        'views': '1.2M',
        'can_download': true,
        'is_liked': false,
      },
      {
        'id': '2',
        'user_id': '2',
        'user_name': 'Sarah Smith',
        'user_avatar': '👩',
        'user_profile_pic': 'https://picsum.photos/200?random=2',
        'caption': 'Morning workout complete! 💪 #fitness #workout #health',
        'thumbnail_url': 'https://picsum.photos/400/400?random=2',
        'video_url': 'https://example.com/video2.mp4',
        'likes_count': 890,
        'comments_count': 34,
        'shares_count': 23,
        'is_video': true,
        'platform': 'TikTok',
        'created_at': '5h ago',
        'duration': '5:30',
        'views': '850K',
        'can_download': true,
        'is_liked': false,
      },
      {
        'id': '3',
        'user_id': '3',
        'user_name': 'Mike Johnson',
        'user_avatar': '🧑',
        'user_profile_pic': 'https://picsum.photos/200?random=3',
        'caption': 'Exploring Tokyo streets 🇯🇵 #travel #japan #adventure',
        'thumbnail_url': 'https://picsum.photos/400/400?random=3',
        'video_url': 'https://example.com/video3.mp4',
        'likes_count': 2300,
        'comments_count': 156,
        'shares_count': 89,
        'is_video': false,
        'platform': 'Instagram',
        'created_at': '1d ago',
        'duration': '15:20',
        'views': '2.5M',
        'can_download': true,
        'is_liked': false,
      },
      {
        'id': '4',
        'user_id': '4',
        'user_name': 'Emma Wilson',
        'user_avatar': '👱‍♀️',
        'user_profile_pic': 'https://picsum.photos/200?random=4',
        'caption': 'Homemade pasta recipe 🍝 #cooking #food #recipe',
        'thumbnail_url': 'https://picsum.photos/400/400?random=4',
        'video_url': 'https://example.com/video4.mp4',
        'likes_count': 1500,
        'comments_count': 78,
        'shares_count': 56,
        'is_video': true,
        'platform': 'YouTube',
        'created_at': '2d ago',
        'duration': '12:45',
        'views': '3.1M',
        'can_download': true,
        'is_liked': false,
      },
      {
        'id': '5',
        'user_id': '5',
        'user_name': 'Alex Brown',
        'user_avatar': '👨',
        'user_profile_pic': 'https://picsum.photos/200?random=5',
        'caption': 'New music mix dropping soon! 🎵 #music #dj #mix',
        'thumbnail_url': 'https://picsum.photos/400/400?random=5',
        'video_url': 'https://example.com/video5.mp4',
        'likes_count': 3200,
        'comments_count': 210,
        'shares_count': 145,
        'is_video': true,
        'platform': 'TikTok',
        'created_at': '3d ago',
        'duration': '3:20',
        'views': '4.5M',
        'can_download': true,
        'is_liked': false,
      },
    ];
  }

  // Trending videos for discovery
  static List<Map<String, dynamic>> get trendingVideos {
    return [
      {
        'id': 't1',
        'title': 'Dance Challenge Viral',
        'channel': 'Dance Crew',
        'views': '5.2M views',
        'duration': '1:45',
        'platform': 'TikTok',
        'thumbnail_url': 'https://picsum.photos/300/200?random=6',
        'trending': true,
        'can_download': true,
      },
      {
        'id': 't2',
        'title': 'Tech Review Latest Phone',
        'channel': 'Tech Guru',
        'views': '1.8M views',
        'duration': '12:30',
        'platform': 'YouTube',
        'thumbnail_url': 'https://picsum.photos/300/200?random=7',
        'trending': true,
        'can_download': true,
      },
      {
        'id': 't3',
        'title': 'Funny Cat Compilation',
        'channel': 'Animal Planet',
        'views': '4.3M views',
        'duration': '7:15',
        'platform': 'Instagram',
        'thumbnail_url': 'https://picsum.photos/300/200?random=8',
        'trending': true,
        'can_download': true,
      },
      {
        'id': 't4',
        'title': 'Gaming Highlights 2024',
        'channel': 'Game Master',
        'views': '3.2M views',
        'duration': '9:45',
        'platform': 'YouTube',
        'thumbnail_url': 'https://picsum.photos/300/200?random=9',
        'trending': true,
        'can_download': true,
      },
    ];
  }

  // Chat data
  static List<Map<String, dynamic>> get chatUsers {
    return [
      {
        'id': '1',
        'name': 'John Doe',
        'username': 'tech_guru',
        'last_message': 'Check this out',
        'time': '1h ago',
        'icon': Icons.computer,
        'is_online': true,
        'unread_count': 0,
        'avatar': '👤',
      },
      {
        'id': '2',
        'name': 'Sarah Smith',
        'username': 'fitness_pro',
        'last_message': 'Gym 7pm?',
        'time': '3h ago',
        'icon': Icons.fitness_center,
        'is_online': false,
        'unread_count': 0,
        'avatar': '👩',
      },
      {
        'id': '3',
        'name': 'Mike Johnson',
        'username': 'travel_buddy',
        'last_message': 'Trip update',
        'time': '1d ago',
        'icon': Icons.flight,
        'is_online': false,
        'unread_count': 2,
        'avatar': '🧑',
      },
      {
        'id': '4',
        'name': 'Emma Wilson',
        'username': 'foodie_chef',
        'last_message': 'New recipe!',
        'time': '2d ago',
        'icon': Icons.restaurant,
        'is_online': true,
        'unread_count': 0,
        'avatar': '👱‍♀️',
      },
      {
        'id': '5',
        'name': 'Alex Brown',
        'username': 'music_lover',
        'last_message': 'New playlist 🔥',
        'time': '3d ago',
        'icon': Icons.music_note,
        'is_online': false,
        'unread_count': 1,
        'avatar': '👨',
      },
    ];
  }

  // Chat messages
  static Map<String, List<Map<String, dynamic>>> get chatMessages {
    return {
      '1': [
        {'id': '1', 'sender_id': '1', 'message': 'Hey there! How are you?', 'time': '10:00 AM', 'is_sent': true, 'is_read': true},
        {'id': '2', 'sender_id': 'current_user', 'message': 'Hi John! I\'m good, working on some new features.', 'time': '10:02 AM', 'is_sent': true, 'is_read': true},
        {'id': '3', 'sender_id': '1', 'message': 'That sounds awesome! Check this cool tech article I found.', 'time': '10:05 AM', 'is_sent': true, 'is_read': true},
        {'id': '4', 'sender_id': 'current_user', 'message': 'Wow, this is really interesting! Thanks for sharing.', 'time': '10:10 AM', 'is_sent': true, 'is_read': true},
      ],
      '2': [
        {'id': '1', 'sender_id': '2', 'message': 'Hey! Are you coming to the gym today?', 'time': '3:00 PM', 'is_sent': true, 'is_read': true},
        {'id': '2', 'sender_id': 'current_user', 'message': 'Yes! I\'ll be there at 7pm.', 'time': '3:10 PM', 'is_sent': true, 'is_read': true},
        {'id': '3', 'sender_id': '2', 'message': 'Perfect! Don\'t forget your water bottle.', 'time': '3:15 PM', 'is_sent': true, 'is_read': true},
      ],
      '3': [
        {'id': '1', 'sender_id': '3', 'message': 'Just landed in Tokyo! The trip has been amazing so far.', 'time': '9:00 AM', 'is_sent': true, 'is_read': true},
        {'id': '2', 'sender_id': 'current_user', 'message': 'That\'s incredible! Send some pictures!', 'time': '9:30 AM', 'is_sent': true, 'is_read': true},
      ],
      '4': [
        {'id': '1', 'sender_id': '4', 'message': 'Just tried a new pasta recipe - it came out perfectly!', 'time': '6:00 PM', 'is_sent': true, 'is_read': true},
        {'id': '2', 'sender_id': 'current_user', 'message': 'I need that recipe! My pasta never turns out right.', 'time': '6:15 PM', 'is_sent': true, 'is_read': true},
      ],
      '5': [
        {'id': '1', 'sender_id': '5', 'message': 'Just finished my new music mix, want to listen?', 'time': '8:00 PM', 'is_sent': true, 'is_read': true},
        {'id': '2', 'sender_id': 'current_user', 'message': 'Definitely! Send me the link.', 'time': '8:05 PM', 'is_sent': true, 'is_read': true},
      ],
    };
  }

  // Get user by ID
  static Map<String, dynamic>? getUserById(String userId) {
    try {
      if (userId == 'current_user') {
        return currentUser;
      }
      return allUsers.firstWhere((user) => user['id'] == userId);
    } catch (e) {
      return null;
    }
  }

  // Get posts by user ID (filtered for private accounts)
  static List<Map<String, dynamic>> getPostsByUser(String userId, {bool checkPrivacy = true}) {
    final user = getUserById(userId);
    final bool isPrivate = user?['is_private'] ?? false;
    final bool isFollowing = user?['is_following'] ?? false;

    // If account is private and viewer is not following, return empty list
    if (checkPrivacy && isPrivate && !isFollowing && userId != 'current_user') {
      return [];
    }

    return allPosts.where((post) => post['user_id'] == userId).toList();
  }

  // Get current user's posts
  static List<Map<String, dynamic>> getUserPosts() {
    return allPosts;
  }

  // Get saved posts
  static List<Map<String, dynamic>> getSavedPosts() {
    return [
      allPosts[1],
      allPosts[3],
    ];
  }

  // Get feed posts (filter private posts if not following)
  static List<Map<String, dynamic>> getFeedPosts() {
    return allPosts.where((post) {
      final userId = post['user_id'];
      final user = getUserById(userId);
      if (user != null && user['is_private'] == true) {
        // Check if current user is following this private account
        return user['is_following'] == true || userId == 'current_user';
      }
      return true;
    }).toList();
  }

  // Get user followers
  static List<Map<String, dynamic>> getUserFollowers(String userId) {
    return allUsers.where((user) => user['id'] != userId).map((user) {
      return {
        'id': user['id'],
        'name': user['full_name'],
        'avatar': user['avatar'],
        'profile_pic': user['profile_pic_url'],
        'is_following': user['is_following'],
        'mutual': (user['followers_count'] ~/ 10).toString(),
      };
    }).toList();
  }

  // Get user following
  static List<Map<String, dynamic>> getUserFollowing(String userId) {
    return allUsers.where((user) => user['id'] != userId).map((user) {
      return {
        'id': user['id'],
        'name': user['full_name'],
        'avatar': user['avatar'],
        'profile_pic': user['profile_pic_url'],
        'mutual': (user['following_count'] ~/ 10).toString(),
        'category': ['Friends', 'Family', 'Work', 'Following'][int.parse(user['id']) % 4],
      };
    }).toList();
  }

  // Get chat users
  static List<Map<String, dynamic>> getChatUsersList() {
    return chatUsers;
  }

  // Get chat messages for a user
  static List<Map<String, dynamic>> getChatMessagesForUser(String userId) {
    return chatMessages[userId] ?? [];
  }

  // Get trending videos
  static List<Map<String, dynamic>> getTrendingVideosList() {
    return trendingVideos;
  }

  // Get search results
  static List<Map<String, dynamic>> getSearchResults(String query) {
    final results = allPosts.where((post) {
      return post['caption'].toLowerCase().contains(query.toLowerCase()) ||
          post['user_name'].toLowerCase().contains(query.toLowerCase());
    }).toList();

    return results.isEmpty ? trendingVideos : results;
  }

  // Get trending searches
  static List<String> getTrendingSearches() {
    return [
      "Cooking tutorials",
      "Travel vlogs",
      "Music videos",
      "Dance challenges",
      "Gaming highlights",
      "Fitness workouts",
      "Tech reviews",
      "Comedy sketches",
    ];
  }

  // Update user follow status
  static void toggleFollow(String userId) {
    final userIndex = allUsers.indexWhere((user) => user['id'] == userId);
    if (userIndex != -1) {
      allUsers[userIndex]['is_following'] = !allUsers[userIndex]['is_following'];
      if (allUsers[userIndex]['is_following']) {
        allUsers[userIndex]['followers_count']++;

        // If this is a private account and we're following, remove from pending requests
        if (allUsers[userIndex]['is_private'] == true) {
          // Remove from pending requests if exists
          pendingFollowRequests.removeWhere((req) => req['id'] == userId);
        }
      } else {
        allUsers[userIndex]['followers_count']--;
      }
    }
  }

  // Add a new message to chat
  static void addMessage(String userId, String messageText) {
    final messages = chatMessages[userId] ?? [];
    final newMessage = {
      'id': (messages.length + 1).toString(),
      'sender_id': 'current_user',
      'message': messageText,
      'time': 'Just now',
      'is_sent': true,
      'is_read': true,
    };
    messages.add(newMessage);
  }

  // Toggle account privacy
  static void toggleAccountPrivacy(bool isPrivate) {
    // Update current user's privacy
    currentUser['is_private'] = isPrivate;
  }

  // Get pending follow requests count
  static int getPendingRequestsCount() {
    return pendingFollowRequests.length;
  }

  // Accept follow request
  static void acceptFollowRequest(String userId) {
    // Find user in allUsers
    final userIndex = allUsers.indexWhere((user) => user['id'] == userId);
    if (userIndex != -1) {
      allUsers[userIndex]['is_following'] = true;
      allUsers[userIndex]['followers_count']++;
    }

    // Remove from pending requests
    pendingFollowRequests.removeWhere((req) => req['id'] == userId);
  }

  // Reject follow request
  static void rejectFollowRequest(String userId) {
    pendingFollowRequests.removeWhere((req) => req['id'] == userId);
  }

  // Send follow request (for private accounts)
  static void sendFollowRequest(String userId) {
    final userIndex = allUsers.indexWhere((user) => user['id'] == userId);
    if (userIndex != -1 && allUsers[userIndex]['is_private'] == true) {
      // In real app, this would notify the user
      allUsers[userIndex]['follow_request_sent'] = true;
    }
  }
}