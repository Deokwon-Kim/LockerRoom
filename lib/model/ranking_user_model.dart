class RankingUserModel {
  final int rank;
  final String userId;
  final String name;
  final int score;
  final int rankChange;
  final String? profileUrl;
  final DateTime completedAt;

  RankingUserModel({
    required this.rank,
    required this.userId,
    required this.name,
    required this.score,
    required this.rankChange,
    this.profileUrl,
    required this.completedAt,
  });

  RankingUserModel copyWith({
    int? rank,
    String? userId,
    String? name,
    int? score,
    int? rankChange,
    String? profileUrl,
    DateTime? completedAt,
  }) {
    return RankingUserModel(
      rank: rank ?? this.rank,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      score: score ?? this.score,
      rankChange: rankChange ?? this.rankChange,
      profileUrl: profileUrl ?? this.profileUrl,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}
