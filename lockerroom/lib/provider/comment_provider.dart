import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:lockerroom/model/comment_model.dart';

class CommentProvider with ChangeNotifier {
  final _commentsCollection = FirebaseFirestore.instance.collection('comments');

  Map<String, List<CommentModel>> _postComments = {};
  Map<String, StreamSubscription> _subs = {};

  List<CommentModel> getComments(String postId) => _postComments[postId] ?? [];

  void subscribeComments(String postId) {
    _subs[postId]?.cancel();
    _subs[postId] = _commentsCollection
        .where('postId', isEqualTo: postId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snap) {
          _postComments[postId] = snap.docs
              .map((doc) => CommentModel.fromDoc(doc))
              .toList();
          notifyListeners();
        });
  }

  Future<void> addComment(String postId, CommentModel comment) async {
    await _commentsCollection.add({...comment.toMap(), 'postId': postId});
  }

  Future<void> toggleLike(CommentModel comment, String userId) async {
    final docRef = _commentsCollection.doc(comment.id);
    final doc = await docRef.get();
    final data = doc.data()!;
    final likedBy = List<String>.from(data['likedBy'] ?? []);

    if (likedBy.contains(userId)) {
      likedBy.remove(userId);
    } else {
      likedBy.add(userId);
    }

    await docRef.update({'likedBy': likedBy, 'likesCount': likedBy.length});
  }

  void cancelSubscription(String postId) {
    _subs[postId]?.cancel();
  }

  @override
  void dispose() {
    _subs.values.forEach((sub) => sub.cancel());
    super.dispose();
  }
}
