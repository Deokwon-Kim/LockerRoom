import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_compress/video_compress.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

class UploadProvider extends ChangeNotifier {
  List<File> _images = [];
  File? _video;
  Uint8List? _videoThumbnail = Uint8List(0);

  double _uploadProgress = 0.0;
  bool _isUploading = false;

  List<File> get images => _images;
  File? get video => _video;
  Uint8List? get videoThumbnail => _videoThumbnail;
  double get uploadProgress => _uploadProgress;
  bool get isUploading => _isUploading;

  void setImages(List<File> newImages) {
    _images = newImages;
    notifyListeners();
  }

  void setVideo(File? videoFile) {
    _video = videoFile;
    _generateThumbnail();
    notifyListeners();
  }

  void clearAll() {
    _images = [];
    _video = null;
    _videoThumbnail = null;
    _uploadProgress = 0.0;
    _isUploading = false;
    notifyListeners();
  }

  Future<void> pickImages() async {
    final pickedImages = await ImagePicker().pickMultiImage();
    if (pickedImages != null) {
      setImages(pickedImages.map((e) => File(e.path)).toList());
    }
  }

  Future<void> pickVideo() async {
    final pickedVideo = await ImagePicker().pickVideo(
      source: ImageSource.gallery,
    );
    if (pickedVideo != null) {
      final compressedVideo = await _compressVideo(File(pickedVideo.path));
      setVideo(compressedVideo);
    }
  }

  Future<File> _compressVideo(File file) async {
    final info = await VideoCompress.compressVideo(
      file.path,
      quality: VideoQuality.MediumQuality,
      deleteOrigin: false,
    );
    return File(info!.path!);
  }

  Future<void> _generateThumbnail() async {
    if (_video == null) return;
    try {
      final data = await VideoThumbnail.thumbnailData(
        video: _video!.path,
        imageFormat: ImageFormat.PNG,
        maxHeight: 120,
        quality: 75,
      );
      _videoThumbnail = data;
    } catch (e) {
      _videoThumbnail = null;
    }
    notifyListeners();
  }

  Future<void> uploadAndSavePost({
    required String userId,
    required String userName,
    String? content,
  }) async {
    if (_images.isEmpty && _video == null) return;

    _isUploading = true;
    _uploadProgress = 0.0;
    notifyListeners();

    List<String> mediaUrls = [];
    int totalCount = _images.length + (_video != null ? 1 : 0);
    int uploadedCount = 0;

    // 이미지 업로드
    for (var img in _images) {
      final url = await _uploadFileWithRetry(img, 'images');
      mediaUrls.add(url);
      uploadedCount++;
      _uploadProgress = uploadedCount / totalCount;
      notifyListeners();
    }

    // 동영상 업로드
    if (_video != null) {
      final url = await _uploadFileWithRetry(_video!, 'videos');
      mediaUrls.add(url);
      uploadedCount++;
      _uploadProgress = uploadedCount / totalCount;
      notifyListeners();
    }

    // Firestore에 Post 저장
    await FirebaseFirestore.instance.collection('posts').add({
      'userId': userId,
      'userName': userName,
      'content': content ?? '',
      'mediaUrls': mediaUrls,
      'createdAt': FieldValue.serverTimestamp(),
    });

    _isUploading = false;
    _uploadProgress = 1.0;
    notifyListeners();

    // 완료 후 초기화
    clearAll();
  }

  Future<String> _uploadFileWithRetry(
    File file,
    String folder, {
    int retries = 3,
  }) async {
    for (int attempt = 0; attempt < retries; attempt++) {
      try {
        final ref = FirebaseStorage.instance.ref().child(
          '$folder/${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last}',
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
