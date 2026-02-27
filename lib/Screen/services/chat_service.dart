// lib/services/chat_service.dart (FIXED VERSION)

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

  // 2. GET MESSAGES FOR A CHAT (UPDATED WITH TICK SYSTEM) - FIXED
  Stream<List<Map<String, dynamic>>> getMessages(String chatId) {
    if (chatId.isEmpty) return Stream.value([]);

    User? currentUser = _auth.currentUser;
    if (currentUser == null) return Stream.value([]);

    // TEMPORARY FIX: Remove orderBy to avoid index issues
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .snapshots()
        .map((snapshot) {

      // Find other user ID (the one who is not current user)
      String? otherUserId;
      for (var doc in snapshot.docs) {
        Map<String, dynamic> data = doc.data();
        if (data['senderId'] != currentUser.uid) {
          otherUserId = data['senderId'];
          break;
        }
      }

      // Manually sort by timestamp
      var messages = snapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data();

        // Get readBy and deliveredTo arrays
        List<String> readBy = List<String>.from(data['readBy'] ?? []);
        List<String> deliveredTo = List<String>.from(data['deliveredTo'] ?? []);

        bool isSentByMe = data['senderId'] == currentUser?.uid;

        return {
          'id': doc.id,
          'sender_id': data['senderId'],
          'message': data['message'],
          'time': _formatTimestamp(data['timestamp']),
          'timestamp': data['timestamp'],
          'is_sent': isSentByMe,
          // ✅ UPDATED: Proper tick status
          'is_read': readBy.contains(otherUserId), // Message read by other user
          'is_delivered': deliveredTo.contains(otherUserId), // Message delivered to other user
          'read_by': readBy,
          'delivered_to': deliveredTo,
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

  // 3. SEND MESSAGE (UPDATED WITH DELIVERY STATUS) - FIXED
  Future<void> sendMessage(String chatId, String message) async {
    User? currentUser = _auth.currentUser;
    if (currentUser == null) return;

    try {
      // Get chat document to find other participant
      DocumentSnapshot chatDoc = await _firestore.collection('chats').doc(chatId).get();

      // FIX: Properly cast chatDoc data
      Map<String, dynamic> chatData = chatDoc.data() as Map<String, dynamic>;
      List participants = List.from(chatData['participants'] ?? []);
      String otherUserId = participants.firstWhere((id) => id != currentUser.uid);

      // Check if other user is online
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(otherUserId).get();

      // FIX: Properly cast userDoc data
      Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>? ?? {};
      bool isOtherOnline = userData['isOnline'] ?? false;

      // ✅ UPDATED: Add deliveredTo field
      Map<String, dynamic> messageData = {
        'senderId': currentUser.uid,
        'message': message,
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'text',
        'readBy': [currentUser.uid], // Sender has read it
        'deliveredTo': isOtherOnline ? [otherUserId] : [], // Delivered if online
      };

      // Add message to messages subcollection
      DocumentReference msgRef = await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .add(messageData);

      // Update chat's last message
      await _firestore.collection('chats').doc(chatId).update({
        'lastMessage': message,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageSender': currentUser.uid,
      });

      // ✅ NEW: If user is offline, setup listener for when they come online
      if (!isOtherOnline) {
        _setupDeliveryListener(chatId, msgRef.id, otherUserId);
      }
    } catch (e) {
      print('Error sending message: $e');
      rethrow;
    }
  }

  // 4. ✅ NEW: SETUP DELIVERY LISTENER FOR OFFLINE USERS - FIXED
  void _setupDeliveryListener(String chatId, String messageId, String otherUserId) {
    _firestore.collection('users').doc(otherUserId).snapshots().listen((snapshot) {
      // FIX: Properly cast snapshot data
      Map<String, dynamic>? userData = snapshot.data() as Map<String, dynamic>?;
      bool isOnline = userData?['isOnline'] ?? false;

      if (isOnline) {
        // User came online - mark message as delivered
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
    });
  }

  // 5. CREATE NEW CHAT - FIXED
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
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        List participants = List.from(data['participants'] ?? []);
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

  // 6. GET UNREAD COUNT (UPDATED)
  Future<int> _getUnreadCount(String chatId, String userId) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .where('senderId', isNotEqualTo: userId) // Messages from others
          .where('readBy', isNotEqualTo: userId) // Not read by current user
          .get();

      return snapshot.docs.length;
    } catch (e) {
      print('Error getting unread count: $e');
      return 0;
    }
  }

  // 7. MARK MESSAGES AS READ (UPDATED WITH BATCH WRITE)
  Future<void> markMessagesAsRead(String chatId) async {
    User? currentUser = _auth.currentUser;
    if (currentUser == null || chatId.isEmpty) return;

    try {
      // Get all unread messages from other users
      QuerySnapshot unreadMessages = await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .where('senderId', isNotEqualTo: currentUser.uid)
          .where('readBy', isNotEqualTo: currentUser.uid)
          .get();

      // Use batch write for better performance
      WriteBatch batch = _firestore.batch();

      for (var doc in unreadMessages.docs) {
        batch.update(doc.reference, {
          'readBy': FieldValue.arrayUnion([currentUser.uid]),
        });
      }

      await batch.commit();
    } catch (e) {
      print('Error marking messages as read: $e');
    }
  }

  // 8. UPDATE ONLINE STATUS
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

  // 9. DELETE MESSAGE
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

  // 10. ✅ NEW: GET OTHER PARTICIPANT ID (Helper method) - FIXED
  Future<String?> getOtherParticipantId(String chatId) async {
    User? currentUser = _auth.currentUser;
    if (currentUser == null) return null;

    try {
      DocumentSnapshot chatDoc = await _firestore.collection('chats').doc(chatId).get();
      Map<String, dynamic> chatData = chatDoc.data() as Map<String, dynamic>;
      List participants = List.from(chatData['participants'] ?? []);
      return participants.firstWhere((id) => id != currentUser.uid);
    } catch (e) {
      print('Error getting other participant: $e');
      return null;
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