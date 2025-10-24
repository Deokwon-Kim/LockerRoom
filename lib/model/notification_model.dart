import 'package:cloud_firestore/cloud_firestore.dart';

class AppNotification {
  final String id;
  final String type;
  final String fromUserId;
  final String userName;
  final DateTime? createdAt;
  final bool isRead;

  AppNotification({
    required this.id,
    required this.type,
    required this.fromUserId,
    required this.userName,
    required this.createdAt,
    required this.isRead,
  });

  factory AppNotification.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return AppNotification(
      id: doc.id,
      type: data['type'] ?? 'unknown',
      fromUserId: data['fromUserId'] ?? '',
      userName: data['userName'] ?? '',
      createdAt: data['createdAt'] == null
          ? DateTime.now()
          : (data['createdAt'] as Timestamp).toDate(),
      isRead: (data['isRead'] ?? false) as bool,
    );
  }
}
