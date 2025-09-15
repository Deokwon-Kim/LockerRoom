import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:lockerroom/model/comment_model.dart';

class CommentProvider with ChangeNotifier {
  final _commentsCollection = FirebaseFirestore.instance.collection('comments');

  final Map<String, List<CommentModel>> _postComments = {};
  final Map<String, StreamSubscription> _subs = {};

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

  Future<void> deleteComment(CommentModel comment) async {
    await _commentsCollection.doc(comment.id).delete();
  }

  Future<void> deleteCommentCascade(CommentModel comment) async {
    // 부모 댓글이면 연결된 모든 답글까지 일괄 삭제
    if (comment.reComments.isEmpty) {
      final batch = FirebaseFirestore.instance.batch();

      // 부모 댓글 문서
      final parentRef = _commentsCollection.doc(comment.id);
      batch.delete(parentRef);

      // 자식 답글들 조회 후 배치 삭제
      final repliesSnap = await _commentsCollection
          .where('postId', isEqualTo: comment.postId)
          .where('reComments', isEqualTo: comment.id)
          .get();
      for (final d in repliesSnap.docs) {
        batch.delete(d.reference);
      }

      await batch.commit();
    } else {
      // 답글이면 단일 삭제
      await deleteComment(comment);
    }
  }

  @override
  void dispose() {
    for (var sub in _subs.values) {
      sub.cancel();
    }
    super.dispose();
  }
}
