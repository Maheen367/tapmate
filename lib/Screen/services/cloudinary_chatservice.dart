import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';

class CloudinaryService {
  static final CloudinaryService _instance = CloudinaryService._internal();
  factory CloudinaryService() => _instance;
  CloudinaryService._internal();

  final String cloudName = "dvxejhpau";
  final String uploadPreset = "Tapmate";

  void initialize() {
    debugPrint('✅ Cloudinary initialized with cloud: $cloudName');
  }

  // Upload voice message using direct HTTP - FIXED
  Future<String?> uploadVoiceMessage(File audioFile, {String? userId, String? chatId}) async {
    try {
      debugPrint('📤 Uploading to Cloudinary: ${audioFile.path}');

      if (!await audioFile.exists()) {
        debugPrint('❌ File does not exist: ${audioFile.path}');
        return null;
      }

      // Create multipart request
      var uri = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/auto/upload');
      var request = http.MultipartRequest('POST', uri);

      // Add fields
      request.fields['upload_preset'] = uploadPreset;
      request.fields['folder'] = 'voice_messages';

      // ✅ FIXED: Use audioFile.path (String) instead of audioFile (File)
      request.files.add(await http.MultipartFile.fromPath(
        'file',
        audioFile.path,  // ← This is a String, not a File
      ));

      // Send request
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        var jsonData = jsonDecode(response.body);
        debugPrint('✅ Upload successful: ${jsonData['secure_url']}');
        return jsonData['secure_url'];
      } else {
        debugPrint('❌ Upload failed: ${response.body}');
        return null;
      }

    } catch (e) {
      debugPrint('❌ Unexpected error: $e');
      return null;
    }
  }

  // Alternative method with more options
  Future<String?> uploadVoiceMessageWithOptions(File audioFile,
      {String? userId, String? chatId, String? folder}) async {
    try {
      debugPrint('📤 Uploading to Cloudinary: ${audioFile.path}');

      if (!await audioFile.exists()) {
        debugPrint('❌ File does not exist: ${audioFile.path}');
        return null;
      }

      var uri = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/auto/upload');
      var request = http.MultipartRequest('POST', uri);

      request.fields['upload_preset'] = uploadPreset;
      request.fields['folder'] = folder ?? 'voice_messages';

      // Add context if provided
      if (userId != null && chatId != null) {
        request.fields['context'] = 'userId=$userId|chatId=$chatId';
      }

      // ✅ FIXED: Use audioFile.path
      request.files.add(await http.MultipartFile.fromPath(
        'file',
        audioFile.path,
      ));

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        var jsonData = jsonDecode(response.body);
        debugPrint('✅ Upload successful: ${jsonData['secure_url']}');
        return jsonData['secure_url'];
      } else {
        debugPrint('❌ Upload failed: ${response.body}');
        return null;
      }

    } catch (e) {
      debugPrint('❌ Unexpected error: $e');
      return null;
    }
  }

  // Get optimized audio URL
  String getOptimizedAudioUrl(String url) {
    return url.replaceFirst('/upload/', '/upload/f_mp3/q_auto/');
  }
}