import 'package:cloud_firestore/cloud_firestore.dart';

class PostModel {
  final String id;
  final String text;
  final List<String> mediaUrls;
  final List<Map<String, dynamic>>? mediaInfo; // 새로운 미디어 정보 필드
  final String userId;
  final DateTime createdAt;
  final DateTime? updateAt;
  final int likesCount;
  final int? viewCount; // 조회수 추가
  final String userNickName;
  final String userName;
  final List<String> likedBy;
  final String? meetupId;

  PostModel({
    required this.id,
    required this.text,
    required this.mediaUrls,
    this.mediaInfo,
    required this.userId,
    required this.createdAt,
    this.updateAt,
    required this.likesCount,
    this.viewCount = 0,
    required this.userNickName,
    required this.userName,
    required this.likedBy,
    this.meetupId,
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
      updateAt: data['updatedAt'] == null
          ? DateTime.now()
          : (data['updatedAt'] as Timestamp).toDate(),
      likesCount: data['likesCount'] ?? 0,
      viewCount: data['viewCount'] ?? 0,
      userNickName: data['userNickName'] ?? '사용자',
      userName: data['name'] ?? '',
      likedBy: List<String>.from(data['likedBy'] ?? const []),
      meetupId: data['meetupId'],
    );
  }

  PostModel copyWith({
    String? text,
    List<String>? mediaUrls,
    List<Map<String, dynamic>>? mediaInfo,
    DateTime? updatedAt,
    int? likesCount,
    int? viewCount,
    String? userNickName,
    String? userName,
    List<String>? likedBy,
    String? meetupId,
  }) {
    return PostModel(
      id: id, // id, userId, createdAt 등 필수 변경 불가 필드는 그대로
      userId: userId,
      createdAt: createdAt,
      text: text ?? this.text,
      mediaUrls: mediaUrls ?? this.mediaUrls,
      mediaInfo: mediaInfo ?? this.mediaInfo,
      updateAt: updatedAt ?? updateAt,
      likesCount: likesCount ?? this.likesCount,
      viewCount: viewCount ?? this.viewCount,
      userNickName: userNickName ?? this.userNickName,
      userName: userName ?? this.userName,
      likedBy: likedBy ?? this.likedBy,
      meetupId: meetupId ?? this.meetupId,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'text': text,
      'mediaUrls': mediaUrls,
      'mediaInfo': mediaInfo,
      'userId': userId,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updateAt != null ? Timestamp.fromDate(updateAt!) : null,
      'likesCount': likesCount,
      'viewCount': viewCount,
      'userNickName': userNickName,
      'userName': userName,
      'likedBy': likedBy,
      'meetupId': meetupId,
    };
  }
}
