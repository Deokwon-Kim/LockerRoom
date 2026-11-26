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
  final double? seasonAvg;
  final int? totalHits;
  final int? totalAtBats;

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
    this.seasonAvg,
    this.totalHits,
    this.totalAtBats,
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
    double? seasonAvg,
    int? totalHits,
    int? totalAtBats,
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
      seasonAvg: seasonAvg ?? this.seasonAvg,
      totalHits: totalHits ?? this.totalHits,
      totalAtBats: totalAtBats ?? this.totalAtBats,
    );
  }
}
