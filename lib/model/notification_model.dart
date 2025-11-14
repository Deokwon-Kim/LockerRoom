import 'package:cloud_firestore/cloud_firestore.dart';

class AppNotification {
  final String id;
  final String type;
  final String fromUserId;
  final String userNickName;
  final DateTime? createdAt;
  final bool isRead;
  final String? postId;
  final String? commentId;
  final String? preview;

  AppNotification({
    required this.id,
    required this.type,
    required this.fromUserId,
    required this.userNickName,
    required this.createdAt,
    required this.isRead,
    this.postId,
    this.commentId,
    this.preview,
  });

  factory AppNotification.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return AppNotification(
      id: doc.id,
      type: data['type'] ?? 'unknown',
      fromUserId: data['fromUserId'] ?? '',
      userNickName: data['userNickName'] ?? '',
      createdAt: data['createdAt'] == null
          ? DateTime.now()
          : (data['createdAt'] as Timestamp).toDate(),
      isRead: (data['isRead'] ?? false) as bool,
      postId: data['postId'] as String?,
      commentId: data['commentId'] as String?,
      preview: data['preview'] as String?,
    );
  }
}
