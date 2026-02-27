// // lib/services/media_service.dart
//
// import 'dart:io';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:image_picker/image_picker.dart';
// import 'package:tapmate/Screen/services/cloudinary_service.dart';
//
// class MediaService {
//   final CloudinaryService _cloudinary = CloudinaryService();
//
//   Future<String> uploadMedia({
//     required XFile file,
//     required bool isVideo,
//   }) async {
//     final user = FirebaseAuth.instance.currentUser;
//     if (user == null) throw Exception('Not logged in');
//
//     final File mediaFile = File(file.path);
//
//     // Upload to Cloudinary
//     final mediaUrl = await _cloudinary.uploadFile(
//       file: mediaFile,
//       isVideo: isVideo,
//     );
//
//     return mediaUrl;
//   }
//
//   Future<XFile?> pickImage() async {
//     final ImagePicker picker = ImagePicker();
//     return await picker.pickImage(source: ImageSource.gallery);
//   }
//
//   Future<XFile?> pickVideo() async {
//     final ImagePicker picker = ImagePicker();
//     return await picker.pickVideo(source: ImageSource.gallery);
//   }
//
//   Future<XFile?> takePhoto() async {
//     final ImagePicker picker = ImagePicker();
//     return await picker.pickImage(source: ImageSource.camera);
//   }
// }