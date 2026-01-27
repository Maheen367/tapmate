import 'package:flutter/material.dart';
import '../services/dummy_data_service.dart';

class SavedPostsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final savedPosts = DummyDataService.getSavedPosts();

    return Scaffold(
      appBar: AppBar(
        title: Text('Saved Posts'),
      ),
      body: savedPosts.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bookmark_border, size: 80, color: Colors.grey[300]),
            SizedBox(height: 20),
            Text(
              'No saved posts yet',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 10),
            Text(
              'Save posts by tapping the bookmark icon',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      )
          : GridView.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
        ),
        itemCount: savedPosts.length,
        itemBuilder: (context, index) {
          final post = savedPosts[index];
          return Image.network(
            post['thumbnail_url'],
            fit: BoxFit.cover,
          );
        },
      ),
    );
  }
}