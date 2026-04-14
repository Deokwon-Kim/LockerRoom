class RankingUserModel {
  final int rank;
  final String userId;
  final String name;
  final int score;
  final int rankChange;
  final String? profileUrl;
  final DateTime completedAt;

  final String? teamName;
  final String tier;

  RankingUserModel({
    required this.rank,
    required this.userId,
    required this.name,
    required this.score,
    required this.rankChange,
    this.profileUrl,
    required this.completedAt,
    this.teamName,
    required this.tier,
  });

  RankingUserModel copyWith({
    int? rank,
    String? userId,
    String? name,
    int? score,
    int? rankChange,
    String? profileUrl,
    DateTime? completedAt,
    String? teamName,
    String? tier,
  }) {
    return RankingUserModel(
      rank: rank ?? this.rank,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      score: score ?? this.score,
      rankChange: rankChange ?? this.rankChange,
      profileUrl: profileUrl ?? this.profileUrl,
      completedAt: completedAt ?? this.completedAt,
      teamName: teamName ?? this.teamName,
      tier: tier ?? this.tier,
    );
  }
}
