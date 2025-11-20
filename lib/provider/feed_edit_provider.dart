import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:lockerroom/model/post_model.dart';

class FeedEditProvider extends ChangeNotifier {
  final _postCollection = FirebaseFirestore.instance.collection('posts');
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // 수정 중인 미디어 리스트
  List<String> _editableMediaUrls = [];
  List<String> get editableMediaUrls => _editableMediaUrls;

  // 삭제된 미디어 URL (storage 정리용)
  List<String> _deletedMediaUrls = [];

  // 로딩상태
  bool _isUploading = false;
  bool get isUploading => _isUploading;

  void setUploading(bool value) {
    _isUploading = value;
    notifyListeners();
  }

  // 초기화 (기존 게시물 데이터 로드)
  void initializeEdit(PostModel post) {
    _editableMediaUrls = List.from(post.mediaUrls);
    _deletedMediaUrls.clear();
    notifyListeners();
  }

  // 미디어 삭제
  void removeMedia(int index) {
    if (index < 0 || index >= _editableMediaUrls.length) return;

    String removedUrl = _editableMediaUrls[index];
    _deletedMediaUrls.add(removedUrl);
    _editableMediaUrls.removeAt(index);
    notifyListeners();
  }

  // 삭제된 미디어 Storage에서 정리
  Future<void> _cleanupDeletedMedia() async {
    for (String url in _deletedMediaUrls) {
      try {
        final ref = _storage.refFromURL(url);
        await ref.delete();
      } catch (e) {
        print('Storage 삭제 실패: $e');
      }
    }
    _deletedMediaUrls.clear();
  }

  // 게시물 업데이트 (text + media)
  Future<bool> updatePost({
    required String postId,
    required String newText,
  }) async {
    try {
      await _postCollection.doc(postId).update({
        'text': newText,
        'mediaUrls': _editableMediaUrls,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // 삭제된 미디어 정리
      await _cleanupDeletedMedia();
      return true;
    } catch (e) {
      print('게시물 업데이트 실패: $e');
      return false;
    }
  }

  // Provider 초기화
  void reset() {
    _editableMediaUrls.clear();
    _deletedMediaUrls.clear();
    _isUploading = false;
    notifyListeners();
  }
}
