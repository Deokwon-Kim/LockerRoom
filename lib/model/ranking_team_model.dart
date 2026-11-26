import 'package:lockerroom/model/quiz_result_model.dart';

class RankingTeamModel {
  final int rank;
  final String teamName;
  final int totalScore;
  final int rankChange;
  final int totalAtBats;
  final int totalHits;

  RankingTeamModel({
    required this.rank,
    required this.teamName,
    required this.totalScore,
    required this.rankChange,
    this.totalAtBats = 0,
    this.totalHits = 0,
  });

  double get battingAverage => totalAtBats > 0 ? totalHits / totalAtBats : 0.0;

  String get formattedBattingAverage =>
      QuizResultModel.formatBattingAverage(battingAverage, totalAtBats);

  RankingTeamModel copyWith({
    int? rank,
    String? teamName,
    int? totalScore,
    int? rankChange,
    int? totalAtBats,
    int? totalHits,
  }) {
    return RankingTeamModel(
      rank: rank ?? this.rank,
      teamName: teamName ?? this.teamName,
      totalScore: totalScore ?? this.totalScore,
      rankChange: rankChange ?? this.rankChange,
      totalAtBats: totalAtBats ?? this.totalAtBats,
      totalHits: totalHits ?? this.totalHits,
    );
  }
}
