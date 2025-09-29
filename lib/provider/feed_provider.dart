import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
// import 'package:lockerroom/model/comment_model.dart';
import 'package:lockerroom/model/post_model.dart';

class FeedProvider extends ChangeNotifier {
  final _postCollection = FirebaseFirestore.instance.collection('posts');
  final _commentCollection = FirebaseFirestore.instance.collection('comments');
  // --- 전체 피드 ---
  List<PostModel> _postsStream = [];
  List<PostModel> get postsStream => _postsStream;
  // 필터의 기준이 되는 전체 스냅샷 원본 목록
  List<PostModel> _allPosts = [];
  String _query = '';

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
            _allPosts = snap.docs.map((doc) => PostModel.fromDoc(doc)).toList();
            _applyFilter();
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

  void setQuery(String query) {
    _query = query.toLowerCase();
    _applyFilter();
  }

  void _applyFilter() {
    if (_query.isEmpty) {
      _postsStream = List<PostModel>.from(_allPosts);
    } else {
      _postsStream = _allPosts
          .where((post) => post.text.toLowerCase().contains(_query))
          .toList();
    }
    notifyListeners();
  }

  // --- 최근 5개 피드 ---
  List<PostModel> _posts = [];
  List<PostModel> get posts => _posts;
  StreamSubscription? _subB;

  FeedProvider();

  void listenRecentPosts() {
    _subB?.cancel();
    _subB = _postCollection
        .orderBy('createdAt', descending: true)
        .limit(5)
        .snapshots()
        .listen(
          (snap) {
            _posts = snap.docs.map((doc) => PostModel.fromDoc(doc)).toList();
            isLoading = false;
            notifyListeners();
          },
          onError: (e) {
            isLoading = false;
            notifyListeners();
          },
        );
  }

  void cancelSubscription() {
    _sub?.cancel();
    _subB?.cancel();
  }

  void cancelAllSubscriptions() {
    _sub?.cancel();
    _subB?.cancel();
    _sub = null;
    _subB = null;
    _postsStream = [];
    _allPosts = [];
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
    notifyListeners();
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

  // Feed작성자의 게시물 불러오기
  Stream<List<PostModel>> listenUserPosts(String userId) {
    return _postCollection
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => PostModel.fromDoc(doc)).toList());
  }

  // 특정 사용자의 게시물 개수를 실시간으로 스트리밍
  Stream<int> listenUserPostCount(String userId) {
    return _postCollection
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) => snapshot.size);
  }

  // 게시글 삭제 시 해당 게시글의 모든 댓글도 함께 삭제
  Future<void> deletePost(PostModel post) async {
    for (final url in post.mediaUrls) {
      await FirebaseStorage.instance.refFromURL(url).delete();
    }
    final firestore = FirebaseFirestore.instance;
    final postRef = _postCollection.doc(post.id);

    // 해당 게시글의 댓글 모두 조회
    final commentsSnap = await _commentCollection
        .where('postId', isEqualTo: post.id)
        .get();

    // Firestore batch로 일괄 삭제 (500개 제한 고려)
    WriteBatch batch = firestore.batch();
    batch.delete(postRef);

    int ops = 1;
    for (final doc in commentsSnap.docs) {
      batch.delete(doc.reference);
      ops++;
      if (ops >= 450) {
        // 여유를 두고 커밋
        await batch.commit();
        batch = firestore.batch();
        ops = 0;
      }
    }

    await batch.commit();
  }
}
