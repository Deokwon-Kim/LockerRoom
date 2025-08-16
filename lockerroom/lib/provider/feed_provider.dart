import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:lockerroom/model/post_model.dart';

class FeedProvider extends ChangeNotifier {
  final _postCollection = FirebaseFirestore.instance.collection('posts');

  Stream<List<PostModel>> get postsStream {
    return _postCollection
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => PostModel.fromDoc(doc)).toList(),
        );
  }

  Future<void> toggleLike(PostModel post) async {
    final postRef = _postCollection.doc(post.id);
    final snapshot = await postRef.get();
    int likes = snapshot['likesCount'] ?? 0;
    await postRef.update({'likesCount': likes + 1});
  }
}
