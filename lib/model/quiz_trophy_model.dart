import 'package:cloud_firestore/cloud_firestore.dart';

enum TrophyType { individual, team }

class QuizTrophyModel {
  final String id;
  final String userId;
  final String seasonId;
  final String seasonLabel;
  final String userName;
  final String? teamName;
  final String? teamLogoUrl;
  final int score;
  final int? rank; // 순위 정보 추가
  final TrophyType type;
  final DateTime earnedAt;
  final double? seasonAvg;
  final int? totalHits;
  final int? totalAtBats;
  final int? maxCombo;
  final String? titleLabel;

  QuizTrophyModel({
    required this.id,
    required this.userId,
    required this.seasonId,
    required this.seasonLabel,
    required this.userName,
    this.teamName,
    this.teamLogoUrl,
    required this.score,
    this.rank,
    required this.type,
    required this.earnedAt,
    this.seasonAvg,
    this.totalHits,
    this.totalAtBats,
    this.maxCombo,
    this.titleLabel,
  });

  factory QuizTrophyModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return QuizTrophyModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      seasonId: data['seasonId'] ?? '',
      seasonLabel: data['seasonLabel'] ?? '',
      userName: data['userName'] ?? '',
      teamName: data['teamName'],
      teamLogoUrl: data['teamLogoUrl'],
      score: data['score'] ?? 0,
      rank: data['rank'],
      type: data['type'] == 'team' ? TrophyType.team : TrophyType.individual,
      earnedAt: (data['earnedAt'] as Timestamp).toDate(),
      seasonAvg: (data['seasonAvg'] as num?)?.toDouble(),
      totalHits: data['totalHits'] as int?,
      totalAtBats: data['totalAtBats'] as int?,
      maxCombo: data['maxCombo'] as int?,
      titleLabel: data['titleLabel'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'seasonId': seasonId,
      'seasonLabel': seasonLabel,
      'userName': userName,
      'teamName': teamName,
      'teamLogoUrl': teamLogoUrl,
      'score': score,
      'rank': rank,
      'type': type == TrophyType.team ? 'team' : 'individual',
      'earnedAt': Timestamp.fromDate(earnedAt),
      if (seasonAvg != null) 'seasonAvg': seasonAvg,
      if (totalHits != null) 'totalHits': totalHits,
      if (totalAtBats != null) 'totalAtBats': totalAtBats,
      if (maxCombo != null) 'maxCombo': maxCombo,
      if (titleLabel != null) 'titleLabel': titleLabel,
    };
  }
}
