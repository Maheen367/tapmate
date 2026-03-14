// lib/services/platform_auth_service.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class PlatformAuthService {
  static final PlatformAuthService _instance = PlatformAuthService._internal();
  factory PlatformAuthService() => _instance;
  PlatformAuthService._internal();

  // Store platform sessions
  final Map<String, PlatformSession> _sessions = {};

  // Get saved session for platform
  Future<PlatformSession?> getSession(String platformId) async {
    final prefs = await SharedPreferences.getInstance();
    final sessionData = prefs.getString('platform_session_$platformId');

    if (sessionData != null) {
      try {
        final Map<String, dynamic> data = json.decode(sessionData);
        return PlatformSession.fromJson(data);
      } catch (e) {
        print('Error loading session: $e');
      }
    }

    return _sessions[platformId];
  }

  // Save session
  Future<void> saveSession(String platformId, PlatformSession session) async {
    _sessions[platformId] = session;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'platform_session_$platformId',
      json.encode(session.toJson()),
    );
  }

  // Clear session (logout)
  Future<void> clearSession(String platformId) async {
    _sessions.remove(platformId);

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('platform_session_$platformId');
  }

  // Check if user is logged in to platform
  Future<bool> isLoggedIn(String platformId) async {
    final session = await getSession(platformId);
    return session != null && !session.isExpired;
  }

  // Get auth token for platform
  Future<String?> getAuthToken(String platformId) async {
    final session = await getSession(platformId);
    return session?.accessToken;
  }
}

class PlatformSession {
  final String platformId;
  final String accessToken;
  final String refreshToken;
  final String userId;
  final String userName;
  final DateTime expiresAt;
  final Map<String, dynamic>? userData;

  PlatformSession({
    required this.platformId,
    required this.accessToken,
    required this.refreshToken,
    required this.userId,
    required this.userName,
    required this.expiresAt,
    this.userData,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  Map<String, dynamic> toJson() => {
    'platformId': platformId,
    'accessToken': accessToken,
    'refreshToken': refreshToken,
    'userId': userId,
    'userName': userName,
    'expiresAt': expiresAt.toIso8601String(),
    'userData': userData,
  };

  factory PlatformSession.fromJson(Map<String, dynamic> json) => PlatformSession(
    platformId: json['platformId'],
    accessToken: json['accessToken'],
    refreshToken: json['refreshToken'],
    userId: json['userId'],
    userName: json['userName'],
    expiresAt: DateTime.parse(json['expiresAt']),
    userData: json['userData'],
  );
}