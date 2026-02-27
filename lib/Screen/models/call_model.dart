// lib/models/call_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class CallModel {
  final String id;
  final String callerId;
  final String receiverId;
  final String callerName;
  final String? callerAvatar;
  final String type; // 'video' or 'voice'
  final String status; // 'outgoing', 'incoming', 'missed'
  final DateTime startTime;
  final DateTime? endTime;
  final int duration; // in seconds

  CallModel({
    required this.id,
    required this.callerId,
    required this.receiverId,
    required this.callerName,
    this.callerAvatar,
    required this.type,
    required this.status,
    required this.startTime,
    this.endTime,
    this.duration = 0,
  });

  factory CallModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    DateTime start = (data['startTime'] as Timestamp).toDate();
    DateTime? end = data['endTime'] != null
        ? (data['endTime'] as Timestamp).toDate()
        : null;

    int duration = 0;
    if (end != null) {
      duration = end.difference(start).inSeconds;
    }

    return CallModel(
      id: doc.id,
      callerId: data['callerId'] ?? '',
      receiverId: data['receiverId'] ?? '',
      callerName: data['callerName'] ?? 'Unknown',
      callerAvatar: data['callerAvatar'],
      type: data['type'] ?? 'voice',
      status: data['status'] ?? 'missed',
      startTime: start,
      endTime: end,
      duration: duration,
    );
  }
}