// import 'dart:io';

import 'package:lockerroom/model/post_model.dart';

class MediaUtils {
  // PostModel의 mediaInfo를 사용하여 비디오 여부 확인 (최우선)
  static bool isVideoFromPost(PostModel post, int index) {
    if (post.mediaInfo != null && index < post.mediaInfo!.length) {
      final mediaItem = post.mediaInfo![index];
      return mediaItem['type'] == 'video';
    }
    // mediaInfo가 없으면 URL 기반으로 fallback
    if (index < post.mediaUrls.length) {
      return isVideoUrl(post.mediaUrls[index]);
    }
    return false;
  }
  
  // URL에서 동영상 파일인지 감지 (fallback)
  static bool isVideoUrl(String url) {
    final videoExtensions = [
      'mp4',
      'mov',
      'avi',
      'mkv',
      '3gp',
      'webm',
      'flv',
      'm4v',
    ];
    final lowerUrl = url.toLowerCase();

    // Firebase Storage URL의 경우 쿼리 파라미터 제거 후 확장자 확인
    final cleanUrl = lowerUrl.split('?').first;
    
    // URL 디코딩 후 확장자 확인
    final decodedUrl = Uri.decodeFull(cleanUrl);

    return videoExtensions.any((ext) => 
      cleanUrl.endsWith('.$ext') || 
      decodedUrl.toLowerCase().endsWith('.$ext')
    );
  }

  // 로컬 파일이 동영상인지 감지
  static bool isVideoFile(String path) {
    final videoExtensions = [
      'mp4',
      'mov',
      'avi',
      'mkv',
      '3gp',
      'webm',
      'flv',
      'm4v',
    ];
    final extension = path.toLowerCase().split('.').last;
    return videoExtensions.contains(extension);
  }

  // 파일 크기를 사람이 읽기 쉬운 형태로 변환
  static String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024)
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
