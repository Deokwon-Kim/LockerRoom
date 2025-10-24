import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ViewService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // 조회수 증가
  static Future<void> incrementViewCount(String postId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final postRef = _firestore.collection('market_posts').doc(postId);

    await _firestore.runTransaction((transaction) async {
      final postDoc = await transaction.get(postRef);

      if (!postDoc.exists) return;

      final data = postDoc.data()!;
      final viewdBy = List<String>.from(data['viewdBy'] ?? []);

      // 이미 조회한 사용자가 아닌 경우에만 조회수 증가
      if (!viewdBy.contains(user.uid)) {
        viewdBy.add(user.uid);
        transaction.update(postRef, {
          'viewCount': FieldValue.increment(1),
          'viewdBy': viewdBy,
        });
      }
    });
  }

  // 조회수만 가져오기
  static Future<int> getViewCount(String postId) async {
    final doc = await _firestore.collection('market_posts').doc(postId).get();
    return doc.data()?['viewCount'] ?? 0;
  }
}
