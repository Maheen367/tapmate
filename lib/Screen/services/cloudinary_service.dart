// lib/services/cloudinary_service.dart

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
}