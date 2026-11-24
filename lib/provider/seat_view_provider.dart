import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:lockerroom/model/seat_view_model.dart';

class SeatViewProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  StreamSubscription<QuerySnapshot>? _sub;

  List<SeatViewModel> _posts = [];
  bool _isLoading = true;
  bool _isUploading = false;

  List<SeatViewModel> get posts => List.unmodifiable(_posts);
  bool get isLoading => _isLoading;
  bool get isUploading => _isUploading;

  void subscribe() {
    if (_sub != null) return;
    _isLoading = true;
    notifyListeners();

    _sub = _firestore
        .collection('seat_views')
        .orderBy('createdAt', descending: true)
        .limit(120)
        .snapshots()
        .listen(
          (snap) {
            _posts = snap.docs.map(SeatViewModel.fromDoc).toList();
            _isLoading = false;
            notifyListeners();
          },
          onError: (_) {
            _isLoading = false;
            notifyListeners();
          },
        );
  }

  Future<bool> createPost({
    required String stadium,
    required String zone,
    required String seatText,
    required String review,
    required List<String> tags,
    required List<File> images,
    String? userNickName,
    String? userProfileImage,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || images.isEmpty) return false;

    _isUploading = true;
    notifyListeners();

    try {
      final docRef = _firestore.collection('seat_views').doc();
      final List<String> uploadedUrls = [];

      for (int i = 0; i < images.length; i++) {
        final ref = FirebaseStorage.instance
            .ref()
            .child('seat_views')
            .child(user.uid)
            .child('${docRef.id}_$i.jpg');
        await ref.putFile(images[i]);
        uploadedUrls.add(await ref.getDownloadURL());
      }

      final post = SeatViewModel(
        id: docRef.id,
        userId: user.uid,
        userNickName: userNickName ?? user.displayName ?? '야구팬',
        userProfileImage: userProfileImage ?? user.photoURL,
        stadium: SeatViewModel.normalizeStadium(stadium),
        zone: zone,
        seatText: seatText.trim(),
        blockNumber: SeatViewModel.extractBlock(seatText),
        imageUrls: uploadedUrls,
        review: review.trim(),
        tags: tags,
        likedBy: const [],
        createdAt: DateTime.now(),
      );

      await docRef.set(post.toMap());
      return true;
    } catch (_) {
      return false;
    } finally {
      _isUploading = false;
      notifyListeners();
    }
  }

  /// 이미 업로드된 이미지 URL(직관기록 저장 시)로 좌석 시야 게시글을 함께 생성
  Future<void> createPostFromUrls({
    required String stadium,
    required String seatText,
    required List<String> imageUrls,
    String review = '',
    String? userNickName,
    String? userProfileImage,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || imageUrls.isEmpty || seatText.trim().isEmpty) return;

    try {
      final docRef = _firestore.collection('seat_views').doc();
      final post = SeatViewModel(
        id: docRef.id,
        userId: user.uid,
        userNickName: userNickName ?? user.displayName ?? '야구팬',
        userProfileImage: userProfileImage ?? user.photoURL,
        stadium: SeatViewModel.normalizeStadium(stadium),
        zone: SeatViewModel.inferZone(seatText),
        seatText: seatText.trim(),
        blockNumber: SeatViewModel.extractBlock(seatText),
        imageUrls: imageUrls,
        review: review.trim(),
        tags: const [],
        likedBy: const [],
        createdAt: DateTime.now(),
      );
      await docRef.set(post.toMap());
    } catch (_) {}
  }

  Future<void> toggleLike(SeatViewModel post) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final ref = _firestore.collection('seat_views').doc(post.id);
    if (post.likedBy.contains(uid)) {
      await ref.update({
        'likedBy': FieldValue.arrayRemove([uid]),
      });
    } else {
      await ref.update({
        'likedBy': FieldValue.arrayUnion([uid]),
      });
    }
  }

  Future<void> deletePost(String postId) async {
    await _firestore.collection('seat_views').doc(postId).delete();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
