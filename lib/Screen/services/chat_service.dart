import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ==================== CHAT LIST FEATURES ====================

  // 1. GET ALL CHATS FOR CURRENT USER - FIXED VERSION
  Stream<List<Map<String, dynamic>>> getChats() {
    User? currentUser = _auth.currentUser;
    if (currentUser == null) {
      print('❌ No current user');
      return Stream.value([]);
    }

    print('📱 Fetching chats for user: ${currentUser.uid}');

    return _firestore
        .collection('chats')
        .where('participants', arrayContains: currentUser.uid)
        .orderBy('lastMessageTime', descending: true)  // ✅ CRITICAL FIX - Add this
        .snapshots()
        .asyncMap((snapshot) async {

      print('📨 Raw chats from Firebase: ${snapshot.docs.length}');

      List<Map<String, dynamic>> chats = [];

      for (var doc in snapshot.docs) {
        try {
          Map<String, dynamic> chatData = doc.data() as Map<String, dynamic>;
          print('📄 Chat doc ID: ${doc.id}');

          // Get other participant's info
          List participants = List.from(chatData['participants'] ?? []);
          print('👥 Participants: $participants');

          String otherUserId = participants.firstWhere(
                (id) => id != currentUser.uid,
            orElse: () => '',
          );

          if (otherUserId.isEmpty) {
            print('❌ No other participant found');
            continue;
          }

          print('👤 Other user ID: $otherUserId');

          // Check if user is blocked
          bool isBlocked = await _isUserBlocked(otherUserId);
          if (isBlocked) {
            print('🚫 User is blocked, skipping');
            continue;
          }

          // Get user data from Firestore
          DocumentSnapshot userDoc = await _firestore
              .collection('users')
              .doc(otherUserId)
              .get();

          print('📄 User doc exists: ${userDoc.exists}');

          Map<String, dynamic> userData = {};
          if (userDoc.exists) {
            var data = userDoc.data();
            if (data != null) {
              userData = data as Map<String, dynamic>;
              print('✅ User data fetched: ${userData['name']}');
            }
          } else {
            print('❌ User document does not exist!');
          }

          // Handle empty profile pics
          String profilePic = userData['profilePic']?.toString() ??
              userData['photoURL']?.toString() ?? '';

          int unreadCount = await _getUnreadCount(doc.id, currentUser.uid);
          bool isMuted = await _isChatMuted(doc.id);

          Map<String, dynamic> chatItem = {
            'chatId': doc.id,
            'userId': otherUserId,
            'name': userData['name']?.toString() ?? 'Unknown User',
            'username': userData['username']?.toString() ?? '',
            'profilePic': profilePic.isNotEmpty ? profilePic : null,
            'avatar': userData['avatar']?.toString() ?? '👤',
            'last_message': chatData['lastMessage']?.toString() ?? 'No messages yet',
            'last_message_time': chatData['lastMessageTime'] as Timestamp?,
            'is_online': userData['isOnline'] as bool? ?? false,
            'unread_count': unreadCount,
            'is_muted': isMuted,
          };

          print('✅ Chat item created with name: ${chatItem['name']}');
          chats.add(chatItem);

        } catch (e) {
          print('❌ Error processing chat doc: $e');
        }
      }

      print('🎉 Total chats processed: ${chats.length}');
      return chats;
    });
  }

  // 2. CHECK IF USER IS BLOCKED
  Future<bool> _isUserBlocked(String otherUserId) async {
    User? currentUser = _auth.currentUser;
    if (currentUser == null) return false;

    try {
      DocumentSnapshot userDoc = await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .get();

      Map<String, dynamic> userData = {};
      if (userDoc.exists) {
        var data = userDoc.data();
        if (data != null) {
          userData = data as Map<String, dynamic>;
        }
      }

      List blockedUsers = List.from(userData['blocked_users'] ?? []);
      return blockedUsers.contains(otherUserId);
    } catch (e) {
      print('Error checking blocked user: $e');
      return false;
    }
  }

  // 3. CHECK IF CHAT IS MUTED
  Future<bool> _isChatMuted(String chatId) async {
    User? currentUser = _auth.currentUser;
    if (currentUser == null) return false;

    try {
      DocumentSnapshot prefDoc = await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('chat_preferences')
          .doc(chatId)
          .get();

      if (!prefDoc.exists) return false;

      Map<String, dynamic> data = {};
      if (prefDoc.exists) {
        var prefData = prefDoc.data();
        if (prefData != null) {
          data = prefData as Map<String, dynamic>;
        }
      }

      bool muted = data['muted'] as bool? ?? false;
      Timestamp? mutedUntil = data['muted_until'] as Timestamp?;

      if (muted && mutedUntil != null) {
        if (mutedUntil.toDate().isBefore(DateTime.now())) {
          await muteChat(chatId, mute: false);
          return false;
        }
      }

      return muted;
    } catch (e) {
      return false;
    }
  }

  // ==================== MESSAGE FEATURES ====================

  // 4. GET MESSAGES FOR A CHAT
  Stream<List<Map<String, dynamic>>> getMessages(String chatId) {
    if (chatId.isEmpty) return Stream.value([]);

    User? currentUser = _auth.currentUser;
    if (currentUser == null) return Stream.value([]);

    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .asyncMap((snapshot) async {

      String? otherUserId = await getOtherParticipantId(chatId);

      var messages = snapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

        List readBy = List.from(data['readBy'] ?? []);
        List deliveredTo = List.from(data['deliveredTo'] ?? []);
        bool isDeleted = data['is_deleted'] as bool? ?? false;
        bool isForwarded = data['is_forwarded'] as bool? ?? false;

        bool isSentByMe = data['senderId'] == currentUser?.uid;

        return {
          'id': doc.id,
          'sender_id': data['senderId'],
          'message': isDeleted ? 'This message was deleted' : (data['message']?.toString() ?? ''),
          'time': _formatTimestamp(data['timestamp'] as Timestamp?),
          'timestamp': data['timestamp'] as Timestamp?,
          'is_sent': isSentByMe,
          'is_read': readBy.contains(otherUserId),
          'is_delivered': deliveredTo.contains(otherUserId),
          'read_by': readBy,
          'delivered_to': deliveredTo,
          'is_deleted': isDeleted,
          'is_forwarded': isForwarded,
          'original_sender': data['original_sender'],
          'type': data['type']?.toString() ?? 'text',
        };
      }).toList();

      return messages;
    });
  }

  // 5. SEND MESSAGE
  Future<void> sendMessage(String chatId, String message) async {
    User? currentUser = _auth.currentUser;
    if (currentUser == null) throw Exception('No user logged in');
    if (message.trim().isEmpty) return;

    try {
      String? otherUserId = await getOtherParticipantId(chatId);
      if (otherUserId == null) throw Exception('Other user not found');

      DocumentSnapshot userDoc = await _firestore
          .collection('users')
          .doc(otherUserId)
          .get();

      Map<String, dynamic> userData = {};
      if (userDoc.exists) {
        var data = userDoc.data();
        if (data != null) {
          userData = data as Map<String, dynamic>;
        }
      }

      bool isOtherOnline = userData['isOnline'] as bool? ?? false;

      Map<String, dynamic> messageData = {
        'senderId': currentUser.uid,
        'message': message,
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'text',
        'readBy': [currentUser.uid],
        'deliveredTo': isOtherOnline ? [otherUserId] : [],
        'is_deleted': false,
        'is_forwarded': false,
      };

      DocumentReference msgRef = await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .add(messageData);

      await _firestore.collection('chats').doc(chatId).update({
        'lastMessage': message,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageSender': currentUser.uid,
      });

      if (!isOtherOnline) {
        _setupDeliveryListener(chatId, msgRef.id, otherUserId);
      }
    } catch (e) {
      print('Error sending message: $e');
      rethrow;
    }
  }

  // 6. SETUP DELIVERY LISTENER
  void _setupDeliveryListener(String chatId, String messageId, String otherUserId) {
    _firestore.collection('users').doc(otherUserId).snapshots().listen((snapshot) {
      if (snapshot.exists) {
        var data = snapshot.data();
        if (data != null) {
          Map<String, dynamic> userData = data as Map<String, dynamic>;
          bool isOnline = userData['isOnline'] as bool? ?? false;

          if (isOnline) {
            _firestore
                .collection('chats')
                .doc(chatId)
                .collection('messages')
                .doc(messageId)
                .update({
              'deliveredTo': FieldValue.arrayUnion([otherUserId]),
            }).catchError((e) {
              print('Error updating delivery status: $e');
            });
          }
        }
      }
    });
  }

  // 7. MARK MESSAGES AS READ - FIXED VERSION
  Future<void> markMessagesAsRead(String chatId) async {
    User? currentUser = _auth.currentUser;
    if (currentUser == null || chatId.isEmpty) return;

    try {
      print('📨 Marking messages as read in chat: $chatId');

      // Get all messages from other users
      QuerySnapshot messages = await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .where('senderId', isNotEqualTo: currentUser.uid)
          .get();

      if (messages.docs.isEmpty) {
        print('✅ No unread messages from others');
        return;
      }

      WriteBatch batch = _firestore.batch();
      int updatedCount = 0;

      for (var doc in messages.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        List readBy = List.from(data['readBy'] ?? []);

        if (!readBy.contains(currentUser.uid)) {
          batch.update(doc.reference, {
            'readBy': FieldValue.arrayUnion([currentUser.uid]),
          });
          updatedCount++;
        }
      }

      if (updatedCount > 0) {
        await batch.commit();
        print('✅ Marked $updatedCount messages as read');
      }

    } catch (e) {
      print('❌ Error marking messages as read: $e');
    }
  }

  // 8. DELETE MESSAGE
  Future<void> deleteMessage(String chatId, String messageId) async {
    try {
      await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc(messageId)
          .delete();
      print('✅ Message deleted: $messageId');
    } catch (e) {
      print('Error deleting message: $e');
      rethrow;
    }
  }

  // 9. FORWARD MESSAGE
  Future<void> forwardMessage(String fromChatId, String messageId, String toUserId) async {
    User? currentUser = _auth.currentUser;
    if (currentUser == null) throw Exception('No user logged in');

    try {
      DocumentSnapshot messageDoc = await _firestore
          .collection('chats')
          .doc(fromChatId)
          .collection('messages')
          .doc(messageId)
          .get();

      if (!messageDoc.exists) throw Exception('Message not found');

      Map<String, dynamic> originalMessage = messageDoc.data() as Map<String, dynamic>;

      String targetChatId = await getOrCreateChat(toUserId);

      await _firestore
          .collection('chats')
          .doc(targetChatId)
          .collection('messages')
          .add({
        'senderId': currentUser.uid,
        'message': originalMessage['message']?.toString() ?? '',
        'timestamp': FieldValue.serverTimestamp(),
        'type': originalMessage['type']?.toString() ?? 'text',
        'is_forwarded': true,
        'original_sender': originalMessage['senderId'],
        'readBy': [currentUser.uid],
        'deliveredTo': [],
        'is_deleted': false,
      });

      await _firestore.collection('chats').doc(targetChatId).update({
        'lastMessage': originalMessage['message']?.toString() ?? '',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageSender': currentUser.uid,
      });

      print('✅ Message forwarded to chat: $targetChatId');
    } catch (e) {
      print('Error forwarding message: $e');
      rethrow;
    }
  }

  // 10. GET OR CREATE CHAT
  Future<String> getOrCreateChat(String otherUserId) async {
    User? currentUser = _auth.currentUser;
    if (currentUser == null) throw Exception('No user logged in');

    try {
      QuerySnapshot existingChats = await _firestore
          .collection('chats')
          .where('participants', arrayContains: currentUser.uid)
          .get();

      for (var doc in existingChats.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        List participants = List.from(data['participants'] ?? []);
        if (participants.contains(otherUserId)) {
          return doc.id;
        }
      }

      DocumentReference chatRef = await _firestore.collection('chats').add({
        'participants': [currentUser.uid, otherUserId],
        'createdAt': FieldValue.serverTimestamp(),
        'lastMessage': '',
        'lastMessageTime': null,
        'lastMessageSender': '',
      });

      print('✅ New chat created: ${chatRef.id}');
      return chatRef.id;
    } catch (e) {
      print('Error creating chat: $e');
      rethrow;
    }
  }

  // 11. CREATE NEW CHAT
  Future<String> createChat(String otherUserId) async {
    return getOrCreateChat(otherUserId);
  }

  // 12. CLEAR CONVERSATION
  Future<void> clearConversation(String chatId) async {
    try {
      QuerySnapshot messages = await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .get();

      WriteBatch batch = _firestore.batch();

      for (var doc in messages.docs) {
        batch.delete(doc.reference);
      }

      batch.update(
        _firestore.collection('chats').doc(chatId),
        {
          'lastMessage': '',
          'lastMessageTime': null,
          'cleared_at': FieldValue.serverTimestamp(),
          'cleared_by': FieldValue.arrayUnion([_auth.currentUser!.uid]),
        },
      );

      await batch.commit();
      print('✅ Conversation cleared: $chatId');
    } catch (e) {
      print('Error clearing conversation: $e');
      rethrow;
    }
  }

  // 13. BLOCK USER
  Future<void> blockUser(String userId) async {
    User? currentUser = _auth.currentUser;
    if (currentUser == null) return;

    try {
      await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .update({
        'blocked_users': FieldValue.arrayUnion([userId])
      });

      await _firestore.collection('blocks').add({
        'blocked_by': currentUser.uid,
        'blocked_user': userId,
        'timestamp': FieldValue.serverTimestamp(),
      });

      print('✅ User blocked: $userId');
    } catch (e) {
      print('Error blocking user: $e');
      rethrow;
    }
  }

  // 14. UNBLOCK USER
  Future<void> unblockUser(String userId) async {
    User? currentUser = _auth.currentUser;
    if (currentUser == null) return;

    try {
      await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .update({
        'blocked_users': FieldValue.arrayRemove([userId])
      });
      print('✅ User unblocked: $userId');
    } catch (e) {
      print('Error unblocking user: $e');
      rethrow;
    }
  }

  // 15. REPORT USER
  Future<void> reportUser(String userId, {String? reason, String? messageId}) async {
    User? currentUser = _auth.currentUser;
    if (currentUser == null) return;

    try {
      await _firestore.collection('reports').add({
        'reported_by': currentUser.uid,
        'reported_user': userId,
        'reason': reason ?? 'No reason provided',
        'message_id': messageId,
        'status': 'pending',
        'timestamp': FieldValue.serverTimestamp(),
      });
      print('✅ User reported: $userId');
    } catch (e) {
      print('Error reporting user: $e');
      rethrow;
    }
  }

  // 16. MUTE/UNMUTE CHAT
  Future<void> muteChat(String chatId, {bool mute = true}) async {
    User? currentUser = _auth.currentUser;
    if (currentUser == null) return;

    try {
      await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('chat_preferences')
          .doc(chatId)
          .set({
        'muted': mute,
        'muted_until': mute ? Timestamp.fromDate(DateTime.now().add(const Duration(days: 7))) : null,
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      print('✅ Chat mute status updated: $mute');
    } catch (e) {
      print('Error muting chat: $e');
      rethrow;
    }
  }

  // 17. UPDATE ONLINE STATUS
  Future<void> updateOnlineStatus(bool isOnline) async {
    User? currentUser = _auth.currentUser;
    if (currentUser == null) return;

    try {
      await _firestore.collection('users').doc(currentUser.uid).update({
        'isOnline': isOnline,
        'lastSeen': FieldValue.serverTimestamp(),
      });
      print('✅ Online status updated: $isOnline');
    } catch (e) {
      print('Error updating online status: $e');
    }
  }

  // 18. SEND FRIEND REQUEST
  Future<void> sendFriendRequest(String receiverId) async {
    User? currentUser = _auth.currentUser;
    if (currentUser == null) return;

    try {
      QuerySnapshot existingRequest = await _firestore
          .collection('friend_requests')
          .where('sender_id', isEqualTo: currentUser.uid)
          .where('receiver_id', isEqualTo: receiverId)
          .where('status', isEqualTo: 'pending')
          .get();

      if (existingRequest.docs.isNotEmpty) return;

      await _firestore.collection('friend_requests').add({
        'sender_id': currentUser.uid,
        'receiver_id': receiverId,
        'status': 'pending',
        'timestamp': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      });

      await _firestore.collection('notifications').add({
        'user_id': receiverId,
        'type': 'friend_request',
        'from_user': currentUser.uid,
        'message': 'sent you a friend request',
        'is_read': false,
        'timestamp': FieldValue.serverTimestamp(),
      });

      print('✅ Friend request sent to: $receiverId');
    } catch (e) {
      print('Error sending friend request: $e');
      rethrow;
    }
  }

  // 19. GET PENDING FRIEND REQUESTS
  Stream<List<Map<String, dynamic>>> getPendingRequests() {
    User? currentUser = _auth.currentUser;
    if (currentUser == null) return Stream.value([]);

    return _firestore
        .collection('friend_requests')
        .where('receiver_id', isEqualTo: currentUser.uid)
        .where('status', isEqualTo: 'pending')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
      List<Map<String, dynamic>> requests = [];

      for (var doc in snapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

        DocumentSnapshot userDoc = await _firestore
            .collection('users')
            .doc(data['sender_id'])
            .get();

        Map<String, dynamic> userData = {};
        if (userDoc.exists) {
          var userDocData = userDoc.data();
          if (userDocData != null) {
            userData = userDocData as Map<String, dynamic>;
          }
        }

        String profilePic = userData['profilePic']?.toString() ??
            userData['photoURL']?.toString() ?? '';

        requests.add({
          'request_id': doc.id,
          'sender_id': data['sender_id'],
          'receiver_id': data['receiver_id'],
          'timestamp': data['timestamp'] as Timestamp?,
          'name': userData['name']?.toString() ?? 'Unknown',
          'username': userData['username']?.toString() ?? '',
          'profilePic': profilePic.isNotEmpty ? profilePic : null,
          'avatar': userData['avatar']?.toString() ?? '👤',
          'bio': userData['bio']?.toString() ?? '',
        });
      }

      return requests;
    });
  }

  // 20. GET SENT REQUESTS
  Stream<List<Map<String, dynamic>>> getSentRequests() {
    User? currentUser = _auth.currentUser;
    if (currentUser == null) return Stream.value([]);

    return _firestore
        .collection('friend_requests')
        .where('sender_id', isEqualTo: currentUser.uid)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
      List<Map<String, dynamic>> requests = [];

      for (var doc in snapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

        DocumentSnapshot userDoc = await _firestore
            .collection('users')
            .doc(data['receiver_id'])
            .get();

        Map<String, dynamic> userData = {};
        if (userDoc.exists) {
          var userDocData = userDoc.data();
          if (userDocData != null) {
            userData = userDocData as Map<String, dynamic>;
          }
        }

        String profilePic = userData['profilePic']?.toString() ??
            userData['photoURL']?.toString() ?? '';

        requests.add({
          'request_id': doc.id,
          'receiver_id': data['receiver_id'],
          'status': data['status']?.toString() ?? 'pending',
          'timestamp': data['timestamp'] as Timestamp?,
          'name': userData['name']?.toString() ?? 'Unknown',
          'username': userData['username']?.toString() ?? '',
          'profilePic': profilePic.isNotEmpty ? profilePic : null,
          'avatar': userData['avatar']?.toString() ?? '👤',
        });
      }

      return requests;
    });
  }

  // 21. ACCEPT FRIEND REQUEST
  Future<void> acceptFriendRequest(String requestId, String senderId) async {
    User? currentUser = _auth.currentUser;
    if (currentUser == null) return;

    try {
      await _firestore.collection('friend_requests').doc(requestId).update({
        'status': 'accepted',
        'updated_at': FieldValue.serverTimestamp(),
      });

      String chatId = await createChat(senderId);

      await _firestore.collection('notifications').add({
        'user_id': senderId,
        'type': 'request_accepted',
        'from_user': currentUser.uid,
        'message': 'accepted your friend request',
        'is_read': false,
        'timestamp': FieldValue.serverTimestamp(),
      });

      await sendMessage(chatId, 'Hey! We are now connected! 👋');

      print('✅ Friend request accepted: $requestId');
    } catch (e) {
      print('Error accepting friend request: $e');
      rethrow;
    }
  }

  // 22. REJECT FRIEND REQUEST
  Future<void> rejectFriendRequest(String requestId) async {
    try {
      await _firestore.collection('friend_requests').doc(requestId).update({
        'status': 'rejected',
        'updated_at': FieldValue.serverTimestamp(),
      });
      print('✅ Friend request rejected: $requestId');
    } catch (e) {
      print('Error rejecting friend request: $e');
      rethrow;
    }
  }

  // 23. CANCEL SENT REQUEST
  Future<void> cancelFriendRequest(String requestId) async {
    try {
      await _firestore.collection('friend_requests').doc(requestId).delete();
      print('✅ Friend request canceled: $requestId');
    } catch (e) {
      print('Error canceling friend request: $e');
      rethrow;
    }
  }

  // 24. CHECK REQUEST STATUS
  Future<String?> checkRequestStatus(String otherUserId) async {
    User? currentUser = _auth.currentUser;
    if (currentUser == null) return null;

    try {
      QuerySnapshot sentRequest = await _firestore
          .collection('friend_requests')
          .where('sender_id', isEqualTo: currentUser.uid)
          .where('receiver_id', isEqualTo: otherUserId)
          .where('status', isEqualTo: 'pending')
          .get();

      if (sentRequest.docs.isNotEmpty) return 'sent';

      QuerySnapshot receivedRequest = await _firestore
          .collection('friend_requests')
          .where('sender_id', isEqualTo: otherUserId)
          .where('receiver_id', isEqualTo: currentUser.uid)
          .where('status', isEqualTo: 'pending')
          .get();

      if (receivedRequest.docs.isNotEmpty) return 'received';

      QuerySnapshot existingChats = await _firestore
          .collection('chats')
          .where('participants', arrayContains: currentUser.uid)
          .get();

      for (var doc in existingChats.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        List participants = List.from(data['participants'] ?? []);
        if (participants.contains(otherUserId)) {
          return 'friends';
        }
      }

      return null;
    } catch (e) {
      print('Error checking request status: $e');
      return null;
    }
  }

  // 25. LOG CALL
  Future<void> logCall({
    required String otherUserId,
    required String callType,
    required String callStatus,
    int? duration,
  }) async {
    User? currentUser = _auth.currentUser;
    if (currentUser == null) return;

    try {
      await _firestore.collection('calls').add({
        'caller_id': currentUser.uid,
        'receiver_id': otherUserId,
        'call_type': callType,
        'call_status': callStatus,
        'duration': duration ?? 0,
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (callStatus == 'missed') {
        await _firestore.collection('notifications').add({
          'user_id': otherUserId,
          'type': 'missed_call',
          'from_user': currentUser.uid,
          'call_type': callType,
          'message': 'Missed $callType call',
          'is_read': false,
          'timestamp': FieldValue.serverTimestamp(),
        });
      }

      print('✅ Call logged: $callType - $callStatus');
    } catch (e) {
      print('Error logging call: $e');
    }
  }

  // 26. GET CALL HISTORY
  Stream<List<Map<String, dynamic>>> getCallHistory() {
    User? currentUser = _auth.currentUser;
    if (currentUser == null) return Stream.value([]);

    return _firestore
        .collection('calls')
        .where('caller_id', isEqualTo: currentUser.uid)
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .asyncMap((snapshot) async {
      List<Map<String, dynamic>> calls = [];

      for (var doc in snapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

        DocumentSnapshot userDoc = await _firestore
            .collection('users')
            .doc(data['receiver_id'])
            .get();

        Map<String, dynamic> userData = {};
        if (userDoc.exists) {
          var userDocData = userDoc.data();
          if (userDocData != null) {
            userData = userDocData as Map<String, dynamic>;
          }
        }

        String profilePic = userData['profilePic']?.toString() ??
            userData['photoURL']?.toString() ?? '';

        calls.add({
          'call_id': doc.id,
          'other_user_id': data['receiver_id'],
          'name': userData['name']?.toString() ?? 'Unknown',
          'profilePic': profilePic.isNotEmpty ? profilePic : null,
          'avatar': userData['avatar']?.toString() ?? '👤',
          'call_type': data['call_type']?.toString() ?? 'voice',
          'call_status': data['call_status']?.toString() ?? 'completed',
          'duration': data['duration'] as int? ?? 0,
          'timestamp': data['timestamp'] as Timestamp?,
          'is_outgoing': true,
        });
      }

      QuerySnapshot receivedCalls = await _firestore
          .collection('calls')
          .where('receiver_id', isEqualTo: currentUser.uid)
          .orderBy('timestamp', descending: true)
          .limit(50)
          .get();

      for (var doc in receivedCalls.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

        DocumentSnapshot userDoc = await _firestore
            .collection('users')
            .doc(data['caller_id'])
            .get();

        Map<String, dynamic> userData = {};
        if (userDoc.exists) {
          var userDocData = userDoc.data();
          if (userDocData != null) {
            userData = userDocData as Map<String, dynamic>;
          }
        }

        String profilePic = userData['profilePic']?.toString() ??
            userData['photoURL']?.toString() ?? '';

        calls.add({
          'call_id': doc.id,
          'other_user_id': data['caller_id'],
          'name': userData['name']?.toString() ?? 'Unknown',
          'profilePic': profilePic.isNotEmpty ? profilePic : null,
          'avatar': userData['avatar']?.toString() ?? '👤',
          'call_type': data['call_type']?.toString() ?? 'voice',
          'call_status': data['call_status']?.toString() ?? 'completed',
          'duration': data['duration'] as int? ?? 0,
          'timestamp': data['timestamp'] as Timestamp?,
          'is_outgoing': false,
        });
      }

      calls.sort((a, b) {
        Timestamp? timeA = a['timestamp'] as Timestamp?;
        Timestamp? timeB = b['timestamp'] as Timestamp?;
        if (timeA == null) return 1;
        if (timeB == null) return -1;
        return timeB.compareTo(timeA);
      });

      return calls;
    });
  }

  // 27. GET UNREAD MISSED CALLS COUNT
  Stream<int> getUnreadMissedCallsCount() {
    User? currentUser = _auth.currentUser;
    if (currentUser == null) return Stream.value(0);

    return _firestore
        .collection('calls')
        .where('receiver_id', isEqualTo: currentUser.uid)
        .where('call_status', isEqualTo: 'missed')
        .where('is_read', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  // 28. MARK MISSED CALLS AS READ
  Future<void> markMissedCallsAsRead() async {
    User? currentUser = _auth.currentUser;
    if (currentUser == null) return;

    try {
      QuerySnapshot missedCalls = await _firestore
          .collection('calls')
          .where('receiver_id', isEqualTo: currentUser.uid)
          .where('call_status', isEqualTo: 'missed')
          .where('is_read', isEqualTo: false)
          .get();

      WriteBatch batch = _firestore.batch();
      for (var doc in missedCalls.docs) {
        batch.update(doc.reference, {'is_read': true});
      }
      await batch.commit();
      print('✅ Missed calls marked as read');
    } catch (e) {
      print('Error marking missed calls: $e');
    }
  }

  // 29. FORMAT CALL DURATION
  String formatDuration(int seconds) {
    if (seconds < 60) {
      return '$seconds sec';
    } else if (seconds < 3600) {
      int minutes = seconds ~/ 60;
      int remainingSeconds = seconds % 60;
      return '$minutes:${remainingSeconds.toString().padLeft(2, '0')} min';
    } else {
      int hours = seconds ~/ 3600;
      int minutes = (seconds % 3600) ~/ 60;
      return '$hours hr $minutes min';
    }
  }

  // 30. GET UNREAD COUNT
  Future<int> _getUnreadCount(String chatId, String userId) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .where('senderId', isNotEqualTo: userId)
          .get();

      int count = 0;
      for (var doc in snapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        List readBy = List.from(data['readBy'] ?? []);
        if (!readBy.contains(userId)) {
          count++;
        }
      }

      return count;
    } catch (e) {
      print('Error getting unread count: $e');
      return 0;
    }
  }

  // 31. GET OTHER PARTICIPANT ID
  Future<String?> getOtherParticipantId(String chatId) async {
    User? currentUser = _auth.currentUser;
    if (currentUser == null) return null;

    try {
      DocumentSnapshot chatDoc = await _firestore.collection('chats').doc(chatId).get();
      if (!chatDoc.exists) return null;

      Map<String, dynamic> chatData = chatDoc.data() as Map<String, dynamic>;
      List participants = List.from(chatData['participants'] ?? []);
      return participants.firstWhere((id) => id != currentUser.uid);
    } catch (e) {
      print('Error getting other participant: $e');
      return null;
    }
  }

  // 32. FORMAT TIMESTAMP
  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'Just now';

    DateTime date = timestamp.toDate();
    DateTime now = DateTime.now();

    if (date.day == now.day && date.month == now.month && date.year == now.year) {
      return '${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } else if (date.day == now.day - 1 && date.month == now.month && date.year == now.year) {
      return 'Yesterday';
    } else {
      return '${date.day}/${date.month}';
    }
  }
}