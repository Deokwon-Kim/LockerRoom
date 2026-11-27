import 'dart:async';
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

  int _uploadProgress = 0;
  bool _isUploading = false;
  bool _uploadFailed = false;
  String? _meetupId;
  String _uploadStatusText = '';

  // 동영상 사전 압축 + 사전 업로드 상태
  int _videoTaskToken = 0;
  Future<String?>? _videoPreprocessFuture;
  String? _preUploadedVideoUrl;
  String? _preUploadedVideoStoragePath;
  bool _isPreProcessingVideo = false;
  int _videoPreprocessProgress = 0;
  String _videoPreprocessLabel = '';

  // 백그라운드 재시도용 스냅샷
  _PendingPostPayload? _lastFailedPayload;

  String get uploadStatusText => _uploadStatusText;
  List<File> get images => _images;
  File? get camera => _camera;
  File? get video => _video;
  Uint8List? get videoThumbnail => _videoThumbnail;
  int get uploadProgress => _uploadProgress;
  bool get isUploading => _isUploading;
  bool get uploadFailed => _uploadFailed;
  String? get meetupId => _meetupId;
  bool get isPreProcessingVideo => _isPreProcessingVideo;
  int get videoPreprocessProgress => _videoPreprocessProgress;
  String get videoPreprocessLabel => _videoPreprocessLabel;

  void setMeetupId(String? id) {
    _meetupId = id;
    notifyListeners();
  }

  void setImages(List<File> newImages) {
    _images = newImages;
    notifyListeners();
  }

  void setVideo(File? videoFile) {
    if (videoFile == null) {
      _cancelAndCleanupPreUploadedVideo();
      _video = null;
      _videoThumbnail = null;
      notifyListeners();
      return;
    }
    _video = videoFile;
    _generateThumbnail();
    _startVideoPreprocess(videoFile);
    notifyListeners();
  }

  void setCamera(File? cameraFile) {
    _camera = cameraFile;
    notifyListeners();
  }

  String? _initialCaption;

  void setInitialCaption(String caption) {
    _initialCaption = caption;
    notifyListeners();
  }

  String? consumeInitialCaption() {
    final caption = _initialCaption;
    _initialCaption = null;
    return caption;
  }

  void clearDraft() {
    _images = [];
    _video = null;
    _camera = null;
    _videoThumbnail = null;
    _initialCaption = null;
    _meetupId = null;
    _isPreProcessingVideo = false;
    _videoPreprocessProgress = 0;
    _videoPreprocessLabel = '';
    _videoPreprocessFuture = null;
    _preUploadedVideoUrl = null;
    _preUploadedVideoStoragePath = null;
    notifyListeners();
  }

  void clearAll() {
    _cancelAndCleanupPreUploadedVideo();
    _images = [];
    _video = null;
    _camera = null;
    _videoThumbnail = null;
    _uploadProgress = 0;
    _isUploading = false;
    _uploadFailed = false;
    _uploadStatusText = '';
    _initialCaption = null;
    _meetupId = null;
    notifyListeners();
  }

  void _cancelAndCleanupPreUploadedVideo() {
    _videoTaskToken++;
    _videoPreprocessFuture = null;
    _isPreProcessingVideo = false;
    _videoPreprocessProgress = 0;
    _videoPreprocessLabel = '';

    final pathToDelete = _preUploadedVideoStoragePath;
    _preUploadedVideoUrl = null;
    _preUploadedVideoStoragePath = null;
    if (pathToDelete != null) {
      FirebaseStorage.instance
          .ref()
          .child(pathToDelete)
          .delete()
          .catchError((_) {});
    }
  }

  Future<void> pickCamera() async {
    final pickedCamera = await ImagePicker().pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
      maxWidth: 1440,
    );
    if (pickedCamera != null) {
      final file = File(pickedCamera.path);
      if (_camera == null) {
        _camera = file;
      } else {
        _images = [..._images, file];
      }
      notifyListeners();
    }
  }

  Future<void> pickImages() async {
    final pickedImages = await ImagePicker().pickMultiImage(
      imageQuality: 85,
      maxWidth: 1440,
    );
    if (pickedImages.isNotEmpty) {
      final existingPaths = _images.map((e) => e.path).toSet();
      final appended = pickedImages
          .map((e) => File(e.path))
          .where((file) => !existingPaths.contains(file.path))
          .toList();
      if (appended.isNotEmpty) {
        setImages([..._images, ...appended]);
      }
    }
  }

  /// ImagePicker 우선 선택 + 60초 검증 + 실패 시 wechat_assets_picker 폴백
  /// 선택 즉시 백그라운드에서 720p·30fps 압축 및 사전 업로드 시작
  Future<void> pickVideoFast(BuildContext context) async {
    final startTime = DateTime.now();
    debugPrint('⚡ 동영상 선택 시작 (ImagePicker)');

    File? videoFile;

    try {
      final pickedVideo = await ImagePicker().pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(seconds: 60),
      );

      if (pickedVideo == null) {
        debugPrint('⚠️ 동영상 선택 취소됨');
        return;
      }

      videoFile = File(pickedVideo.path);
    } catch (e) {
      debugPrint('⚠️ ImagePicker 오류, wechat_assets_picker로 폴백: $e');
      if (!context.mounted) return;
      final List<AssetEntity>? result = await AssetPicker.pickAssets(
        context,
        pickerConfig: const AssetPickerConfig(
          requestType: RequestType.video,
          maxAssets: 1,
        ),
      );

      if (result == null || result.isEmpty) {
        return;
      }

      final asset = result.first;
      try {
        videoFile = await asset.originFile;
      } catch (_) {
        videoFile = await asset.file;
      }
    }

    if (videoFile == null) {
      throw Exception('동영상 파일을 불러올 수 없습니다.');
    }

    // 1분 이하 길이 검증
    try {
      final mediaInfo = await VideoCompress.getMediaInfo(videoFile.path);
      final videoDuration = mediaInfo.duration ?? 0;
      final durationInSeconds = (videoDuration / 1000).round();
      debugPrint('⏱️ 비디오 길이: $durationInSeconds초');

      if (durationInSeconds > 60) {
        throw VideoDurationExceededException(
          '1분 이하의 동영상만 업로드 가능합니다.\n현재 길이: $durationInSeconds초',
        );
      }
    } catch (e) {
      if (e is VideoDurationExceededException) {
        rethrow;
      }
      debugPrint('⚠️ 비디오 길이 확인 실패: $e');
    }

    _cancelAndCleanupPreUploadedVideo();
    _video = videoFile;
    notifyListeners();

    debugPrint(
      '⚡ 동영상 선택 UI 반영: ${DateTime.now().difference(startTime).inMilliseconds}ms',
    );

    _generateThumbnail();
    _startVideoPreprocess(videoFile);
  }

  /// 동영상 선택 직후 백그라운드에서 720p·30fps 압축 + Storage 사전 업로드 진행
  void _startVideoPreprocess(File sourceFile) {
    final token = ++_videoTaskToken;
    _isPreProcessingVideo = true;
    _videoPreprocessProgress = 0;
    _videoPreprocessLabel = '화질 최적화 중...';
    notifyListeners();

    _videoPreprocessFuture = _runVideoPreprocessPipeline(sourceFile, token);
  }

  Future<String?> _runVideoPreprocessPipeline(
    File sourceFile,
    int token,
  ) async {
    Subscription? progressSub;
    try {
      final stopwatch = Stopwatch()..start();
      File fileToUpload = sourceFile;

      // 1. 파일 크기·해상도 확인 (15MB 미만 & 720p 이하이면 압축 생략)
      final fileSizeMB = sourceFile.lengthSync() / (1024 * 1024);
      bool shouldCompress = true;
      try {
        final info = await VideoCompress.getMediaInfo(sourceFile.path);
        final width = info.width ?? 0;
        final height = info.height ?? 0;
        final maxDim = width > height ? width : height;
        if (fileSizeMB < 15 && maxDim > 0 && maxDim <= 1280) {
          shouldCompress = false;
          debugPrint(
            '⏭️ 이미 최적화된 영상 (${fileSizeMB.toStringAsFixed(1)}MB, ${width}x$height) - 압축 생략',
          );
        }
      } catch (_) {}

      if (token != _videoTaskToken) return null;

      if (shouldCompress) {
        progressSub = VideoCompress.compressProgress$.subscribe((progress) {
          if (token != _videoTaskToken) return;
          _videoPreprocessProgress = (progress * 0.5).round().clamp(0, 50);
          _videoPreprocessLabel = '화질 최적화 중 (${progress.round()}%)';
          notifyListeners();
        });

        final compressed = await _compressVideo720p(sourceFile);
        progressSub.unsubscribe();
        progressSub = null;
        if (token != _videoTaskToken) return null;
        fileToUpload = compressed;
        debugPrint(
          '🎬 720p 압축 완료: ${stopwatch.elapsedMilliseconds}ms (${(fileToUpload.lengthSync() / (1024 * 1024)).toStringAsFixed(1)}MB)',
        );
      }

      // 2. 사전 업로드 시작
      _videoPreprocessLabel = '사전 업로드 중...';
      _videoPreprocessProgress = shouldCompress ? 50 : 10;
      notifyListeners();

      final storagePath =
          'videos/${DateTime.now().millisecondsSinceEpoch}_${fileToUpload.path.split('/').last}';
      final ref = FirebaseStorage.instance.ref().child(storagePath);
      final task = ref.putFile(
        fileToUpload,
        SettableMetadata(contentType: 'video/mp4'),
      );

      task.snapshotEvents.listen((snapshot) {
        if (token != _videoTaskToken) return;
        if (snapshot.totalBytes > 0) {
          final ratio = snapshot.bytesTransferred / snapshot.totalBytes;
          final base = shouldCompress ? 50 : 10;
          _videoPreprocessProgress = (base + ratio * (100 - base))
              .round()
              .clamp(base, 99);
          _videoPreprocessLabel = '사전 업로드 중 (${(ratio * 100).round()}%)';
          notifyListeners();
        }
      });

      await task;

      if (token != _videoTaskToken) {
        // 대기 중 취소되었으면 방금 올라간 파일 정리
        await ref.delete().catchError((_) {});
        return null;
      }

      final url = await ref.getDownloadURL();
      if (token != _videoTaskToken) {
        await ref.delete().catchError((_) {});
        return null;
      }

      _preUploadedVideoUrl = url;
      _preUploadedVideoStoragePath = storagePath;
      _isPreProcessingVideo = false;
      _videoPreprocessProgress = 100;
      _videoPreprocessLabel = '업로드 준비 완료';
      notifyListeners();
      debugPrint('⚡ 동영상 사전 업로드 완료: 총 ${stopwatch.elapsedMilliseconds}ms');
      return url;
    } catch (e) {
      debugPrint('⚠️ 동영상 사전 처리 오류: $e');
      if (token == _videoTaskToken) {
        _isPreProcessingVideo = false;
        _videoPreprocessLabel = '';
        notifyListeners();
      }
      return null;
    } finally {
      progressSub?.unsubscribe();
    }
  }

  Future<File> _compressVideo720p(File file) async {
    try {
      final info = await VideoCompress.compressVideo(
        file.path,
        quality: VideoQuality.Res1280x720Quality,
        deleteOrigin: false,
        includeAudio: true,
        frameRate: 30,
      );
      if (info?.path != null) {
        return File(info!.path!);
      }
      return file;
    } catch (e) {
      debugPrint('⚠️ 720p 압축 실패, 원본 반환: $e');
      return file;
    }
  }

  Future<void> _generateThumbnail() async {
    if (_video == null) return;
    final startTime = DateTime.now();

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
      debugPrint(
        '🎨 썸네일 생성 완료: ${DateTime.now().difference(startTime).inMilliseconds}ms',
      );
    } catch (e) {
      _videoThumbnail = null;
      notifyListeners();
      debugPrint('❌ 썸네일 생성 실패: $e');
    }
  }

  Future<File> _compressBeforeUpload(File file) async {
    try {
      return await _compressVideo720p(file);
    } catch (e) {
      debugPrint('⚠️ 압축 중 오류: $e, 원본 파일로 업로드 시도');
      return file;
    }
  }

  /// 백그라운드 게시 시작 (호출 즉시 드래프트 비우고, 피드 상단 진행 바로 상태 표시)
  void startBackgroundPost({
    required String userId,
    required String userNickName,
    required String name,
    required String text,
    List<String> hashtags = const [],
    VoidCallback? onCompleted,
  }) {
    final payload = _PendingPostPayload(
      userId: userId,
      userNickName: userNickName,
      name: name,
      text: text,
      hashtags: List<String>.from(hashtags),
      images: List<File>.from(_images),
      camera: _camera,
      video: _video,
      meetupId: _meetupId,
      preUploadedVideoUrl: _preUploadedVideoUrl,
      videoPreprocessFuture: _videoPreprocessFuture,
    );

    // 드래프트 비우기 (단, 진행 중인 사전 업로드 토큰/파일은 유지)
    _images = [];
    _video = null;
    _camera = null;
    _videoThumbnail = null;
    _initialCaption = null;
    _meetupId = null;
    _isPreProcessingVideo = false;
    _videoPreprocessProgress = 0;
    _videoPreprocessLabel = '';
    _videoPreprocessFuture = null;
    _preUploadedVideoUrl = null;
    _preUploadedVideoStoragePath = null;

    _isUploading = true;
    _uploadFailed = false;
    _uploadProgress = 5;
    _uploadStatusText = '게시물 업로드 준비 중...';
    _lastFailedPayload = null;
    notifyListeners();

    unawaited(_executeBackgroundUpload(payload, onCompleted: onCompleted));
  }

  Future<void> retryLastFailedUpload() async {
    final payload = _lastFailedPayload;
    if (payload == null || _isUploading) return;
    _isUploading = true;
    _uploadFailed = false;
    _uploadProgress = 5;
    _uploadStatusText = '다시 업로드 중...';
    notifyListeners();
    await _executeBackgroundUpload(payload);
  }

  void dismissUploadError() {
    _uploadFailed = false;
    _uploadStatusText = '';
    _lastFailedPayload = null;
    notifyListeners();
  }

  Future<void> _executeBackgroundUpload(
    _PendingPostPayload payload, {
    VoidCallback? onCompleted,
  }) async {
    try {
      final List<String> mediaUrls = [];
      final imageFiles = <File>[
        ...payload.images,
        if (payload.camera != null) payload.camera!,
      ];
      final hasVideo = payload.video != null;
      final totalSteps =
          imageFiles.length + (hasVideo ? 1 : 0) + 1; // +1은 Firestore 저장
      int completedSteps = 0;

      // 1. 이미지 병렬 업로드
      if (imageFiles.isNotEmpty) {
        _uploadStatusText = '사진 업로드 중 (${imageFiles.length}장)...';
        notifyListeners();

        final uploadedImages = await Future.wait(
          imageFiles.map((file) async {
            final url = await _uploadFileWithRetry(
              file,
              'images',
              contentType: 'image/jpeg',
            );
            completedSteps++;
            _uploadProgress = ((completedSteps / totalSteps) * 90)
                .round()
                .clamp(5, 90);
            notifyListeners();
            return url;
          }),
        );
        mediaUrls.addAll(uploadedImages);
      }

      // 2. 동영상 (사전 업로드 결과 우선 사용, 없으면 720p 압축 후 업로드)
      if (hasVideo) {
        String? videoUrl = payload.preUploadedVideoUrl;
        if (videoUrl == null && payload.videoPreprocessFuture != null) {
          _uploadStatusText = '동영상 마무리 중...';
          notifyListeners();
          videoUrl = await payload.videoPreprocessFuture;
        }
        if (videoUrl == null) {
          _uploadStatusText = '동영상 화질 최적화 중...';
          notifyListeners();
          final compressedVideo = await _compressBeforeUpload(payload.video!);
          _uploadStatusText = '동영상 업로드 중...';
          notifyListeners();
          videoUrl = await _uploadFileWithRetry(
            compressedVideo,
            'videos',
            contentType: 'video/mp4',
            onProgress: (ratio) {
              final stepBase = (completedSteps / totalSteps) * 90;
              final stepSpan = (1 / totalSteps) * 90;
              _uploadProgress = (stepBase + ratio * stepSpan).round().clamp(
                5,
                92,
              );
              _uploadStatusText = '동영상 업로드 중 (${(ratio * 100).round()}%)';
              notifyListeners();
            },
          );
        }
        mediaUrls.add(videoUrl);
        completedSteps++;
        _uploadProgress = ((completedSteps / totalSteps) * 90).round().clamp(
          10,
          92,
        );
        notifyListeners();
      }

      // 3. Firestore 저장
      _uploadStatusText = '피드에 게시 중...';
      _uploadProgress = 95;
      notifyListeners();

      await FirebaseFirestore.instance.collection('posts').add({
        'userId': payload.userId,
        'userNickName': payload.userNickName,
        'name': payload.name,
        'text': payload.text,
        'hashtags': payload.hashtags,
        'mediaUrls': mediaUrls,
        'meetupId': payload.meetupId,
        'createdAt': FieldValue.serverTimestamp(),
      });

      _uploadProgress = 100;
      _uploadStatusText = '게시 완료!';
      notifyListeners();
      onCompleted?.call();

      await Future.delayed(const Duration(milliseconds: 1200));

      _isUploading = false;
      _uploadProgress = 0;
      _uploadStatusText = '';
      notifyListeners();
    } catch (e) {
      debugPrint('❌ 백그라운드 게시 실패: $e');
      _isUploading = false;
      _uploadFailed = true;
      _uploadProgress = 0;
      _uploadStatusText = '게시물 업로드에 실패했습니다';
      _lastFailedPayload = payload;
      notifyListeners();
    }
  }

  /// 기존 동기 업로드 API 호환 유지
  Future<void> uploadAndSavePost({
    required String userId,
    required String userNickName,
    required String name,
    required String text,
  }) async {
    final completer = Completer<void>();
    startBackgroundPost(
      userId: userId,
      userNickName: userNickName,
      name: name,
      text: text,
      onCompleted: () {
        if (!completer.isCompleted) completer.complete();
      },
    );
    return completer.future;
  }

  Future<String> _uploadFileWithRetry(
    File file,
    String folder, {
    String? contentType,
    void Function(double ratio)? onProgress,
    int retries = 3,
  }) async {
    for (int attempt = 0; attempt < retries; attempt++) {
      try {
        final ref = FirebaseStorage.instance.ref().child(
          '$folder/${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last}',
        );
        final metadata = contentType != null
            ? SettableMetadata(contentType: contentType)
            : null;
        final task = ref.putFile(file, metadata);
        if (onProgress != null) {
          task.snapshotEvents.listen((snapshot) {
            if (snapshot.totalBytes > 0) {
              onProgress(snapshot.bytesTransferred / snapshot.totalBytes);
            }
          });
        }
        await task;
        return await ref.getDownloadURL();
      } catch (e) {
        if (attempt == retries - 1) rethrow;
      }
    }
    throw Exception('업로드 실패: ${file.path}');
  }
}

class _PendingPostPayload {
  final String userId;
  final String userNickName;
  final String name;
  final String text;
  final List<String> hashtags;
  final List<File> images;
  final File? camera;
  final File? video;
  final String? meetupId;
  final String? preUploadedVideoUrl;
  final Future<String?>? videoPreprocessFuture;

  _PendingPostPayload({
    required this.userId,
    required this.userNickName,
    required this.name,
    required this.text,
    this.hashtags = const [],
    required this.images,
    required this.camera,
    required this.video,
    required this.meetupId,
    required this.preUploadedVideoUrl,
    required this.videoPreprocessFuture,
  });
}
