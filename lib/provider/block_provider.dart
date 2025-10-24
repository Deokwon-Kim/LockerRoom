import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:lockerroom/repository/user_repository.dart';

class BlockProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final UserRepository _userRepository;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _blockedBySubscription;
  final Set<String> _blockedUserIds = <String>{};
  final Set<String> _blockedByUserIds = <String>{};

  Set<String> get blockedUserIds => _blockedUserIds;
  Set<String> get blockedByUserIds => _blockedByUserIds;

  BlockProvider(this._userRepository);

  void listen(String currentUserId) {
    _subscription?.cancel();
    _blockedBySubscription?.cancel();

    // 내가 차단한 사용자 목록
    _subscription = _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('blocked')
        .snapshots()
        .listen((snapshot) {
          _blockedUserIds
            ..clear()
            ..addAll(snapshot.docs.map((doc) => doc.id));
          notifyListeners();
        });

    // 나를 차단한 사용자 목록
    _blockedBySubscription = _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('blockedBy')
        .snapshots()
        .listen((snapshot) {
          _blockedByUserIds
            ..clear()
            ..addAll(snapshot.docs.map((doc) => doc.id));
          notifyListeners();
        });
  }

  bool isBlocked(String userId) => _blockedUserIds.contains(userId);

  bool isBlockedBy(String userId) => _blockedByUserIds.contains(userId);

  Future<bool> isBlockedByAsync(
    String currentUserId,
    String targetUserId,
  ) async {
    final doc = await _firestore
        .collection('users')
        .doc(targetUserId)
        .collection('blocked')
        .doc(currentUserId)
        .get();
    return doc.exists;
  }

  Stream<bool> getBlockedByStream(String currentUserId, String targetUserId) {
    return _firestore
        .collection('users')
        .doc(targetUserId)
        .collection('blocked')
        .doc(currentUserId)
        .snapshots()
        .map((doc) => doc.exists);
  }

  Future<void> blockUser({
    required String currentUserId,
    required String targetUserId,
  }) async {
    if (currentUserId == targetUserId) return;

    // 먼저 팔로우를 해제 (내가 상대를 팔로우하고 있으면)
    final isFollowing = await _userRepository.isFollowing(
      currentUserId,
      targetUserId,
    );
    if (isFollowing) {
      await _userRepository.unfollowUser(currentUserId, targetUserId);
    }

    // 상대가 나를 팔로우하고 있으면 언팔로우 처리
    final isFollowedByTarget = await _userRepository.isFollowing(
      targetUserId,
      currentUserId,
    );
    if (isFollowedByTarget) {
      // 내 팔로워 수가 0 이상일 때만 언팔로우
      final currentUserDoc = await _firestore
          .collection('users')
          .doc(currentUserId)
          .get();
      final followersCount =
          currentUserDoc.data()?['followersCount'] as int? ?? 0;

      if (followersCount > 0) {
        await _userRepository.unfollowUser(targetUserId, currentUserId);
      }
    }

    // 양방향 차단 저장
    await _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('blocked')
        .doc(targetUserId)
        .set({'blockedAt': FieldValue.serverTimestamp()});

    // 상대방의 blockedBy 컬렉션에도 추가
    await _firestore
        .collection('users')
        .doc(targetUserId)
        .collection('blockedBy')
        .doc(currentUserId)
        .set({'blockedAt': FieldValue.serverTimestamp()});
  }

  Future<void> unblockUser({
    required String currentUserId,
    required String targetUserId,
  }) async {
    await _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('blocked')
        .doc(targetUserId)
        .delete();

    // 상대방의 blockedBy 컬렉션에서도 삭제
    await _firestore
        .collection('users')
        .doc(targetUserId)
        .collection('blockedBy')
        .doc(currentUserId)
        .delete();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _blockedBySubscription?.cancel();
    super.dispose();
  }

  void cancel() {
    _subscription?.cancel();
    _blockedBySubscription?.cancel();
    _subscription = null;
    _blockedBySubscription = null;
  }
}
