import 'dart:io';
import 'package:flutter/material.dart';

class PostModel {
  final List<File> images; // 여러 이미지 지원
  final String caption;
  final String authorName; // 작성자 이름
  final ImageProvider? authorProfileImage; // 작성자 프로필 이미지
  final DateTime createdAt; // 작성 시간

  PostModel({
    required this.images,
    required this.caption,
    required this.authorName,
    this.authorProfileImage,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  // 하위 호환성을 위한 생성자
  PostModel.singleImage({
    required File image,
    required this.caption,
    required this.authorName,
    this.authorProfileImage,
    DateTime? createdAt,
  }) : images = [image], createdAt = createdAt ?? DateTime.now();

  // 첫 번째 이미지를 반환하는 getter (하위 호환성)
  File get image {
    if (images.isEmpty) {
      throw StateError('No images available in this post');
    }
    return images.first;
  }
  
  // 이미지가 있는지 확인하는 getter
  bool get hasImages => images.isNotEmpty;
}
