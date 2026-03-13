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

  // Upload voice message
  Future<String?> uploadVoiceMessage(File audioFile, {String? userId, String? chatId}) async {
    try {
      debugPrint('📤 Uploading to Cloudinary: ${audioFile.path}');

      if (!await audioFile.exists()) {
        debugPrint('❌ File does not exist: ${audioFile.path}');
        return null;
      }

      var uri = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/auto/upload');
      var request = http.MultipartRequest('POST', uri);

      request.fields['upload_preset'] = uploadPreset;
      request.fields['folder'] = 'voice_messages';

      if (userId != null && chatId != null) {
        request.fields['context'] = 'userId=$userId|chatId=$chatId';
      }

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

  // Upload image/video file
  Future<Map<String, dynamic>?> uploadMediaFile(File file, {String? userId, String? chatId}) async {
    try {
      debugPrint('📤 Uploading media to Cloudinary: ${file.path}');

      if (!await file.exists()) {
        debugPrint('❌ File does not exist: ${file.path}');
        return null;
      }

      // Detect file type
      String fileExtension = file.path.split('.').last.toLowerCase();
      bool isVideo = ['mp4', 'mov', 'avi', 'mkv', '3gp'].contains(fileExtension);
      String resourceType = isVideo ? 'video' : 'image';

      var uri = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/$resourceType/upload');
      var request = http.MultipartRequest('POST', uri);

      request.fields['upload_preset'] = uploadPreset;
      request.fields['folder'] = 'chat_media';

      if (userId != null && chatId != null) {
        request.fields['context'] = 'userId=$userId|chatId=$chatId';
      }

      request.files.add(await http.MultipartFile.fromPath(
        'file',
        file.path,
      ));

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        var jsonData = jsonDecode(response.body);
        debugPrint('✅ Upload successful: ${jsonData['secure_url']}');
        return {
          'url': jsonData['secure_url'],
          'type': isVideo ? 'video' : 'image',
          'publicId': jsonData['public_id'],
          'width': jsonData['width'],
          'height': jsonData['height'],
          'format': jsonData['format'],
          'bytes': jsonData['bytes'],
        };
      } else {
        debugPrint('❌ Upload failed: ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Error: $e');
      return null;
    }
  }

  // 🔥 NEW: Upload document file (PDF, DOC, TXT, etc.)
  Future<Map<String, dynamic>?> uploadDocumentFile(File file, {String? userId, String? chatId}) async {
    try {
      debugPrint('📤 Uploading document to Cloudinary: ${file.path}');

      if (!await file.exists()) {
        debugPrint('❌ File does not exist: ${file.path}');
        return null;
      }

      // Get file info
      String fileName = file.path.split('/').last;
      String fileExtension = fileName.split('.').last.toLowerCase();

      var uri = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/raw/upload');
      var request = http.MultipartRequest('POST', uri);

      request.fields['upload_preset'] = uploadPreset;
      request.fields['folder'] = 'chat_documents';
      request.fields['public_id'] = fileName.split('.').first; // Remove extension

      if (userId != null && chatId != null) {
        request.fields['context'] = 'userId=$userId|chatId=$chatId';
      }

      request.files.add(await http.MultipartFile.fromPath(
        'file',
        file.path,
      ));

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        var jsonData = jsonDecode(response.body);
        debugPrint('✅ Document upload successful: ${jsonData['secure_url']}');
        return {
          'url': jsonData['secure_url'],
          'type': 'document',
          'fileName': fileName,
          'fileExtension': fileExtension,
          'publicId': jsonData['public_id'],
          'format': jsonData['format'],
          'bytes': jsonData['bytes'],
        };
      } else {
        debugPrint('❌ Upload failed: ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Error: $e');
      return null;
    }
  }

  // Get optimized URL
  String getOptimizedUrl(String url) {
    return url.replaceFirst('/upload/', '/upload/f_auto/q_auto/');
  }
}