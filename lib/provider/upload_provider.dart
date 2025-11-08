import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_compress/video_compress.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';

class VideoDurationExceededException implements Exception {
  final String message;
  VideoDurationExceededException(this.message);
  @override
  String toString() => message;
}

class UploadProvider extends ChangeNotifier {
  List<File> _images = [];
  File? _camera;
  File? _video;
  Uint8List? _videoThumbnail = Uint8List(0);

  double _uploadProgress = 0.0;
  bool _isUploading = false;

  List<File> get images => _images;
  File? get camera => _camera;
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

  void setCamera(File? cameraFile) {
    _camera = cameraFile;
    notifyListeners();
  }

  void clearAll() {
    _images = [];
    _video = null;
    _camera = null;
    _videoThumbnail = null;
    _uploadProgress = 0.0;
    _isUploading = false;
    notifyListeners();
  }

  Future<void> pickCamera() async {
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
      setImages(pickedImages.map((e) => File(e.path)).toList());
    }
  }

  /// ⚡ wechat_assets_picker를 사용한 빠른 동영상 선택 (iCloud 오류 시 자동 폴백)
  Future<void> pickVideoFast(BuildContext context) async {
    final startTime = DateTime.now();
    print('⚡ pickVideoFast 시작');

    try {
      print('⚡ wechat_assets_picker 갤러리 열기...');

      final List<AssetEntity>? result = await AssetPicker.pickAssets(
        context,
        pickerConfig: const AssetPickerConfig(
          requestType: RequestType.video,
          maxAssets: 1,
        ),
      );

      if (result == null || result.isEmpty) {
        print('⚠️ 동영상 선택 취소됨');
        return;
      }

      print(
        '⚡ wechat_assets_picker 선택 완료: ${DateTime.now().difference(startTime).inMilliseconds}ms',
      );

      final asset = result.first;

      // 파일 가져오기 시도
      File? videoFile;

      // 1차 시도: originFile (가장 빠름)
      try {
        videoFile = await asset.originFile;
        print('✅ originFile 성공');
      } catch (e) {
        print('⚠️ originFile 실패: $e');

        // 2차 시도: file (캐시)
        try {
          videoFile = await asset.file;
          print('✅ file 캐시 성공');
        } catch (e2) {
          print('⚠️ file 캐시도 실패: $e2');
          videoFile = null;
        }
      }

      if (videoFile == null) {
        throw Exception('wechat_assets_picker에서 파일을 가져올 수 없음');
      }

      // 📏 비디오 길이 확인 - VideoCompress를 사용해서 정확한 길이 가져오기
      try {
        final mediaInfo = await VideoCompress.getMediaInfo(videoFile.path);
        final videoDuration = mediaInfo.duration ?? 0; // ms 단위
        final durationInSeconds = (videoDuration / 1000).round();
        print('⏱️ 비디오 길이: ${durationInSeconds}초 (${videoDuration}ms)');

        if (durationInSeconds > 60) {
          throw VideoDurationExceededException(
            '1분 이하의 동영상만 업로드 가능합니다.\n현재 길이: ${durationInSeconds}초',
          );
        }
      } catch (e) {
        if (e is VideoDurationExceededException) {
          rethrow;
        }
        print('⚠️ 비디오 길이 확인 실패: $e, 계속 진행합니다');
        // 길이 확인 실패해도 계속 진행
      }

      // 파일 크기 확인
      final fileSizeInMB = videoFile.lengthSync() / (1024 * 1024);
      print('📁 파일 크기: ${fileSizeInMB.toStringAsFixed(2)} MB');

      _video = videoFile;
      notifyListeners();

      print(
        '⚡ UI 표시 완료: ${DateTime.now().difference(startTime).inMilliseconds}ms',
      );

      // 썸네일 백그라운드 생성
      _generateThumbnail();
      return;
    } catch (e) {
      print('❌ wechat_assets_picker 오류: $e');

      // 1분 초과 오류인 경우 (사용자에게 표시)
      if (e is VideoDurationExceededException) {
        print('⏱️ 1분 초과 오류 - 사용자에게 표시');
        rethrow; // 에러 메시지 표시를 위해 전파
      }

      // 다른 오류는 기존 ImagePicker로 폴백
      print('📱 기존 ImagePicker로 자동 폴백 중...');
      try {
        final pickedVideo = await ImagePicker().pickVideo(
          source: ImageSource.gallery,
          maxDuration: const Duration(seconds: 60),
        );

        if (pickedVideo != null) {
          final videoFile = File(pickedVideo.path);
          _video = videoFile;
          notifyListeners();
          print('✅ ImagePicker 폴백 성공');
          _generateThumbnail();
        }
      } catch (fallbackError) {
        print('❌ 폴백도 실패: $fallbackError');
        rethrow;
      }
    }
  }

  Future<File> _compressVideoFast(File file, int durationSeconds) async {
    // 항상 중간 품질로 고정 (품질과 속도의 균형)
    const quality = VideoQuality.MediumQuality;

    try {
      final info = await VideoCompress.compressVideo(
        file.path,
        quality: quality,
        deleteOrigin: false,
        includeAudio: true,
        frameRate: 20, // 24fps → 20fps로 낮춤 (더 빠른 압축)
      );
      return File(info!.path!);
    } catch (e) {
      // 압축 실패 시 원본 반환
      return file;
    }
  }

  Future<void> _generateThumbnail() async {
    if (_video == null) return;
    final startTime = DateTime.now();
    print('🎨 썸네일 생성 시작');

    try {
      final data = await VideoThumbnail.thumbnailData(
        video: _video!.path,
        imageFormat: ImageFormat.PNG,
        maxHeight: 150,
        maxWidth: 200,
        quality: 100,
        timeMs: 0,
      );
      _videoThumbnail = data;
      notifyListeners();
      print(
        '🎨 썸네일 생성 완료: ${DateTime.now().difference(startTime).inMilliseconds}ms',
      );
    } catch (e) {
      _videoThumbnail = null;
      notifyListeners();
      print('❌ 썸네일 생성 실패: $e');
    }
  }

  Future<File> _compressBeforeUpload(File file) async {
    try {
      final mediaInfo = await VideoCompress.getMediaInfo(file.path);
      final durationSeconds = (mediaInfo.duration ?? 0) ~/ 1000;

      final compressedVideo = await _compressVideoFast(file, durationSeconds);
      return compressedVideo;
    } catch (e) {
      // 에러 발생 시 원본 반환
      print('⚠️ 압축 중 오류: $e, 원본 파일로 업로드 시도');
      return file;
    }
  }

  Future<void> uploadAndSavePost({
    required String userId,
    required String userNickName,
    required String name,
    required String text,
  }) async {
    _isUploading = true;
    _uploadProgress = 0.0;
    notifyListeners();

    List<String> mediaUrls = [];
    int totalCount =
        _images.length + (_video != null ? 1 : 0) + (_camera != null ? 1 : 0);
    int uploadedCount = 0;

    // 이미지 업로드
    for (var img in _images) {
      final url = await _uploadFileWithRetry(img, 'images');
      mediaUrls.add(url);
      uploadedCount++;
      _uploadProgress = totalCount > 0 ? uploadedCount / totalCount : 1.0;
      notifyListeners();
    }

    // 동영상 업로드
    if (_video != null) {
      // 업로드 전에 압축
      final compressedVideo = await _compressBeforeUpload(_video!);
      final url = await _uploadFileWithRetry(compressedVideo, 'videos');
      mediaUrls.add(url);
      uploadedCount++;
      _uploadProgress = totalCount > 0 ? uploadedCount / totalCount : 1.0;
      notifyListeners();
    }

    // 카메라 이미지 업로드
    if (_camera != null) {
      final url = await _uploadFileWithRetry(_camera!, 'images');
      mediaUrls.add(url);
      uploadedCount++;
      _uploadProgress = totalCount > 0 ? uploadedCount / totalCount : 1.0;
      notifyListeners();
    }

    // Firestore에 Post 저장
    await FirebaseFirestore.instance.collection('posts').add({
      'userId': userId,
      'userNickName': userNickName,
      'name': name,
      'text': text,
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
