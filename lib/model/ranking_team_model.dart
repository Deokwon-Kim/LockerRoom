class RankingTeamModel {
  final int rank;
  final String teamName;
  final int totalScore;
  final int rankChange;

  RankingTeamModel({
    required this.rank,
    required this.teamName,
    required this.totalScore,
    required this.rankChange,
  });

  RankingTeamModel copyWith({
    int? rank,
    String? teamName,
    int? totalScore,
    int? rankChange,
  }) {
    return RankingTeamModel(
      rank: rank ?? this.rank,
      teamName: teamName ?? this.teamName,
      totalScore: totalScore ?? this.totalScore,
      rankChange: rankChange ?? this.rankChange,
    );
  }
}
