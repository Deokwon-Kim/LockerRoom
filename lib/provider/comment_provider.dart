import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:lockerroom/model/comment_model.dart';

class CommentProvider with ChangeNotifier {
  final _commentsCollection = FirebaseFirestore.instance.collection('comments');
  final _marketCommentsCollection = FirebaseFirestore.instance.collection(
    'marketComments',
  );
  final _seatViewCommentsCollection = FirebaseFirestore.instance.collection(
    'seat_view_comments',
  );
  final _attendanceCommentsCollection = FirebaseFirestore.instance.collection(
    'attendance_comments',
  );

  final Map<String, List<CommentModel>> _postComments = {};
  final Map<String, StreamSubscription> _subs = {};
  final Map<String, List<CommentModel>> _seatViewComments = {};
  final Map<String, StreamSubscription> _seatViewSubs = {};
  final Map<String, List<CommentModel>> _attendanceComments = {};
  final Map<String, StreamSubscription> _attendanceSubs = {};

  Set<String> _blockedUserIds = <String>{};
  Set<String> _blockedByUserIds = <String>{};

  List<CommentModel> getComments(String postId) {
    final comments = _postComments[postId] ?? [];
    return comments
        .where(
          (c) =>
              !_blockedUserIds.contains(c.userId) &&
              !_blockedByUserIds.contains(c.userId),
        )
        .toList();
  }

  void setBlockedUsers(Set<String> ids) {
    _blockedUserIds = ids;
    notifyListeners();
  }

  void setBlockedByUsers(Set<String> ids) {
    _blockedByUserIds = ids;
    notifyListeners();
  }

