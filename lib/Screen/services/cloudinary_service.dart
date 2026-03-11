import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

class CloudinaryService {
  // 🔥 APNE SAHI CREDENTIALS YAHAN DALO
  static const String cloudName = 'dhzlkionm';  // Tumhara cloud name
  static const String apiKey = '169672485344253';  // Tumhari API key
  static const String apiSecret = 'dwiInp9xcKRuJ9A8Op-DXy_0pdU';  // Tumhara secret

  // 🔥 IMPORTANT: Upload preset add karo
  static const String uploadPreset = 'tapmate_preset';  // Dashboard mein banao

  Future<String> uploadFile({
    required File file,
    required bool isVideo,
  }) async {
    try {
      print('📤 Uploading to Cloudinary...');
      print('Cloud Name: $cloudName');
      print('Upload Preset: $uploadPreset');

      var uri = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/${isVideo ? 'video' : 'image'}/upload');

      var request = http.MultipartRequest('POST', uri)
        ..fields['upload_preset'] = uploadPreset
        ..files.add(await http.MultipartFile.fromPath(
          'file',
          file.path,
          contentType: MediaType(isVideo ? 'video' : 'image', isVideo ? 'mp4' : 'jpg'),
        ));

      var response = await request.send();
      var responseData = await response.stream.bytesToString();
      var jsonData = json.decode(responseData);

      print('Cloudinary Response: $jsonData');

      if (jsonData['secure_url'] != null) {
        return jsonData['secure_url'];
      } else {
        throw Exception('Upload failed: ${jsonData['error']['message']}');
      }
    } catch (e) {
      print('❌ Cloudinary upload error: $e');
      rethrow;
    }
  }

  // 🔥 FIXED: Voice message upload method
  Future<String?> uploadVoiceMessage(File audioFile, {String? userId, String? chatId}) async {
    try {
      print('📤 Uploading voice message to Cloudinary: ${audioFile.path}');
      print('Cloud Name: $cloudName');
      print('Upload Preset: $uploadPreset');

      // Check if file exists
      if (!await audioFile.exists()) {
        print('❌ File does not exist: ${audioFile.path}');
        return null;
      }

      // Create URI for video upload (audio files use video endpoint)
      var uri = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/video/upload');

      // Create multipart request
      var request = http.MultipartRequest('POST', uri)
        ..fields['upload_preset'] = uploadPreset
        ..fields['folder'] = 'voice_messages'
        ..fields['resource_type'] = 'video';

      // Add user and chat info in context
      if (userId != null && chatId != null) {
        request.fields['context'] = 'userId=$userId|chatId=$chatId';
      }

      // Add file to request
      request.files.add(await http.MultipartFile.fromPath(
        'file',
        audioFile.path,
        contentType: MediaType('audio', 'm4a'),
      ));

      // Send request
      var response = await request.send();
      var responseData = await response.stream.bytesToString();
      var jsonData = json.decode(responseData);

      print('✅ Cloudinary Response: $jsonData');

      if (jsonData['secure_url'] != null) {
        print('✅ Upload successful: ${jsonData['secure_url']}');
        return jsonData['secure_url'];
      } else {
        print('❌ Upload failed: ${jsonData['error']['message']}');
        return null;
      }
    } catch (e) {
      print('❌ Cloudinary upload error: $e');
      return null;
    }
  }

  // Get optimized audio URL
  String getOptimizedAudioUrl(String url) {
    return url.replaceFirst('/upload/', '/upload/f_mp3/q_auto/');
  }
}