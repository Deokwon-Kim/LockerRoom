import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final postRef = _postCollection.doc(post.id);

    await FirebaseFirestore.instance.runTransaction((tx) async {
      final snap = await tx.get(postRef);
      if (!snap.exists) return;

      final data = snap.data() as Map<String, dynamic>;
      final currentLikes = (data['likesCount'] ?? 0) as int;
      final likedByList = List<String>.from(data['likedBy'] ?? const []);

      final isLiked = likedByList.contains(uid);
      if (isLiked) {
        likedByList.remove(uid);
      } else {
        likedByList.add(uid);
      }

      final newLikes = isLiked
          ? (currentLikes > 0 ? currentLikes - 1 : 0)
          : currentLikes + 1;

      tx.update(postRef, {'likedBy': likedByList, 'likesCount': newLikes});
    });
  }
}
