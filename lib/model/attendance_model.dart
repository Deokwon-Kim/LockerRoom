import 'package:cloud_firestore/cloud_firestore.dart';

class AttendanceModel {
  final String gameId;
  final int season;
  final String date;
  final String time;
  final String stadium;
  final String homeTeam;
  final String awayTeam;
  final String myTeam;
  final String? oppTeam;
  final int myScore;
  final int opponentScore;
  final String? imageUrl;
  final String? memo;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  AttendanceModel({
    required this.gameId,
    required this.season,
    required this.date,
    required this.time,
    required this.stadium,
    required this.homeTeam,
    required this.awayTeam,
    required this.myTeam,
    this.oppTeam,
    required this.myScore,
    required this.opponentScore,
    this.imageUrl,
    this.memo,
    this.createdAt,
    this.updatedAt,
  });

  // Firestore DocumentSnapshot에서 모델로 변환
  factory AttendanceModel.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // 점수 안전하게 파싱 (int 또는 String 모두 처리)
    final int myScore = data['myScore'] is int
        ? data['myScore'] as int
        : int.tryParse('${data['myScore']}') ?? 0;

    final int opponentScore = data['opponentScore'] is int
        ? data['opponentScore'] as int
        : int.tryParse('${data['opponentScore']}') ?? 0;

    return AttendanceModel(
      gameId: data['gameId'] ?? '',
      season: data['season'] ?? 0,
      date: data['date'] ?? '',
      time: data['time'] ?? '',
      stadium: data['stadium'] ?? '',
      homeTeam: data['homeTeam'] ?? '',
      awayTeam: data['awayTeam'] ?? '',
      myTeam: data['myTeam'] ?? '',
      oppTeam: data['oppTeam'],
      myScore: myScore,
      opponentScore: opponentScore,
      imageUrl: data['imageUrl'],
      memo: data['memo'],
      createdAt: data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : null,
      updatedAt: data['updatedAt'] is Timestamp
          ? (data['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }

  // Map에서 모델로 변환 (직접 Map을 받을 때 사용)
  factory AttendanceModel.fromMap(Map<String, dynamic> data) {
    final int myScore = data['myScore'] is int
        ? data['myScore'] as int
        : int.tryParse('${data['myScore']}') ?? 0;

    final int opponentScore = data['opponentScore'] is int
        ? data['opponentScore'] as int
        : int.tryParse('${data['opponentScore']}') ?? 0;

    return AttendanceModel(
      gameId: data['gameId'] ?? '',
      season: data['season'] ?? 0,
      date: data['date'] ?? '',
      time: data['time'] ?? '',
      stadium: data['stadium'] ?? '',
      homeTeam: data['homeTeam'] ?? '',
      awayTeam: data['awayTeam'] ?? '',
      myTeam: data['myTeam'] ?? '',
      oppTeam: data['oppTeam'],
      myScore: myScore,
      opponentScore: opponentScore,
      imageUrl: data['imageUrl'],
      memo: data['memo'],
      createdAt: data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : null,
      updatedAt: data['updatedAt'] is Timestamp
          ? (data['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }

  // 모델을 Firestore Map으로 변환
  Map<String, dynamic> toMap() {
    return {
      'gameId': gameId,
      'season': season,
      'date': date,
      'time': time,
      'stadium': stadium,
      'homeTeam': homeTeam,
      'awayTeam': awayTeam,
      'myTeam': myTeam,
      if (oppTeam != null) 'oppTeam': oppTeam,
      'myScore': myScore,
      'opponentScore': opponentScore,
      if (imageUrl != null) 'imageUrl': imageUrl,
      if (memo != null && memo!.isNotEmpty) 'memo': memo,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  // copyWith 메서드 (선택사항, 필요시 사용)
  AttendanceModel copyWith({
    String? gameId,
    int? season,
    String? date,
    String? time,
    String? stadium,
    String? homeTeam,
    String? awayTeam,
    String? myTeam,
    String? oppTeam,
    int? myScore,
    int? opponentScore,
    String? imageUrl,
    String? memo,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AttendanceModel(
      gameId: gameId ?? this.gameId,
      season: season ?? this.season,
      date: date ?? this.date,
      time: time ?? this.time,
      stadium: stadium ?? this.stadium,
      homeTeam: homeTeam ?? this.homeTeam,
      awayTeam: awayTeam ?? this.awayTeam,
      myTeam: myTeam ?? this.myTeam,
      oppTeam: oppTeam ?? this.oppTeam,
      myScore: myScore ?? this.myScore,
      opponentScore: opponentScore ?? this.opponentScore,
      imageUrl: imageUrl ?? this.imageUrl,
      memo: memo ?? this.memo,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
