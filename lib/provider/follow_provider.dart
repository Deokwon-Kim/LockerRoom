import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:lockerroom/model/user_model.dart';
import 'package:lockerroom/repository/user_repository.dart';

class FollowProvider extends ChangeNotifier {
  final UserRepository _repository;
  final String currentUserId;

  FollowProvider(this._repository, this.currentUserId);

  bool _isFollowing = false;
  bool get isFollowing => _isFollowing;

  String _userSearchQuery = '';
  String get userSearchQuery => _userSearchQuery;

  Set<String> _blockedUserIds = <String>{};

  void setUserSearchQuery(String query) {
    _userSearchQuery = query.trim().toLowerCase();
    notifyListeners();
  }

  void setBlockedUsers(Set<String> ids) {
    _blockedUserIds = ids;
    notifyListeners();
  }

  List<UserModel> filterUsers(List<UserModel> users) {
    var filtered = users;

    // 차단된 사용자 필터링
    filtered = filtered.where((u) => !_blockedUserIds.contains(u.uid)).toList();

    // 검색어 필터링
    if (_userSearchQuery.isEmpty) return filtered;
    return filtered
        .where((u) => (u.userNickName).toLowerCase().contains(_userSearchQuery))
        .toList();
  }

  final Map<String, bool> _followingByUserId = {};
  bool isFollowingUser(String targetUserId) =>
      _followingByUserId[targetUserId] ?? false;

  Future<void> loadFollowingStatus(String targetUserId) async {
    final v = await _repository.isFollowing(currentUserId, targetUserId);
    _followingByUserId[targetUserId] = v;
    notifyListeners();
  }

  Future<void> toggleFollow(String targetUserId) async {
    final now = isFollowingUser(targetUserId);
    if (now) {
      await _repository.unfollowUser(currentUserId, targetUserId);
      _followingByUserId[targetUserId] = false;
    } else {
      await _repository.followUser(currentUserId, targetUserId);
      _followingByUserId[targetUserId] = true;
    }
    notifyListeners();
  }

  Stream<int> getFollowersCountStream(String userId) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((doc) => (doc.data()?['followersCount'] ?? 0) as int);
  }

  Stream<int> getFollowCountStream(String userId) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((doc) => (doc.data()?['followingCount'] ?? 0) as int);
  }

  Future<List<UserModel>> _fetchUsersByIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    final List<List<String>> chunks = [];
    for (int i = 0; i < ids.length; i += 10) {
      chunks.add(ids.sublist(i, i + 10 > ids.length ? ids.length : i + 10));
    }

    final results = await Future.wait(
      chunks.map(
        (chunks) => FirebaseFirestore.instance
            .collection('users')
            .where('uid', whereIn: chunks)
            .get(),
      ),
    );

    return results
        .expand((q) => q.docs.map((d) => UserModel.fromDoc(d)))
        .toList();
  }

  Stream<List<UserModel>> followersUsers(String userId) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('followers')
        .snapshots()
        .asyncMap((snap) async {
          final ids = snap.docs.map((d) => d.id).toList();
          return _fetchUsersByIds(ids);
        });
  }

  Stream<List<UserModel>> followingUsers(String userId) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('following')
        .snapshots()
        .asyncMap((snap) async {
          final ids = snap.docs.map((d) => d.id).toList();
          return _fetchUsersByIds(ids);
        });
  }
}
