import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:lockerroom/model/market_post_model.dart';

class MarketFeedProvider extends ChangeNotifier {
  final _marketPostCollection = FirebaseFirestore.instance.collection(
    'market_posts',
  );

  // 전체피드
  List<MarketPostModel> _marketPostsStream = [];
  List<MarketPostModel> get marketPostsStream => _marketPostsStream;

  List<MarketPostModel> _allMarketPosts = [];
  String _query = '';

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

  void _applyFilter() {
    if (_query.isEmpty) {
      _marketPostsStream = List<MarketPostModel>.from(_allMarketPosts);
    } else {
      _marketPostsStream = _allMarketPosts
          .where((post) => post.title.toLowerCase().contains(_query))
          .toList();
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _marketSub?.cancel();
    super.dispose();
  }

  // 게시글 삭제
  Future<void> deletePost(MarketPostModel marketPost) async {
    for (final url in marketPost.imageUrls) {
      await FirebaseStorage.instance.refFromURL(url).delete();
    }
    final firestore = FirebaseFirestore.instance;
    final marketPostRef = _marketPostCollection.doc(marketPost.userId);
  }
}
