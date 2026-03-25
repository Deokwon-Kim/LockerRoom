class QuizSeasonUtils {
  // 현재시각 기준 시즌 ID 생성
  static String getCurrentSeasonId() {
    final now = DateTime.now();
    return '${now.year}_${now.month.toString().padLeft(2, '0')}';
  }

  // 특정 날짜 기준 시즌 ID 생성
  static String getSeasonIdFromDate(DateTime date) {
    return '${date.year}_${date.month.toString().padLeft(2, '0')}';
  }

  // 사용자에게 보여줄 시즌 명칭
  static String getSeasonLabel(String seasonId) {
    final parts = seasonId.split('_');
    if (parts.length != 2) return seasonId;
    return '${parts[0]}년 ${parts[1]}월 시즌';
  }
}
