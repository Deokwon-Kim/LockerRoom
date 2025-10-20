import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String username;
  final String name;
  final String useremail;
  final String uid;
  final String? profileImage;
  final int followersCount;
  final int followingCount;

  UserModel({
    required this.username,
    required this.name,
    required this.useremail,
    required this.uid,
    this.profileImage,
    required this.followersCount,
    required this.followingCount,
  });

  factory UserModel.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final username = data['username'] ?? 'Unknown';
    final name = data['name'] ?? ''; // name이 없으면 username 사용
    return UserModel(
      username: username,
      name: name,
      useremail: data['email'] ?? 'Unknown',
      uid: data['uid'],
      profileImage: data['profileImage'] ?? '',
      followersCount: data['followersCount'] ?? 0,
      followingCount: data['followingCount'] ?? 0,
    );
  }
}
