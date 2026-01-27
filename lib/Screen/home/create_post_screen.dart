import 'package:flutter/material.dart';

class CreatePostScreen extends StatefulWidget {
  @override
  _CreatePostScreenState createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  TextEditingController _captionController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Create Post'),
        leading: IconButton(
          icon: Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Post created successfully!')),
              );
              Navigator.pop(context);
            },
            child: Text(
              'Share',
              style: TextStyle(
                color: Color(0xFFA64D79),
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Video/Image preview
          Container(
            height: 300,
            color: Colors.grey[200],
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.video_library, size: 60, color: Colors.grey[500]),
                  SizedBox(height: 10),
                  Text(
                    'Select a video or photo',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      // Pick video/image
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFFA64D79),
                    ),
                    child: Text('Select from Library'),
                  ),
                ],
              ),
            ),
          ),
          // Caption
          Padding(
            padding: EdgeInsets.all(16),
            child: TextField(
              controller: _captionController,
              decoration: InputDecoration(
                hintText: 'Write a caption...',
                border: InputBorder.none,
              ),
              maxLines: 5,
            ),
          ),
        ],
      ),
    );
  }
}