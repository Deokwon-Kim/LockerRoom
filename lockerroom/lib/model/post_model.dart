import 'package:cloud_firestore/cloud_firestore.dart';

class PostModel {
  final String id;
  final String text;
  final List<String> mediaUrls;
  final String userId;
  final DateTime createdAt;
  final int likesCount;
  final String userName;
  final List<String> likedBy;

  PostModel({
    required this.id,
    required this.text,
    required this.mediaUrls,
    required this.userId,
    required this.createdAt,
    required this.likesCount,
    required this.userName,
    required this.likedBy,
  });

  factory PostModel.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PostModel(
      id: doc.id,
      text: data['text'] ?? "",
      mediaUrls: List<String>.from(data['mediaUrls'] ?? []),
      userId: data['userId'] ?? "",
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      likesCount: data['likesCount'] ?? 0,
      userName: data['userName'] ?? '사용자',
      likedBy: List<String>.from(data['likedBy'] ?? const []),
    );
  }
}
