import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String username;
  final String useremail;
  final String uid;
  final String? profileImage;
  final int followersCount;
  final int followingCount;

  UserModel({
    required this.username,
    required this.useremail,
    required this.uid,
    this.profileImage,
    required this.followersCount,
    required this.followingCount,
  });

  factory UserModel.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      username: data['username'] ?? 'Unknown',
      useremail: data['email'] ?? 'Unknown',
      uid: data['uid'],
      profileImage: data['profileImage'] ?? '',
      followersCount: data['followersCount'] ?? 0,
      followingCount: data['followingCount'] ?? 0,
    );
  }
}
