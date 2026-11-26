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
  int _uploadProgress = 0;
  String _uploadStatusText = '';
  String? _lastError;

  List<SeatViewModel> get posts => List.unmodifiable(_posts);
  bool get isLoading => _isLoading;
  bool get isUploading => _isUploading;
  int get uploadProgress => _uploadProgress;
  String get uploadStatusText => _uploadStatusText;
  String? get lastError => _lastError;

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
    _uploadProgress = 5;
    _uploadStatusText = '사진 업로드 준비 중...';
    _lastError = null;
    notifyListeners();

    try {
      final docRef = _firestore.collection('seat_views').doc();
      final List<String> uploadedUrls = [];

      for (int i = 0; i < images.length; i++) {
        _uploadStatusText = '사진 업로드 중... (${i + 1}/${images.length})';
        notifyListeners();

        final file = images[i];
        final rawName = file.path.split('/').last;
        final lower = rawName.toLowerCase();
        final ext = lower.endsWith('.png')
            ? 'png'
            : (lower.endsWith('.heic') ? 'heic' : 'jpg');
        final contentType = ext == 'png'
            ? 'image/png'
            : (ext == 'heic' ? 'image/heic' : 'image/jpeg');

        final ref = FirebaseStorage.instance
            .ref()
            .child('seat_views')
            .child(user.uid)
            .child('${docRef.id}_$i.$ext');
        final metadata = SettableMetadata(contentType: contentType);

        try {
          final task = ref.putFile(file, metadata);
          task.snapshotEvents.listen((snap) {
            if (snap.totalBytes > 0) {
              final ratio = snap.bytesTransferred / snap.totalBytes;
              final base = (i / images.length) * 85;
              final span = (1 / images.length) * 85;
              _uploadProgress = (base + ratio * span).round().clamp(5, 90);
              notifyListeners();
            }
          });
          await task;
        } catch (_) {
          final bytes = await file.readAsBytes();
          await ref.putData(bytes, metadata);
        }
        uploadedUrls.add(await ref.getDownloadURL());
      }

      _uploadProgress = 95;
      _uploadStatusText = '좌석 시야 게시글 저장 중...';
      notifyListeners();

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
      _uploadProgress = 100;
      _uploadStatusText = '업로드 완료!';
      notifyListeners();
      return true;
    } catch (e) {
      _lastError = e.toString();
      debugPrint('SeatView createPost error: $e');
      return false;
    } finally {
      _isUploading = false;
      _uploadProgress = 0;
      _uploadStatusText = '';
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

  Future<bool> updatePost({
    required SeatViewModel original,
    required String stadium,
    required String zone,
    required String seatText,
    required String review,
    required List<String> tags,
    required List<String> keptImageUrls,
    required List<File> newImages,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.uid != original.userId) return false;
    if (keptImageUrls.isEmpty && newImages.isEmpty) return false;

    _isUploading = true;
    _uploadProgress = 5;
    _uploadStatusText = '수정 내용 반영 중...';
    _lastError = null;
    notifyListeners();

    try {
      final List<String> finalUrls = [...keptImageUrls];
      final ts = DateTime.now().millisecondsSinceEpoch;

      for (int i = 0; i < newImages.length; i++) {
        _uploadStatusText = '새 사진 업로드 중... (${i + 1}/${newImages.length})';
        notifyListeners();

        final file = newImages[i];
        final rawName = file.path.split('/').last;
        final lower = rawName.toLowerCase();
        final ext = lower.endsWith('.png')
            ? 'png'
            : (lower.endsWith('.heic') ? 'heic' : 'jpg');
        final contentType = ext == 'png'
            ? 'image/png'
            : (ext == 'heic' ? 'image/heic' : 'image/jpeg');

        final ref = FirebaseStorage.instance
            .ref()
            .child('seat_views')
            .child(user.uid)
            .child('${original.id}_edit_${ts}_$i.$ext');
        final metadata = SettableMetadata(contentType: contentType);

        try {
          await ref.putFile(file, metadata);
        } catch (_) {
          final bytes = await file.readAsBytes();
          await ref.putData(bytes, metadata);
        }
        finalUrls.add(await ref.getDownloadURL());
      }

      _uploadProgress = 95;
      _uploadStatusText = '저장 중...';
      notifyListeners();

      await _firestore.collection('seat_views').doc(original.id).update({
        'stadium': SeatViewModel.normalizeStadium(stadium),
        'zone': zone,
        'seatText': seatText.trim(),
        'blockNumber': SeatViewModel.extractBlock(seatText),
        'imageUrls': finalUrls,
        'review': review.trim(),
        'tags': tags,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      _uploadProgress = 100;
      _uploadStatusText = '수정 완료!';
      notifyListeners();
      return true;
    } catch (e) {
      _lastError = e.toString();
      debugPrint('SeatView updatePost error: $e');
      return false;
    } finally {
      _isUploading = false;
      _uploadProgress = 0;
      _uploadStatusText = '';
      notifyListeners();
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
