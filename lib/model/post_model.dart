import 'package:cloud_firestore/cloud_firestore.dart';

class PostModel {
  final String id;
  final String text;
  final List<String> mediaUrls;
  final List<Map<String, dynamic>>? mediaInfo; // 새로운 미디어 정보 필드
  final String userId;
  final DateTime createdAt;
  final int likesCount;
  final String userNickName;
  final String userName;

  final List<String> likedBy;

  PostModel({
    required this.id,
    required this.text,
    required this.mediaUrls,
    this.mediaInfo,
    required this.userId,
    required this.createdAt,
    required this.likesCount,
    required this.userNickName,
    required this.userName,
    required this.likedBy,
  });

  factory PostModel.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // mediaInfo 파싱 (기존 데이터와 호환성 유지)
    List<Map<String, dynamic>>? mediaInfo;
    if (data['mediaInfo'] != null) {
      mediaInfo = List<Map<String, dynamic>>.from(
        data['mediaInfo'].map((item) => Map<String, dynamic>.from(item)),
      );
    }

    return PostModel(
      id: doc.id,
      text: data['text'] ?? "",
      mediaUrls: List<String>.from(data['mediaUrls'] ?? []),
      mediaInfo: mediaInfo,
      userId: data['userId'] ?? "",
      createdAt: data['createdAt'] == null
          ? DateTime.now()
          : (data['createdAt'] as Timestamp).toDate(),
      likesCount: data['likesCount'] ?? 0,
      userNickName: data['userName'] ?? '사용자',
      userName: data['name'] ?? '',
      likedBy: List<String>.from(data['likedBy'] ?? const []),
    );
  }
}
