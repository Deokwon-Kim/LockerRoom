import 'package:cloud_firestore/cloud_firestore.dart';

class CommentModel {
  final String id;
  final String postId;
  final String userId;
  final String userName;
  final String text;
  final String reComments;
  final int? likesCount;
  final List<String> likedBy;
  final DateTime createdAt;
  final bool isSecret;

  CommentModel({
    required this.id,
    required this.postId,
    required this.userId,
    required this.userName,
    required this.text,
    required this.reComments,
    this.likesCount = 0,
    this.likedBy = const [],
    required this.createdAt,
    this.isSecret = false,
  });

  factory CommentModel.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final dynamic createdAtRaw = data['createdAt'];
    DateTime createdAt;
    if (createdAtRaw is Timestamp) {
      createdAt = createdAtRaw.toDate();
    } else if (createdAtRaw is DateTime) {
      createdAt = createdAtRaw;
    } else if (createdAtRaw is String) {
      createdAt = DateTime.tryParse(createdAtRaw) ?? DateTime.now();
    } else {
      // 서버 타임스탬프 지연 등으로 null일 수 있으므로 현재 시각으로 대체
      createdAt = DateTime.now();
    }

    return CommentModel(
      id: doc.id,
      postId: data['postId'] ?? '',
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? '',
      text: data['text'] ?? '',
      reComments: (data['reComments'] ?? '') as String,
      likesCount: data['likesCount'] ?? 0,
      likedBy: List<String>.from(data['likedBy'] ?? []),
      createdAt: createdAt,
      isSecret: data['isSecret'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'postId': postId,
      'userId': userId,
      'userName': userName,
      'text': text,
      'reComments': reComments,
      'likesCount': likesCount,
      'likedBy': likedBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'isSecret': isSecret,
    };
  }
}
