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
  final TrophyType type;
  final DateTime earnedAt;

  QuizTrophyModel({
    required this.id,
    required this.userId,
    required this.seasonId,
    required this.seasonLabel,
    required this.userName,
    this.teamName,
    this.teamLogoUrl,
    required this.score,
    required this.type,
    required this.earnedAt,
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
      type: data['type'] == 'team' ? TrophyType.team : TrophyType.individual,
      earnedAt: (data['earnedAt'] as Timestamp).toDate(),
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
      'type': type == TrophyType.team ? 'team' : 'individual',
      'earnedAt': Timestamp.fromDate(earnedAt),
    };
  }
}
