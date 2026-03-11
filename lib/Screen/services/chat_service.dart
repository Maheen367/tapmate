import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:tapmate/Screen/services/cloudinary_service.dart'; // NEW IMPORT

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ==================== CHAT LIST FEATURES ====================

  // GET ALL CHATS FOR CURRENT USER
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
        .snapshots()
        .asyncMap((snapshot) async {
      print('📨 Raw chats from Firebase: ${snapshot.docs.length}');

      List<Map<String, dynamic>> chats = [];

      for (var doc in snapshot.docs) {
        try {
          Map<String, dynamic> chatData = doc.data() as Map<String, dynamic>;

          List participants = List.from(chatData['participants'] ?? []);

          String otherUserId = participants.firstWhere(
                (id) => id != currentUser.uid,
            orElse: () => '',
          );

          if (otherUserId.isEmpty) continue;

          DocumentSnapshot userDoc = await _firestore
              .collection('users')
              .doc(otherUserId)
              .get();

          Map<String, dynamic> userData = {};
          if (userDoc.exists) {
            var data = userDoc.data();
            if (data != null) userData = data as Map<String, dynamic>;
          }

          String profilePic = userData['profilePic']?.toString() ??
              userData['photoURL']?.toString() ?? '';

          int unreadCount = await _getUnreadCount(doc.id, currentUser.uid);
          bool isMuted = await _isChatMuted(doc.id);

          chats.add({
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
          });
        } catch (e) {
          print('❌ Error processing chat doc: $e');
        }
      }

      chats.sort((a, b) {
        Timestamp? timeA = a['last_message_time'] as Timestamp?;
        Timestamp? timeB = b['last_message_time'] as Timestamp?;
        if (timeA == null) return 1;
        if (timeB == null) return -1;
        return timeB.compareTo(timeA);
      });

      return chats;
    });
  }

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

      Map<String, dynamic> data = prefDoc.data() as Map<String, dynamic>? ?? {};

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

  // GET MESSAGES FOR A CHAT
  Stream<List<Map<String, dynamic>>> getMessages(String chatId) {
    if (chatId.isEmpty) return Stream.value([]);

    User? currentUser = _auth.currentUser;
    if (currentUser == null) return Stream.value([]);

    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
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

        Map<String, dynamic> messageMap = {
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

        // Add voice-specific fields
        if (data['type'] == 'voice') {
          messageMap.addAll({
            'audioUrl': data['audioUrl']?.toString() ?? '',
            'duration': data['duration'] as int? ?? 0,
            'fileSize': data['fileSize'] as int? ?? 0,
          });
        }

        return messageMap;
      }).toList();

      messages.sort((a, b) {
        Timestamp? timeA = a['timestamp'] as Timestamp?;
        Timestamp? timeB = b['timestamp'] as Timestamp?;
        if (timeA == null) return 1;
        if (timeB == null) return -1;
        return timeA.compareTo(timeB);
      });

      return messages;
    });
  }

  // SEND TEXT MESSAGE
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

      Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>? ?? {};
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

  // SEND VOICE MESSAGE - UPDATED WITH CLOUDINARY
  Future<void> sendVoiceMessage(
      String chatId,
      File audioFile, {
        int duration = 0,
      }) async {
    User? currentUser = _auth.currentUser;
    if (currentUser == null) throw Exception('No user logged in');

    try {
      String? otherUserId = await getOtherParticipantId(chatId);
      if (otherUserId == null) throw Exception('Other user not found');

      print('📤 Uploading voice message to Cloudinary: ${audioFile.path}');
      print('📏 File size: ${await audioFile.length()} bytes');
      print('⏱️ Duration: $duration seconds');

      // Upload to Cloudinary
      String? audioUrl = await CloudinaryService().uploadVoiceMessage(
        audioFile,
        userId: currentUser.uid,
        chatId: chatId,
      );

      if (audioUrl == null) {
        throw Exception('Failed to upload to Cloudinary');
      }

      print('✅ Cloudinary URL: $audioUrl');

      // Check if other user is online
      DocumentSnapshot userDoc = await _firestore
          .collection('users')
          .doc(otherUserId)
          .get();

      Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>? ?? {};
      bool isOtherOnline = userData['isOnline'] as bool? ?? false;

      // Create message in Firestore with Cloudinary URL
      Map<String, dynamic> messageData = {
        'senderId': currentUser.uid,
        'message': '🎤 Voice message',
        'audioUrl': audioUrl,
        'duration': duration,
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'voice',
        'readBy': [currentUser.uid],
        'deliveredTo': isOtherOnline ? [otherUserId] : [],
        'is_deleted': false,
        'is_forwarded': false,
        'fileSize': await audioFile.length(),
        'cloudName': 'dvxejhpau',
      };

      // Add message to chat
      DocumentReference msgRef = await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .add(messageData);

      print('✅ Voice message added to chat: ${msgRef.id}');

      // Update chat last message
      await _firestore.collection('chats').doc(chatId).update({
        'lastMessage': '🎤 Voice message',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageSender': currentUser.uid,
        'lastMessageType': 'voice',
      });

      // Delete temp file after successful upload
      try {
        if (await audioFile.exists()) {
          await audioFile.delete();
          print('✅ Temp file deleted');
        }
      } catch (e) {
        print('⚠️ Error deleting temp file: $e');
      }
    } catch (e) {
      print('❌ Error sending voice message: $e');
      rethrow;
    }
  }

  // NEW: Download voice message from Cloudinary
  Future<File?> downloadVoiceMessage(String audioUrl) async {
    try {
      print('📥 Downloading voice from: $audioUrl');

      // Create a unique filename
      final tempDir = await getTemporaryDirectory();
      final fileName = 'voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      final filePath = '${tempDir.path}/$fileName';
      final file = File(filePath);

      // Download the file
      final response = await http.get(Uri.parse(audioUrl));

      if (response.statusCode == 200) {
        await file.writeAsBytes(response.bodyBytes);
        print('✅ Voice downloaded to: $filePath');
        return file;
      } else {
        print('❌ Download failed: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('❌ Error downloading voice: $e');
      return null;
    }
  }

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

  // MARK MESSAGES AS READ
  Future<void> markMessagesAsRead(String chatId) async {
    User? currentUser = _auth.currentUser;
    if (currentUser == null || chatId.isEmpty) return;

    try {
      print('📨 Marking messages as read in chat: $chatId');

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

  // DELETE MESSAGE
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

  // FORWARD MESSAGE
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

  // GET OR CREATE CHAT
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

  // CREATE NEW CHAT
  Future<String> createChat(String otherUserId) async {
    return getOrCreateChat(otherUserId);
  }

  // CLEAR CONVERSATION
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

  // BLOCK USER
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

  // UNBLOCK USER
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

  // REPORT USER
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

  // MUTE/UNMUTE CHAT
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

  // UPDATE ONLINE STATUS
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

  // SEND FRIEND REQUEST
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

  // GET PENDING FRIEND REQUESTS
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

        Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>? ?? {};

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

  // GET SENT REQUESTS
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

        Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>? ?? {};

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

  // ACCEPT FRIEND REQUEST
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

  // REJECT FRIEND REQUEST
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

  // CANCEL SENT REQUEST
  Future<void> cancelFriendRequest(String requestId) async {
    try {
      await _firestore.collection('friend_requests').doc(requestId).delete();
      print('✅ Friend request canceled: $requestId');
    } catch (e) {
      print('Error canceling friend request: $e');
      rethrow;
    }
  }

  // CHECK REQUEST STATUS
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

  // LOG CALL
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

  // GET CALL HISTORY
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

        Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>? ?? {};

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

        Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>? ?? {};

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

  // GET UNREAD MISSED CALLS COUNT
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

  // MARK MISSED CALLS AS READ
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

  // FORMAT CALL DURATION
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

  // GET UNREAD COUNT
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

  // GET OTHER PARTICIPANT ID
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

  // FORMAT TIMESTAMP
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