import 'package:cloud_firestore/cloud_firestore.dart';

class MeetupModel {
  final String id;
  final String userId;
  final String userNickName;
  final String? userProfileImage;
  final String title;
  final String content;
  final String gameDate;
  final String gameTime;
  final String stadium;
  final String homeTeam;
  final String awayTeam;
  final String myTeam;
  final String? announcement;
  final String? announcementId;
  final String? announcementAuthorId;
  final DateTime? announcementCreatedAt;
  final int maxParticipants;
  final List<String> participants;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final int viewCount;
  final int commentCount;
  final List<String> images;
  final List<String> attendedParticipants;
  final String? lastMessage;
  final String? lastMessageAt;

  // 공지사항 메시지 ID (announcementId 필드를 사용)
  String? get noticeMessageId => announcementId;

  MeetupModel({
    required this.id,
    required this.userId,
    required this.userNickName,
    this.userProfileImage,
    required this.title,
    required this.content,
    required this.gameDate,
    required this.gameTime,
    required this.stadium,
    required this.homeTeam,
    required this.awayTeam,
    required this.myTeam,
    this.maxParticipants = 10,
    this.participants = const [],
    required this.createdAt,
    this.updatedAt,
    this.viewCount = 0,
    this.commentCount = 0,
    this.images = const [],
    this.attendedParticipants = const [],
    this.announcement,
    this.announcementId,
    this.announcementAuthorId,
    this.announcementCreatedAt,
    this.lastMessage,
    this.lastMessageAt,
  });

  factory MeetupModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MeetupModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      userNickName: data['userNickName'] ?? '',
      userProfileImage: data['userProfileImage'],
      title: data['title'] ?? '',
      content: data['content'] ?? '',
      gameDate: data['gameDate'] ?? '',
      gameTime: data['gameTime'] ?? '',
      stadium: data['stadium'] ?? '',
      homeTeam: data['homeTeam'] ?? '',
      awayTeam: data['awayTeam'] ?? '',
      myTeam: data['myTeam'] ?? '',
      maxParticipants: data['maxParticipants'] ?? 10,
      participants: List<String>.from(data['participants'] ?? []),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      viewCount: data['viewCount'] ?? 0,
      commentCount: data['commentCount'] ?? 0,
      images: List<String>.from(data['images'] ?? []),
      attendedParticipants: List<String>.from(
        data['attendedParticipants'] ?? [],
      ),
      announcement: data['announcement'],
      announcementId: data['announcementId'],
      announcementAuthorId: data['announcementAuthorId'],
      announcementCreatedAt: (data['announcementCreatedAt'] as Timestamp?)
          ?.toDate(),
      lastMessage: data['lastMessage'],
      lastMessageAt: data['lastMessageAt'],
    );
  }
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'userNickName': userNickName,
      'userProfileImage': userProfileImage,
      'title': title,
      'content': content,
      'gameDate': gameDate,
      'gameTime': gameTime,
      'stadium': stadium,
      'homeTeam': homeTeam,
      'awayTeam': awayTeam,
      'myTeam': myTeam,
      'maxParticipants': maxParticipants,
      'participants': participants,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'viewCount': viewCount,
      'commentCount': commentCount,
      'images': images,
      'attendedParticipants': attendedParticipants,
      'announcement': announcement,
      'announcementId': announcementId,
      'announcementAuthorId': announcementAuthorId,
      'announcementCreatedAt': announcementCreatedAt != null
          ? Timestamp.fromDate(announcementCreatedAt!)
          : null,
      'lastMessage': lastMessage,
      'lastMessageAt': lastMessageAt,
    };
  }

  MeetupModel copyWith({
    String? id,
    String? userId,
    String? userNickName,
    String? userProfileImage,
    String? title,
    String? content,
    String? gameDate,
    String? gameTime,
    String? stadium,
    String? homeTeam,
    String? awayTeam,
    String? myTeam,
    String? announcement,
    String? announcementId,
    String? announcementAuthorId,
    DateTime? announcementCreatedAt,
    int? maxParticipants,
    List<String>? participants,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? viewCount,
    int? commentCount,
    List<String>? images,
    List<String>? attendedParticipants,
    String? lastMessage,
    String? lastMessageAt,
  }) {
    return MeetupModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userNickName: userNickName ?? this.userNickName,
      userProfileImage: userProfileImage ?? this.userProfileImage,
      title: title ?? this.title,
      content: content ?? this.content,
      gameDate: gameDate ?? this.gameDate,
      gameTime: gameTime ?? this.gameTime,
      stadium: stadium ?? this.stadium,
      homeTeam: homeTeam ?? this.homeTeam,
      awayTeam: awayTeam ?? this.awayTeam,
      myTeam: myTeam ?? this.myTeam,
      maxParticipants: maxParticipants ?? this.maxParticipants,
      participants: participants ?? this.participants,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      viewCount: viewCount ?? this.viewCount,
      commentCount: commentCount ?? this.commentCount,
      images: images ?? this.images,
      attendedParticipants: attendedParticipants ?? this.attendedParticipants,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
    );
  }

  bool get isFull => participants.length >= maxParticipants;
  int get remainingSlots => maxParticipants - participants.length;
}
