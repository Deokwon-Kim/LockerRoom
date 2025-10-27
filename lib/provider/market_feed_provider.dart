import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:lockerroom/model/market_post_model.dart';
import 'package:lockerroom/services/view_service.dart';

class MarketFeedProvider extends ChangeNotifier {
  final _marketPostCollection = FirebaseFirestore.instance.collection(
    'market_posts',
  );

  // 전체피드
  List<MarketPostModel> _marketPostsStream = [];
  List<MarketPostModel> get marketPostsStream => _marketPostsStream;

  List<MarketPostModel> _allMarketPosts = [];
  String _query = '';
  Set<String> _blockedUserIds = <String>{};
  Set<String> _blockedByUserIds = <String>{};

  StreamSubscription? _marketSub;
  bool isLoading = true;

  // 전체피드 구독
  void marketPostStream(String userId) {
    _marketSub?.cancel();
    _marketSub = _marketPostCollection
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen(
          (snap) {
            _allMarketPosts = snap.docs
                .map((doc) => MarketPostModel.fromDoc(doc))
                .toList();
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

  void setBlockedUsers(Set<String> ids) {
    _blockedUserIds = ids;
    _applyFilter();
  }

  void setBlockedByUsers(Set<String> ids) {
    _blockedByUserIds = ids;
    _applyFilter();
  }

  void _applyFilter() {
    if (_query.isEmpty) {
      _marketPostsStream = _allMarketPosts
          .where(
            (p) =>
                !_blockedUserIds.contains(p.userId) &&
                !_blockedByUserIds.contains(p.userId),
          )
          .toList();
    } else {
      _marketPostsStream = _allMarketPosts.where((post) {
        if (_blockedUserIds.contains(post.userId)) return false;
        if (_blockedByUserIds.contains(post.userId)) return false;
        return post.title.toLowerCase().contains(_query);
      }).toList();
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _marketSub?.cancel();
    super.dispose();
  }

  void cancelAllSubscriptions() {
    _marketSub?.cancel();
    _marketSub = null;
    _marketPostsStream = [];
    _allMarketPosts = [];
  }

  // 게시글 삭제
  Future<void> deletePost(MarketPostModel marketPost) async {
    try {
      print('Deleting post: ${marketPost.title}');

      // 1. Firebase Storage에서 이미지들 삭제
      for (final url in marketPost.imageUrls) {
        try {
          await FirebaseStorage.instance.refFromURL(url).delete();
          print('Deleted image: $url');
        } catch (e) {
          print('Error deleting image $url: $e');
          // 이미지 삭제 실패해도 계속 진행
        }
      }

      // 2. Firestore에서 문서 삭제
      await _marketPostCollection.doc(marketPost.postId).delete();
      print(
        'Deleted post from Firestore with documentId: ${marketPost.postId}',
      );

      // 3. 로컬 리스트에서도 제거
      _allMarketPosts.removeWhere((post) => post.postId == marketPost.postId);
      _applyFilter();
      notifyListeners();
    } catch (e) {
      print('Error deleting post: $e');
      rethrow; // 에러를 다시 던져서 UI에서 처리할 수 있도록
    }
  }

  // 게시글 조회 시 조회수 증가
  Future<void> viewPost(String postId) async {
    try {
      await ViewService.incrementViewCount(postId);
      // 로컬 상태 업데이트
      final postIndex = _allMarketPosts.indexWhere(
        (post) => post.postId == postId,
      );
      if (postIndex != -1) {
        _allMarketPosts[postIndex] = _allMarketPosts[postIndex].copyWith(
          viewCount: _allMarketPosts[postIndex].viewCount + 1,
        );
        notifyListeners();
      }
    } catch (e) {
      print('조회수 증가 실패: $e');
    }
  }

  Future<void> toggleLike(MarketPostModel marketPost) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final postRef = _marketPostCollection.doc(marketPost.postId);

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
  Stream<List<MarketPostModel>> listenMyMarketPosts() {
    return FirebaseAuth.instance.authStateChanges().asyncExpand((user) {
      if (user == null) return const Stream<List<MarketPostModel>>.empty();
      return _marketPostCollection
          .where('userId', isEqualTo: user.uid)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map(
            (snapshot) => snapshot.docs
                .map((doc) => MarketPostModel.fromDoc(doc))
                .toList(),
          );
    });
  }

  // 피드 신고 기능
  Future<void> reportMarketPost({
    required MarketPostModel marketPost,
    required String reporterUserId,
    required String reporterUserName,
    required String reason,
  }) async {
    await FirebaseFirestore.instance.collection('market_feed_reports').add({
      'type': 'market_post',
      'postId': marketPost.postId,
      'reportedUserId': marketPost.userId,
      'reportedUserName': marketPost.userName,
      'reporterUserId': reporterUserId,
      'reporterUserName': reporterUserName,
      'postText': marketPost.description,
      'reason': reason,
      'createdAt': FieldValue.serverTimestamp(),
      'status': 'pending', // pending, reviewed, closed
    });

    // 알림 대상 결정
    final targetUserId = 'Wxi2XKOWJYQeCSD9eY9wunyew1U2';

    // Firestore에 알림문서 추가
    await FirebaseFirestore.instance.collection('notifications').add({
      'type': 'market_post_report',
      'postId': marketPost.postId,
      'reportedUserId': marketPost.userId,
      'reportedUserName': marketPost.userName,
      'reporterUserId': reporterUserId,
      'reporterUserName': reporterUserName,
      'toUserId': targetUserId,
      'postText': marketPost.description,
      'reason': reason,
      'createdAt': FieldValue.serverTimestamp(),
      'status': 'pending',
    });
  }
}
