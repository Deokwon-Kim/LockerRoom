import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:lockerroom/model/market_post_model.dart';

class MarketfeededitProvider extends ChangeNotifier {
  final _marketPostCollection = FirebaseFirestore.instance.collection(
    'market_posts',
  );
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // 수정 중인 이미지 리스트
  List<String> _editImageUrls = [];
  List<String> get editImageUrls => _editImageUrls;

  // 삭제된 미디어 URL (storage 정리용)
  List<String> _deleteImageUrls = [];

  // 로딩상태
  bool _isUploading = false;
  bool get isUploading => _isUploading;

  // 초기화 (기존 게시물 데이터 로드)
  void initializeEdit(MarketPostModel marketPost) {
    _editImageUrls = List.from(marketPost.imageUrls);
    _deleteImageUrls.clear();
    notifyListeners();
  }

  // 이미지 삭제
  void removeImage(int index) {
    if (index < 0 || index >= _editImageUrls.length) return;

    String removedImage = _editImageUrls[index];
    _deleteImageUrls.add(removedImage);
    _editImageUrls.removeAt(index);
    notifyListeners();
  }

  // 삭제된 이미지 Storage에서 정리
  Future<void> _cleanDeleteImage() async {
    for (String url in _deleteImageUrls) {
      try {
        final ref = _storage.refFromURL(url);
        await ref.delete();
      } catch (e) {
        print('Storage 삭제 실패: $e');
      }
    }
    _deleteImageUrls.clear();
  }

  // 게시물 업데이트
  Future<bool> updateMarketPost({
    required String postId,
    required String newtitle,
    required String newDesc,
    required String newPrice,
    required String newType,
  }) async {
    try {
      _isUploading = true;
      notifyListeners();

      await _marketPostCollection.doc(postId).update({
        'title': newtitle,
        'description': newDesc,
        'price': newPrice,
        'type': newType,
        'imageUrls': _editImageUrls,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // 삭제된 이미지 정리
      await _cleanDeleteImage();

      _isUploading = false;
      notifyListeners();
      return true;
    } catch (e) {
      print('게시물 업데이트 실패: $e');
      _isUploading = false;
      notifyListeners();
      return false;
    }
  }
}
