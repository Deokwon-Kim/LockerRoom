import 'package:cloud_firestore/cloud_firestore.dart';

class AppNotification {
  final String id;
  final String type;
  final String fromUserId;
  final Timestamp? createdAt;
  final bool isRead;

  AppNotification({
    required this.id,
    required this.type,
    required this.fromUserId,
    required this.createdAt,
    required this.isRead,
  });

  factory AppNotification.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return AppNotification(
      id: doc.id,
      type: data['type'] ?? 'unknown',
      fromUserId: data['fromUserId'] ?? '',
      createdAt: data['createdAt'],
      isRead: (data['isRead'] ?? false) as bool,
    );
  }
}

