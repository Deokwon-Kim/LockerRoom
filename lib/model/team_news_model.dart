enum NewsCategory { all, game, player, transfer }

extension NewsCategoryX on NewsCategory {
  String get label {
    switch (this) {
      case NewsCategory.all:
        return '전체';
      case NewsCategory.game:
        return '경기';
      case NewsCategory.player:
        return '선수·전력';
      case NewsCategory.transfer:
        return '이적·부상';
    }
  }
}

class TeamNewsModel {
  final String id;
  final String teamSymple;
  final String title;
  final String source;
  final String url;
  final DateTime publishedAt;
  final NewsCategory category;

  const TeamNewsModel({
    required this.id,
    required this.teamSymple,
    required this.title,
    required this.source,
    required this.url,
    required this.publishedAt,
    required this.category,
  });

  String get relativeTimeText {
    final diff = DateTime.now().difference(publishedAt);
    if (diff.inMinutes < 1) return '방금 전';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    if (diff.inDays < 7) return '${diff.inDays}일 전';
    return '${publishedAt.month}/${publishedAt.day}';
  }

  static NewsCategory classifyTitle(String title) {
    final t = title;
    const transferKeywords = [
      '트레이드',
      'FA',
      '부상',
      '말소',
      '콜업',
      '방출',
      '영입',
      '재계약',
      '은퇴',
      '수술',
      '재활',
      '이적',
      '복귀',
    ];
    for (final k in transferKeywords) {
      if (t.contains(k)) return NewsCategory.transfer;
    }

    const gameKeywords = [
      '승리',
      '패배',
      '역전',
      '홈런',
      '완봉',
      '완투',
      '시리즈',
      '결승타',
      '끝내기',
      '연승',
      '연패',
      '개막',
      '한국시리즈',
      '플레이오프',
      '준플레이오프',
      '승',
      '패',
    ];
    for (final k in gameKeywords) {
      if (t.contains(k)) return NewsCategory.game;
    }

    return NewsCategory.player;
  }
}