  void subscribeComments(String postId) {
    _subs[postId]?.cancel();
    _subs[postId] = _commentsCollection
        .where('postId', isEqualTo: postId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen(
          (snap) {
            _postComments[postId] = snap.docs
                .map((doc) => CommentModel.fromDoc(doc))
                .toList();
            notifyListeners();
          },
          onError: (e) {
            print('댓글 구독 에러: $e');
            // 에러 무시 (회원탈퇴 등으로 인한 permission-denied)
          },
        );
  }

  final Map<String, List<CommentModel>> _marketPostComments = {};
  final Map<String, StreamSubscription> _marketSubs = {};

  List<CommentModel> getMarketComments(String postId) {
    final comments = _marketPostComments[postId] ?? [];
    return comments
        .where(
          (c) =>
              !_blockedUserIds.contains(c.userId) &&
              !_blockedByUserIds.contains(c.userId),
        )
        .toList();
  }

  void subscribeMarketComments(String postId) {
    _marketSubs[postId]?.cancel();
    _marketSubs[postId] = _marketCommentsCollection
        .where('postId', isEqualTo: postId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen(
          (snap) {
            _marketPostComments[postId] = snap.docs
                .map((doc) => CommentModel.fromDoc(doc))
                .toList();
            notifyListeners();
          },
          onError: (e) {
            print('마켓 댓글 구독 에러: $e');
            // 에러 무시 (회원탈퇴 등으로 인한 permission-denied)
          },
        );
  }

  Future<void> addCommentAndNotify({
    required String postId,
    required CommentModel comment,
    required String currentUserId,
    required String postOwnerId,
    String? parentCommentOwnerId,
  }) async {
    // 댓글 생성
    final commentRef = await _commentsCollection.add({
      ...comment.toMap(),
      'postId': postId,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // 알림 대상 결정
    final targetUserId = (parentCommentOwnerId?.isNotEmpty ?? false)
        ? parentCommentOwnerId
        : postOwnerId;

    // 자기 자신이면 알림 스킵
    if (targetUserId == currentUserId) return;

    // 알림 내용 미리보기
    final preview = comment.text.length > 40
        ? '${comment.text.substring(0, 40)}...'
        : comment.text;

    // Firestore에 알림 문서 추가
    await FirebaseFirestore.instance.collection('notifications').add({
      'type': 'comment',
      'postId': postId,
      'commentId': commentRef.id,
      'fromUserId': currentUserId,
      'toUserId': targetUserId,
      'preview': preview,
      'createdAt': FieldValue.serverTimestamp(),
      'isRead': false,
    });
  }

  Future<void> addMarketCommentAndNotify({
    required String marketPostId,
    required CommentModel marketComment,
    required String currentUserId,
    required String marketPostOwnerId,
    String? parentMarketCommentOwnerId,
  }) async {
    // 댓글 생성
    final commentRef = await _marketCommentsCollection.add({
      ...marketComment.toMap(),
      'postId': marketPostId,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // 알림 대상 결정
    final targetUserId = (parentMarketCommentOwnerId?.isNotEmpty ?? false)
        ? parentMarketCommentOwnerId
        : marketPostOwnerId;

    // 자기 자신이면 알림 스킵
    if (targetUserId == currentUserId) return;

    // 알림 내용 미리보기
    final preview = marketComment.text.length > 40
        ? '${marketComment.text.substring(0, 40)}...'
        : marketComment.text;

    // Firestore에 알림 문서 추가
    await FirebaseFirestore.instance.collection('notifications').add({
      'type': 'marketComment',
      'postId': marketPostId,
      'commentId': commentRef.id,
      'fromUserId': currentUserId,
      'toUserId': targetUserId,
      'preview': preview,
      'createdAt': FieldValue.serverTimestamp(),
      'isRead': false,
    });
  }

  Future<void> commentLikeAndNotify({
    required String commentId,
    required CommentModel comment,
    required String currentUserId,
    required String commentOwnerId,
  }) async {
    // 댓글 좋아요 반영
    final docRef = _commentsCollection.doc(comment.id);
    final doc = await docRef.get();
    final data = doc.data()!;
    final likedBy = List<String>.from(data['likedBy'] ?? []);

    final wasLiked = likedBy.contains(currentUserId);

    if (wasLiked) {
      likedBy.remove(currentUserId);
    } else {
      likedBy.add(currentUserId);
    }

    await docRef.update({'likedBy': likedBy, 'likesCount': likedBy.length});

    // 좋아요 추가할 때만 알림 전송 (취소할 때는 알림 안 함)
    if (wasLiked) return;

    // 알림 대상 결정
    final targetUserId = commentOwnerId;

    // 댓글 작성자의 좋아요는 알림없음
    if (targetUserId == currentUserId) return;

    // 알림내용 미리보기
    final preview = comment.text.length > 40
        ? '${comment.text.substring(0, 40)}...'
        : comment.text;
    // Firestore에 알림 문서 추가
    await FirebaseFirestore.instance.collection('notifications').add({
      'type': 'commentLike',
      'commentId': commentId,
      'fromUserId': currentUserId,
      'toUserId': targetUserId,
      'preview': preview,
      'createdAt': FieldValue.serverTimestamp(),
      'isRead': false,
    });
  }

  void cancelSubscription(String postId) {
    _subs[postId]?.cancel();
  }

  void cancelAllSubscriptions() {
    for (final sub in _subs.values) {
      sub.cancel();
    }
    _subs.clear();
    _postComments.clear();
  }

  Future<void> deleteComment(CommentModel comment) async {
    await _commentsCollection.doc(comment.id).delete();
  }

  Future<void> deleteMarketComment(CommentModel comment) async {
    await _marketCommentsCollection.doc(comment.id).delete();
  }

  Future<void> deleteCommentCascade(CommentModel comment) async {
    // 트리 전체(부모/답글 포함)를 재귀적으로 삭제
    // 1) 현재 댓글의 모든 직계 자식을 가져와 먼저 삭제
    final repliesSnap = await _commentsCollection
        .where('postId', isEqualTo: comment.postId)
        .where('reComments', isEqualTo: comment.id)
        .get();

    for (final d in repliesSnap.docs) {
      // 자식 댓글도 하위가 있을 수 있으므로 재귀 호출
      final child = CommentModel.fromDoc(d);
      await deleteCommentCascade(child);
    }

    // 2) 마지막으로 현재 댓글 삭제
    await _commentsCollection.doc(comment.id).delete();
  }

  // 댓글 신고 기능
  Future<void> reportComment({
    required CommentModel comment,
    required String reporterUserId,
    required String reporterUserName,
    required String reason,
  }) async {
    await FirebaseFirestore.instance.collection('feed_comment_reports').add({
      'type': 'comment',
      'commentId': comment.id,
      'postId': comment.postId,
      'reportedUserId': comment.userId,
      'reportedUserName': comment.userName,
      'reporterUserId': reporterUserId,
      'reporterUserName': reporterUserName,
      'commentText': comment.text,
      'reason': reason,
      'createdAt': FieldValue.serverTimestamp(),
      'status': 'pending', // pending, reviewed, closed
    });

    // 알림 대상 결정
    final targetUserId = 'Wxi2XKOWJYQeCSD9eY9wunyew1U2';

    // Firestore에 알림문서 추가
    await FirebaseFirestore.instance.collection('notifications').add({
      'type': 'comment_report',
      'commentId': comment.id,
      'reportedUserId': comment.userId,
      'reportedUserName': comment.userName,
      'reporterUserId': reporterUserId,
      'reporterUserName': reporterUserName,
      'toUserId': targetUserId,
      'commentText': comment.text,
      'reason': reason,
      'createdAt': FieldValue.serverTimestamp(),
      'status': 'pending',
    });
  }

  // 마켓 댓글 신고 기능
  Future<void> reportMarketComment({
    required CommentModel comment,
    required String reporterUserId,
    required String reporterUserName,
    required String reason,
  }) async {
    await FirebaseFirestore.instance.collection('market_comment_reports').add({
      'type': 'market_comment',
      'commentId': comment.id,
      'postId': comment.postId,
      'reportedUserId': comment.userId,
      'reportedUserName': comment.userName,
      'reporterUserId': reporterUserId,
      'reporterUserName': reporterUserName,
      'commentText': comment.text,
      'reason': reason,
      'createdAt': FieldValue.serverTimestamp(),
      'status': 'pending', // pending, reviewed, closed
    });

    // 알림 대상 결정
    final targetUserId = 'Wxi2XKOWJYQeCSD9eY9wunyew1U2';

    // Firestore에 알림문서 추가
    await FirebaseFirestore.instance.collection('notifications').add({
      'type': 'market_comment_report',
      'commentId': comment.id,
      'reportedUserId': comment.userId,
      'reportedUserName': comment.userName,
      'reporterUserId': reporterUserId,
      'reporterUserName': reporterUserName,
      'toUserId': targetUserId,
      'commentText': comment.text,
      'reason': reason,
      'createdAt': FieldValue.serverTimestamp(),
      'status': 'pending',
    });
  }

  @override
  void dispose() {
    for (var sub in _subs.values) {
      sub.cancel();
    }
    for (var sub in _marketSubs.values) {
      sub.cancel();
    }
    for (var sub in _seatViewSubs.values) {
      sub.cancel();
    }
    for (var sub in _attendanceSubs.values) {
      sub.cancel();
    }
    super.dispose();
  }

  // ====== 좌석 시야 댓글 ======
  List<CommentModel> getSeatViewComments(String postId) {
    final comments = _seatViewComments[postId] ?? [];
    return comments
        .where(
          (c) =>
              !_blockedUserIds.contains(c.userId) &&
              !_blockedByUserIds.contains(c.userId),
        )
        .toList();
  }

  void subscribeSeatViewComments(String postId) {
    _seatViewSubs[postId]?.cancel();
    _seatViewSubs[postId] = _seatViewCommentsCollection
        .where('postId', isEqualTo: postId)
        .snapshots()
        .listen(
          (snap) {
            final list = snap.docs
                .map((doc) => CommentModel.fromDoc(doc))
                .toList()
              ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
            _seatViewComments[postId] = list;
            notifyListeners();
          },
          onError: (e) {
            debugPrint('좌석시야 댓글 구독 에러: $e');
          },
        );
  }

  void cancelSeatViewSubscription(String postId) {
    _seatViewSubs[postId]?.cancel();
    _seatViewSubs.remove(postId);
  }

  Future<void> addSeatViewCommentAndNotify({
    required String postId,
    required CommentModel comment,
    required String currentUserId,
    required String postOwnerId,
    String? parentCommentOwnerId,
  }) async {
    final commentRef = await _seatViewCommentsCollection.add({
      ...comment.toMap(),
      'postId': postId,
      'createdAt': FieldValue.serverTimestamp(),
    });

    final current = List<CommentModel>.from(_seatViewComments[postId] ?? []);
    if (!current.any((c) => c.id == commentRef.id)) {
      current.add(
        CommentModel(
          id: commentRef.id,
          postId: postId,
          userId: comment.userId,
          userName: comment.userName,
          text: comment.text,
          reComments: comment.reComments,
          createdAt: DateTime.now(),
        ),
      );
      _seatViewComments[postId] = current;
      notifyListeners();
    }

    await FirebaseFirestore.instance
        .collection('seat_views')
        .doc(postId)
        .update({'commentsCount': FieldValue.increment(1)});

    final targetUserId = (parentCommentOwnerId?.isNotEmpty ?? false)
        ? parentCommentOwnerId!
        : postOwnerId;

    if (targetUserId == currentUserId || targetUserId.isEmpty) return;

    final preview = comment.text.length > 40
        ? '${comment.text.substring(0, 40)}...'
        : comment.text;

    await FirebaseFirestore.instance.collection('notifications').add({
      'type': 'seatViewComment',
      'postId': postId,
      'commentId': commentRef.id,
      'fromUserId': currentUserId,
      'toUserId': targetUserId,
      'preview': preview,
      'createdAt': FieldValue.serverTimestamp(),
      'isRead': false,
    });
  }

  Future<void> deleteSeatViewComment({
    required String postId,
    required String commentId,
  }) async {
    await _seatViewCommentsCollection.doc(commentId).delete();
    await FirebaseFirestore.instance
        .collection('seat_views')
        .doc(postId)
        .update({'commentsCount': FieldValue.increment(-1)});
  }

  // ====== 직관기록 댓글 ======
  String attendancePostKey(String ownerUserId, String gameId) =>
      '${ownerUserId}_$gameId';

  List<CommentModel> getAttendanceComments(String ownerUserId, String gameId) {
    final key = attendancePostKey(ownerUserId, gameId);
    final comments = _attendanceComments[key] ?? [];
    return comments
        .where(
          (c) =>
              !_blockedUserIds.contains(c.userId) &&
              !_blockedByUserIds.contains(c.userId),
        )
        .toList();
  }

  void subscribeAttendanceComments(String ownerUserId, String gameId) {
    final key = attendancePostKey(ownerUserId, gameId);
    _attendanceSubs[key]?.cancel();
    _attendanceSubs[key] = _attendanceCommentsCollection
        .where('postId', isEqualTo: key)
        .snapshots()
        .listen(
          (snap) {
            final list = snap.docs
                .map((doc) => CommentModel.fromDoc(doc))
                .toList()
              ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
            _attendanceComments[key] = list;
            notifyListeners();
          },
          onError: (e) {
            debugPrint('직관기록 댓글 구독 에러: $e');
          },
        );
  }

  void cancelAttendanceSubscription(String ownerUserId, String gameId) {
    final key = attendancePostKey(ownerUserId, gameId);
    _attendanceSubs[key]?.cancel();
    _attendanceSubs.remove(key);
  }

  Future<void> addAttendanceCommentAndNotify({
    required String ownerUserId,
    required String gameId,
    required CommentModel comment,
    required String currentUserId,
    String? parentCommentOwnerId,
  }) async {
    final key = attendancePostKey(ownerUserId, gameId);
    final commentRef = await _attendanceCommentsCollection.add({
      ...comment.toMap(),
      'postId': key,
      'attendanceOwnerId': ownerUserId,
      'gameId': gameId,
      'createdAt': FieldValue.serverTimestamp(),
    });

    final current = List<CommentModel>.from(_attendanceComments[key] ?? []);
    if (!current.any((c) => c.id == commentRef.id)) {
      current.add(
        CommentModel(
          id: commentRef.id,
          postId: key,
          userId: comment.userId,
          userName: comment.userName,
          text: comment.text,
          reComments: comment.reComments,
          createdAt: DateTime.now(),
        ),
      );
      _attendanceComments[key] = current;
      notifyListeners();
    }

    await FirebaseFirestore.instance
        .collection('users')
        .doc(ownerUserId)
        .collection('attendances')
        .doc(gameId)
        .update({'commentsCount': FieldValue.increment(1)});

    final targetUserId = (parentCommentOwnerId?.isNotEmpty ?? false)
        ? parentCommentOwnerId!
        : ownerUserId;

    if (targetUserId == currentUserId || targetUserId.isEmpty) return;

    final preview = comment.text.length > 40
        ? '${comment.text.substring(0, 40)}...'
        : comment.text;

    await FirebaseFirestore.instance.collection('notifications').add({
      'type': 'attendanceComment',
      'postId': key,
      'ownerUserId': ownerUserId,
      'gameId': gameId,
      'commentId': commentRef.id,
      'fromUserId': currentUserId,
      'toUserId': targetUserId,
      'preview': preview,
      'createdAt': FieldValue.serverTimestamp(),
      'isRead': false,
    });
  }

  Future<void> deleteAttendanceComment({
    required String ownerUserId,
    required String gameId,
    required String commentId,
  }) async {
    await _attendanceCommentsCollection.doc(commentId).delete();
    await FirebaseFirestore.instance
        .collection('users')
        .doc(ownerUserId)
        .collection('attendances')
        .doc(gameId)
        .update({'commentsCount': FieldValue.increment(-1)});
  }
}
