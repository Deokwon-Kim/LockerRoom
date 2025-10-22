import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class BlockProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subscription;
  final Set<String> _blockedUserIds = <String>{};

  Set<String> get blockedUserIds => _blockedUserIds;

  void listen(String currentUserId) {
    _subscription?.cancel();
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
  }

  bool isBlocked(String userId) => _blockedUserIds.contains(userId);

  Future<void> blockUser({
    required String currentUserId,
    required String targetUserId,
  }) async {
    if (currentUserId == targetUserId) return;
    await _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('blocked')
        .doc(targetUserId)
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
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void cancel() {
    _subscription?.cancel();
    _subscription = null;
  }
}
