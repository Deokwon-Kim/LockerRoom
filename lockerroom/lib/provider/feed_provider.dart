import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:lockerroom/model/post_model.dart';

class FeedProvider extends ChangeNotifier {
  final _postCollection = FirebaseFirestore.instance.collection('posts');
  // --- 전체 피드 ---
  List<PostModel> _postsStream = [];
  List<PostModel> get postsStream => _postsStream;
  StreamSubscription? _sub;
  bool isLoading = true;

  // 전체 피드 구독
  void postStream(String userId) {
    _sub?.cancel();
    _sub = _postCollection
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen(
          (snap) {
            _postsStream = snap.docs
                .map((doc) => PostModel.fromDoc(doc))
                .toList();
            isLoading = false;
            notifyListeners();
          },
          onError: (e) {
            print('Firestore error: $e');
            isLoading = false;
            notifyListeners();
          },
        );
  }

  // --- 최근 5개 피드 ---
  List<PostModel> _posts = [];
  List<PostModel> get posts => _posts;
  StreamSubscription? _subB;

  FeedProvider() {
    _subB?.cancel();
    _subB = _postCollection
        .orderBy('createdAt', descending: true)
        .limit(5)
        .snapshots()
        .listen((snap) {
          _posts = snap.docs.map((doc) => PostModel.fromDoc(doc)).toList();
          isLoading = false;
          notifyListeners();
        });
  }

  void cancelSubscription() {
    _sub?.cancel();
    _subB?.cancel();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _subB?.cancel();
    super.dispose();
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

  // 현재 로그인 한 유저에 게시물만 불러오기
  Stream<List<PostModel>> listenMyPosts() {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return const Stream.empty();
    return _postCollection
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => PostModel.fromDoc(doc)).toList(),
        );
  }

  // 현재 로그인 한 유저 게시물 삭제
  Future<void> deletePost(String postId) async {
    await _postCollection.doc(postId).delete();
  }
}
