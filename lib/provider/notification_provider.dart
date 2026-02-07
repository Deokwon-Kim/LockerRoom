import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:lockerroom/model/notification_model.dart';
import 'package:toastification/toastification.dart';
import 'package:lockerroom/services/navigation_service.dart';
import 'package:lockerroom/model/post_model.dart';
import 'package:lockerroom/page/feed/feed_detail_page.dart';
import 'package:lockerroom/model/meetup_model.dart';
import 'package:lockerroom/page/meetup/meetup_detail_page.dart';

class NotificationProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;

  List<AppNotification> _notifications = [];
  List<AppNotification> get notifications => _notifications;
  bool isLoading = true;
  int get unreadCount => _notifications.where((n) => !n.isRead).length;
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

  Future<void> markAllAsRead(String userId) async {
    try {
      // 로컬 리스트가 아니라 Firestore에서 직접 조회
      final snapshot = await _firestore
          .collection('notifications')
          .where('toUserId', isEqualTo: userId)
          .where('isRead', isEqualTo: false) // 읽지 않은 것만
          .get();

      if (snapshot.docs.isEmpty) return;

      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.update(doc.reference, {'isRead': true});
      }

      await batch.commit();

      // 로컬 리스트도 업데이트 (Stream이 업데이트하기 전에)
      _notifications = _notifications.map((n) {
        if (!n.isRead) {
          return AppNotification(
            id: n.id,
            type: n.type,
            fromUserId: n.fromUserId,
            userNickName: n.userNickName,
            createdAt: n.createdAt,
            isRead: true,
            postId: n.postId,
            commentId: n.commentId,
            preview: n.preview,
          );
        }
        return n;
      }).toList();

      notifyListeners();
    } catch (e) {
      debugPrint('모든 알림 읽음 처리 오류: $e');
    }
  }

  Future<void> deleteNotification(String notificationId) async {
    try {
      await _firestore.collection('notifications').doc(notificationId).delete();
    } catch (e) {
      rethrow;
    }
  }

  Future<String> fetchUserName(String userId) async {
    if (_userNameCache.containsKey(userId)) {
      return _userNameCache[userId]!;
    }
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      final data = doc.data();
      final userNickName = (data?['userNickName'] as String?)?.trim();
      final result = (userNickName == null || userNickName.isEmpty)
          ? '알 수 없음'
          : userNickName;
      _userNameCache[userId] = result;
      return result;
    } catch (_) {
      return '알 수 없음';
    }
  }

  void _showNotificationToast(AppNotification notification) async {
    // 사용자 이름 가져오기 (캐시에서 먼저 확인)
    String userNickName = notification.userNickName;
    if (userNickName.isEmpty) {
      userNickName = await fetchUserName(notification.fromUserId);
    }

    String title = '';
    String description = '';
    ToastificationType type = ToastificationType.info;
    IconData icon = Icons.notifications;

    switch (notification.type) {
      case 'follow':
        title = '새 팔로워';
        description = userNickName != '알 수 없음'
            ? '$userNickName 회원님을 팔로우했습니다'
            : '누군가 회원님을 팔로우했습니다';
        type = ToastificationType.success;
        icon = Icons.person_add;
        break;
      case 'feedLike':
        title = '좋아요';
        description = userNickName != '알 수 없음'
            ? '$userNickName님이 회원님의 게시글을 좋아합니다'
            : '회원님의 게시글에 좋아요가 추가되었습니다';
        type = ToastificationType.info;
        icon = Icons.favorite;
        break;
      case 'commentLike':
        title = '댓글 좋아요';
        description = userNickName != '알 수 없음'
            ? '$userNickName님이 회원님의 댓글을 좋아합니다'
            : '회원님의 댓글에 좋아요가 추가되었습니다';
        type = ToastificationType.info;
        icon = Icons.favorite;
        break;
      case 'comment':
        title = '새 댓글';
        description = userNickName != '알 수 없음'
            ? '$userNickName님이 회원님의 게시글에 댓글을 남겼습니다'
            : '회원님의 게시글에 새 댓글이 달렸습니다';
        type = ToastificationType.info;
        icon = Icons.comment;
        break;
      case 'marketComment':
        title = '마켓 댓글';
        description = userNickName != '알 수 없음'
            ? '$userNickName님이 회원님의 마켓 게시글에 댓글을 남겼습니다'
            : '회원님의 마켓 게시글에 새 댓글이 달렸습니다';
        type = ToastificationType.info;
        icon = Icons.comment;
        break;
      case 'meetup_request':
        title = '모임 참여 신청';
        description = userNickName != '알 수 없음'
            ? '$userNickName님이 모임 참여를 신청했습니다'
            : '회원님의 모임에 새로운 참여 신청이 도착했습니다';
        type = ToastificationType.info;
        icon = Icons.person_add;
        break;
      case 'meetup_approved':
        title = '모임 참여 승인';
        description = '신청하신 모임 참여가 승인되었습니다!';
        type = ToastificationType.success;
        icon = Icons.check_circle;
        break;
      case 'meetup_rejected':
        title = '모임 참여 거절';
        description = '신청하신 모임 참여가 거절되었습니다.';
        type = ToastificationType.error;
        icon = Icons.cancel;
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
      notification: notification,
    );
  }

  void _showToastMessage({
    required String title,
    required String description,
    required ToastificationType type,
    required IconData icon,
    required AppNotification notification,
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
        callbacks: ToastificationCallbacks(
          onTap: (toastItem) => _onNotificationTap(context, notification),
        ),
      );
    }
  }

  Future<void> _onNotificationTap(
    BuildContext context,
    AppNotification n,
  ) async {
    final isFeedLike = n.type == 'feedLike';
    final isComment = n.type == 'comment';
    final commentLike = n.type == 'commentLike';

    if (n.postId != null) {
      if (isFeedLike || isComment) {
        try {
          final postDoc = await _firestore
              .collection('posts')
              .doc(n.postId)
              .get();

          if (postDoc.exists) {
            final post = PostModel.fromDoc(postDoc);
            if (!context.mounted) return;
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => FeedDetailPage(post: post),
              ),
            );
          } else {
            if (!context.mounted) return;
            toastification.show(
              context: context,
              type: ToastificationType.error,
              alignment: Alignment.bottomCenter,
              autoCloseDuration: Duration(seconds: 2),
              title: Text('게시물을 찾을 수 없습니다'),
            );
          }
        } catch (e) {
          if (!context.mounted) return;
          toastification.show(
            context: context,
            type: ToastificationType.error,
            alignment: Alignment.bottomCenter,
            autoCloseDuration: Duration(seconds: 2),
            title: Text('오류가 발생했습니다'),
          );
        }
      }
    } else if (commentLike && n.commentId != null) {
      // 댓글 좋아요 -> 댓글 -> 게시물
      try {
        final commentDoc = await _firestore
            .collection('comments')
            .doc(n.commentId)
            .get();

        if (commentDoc.exists) {
          final commentPostId = commentDoc.data()?['postId'] as String?;
          if (commentPostId != null) {
            final postDoc = await _firestore
                .collection('posts')
                .doc(commentPostId)
                .get();

            if (postDoc.exists) {
              final post = PostModel.fromDoc(postDoc);
              if (!context.mounted) return;
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => FeedDetailPage(post: post),
                ),
              );
            }
          }
        } else {
          if (!context.mounted) return;
          toastification.show(
            context: context,
            type: ToastificationType.error,
            alignment: Alignment.bottomCenter,
            autoCloseDuration: Duration(seconds: 2),
            title: Text('댓글을 찾을 수 없습니다'),
          );
        }
      } catch (e) {
        if (!context.mounted) return;
        toastification.show(
          context: context,
          type: ToastificationType.error,
          alignment: Alignment.bottomCenter,
          autoCloseDuration: Duration(seconds: 2),
          title: Text('오류가 발생했습니다'),
        );
      }
    } else if (n.type == 'meetup_request' ||
        n.type == 'meetup_approved' ||
        n.type == 'meetup_rejected') {
      // 모임 관련 알림 처리
      final meetupId = n.meetupId;
      if (meetupId != null) {
        try {
          final meetupDoc = await _firestore
              .collection('meetups')
              .doc(meetupId)
              .get();
          if (meetupDoc.exists) {
            final meetup = MeetupModel.fromFirestore(meetupDoc);
            if (!context.mounted) return;
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => MeetupDetailPage(meetup: meetup),
              ),
            );
          }
        } catch (e) {
          debugPrint('모임 이동 오류: $e');
        }
      }
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
