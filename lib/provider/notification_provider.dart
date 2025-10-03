import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:lockerroom/model/notification_model.dart';
import 'package:lockerroom/services/notification_service.dart';

class NotificationProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;

  List<AppNotification> _notifications = [];
  List<AppNotification> get notifications => _notifications;
  bool isLoading = true;
  final Map<String, String> _userNameCache = {};

  void listen(String userId) {
    _sub?.cancel();
    _sub = _firestore
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen(
          (snap) {
            final next = snap.docs
                .map((d) => AppNotification.fromDoc(d))
                .toList();

            // 새로 추가된 알림만 탐지
            if (_notifications.isNotEmpty &&
                next.length > _notifications.length) {
              final newItems = next
                  .where((n) => _notifications.every((o) => o.id != n.id))
                  .toList();
              for (final n in newItems) {
                if (n.type == 'follow') {
                  NotificationService().showForegroundNotification(
                    title: '새 팔로워',
                    body: '누군가 당신을 팔로우했습니다',
                  );
                } else {
                  NotificationService().showForegroundNotification(
                    title: '알림',
                    body: '새로운 알림이 도착했습니다',
                  );
                }
              }
            }

            _notifications = next;
            isLoading = false;
            notifyListeners();
          },
          onError: (e) {
            isLoading = false;
            notifyListeners();
          },
        );
  }

  Future<void> markAsRead(String userId, String notificationId) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .doc(notificationId)
        .update({'isRead': true});
  }

  Future<String> fetchUserName(String userId) async {
    if (_userNameCache.containsKey(userId)) {
      return _userNameCache[userId]!;
    }
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      final data = doc.data();
      final name = (data?['username'] as String?)?.trim();
      final result = (name == null || name.isEmpty) ? '알 수 없음' : name;
      _userNameCache[userId] = result;
      return result;
    } catch (_) {
      return '알 수 없음';
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
