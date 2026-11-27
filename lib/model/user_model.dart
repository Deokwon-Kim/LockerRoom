import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lockerroom/model/mate_checklist_model.dart';

class UserModel {
  final String userNickName;
  final String name;
  final String useremail;
  final String uid;
  final String? profileImage;
  final int followersCount;
  final int followingCount;
  final Map<String, bool> mutedMeetups;
  final bool isNotificationsEnabled;
  final int? birthYear;
  final MateChecklistModel? mateChecklist;

  UserModel({
    required this.userNickName,
    required this.name,
    required this.useremail,
    required this.uid,
    this.profileImage,
    required this.followersCount,
    required this.followingCount,
    this.mutedMeetups = const {},
    this.isNotificationsEnabled = true,
    this.birthYear,
    this.mateChecklist,
  });

  factory UserModel.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final userNickName = data['userNickName'] ?? 'Unknown';
    final name = data['name'] ?? ''; // name이 없으면 username 사용
    final rawChecklist = data['mateChecklist'];
    return UserModel(
      userNickName: userNickName,
      name: name,
      useremail: data['email'] ?? 'Unknown',
      uid: data['uid'] ?? 'Unknown',
      profileImage: data['profileImage'] ?? '',
      followersCount: data['followersCount'] ?? 0,
      followingCount: data['followingCount'] ?? 0,
      mutedMeetups: Map<String, bool>.from(data['mutedMeetups'] ?? {}),
      isNotificationsEnabled: data['isNotificationsEnabled'] ?? true,
      birthYear: data['birthYear'] == null
          ? null
          : (data['birthYear'] as num).toInt(),
      mateChecklist: rawChecklist is Map<String, dynamic>
          ? MateChecklistModel.fromMap(rawChecklist)
          : null,
    );
  }
}
