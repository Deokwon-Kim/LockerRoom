import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class MarketUploadProvider extends ChangeNotifier {
  List<File> _images = [];
  File? _camera;
  double _uploadProgress = 0.0;
  bool _isUploading = false;
  static const int maxImages = 10;

  List<File> get images => _images;
  File? get camera => _camera;
  double get uploadProgress => _uploadProgress;
  bool get isUploading => _isUploading;

  void setImages(List<File> newImages) {
    _images = newImages;
    notifyListeners();
  }

  void setCamera(File? cameraFile) {
    _camera = cameraFile;
    notifyListeners();
  }

  void clearAll() {
    _images = [];
    _camera = null;
    _uploadProgress = 0.0;
    _isUploading = false;
    notifyListeners();
  }

  Future<void> pickCamera() async {
    // 현재 개수(기존 이미지 + 카메라 1) 가 한도에 도달하면 무시
    final currentCount = _images.length + (_camera != null ? 1 : 0);
    if (currentCount >= maxImages) return;
    final pickedCamera = await ImagePicker().pickImage(
      source: ImageSource.camera,
    );
    if (pickedCamera != null) {
      _camera = File(pickedCamera.path);
      notifyListeners();
    }
  }

  Future<void> pickImages() async {
    final pickedImages = await ImagePicker().pickMultiImage();
    if (pickedImages.isNotEmpty) {
      // 남은 슬롯 계산
      final currentCount = _images.length + (_camera != null ? 1 : 0);
      final remaining = maxImages - currentCount;
      if (remaining <= 0) return;
      final filesToAdd = pickedImages
          .take(remaining)
          .map((e) => File(e.path))
          .toList();
      setImages([..._images, ...filesToAdd]);
    }
  }

  Future<void> uploadAndSavePost({
    required String userId,
    required String userName,
    required String title,
    String? description,
    required String price,
    required String type,
  }) async {
    if (_images.isEmpty && _camera == null) return;

    _isUploading = true;
    _uploadProgress = 0.0;
    notifyListeners();

    List<String> imageUrls = [];
    int totalCount = _images.length + (_camera != null ? 1 : 0);
    int uploadCount = 0;

    // 이미지 업로드
    for (var img in _images) {
      final url = await _uploadFileWithRetry(img);
      imageUrls.add(url);
      uploadCount++;
      _uploadProgress = uploadCount / totalCount;
      notifyListeners();
    }

    // 카메라 이미지 업로드
    if (_camera != null) {
      final url = await _uploadFileWithRetry(_camera!);
      imageUrls.add(url);
      uploadCount++;
      _uploadProgress = uploadCount / totalCount;
      notifyListeners();
    }

    // Firestore에 게시물 저장
    await FirebaseFirestore.instance
        .collection('market_posts')
        .doc(userId)
        .set({
          'userId': userId,
          'userName': userName,
          'title': title,
          'description': description,
          'price': price,
          'type': type,
          'imageUrls': imageUrls,
          'createdAt': FieldValue.serverTimestamp(),
        });

    _isUploading = false;
    _uploadProgress = 1.0;
    notifyListeners();

    // 업로드 완료 후 초기화
    clearAll();
  }

  Future<String> _uploadFileWithRetry(File file, {int retries = 3}) async {
    for (int attempt = 0; attempt < retries; attempt++) {
      try {
        final ref = FirebaseStorage.instance.ref().child(
          'after_market/${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last}',
        );
        final task = ref.putFile(file);
        await task;
        return await ref.getDownloadURL();
      } catch (e) {
        if (attempt == retries - 1) rethrow;
      }
    }
    throw Exception('업로드 실패: ${file.path}');
  }
}
