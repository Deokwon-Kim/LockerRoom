import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:lockerroom/model/notification_model.dart';
import 'package:toastification/toastification.dart';
import 'package:lockerroom/services/navigation_service.dart';

class NotificationProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;

  List<AppNotification> _notifications = [];
  List<AppNotification> get notifications => _notifications;
  bool isLoading = true;
  final Map<String, String> _userNameCache = {};

  void listen(String userId) {
    _sub?.cancel();
    isLoading = true;
    _notifications = [];
    notifyListeners();

    try {
      _sub = _firestore
          .collection('notifications')
          .where('toUserId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .listen(
            (snap) {
              final next = snap.docs
                  .map((d) {
                    try {
                      return AppNotification.fromDoc(d);
                    } catch (e) {
                      return null;
                    }
                  })
                  .whereType<AppNotification>()
                  .toList();

              // 새로 추가된 알림만 탐지
              if (_notifications.isNotEmpty &&
                  next.length > _notifications.length) {
                final newItems = next
                    .where((n) => _notifications.every((o) => o.id != n.id))
                    .toList();
                for (final n in newItems) {
                  _showNotificationToast(n);
                }
              }

              _notifications = next;
              isLoading = false;
              notifyListeners();
            },
            onError: (e) {
              isLoading = false;
              _notifications = [];
              notifyListeners();
            },
          );
    } catch (e) {
      // 인덱스가 없는 경우를 대비해 orderBy 없이 시도
      try {
        _sub = _firestore
            .collection('notifications')
            .where('toUserId', isEqualTo: userId)
            .snapshots()
            .listen(
              (snap) {
                final next = snap.docs
                    .map((d) {
                      try {
                        return AppNotification.fromDoc(d);
                      } catch (e) {
                        return null;
                      }
                    })
                    .whereType<AppNotification>()
                    .toList();

                // 메모리에서 정렬
                next.sort((a, b) {
                  final aTime = a.createdAt ?? DateTime(0);
                  final bTime = b.createdAt ?? DateTime(0);
                  return bTime.compareTo(aTime);
                });

                if (_notifications.isNotEmpty &&
                    next.length > _notifications.length) {
                  final newItems = next
                      .where((n) => _notifications.every((o) => o.id != n.id))
                      .toList();
                  for (final n in newItems) {
                    _showNotificationToast(n);
                  }
                }

                _notifications = next;
                isLoading = false;
                notifyListeners();
              },
              onError: (e) {
                isLoading = false;
                _notifications = [];
                notifyListeners();
              },
            );
      } catch (e2) {
        isLoading = false;
        _notifications = [];
        notifyListeners();
      }
    }
  }

  void cancel() {
    _sub?.cancel();
    _sub = null;
  }

  Future<void> markAsRead(String userId, String notificationId) async {
    await _firestore.collection('notifications').doc(notificationId).update({
      'isRead': true,
    });
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

  void _showNotificationToast(AppNotification notification) async {
    // 사용자 이름 가져오기 (캐시에서 먼저 확인)
    String userName = notification.userName;
    if (userName.isEmpty) {
      userName = await fetchUserName(notification.fromUserId);
    }

    String title = '';
    String description = '';
    ToastificationType type = ToastificationType.info;
    IconData icon = Icons.notifications;

    switch (notification.type) {
      case 'follow':
        title = '새 팔로워';
        description = userName != '알 수 없음'
            ? '$userName님이 회원님을 팔로우했습니다'
            : '누군가 회원님을 팔로우했습니다';
        type = ToastificationType.success;
        icon = Icons.person_add;
        break;
      case 'feedLike':
        title = '좋아요';
        description = userName != '알 수 없음'
            ? '$userName님이 회원님의 게시글을 좋아합니다'
            : '회원님의 게시글에 좋아요가 추가되었습니다';
        type = ToastificationType.info;
        icon = Icons.favorite;
        break;
      case 'commentLike':
        title = '댓글 좋아요';
        description = userName != '알 수 없음'
            ? '$userName님이 회원님의 댓글을 좋아합니다'
            : '회원님의 댓글에 좋아요가 추가되었습니다';
        type = ToastificationType.info;
        icon = Icons.favorite;
        break;
      case 'comment':
        title = '새 댓글';
        description = userName != '알 수 없음'
            ? '$userName님이 회원님의 게시글에 댓글을 남겼습니다'
            : '회원님의 게시글에 새 댓글이 달렸습니다';
        type = ToastificationType.info;
        icon = Icons.comment;
        break;
      case 'marketComment':
        title = '마켓 댓글';
        description = userName != '알 수 없음'
            ? '$userName님이 회원님의 마켓 게시글에 댓글을 남겼습니다'
            : '회원님의 마켓 게시글에 새 댓글이 달렸습니다';
        type = ToastificationType.info;
        icon = Icons.comment;
        break;
      default:
        title = '새 알림';
        description = '새로운 알림이 도착했습니다';
        type = ToastificationType.info;
        icon = Icons.notifications;
    }

    _showToastMessage(
      title: title,
      description: description,
      type: type,
      icon: icon,
    );
  }

  void _showToastMessage({
    required String title,
    required String description,
    required ToastificationType type,
    required IconData icon,
  }) {
    // navigatorKey를 통해 전역적으로 토스트 메시지 표시
    final context = navigatorKey.currentContext;
    if (context != null) {
      toastification.show(
        context: context,
        title: Text(title),
        description: Text(description),
        type: type,
        alignment: Alignment.topCenter,
        autoCloseDuration: const Duration(seconds: 3),
        icon: Icon(icon, color: Colors.white),
        style: ToastificationStyle.flat,
        showProgressBar: false,
      );
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
