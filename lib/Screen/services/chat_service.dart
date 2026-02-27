// lib/services/chat_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // 1. GET ALL CHATS FOR CURRENT USER
  Stream<List<Map<String, dynamic>>> getChats() {
    User? currentUser = _auth.currentUser;
    if (currentUser == null) return Stream.value([]);

    // TEMPORARY FIX: Remove orderBy to avoid index issues
    return _firestore
        .collection('chats')
        .where('participants', arrayContains: currentUser.uid)
        .snapshots()
        .asyncMap((snapshot) async {
      List<Map<String, dynamic>> chats = [];

      for (var doc in snapshot.docs) {
        Map<String, dynamic> chatData = doc.data();

        // Get other participant's info
        String otherUserId = (chatData['participants'] as List)
            .firstWhere((id) => id != currentUser.uid);

        DocumentSnapshot userDoc = await _firestore
            .collection('users')
            .doc(otherUserId)
            .get();

        Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>? ?? {};

        // Get unread count
        int unreadCount = await _getUnreadCount(doc.id, currentUser.uid);

        chats.add({
          'chatId': doc.id,
          'userId': otherUserId,
          'name': userData['name'] ?? 'Unknown',
          'username': userData['username'] ?? '',
          'profilePic': userData['profilePic'] ?? userData['photoURL'] ?? '',
          'avatar': userData['avatar'] ?? '👤',
          'last_message': chatData['lastMessage'] ?? '',
          'last_message_time': chatData['lastMessageTime'],
          'is_online': userData['isOnline'] ?? false,
          'unread_count': unreadCount,
        });
      }

      // Sort manually by lastMessageTime
      chats.sort((a, b) {
        Timestamp? timeA = a['last_message_time'];
        Timestamp? timeB = b['last_message_time'];

        if (timeA == null) return 1;
        if (timeB == null) return -1;

        return timeB.compareTo(timeA); // Newest first
      });

      return chats;
    });
  }

  // 2. GET MESSAGES FOR A CHAT
  Stream<List<Map<String, dynamic>>> getMessages(String chatId) {
    if (chatId.isEmpty) return Stream.value([]);

    // TEMPORARY FIX: Remove orderBy to avoid index issues
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .snapshots()
        .map((snapshot) {
      // Manually sort by timestamp
      var messages = snapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data();
        return {
          'id': doc.id,
          'sender_id': data['senderId'],
          'message': data['message'],
          'time': _formatTimestamp(data['timestamp']),
          'timestamp': data['timestamp'],
          'is_sent': data['senderId'] == _auth.currentUser?.uid,
          'is_read': data['readBy']?.contains(_auth.currentUser?.uid) ?? false,
        };
      }).toList();

      // Sort by timestamp (oldest first)
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

  // 3. SEND MESSAGE
  Future<void> sendMessage(String chatId, String message) async {
    User? currentUser = _auth.currentUser;
    if (currentUser == null) return;

    try {
      // Add message to messages subcollection
      await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .add({
        'senderId': currentUser.uid,
        'message': message,
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'text',
        'readBy': [currentUser.uid],
      });

      // Update chat's last message
      await _firestore.collection('chats').doc(chatId).update({
        'lastMessage': message,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageSender': currentUser.uid,
      });
    } catch (e) {
      print('Error sending message: $e');
      rethrow;
    }
  }

  // 4. CREATE NEW CHAT
  Future<String> createChat(String otherUserId) async {
    User? currentUser = _auth.currentUser;
    if (currentUser == null) throw Exception('No user logged in');

    try {
      // Check if chat already exists
      QuerySnapshot existingChats = await _firestore
          .collection('chats')
          .where('participants', arrayContains: currentUser.uid)
          .get();

      for (var doc in existingChats.docs) {
        List participants = doc['participants'];
        if (participants.contains(otherUserId)) {
          return doc.id; // Return existing chat
        }
      }

      // Create new chat
      DocumentReference chatRef = await _firestore.collection('chats').add({
        'participants': [currentUser.uid, otherUserId],
        'createdAt': FieldValue.serverTimestamp(),
        'lastMessage': '',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageSender': '',
      });

      return chatRef.id;
    } catch (e) {
      print('Error creating chat: $e');
      rethrow;
    }
  }

  // 5. GET UNREAD COUNT
  Future<int> _getUnreadCount(String chatId, String userId) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .where('readBy', isNotEqualTo: userId)
          .get();

      return snapshot.docs.length;
    } catch (e) {
      print('Error getting unread count: $e');
      return 0;
    }
  }

  // 6. MARK MESSAGES AS READ
  Future<void> markMessagesAsRead(String chatId) async {
    User? currentUser = _auth.currentUser;
    if (currentUser == null || chatId.isEmpty) return;

    try {
      QuerySnapshot unreadMessages = await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .where('readBy', isNotEqualTo: currentUser.uid)
          .get();

      for (var doc in unreadMessages.docs) {
        await doc.reference.update({
          'readBy': FieldValue.arrayUnion([currentUser.uid])
        });
      }
    } catch (e) {
      print('Error marking messages as read: $e');
    }
  }

  // 7. UPDATE ONLINE STATUS
  Future<void> updateOnlineStatus(bool isOnline) async {
    User? currentUser = _auth.currentUser;
    if (currentUser == null) return;

    try {
      await _firestore.collection('users').doc(currentUser.uid).update({
        'isOnline': isOnline,
        'lastSeen': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating online status: $e');
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
    } catch (e) {
      print('Error deleting message: $e');
      rethrow;
    }
  }

  // Helper: Format timestamp
  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'Just now';

    DateTime date = timestamp.toDate();
    DateTime now = DateTime.now();

    if (date.day == now.day && date.month == now.month && date.year == now.year) {
      // Today - show time
      return '${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } else if (date.day == now.day - 1 && date.month == now.month && date.year == now.year) {
      // Yesterday
      return 'Yesterday';
    } else {
      // Other days
      return '${date.day}/${date.month}';
    }
  }
}