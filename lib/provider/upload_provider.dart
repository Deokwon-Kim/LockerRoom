import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/widgets.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:path_provider/path_provider.dart';

class UploadProvider extends ChangeNotifier {
  final ImagePicker _picker = ImagePicker();
  List<XFile> _mediaFiles = [];
  Map<String, String> _videoThumbnails = {}; // 동영상 파일 경로 -> 썸네일 경로
  bool _isUploading = false;

  List<XFile> get mediaFiles => _mediaFiles;
  Map<String, String> get videoThumbnails => _videoThumbnails;
  bool get isUploading => _isUploading;
  
  // 파일이 비디오인지 확인
  bool isVideoFile(XFile file) {
    final extension = file.path.toLowerCase().split('.').last;
    return ['mp4', 'mov', 'avi', 'mkv', '3gp', 'webm', 'flv'].contains(extension);
  }
  
  // 비디오 썸네일 생성
  Future<String?> generateVideoThumbnail(XFile videoFile) async {
    try {
      final thumbnailPath = await VideoThumbnail.thumbnailFile(
        video: videoFile.path,
        thumbnailPath: (await getTemporaryDirectory()).path,
        imageFormat: ImageFormat.JPEG,
        maxHeight: 300,
        quality: 75,
      );
      return thumbnailPath;
    } catch (e) {
      debugPrint('썸네일 생성 에러: $e');
      return null;
    }
  }

  // 다중 이미지/ 영상 선택
  Future<void> pickMultipleMedia() async {
    try {
      final List<XFile> pickedFiles = await _picker.pickMultipleMedia();

      if (pickedFiles.isNotEmpty) {
        _mediaFiles = pickedFiles;
        notifyListeners();
        
        // 동영상 파일들의 썸네일 생성
        for (var file in pickedFiles) {
          if (isVideoFile(file)) {
            final thumbnailPath = await generateVideoThumbnail(file);
            if (thumbnailPath != null) {
              _videoThumbnails[file.path] = thumbnailPath;
            }
          }
        }
        notifyListeners();
      }
    } catch (e) {
      debugPrint('미디어 선택 에러: $e');
    }
  }

  // 개별 미디어 제거
  void removeMediaAt(int index) {
    if (index >= 0 && index < _mediaFiles.length) {
      final removedFile = _mediaFiles[index];
      _mediaFiles.removeAt(index);
      
      // 동영상 썸네일도 제거
      if (_videoThumbnails.containsKey(removedFile.path)) {
        _videoThumbnails.remove(removedFile.path);
      }
      
      notifyListeners();
    }
  }

  // 업로드
  Future<bool> uploadPost(String text) async {
    final currnetUser = FirebaseAuth.instance.currentUser;
    if (currnetUser == null) return false;
    if (text.trim().isEmpty) return false;
    if (_mediaFiles.isEmpty) return false;

    _isUploading = true;
    notifyListeners();

    try {
      List<String> mediaUrls = [];
      for (var file in _mediaFiles) {
        final fileName =
            "${DateTime.now().millisecondsSinceEpoch}_${currnetUser.uid}";
        final ref = FirebaseStorage.instance
            .ref()
            .child('posts')
            .child(currnetUser.uid)
            .child(fileName);
        await ref.putFile(File(file.path));
        final url = await ref.getDownloadURL();
        mediaUrls.add(url);
      }

      // 미디어 타입 정보 생성
      List<Map<String, dynamic>> mediaInfo = [];
      for (int i = 0; i < _mediaFiles.length; i++) {
        final file = _mediaFiles[i];
        final isVideo = isVideoFile(file);
        mediaInfo.add({
          'url': mediaUrls[i],
          'type': isVideo ? 'video' : 'image',
          'filename': file.name,
        });
      }

      await FirebaseFirestore.instance.collection('posts').add({
        'userName': currnetUser.displayName,
        'userId': currnetUser.uid,
        'text': text,
        'mediaUrls': mediaUrls, // 기존 호환성을 위해 유지
        'mediaInfo': mediaInfo, // 새로운 상세 정보
        'createdAt': FieldValue.serverTimestamp(),
        'likesCount': 0,
        'profileImageUrl': currnetUser.photoURL ?? '',
      });

      _mediaFiles.clear();
      _videoThumbnails.clear(); // 썸네일 캐시도 정리
      _isUploading = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('업로드 에러: $e');
      _isUploading = false;
      notifyListeners();
      return false;
    }
  }
}
