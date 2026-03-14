// lib/services/cloudinary_service.dart
import 'dart:io';
import 'package:cloudinary_public/cloudinary_public.dart';

class CloudinaryService {
  static final CloudinaryService _instance = CloudinaryService._internal();
  factory CloudinaryService() => _instance;
  CloudinaryService._internal();

  // 🔥 APNE CLOUDINARY CREDENTIALS
  final String cloudName = 'dvxejhpau';  // Tumhara cloud name
  final String uploadPreset = 'tapmate fyp'; // Cloudinary console mein ye preset banana hai

  late CloudinaryPublic _cloudinary;

  // ✅ 1. INIT METHOD - Cloudinary initialize karta hai
  void init() {
    _cloudinary = CloudinaryPublic(cloudName, uploadPreset);
    print('✅ Cloudinary initialized with cloud: $cloudName');
  }

  // ✅ 2. UPLOAD PROFILE PICTURE METHOD - Photo upload karta hai
  Future<String?> uploadProfilePicture(File imageFile, String userId) async {
    try {
      print('📤 Uploading to Cloudinary...');

      final response = await _cloudinary.uploadFile(
        CloudinaryFile.fromFile(imageFile.path,
          publicId: 'profile_$userId',
          folder: 'profile image',
        ),
      );

      print('✅ Upload successful: ${response.secureUrl}');
      return response.secureUrl;

    } catch (e) {
      print('❌ Error uploading to Cloudinary: $e');
      return null;
    }
  }

  // ✅ 3. GET OPTIMIZED IMAGE URL - Resize karta hai
  String getOptimizedImageUrl(String url, {int width = 200, int height = 200}) {
    if (url.isEmpty || !url.contains('cloudinary.com')) return url;
    return url.replaceFirst(
      '/upload/',
      '/upload/w_$width,h_$height,c_fill,q_auto,f_auto/',
    );
  }

  // ✅ 4. GET CIRCULAR IMAGE URL - Gol gol image banata hai (profile pic ke liye)
  String getCircularImageUrl(String url, {int size = 200}) {
    if (url.isEmpty || !url.contains('cloudinary.com')) return url;
    return url.replaceFirst(
      '/upload/',
      '/upload/w_$size,h_$size,c_fill,r_max,q_auto,f_auto/',
    );
  }
}