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

  Future<void> loadFollowingStatus(String targetUserId) async {
    _isFollowing = await _repository.isFollowing(currentUserId, targetUserId);
    notifyListeners();
  }

  Future<void> toggleFollow(String targetUserId) async {
    if (_isFollowing) {
      await _repository.unfollowUser(currentUserId, targetUserId);
      _isFollowing = false;
    } else {
      await _repository.followUser(currentUserId, targetUserId);
      _isFollowing = true;
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

  Stream<List<UserModel>> followersUsers(String userId) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('followers')
        .snapshots()
        .asyncMap((snap) async {
          final ids = snap.docs.map((d) => d.id).toList();
          final users = await Future.wait(
            ids.map((id) async {
              final doc = await FirebaseFirestore.instance
                  .collection('users')
                  .doc(id)
                  .get();
              return UserModel.fromDoc(doc);
            }),
          );
          return users;
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
          final users = await Future.wait(
            ids.map((id) async {
              final doc = await FirebaseFirestore.instance
                  .collection('users')
                  .doc(id)
                  .get();
              return UserModel.fromDoc(doc);
            }),
          );
          return users;
        });
  }
}
