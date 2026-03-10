// lib/Screen/home/create_post_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:tapmate/Screen/constants/app_colors.dart';
import 'package:tapmate/Screen/services/media_service.dart';

class CreatePostScreen extends StatefulWidget {
  @override
  _CreatePostScreenState createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final TextEditingController _captionController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  XFile? _selectedMedia;
  bool _isLoading = false;
  bool _isVideo = false;

  Future<void> _pickMedia() async {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library, color: AppColors.primary),
              title: const Text('Choose from Gallery'),
              onTap: () async {
                Navigator.pop(context);
                final XFile? image = await _picker.pickImage(
                  source: ImageSource.gallery,
                );
                if (image != null) {
                  setState(() {
                    _selectedMedia = image;
                    _isVideo = false;
                  });
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.video_library, color: AppColors.primary),
              title: const Text('Choose Video'),
              onTap: () async {
                Navigator.pop(context);
                final XFile? video = await _picker.pickVideo(
                  source: ImageSource.gallery,
                );
                if (video != null) {
                  setState(() {
                    _selectedMedia = video;
                    _isVideo = true;
                  });
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: AppColors.primary),
              title: const Text('Take Photo'),
              onTap: () async {
                Navigator.pop(context);
                final XFile? photo = await _picker.pickImage(
                  source: ImageSource.camera,
                );
                if (photo != null) {
                  setState(() {
                    _selectedMedia = photo;
                    _isVideo = false;
                  });
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<String> _uploadMedia() async {
    if (_selectedMedia == null) throw Exception('No media selected');

    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Not logged in');

    String fileName = '${user.uid}_${DateTime.now().millisecondsSinceEpoch}';
    String path = 'posts/${_isVideo ? 'videos' : 'images'}/$fileName';

    Reference ref = FirebaseStorage.instance.ref().child(path);
    UploadTask uploadTask = ref.putFile(File(_selectedMedia!.path));

    TaskSnapshot snapshot = await uploadTask;
    return await snapshot.ref.getDownloadURL();
  }

// lib/Screen/home/create_post_screen.dart mein _sharePost method

  // lib/Screen/home/create_post_screen.dart mein _sharePost method

  Future<void> _sharePost() async {
    if (_selectedMedia == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a media file')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Not logged in');

      // Get user data
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!userDoc.exists) {
        throw Exception('User document not found');
      }

      final userData = userDoc.data() as Map<String, dynamic>;

      // 🔥 UPLOAD TO CLOUDINARY
      print('📤 Uploading media to Cloudinary...');
      final mediaUrl = await MediaService().uploadMedia(
        file: _selectedMedia!,
        isVideo: _isVideo,
      );
      print('✅ Media uploaded: $mediaUrl');

      // Create post in Firestore
      await FirebaseFirestore.instance.collection('posts').add({
        'userId': user.uid,
        'userName': userData['name'] ?? user.displayName ?? 'User',
        'userProfilePic': userData['profile_pic'] ?? '',
        'caption': _captionController.text.trim(),
        'thumbnailUrl': mediaUrl,
        'videoUrl': _isVideo ? mediaUrl : null,
        'createdAt': FieldValue.serverTimestamp(),
        'likes': 0,
        'comments': 0,
        'isVideo': _isVideo,
      });

      // Update user's post count
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'posts_count': FieldValue.increment(1),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Post created successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      print('❌ ERROR: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Create Post',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 2,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _sharePost,
            child: _isLoading
                ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            )
                : const Text(
              'Share',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Column(
                  children: [
                    // Media preview
                    _selectedMedia == null
                        ? GestureDetector(
                      onTap: _pickMedia,
                      child: _buildMediaPreview(),
                    )
                        : _buildMediaPreview(),

                    // Caption input
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: TextField(
                        controller: _captionController,
                        decoration: const InputDecoration(
                          hintText: 'Write a caption...',
                          border: InputBorder.none,
                        ),
                        maxLines: 5,
                        textInputAction: TextInputAction.done,
                      ),
                    ),

                    // Change media button
                    if (_selectedMedia != null)
                      TextButton(
                        onPressed: _pickMedia,
                        child: const Text(
                          'Change Media',
                          style: TextStyle(color: AppColors.primary),
                        ),
                      ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMediaPreview() {
    return Container(
      height: 300,
      width: double.infinity,
      color: Colors.grey[200],
      child: _selectedMedia == null
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_photo_alternate,
              size: 60,
              color: Colors.grey[500],
            ),
            const SizedBox(height: 10),
            Text(
              'Tap to select media',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      )
          : _isVideo
          ? Stack(
        alignment: Alignment.center,
        children: [
          Image.file(
            File(_selectedMedia!.path),
            fit: BoxFit.cover,
            width: double.infinity,
            height: 300,
            errorBuilder: (context, error, stack) {
              return Container(
                color: Colors.grey[300],
                child: const Center(
                  child: Icon(Icons.video_file, size: 50),
                ),
              );
            },
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Colors.black54,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.play_arrow,
              color: Colors.white,
              size: 40,
            ),
          ),
        ],
      )
          : Image.file(
        File(_selectedMedia!.path),
        fit: BoxFit.cover,
        width: double.infinity,
        height: 300,
      ),
    );
  }
}