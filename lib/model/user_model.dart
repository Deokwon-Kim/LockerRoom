import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String username;
  final String useremail;
  final String uid;
  final String? profileImageUrl;
  final int followersCount;
  final int followingCount;

  UserModel({
    required this.username,
    required this.useremail,
    required this.uid,
    this.profileImageUrl,
    required this.followersCount,
    required this.followingCount,
  });

  factory UserModel.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      username: data['username'] ?? 'Unknown',
      useremail: data['email'] ?? 'Unknown',
      uid: data['uid'],
      profileImageUrl: data['profileImageUrl'] ?? '',
      followersCount: data['followersCount'] ?? 0,
      followingCount: data['followingCount'] ?? 0,
    );
  }
}
