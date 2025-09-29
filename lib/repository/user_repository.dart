import 'package:cloud_firestore/cloud_firestore.dart';

class UserRepository {
  final _firestore = FirebaseFirestore.instance;

  Future<void> followUser(String currentUserId, String targetUserId) async {
    final batch = _firestore.batch();

    final currentUserRef = _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('following')
        .doc(targetUserId);

    final targetUserRef = _firestore
        .collection('users')
        .doc(targetUserId)
        .collection('followers')
        .doc(currentUserId);

    batch.set(currentUserRef, {'followedAt': FieldValue.serverTimestamp()});
    batch.set(targetUserRef, {'followedAt': FieldValue.serverTimestamp()});

    batch.update(_firestore.collection('users').doc(currentUserId), {
      'followingCount': FieldValue.increment(1),
    });
    batch.update(_firestore.collection('users').doc(targetUserId), {
      'followersCount': FieldValue.increment(1),
    });

    await batch.commit();
  }

  Future<void> unfollowUser(String currentUserId, String targetUserId) async {
    final batch = _firestore.batch();

    final currentUserRef = _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('following')
        .doc(targetUserId);

    final targetUserRef = _firestore
        .collection('users')
        .doc(targetUserId)
        .collection('followers')
        .doc(currentUserId);

    batch.delete(currentUserRef);
    batch.delete(targetUserRef);

    batch.update(_firestore.collection('users').doc(currentUserId), {
      'followingCount': FieldValue.increment(-1),
    });
    batch.update(_firestore.collection('users').doc(targetUserId), {
      'followersCount': FieldValue.increment(-1),
    });

    await batch.commit();
  }

  Future<bool> isFollowing(String currentUserId, String targetUserId) async {
    final doc = await _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('following')
        .doc(targetUserId)
        .get();

    return doc.exists;
  }
}
