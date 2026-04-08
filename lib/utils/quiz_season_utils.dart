class QuizSeasonUtils {
  // 시즌 종료일 (매달 5일 종료로 설정 / QA용)
  static const int seasonEndDay = 7;

  // 현재시각 기준 시즌 ID 생성
  static String getCurrentSeasonId() {
    final now = DateTime.now();
    // 만약 오늘 날짜가 시즌 종료일(6일)을 지났다면 다음 달 시즌으로 간주
    if (now.day > seasonEndDay) {
      final nextMonth = DateTime(now.year, now.month + 1);
      return '${nextMonth.year}_${nextMonth.month.toString().padLeft(2, '0')}';
    }
    return '${now.year}_${now.month.toString().padLeft(2, '0')}';
  }

  // 이전 시즌 ID 가져오기 (결과창 조회용)
  static String getPreviousSeasonId() {
    final now = DateTime.now();
    final prevMonth = DateTime(now.year, now.month - 1);
    if (now.day > seasonEndDay) {
      // 이미 종료일을 지났다면 현재 월이 종료된 시즌임
      return '${now.year}_${now.month.toString().padLeft(2, '0')}';
    }
    return '${prevMonth.year}_${prevMonth.month.toString().padLeft(2, '0')}';
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

  // 점수 기반 티어 명칭 반환
  static String getTier(int score) {
    if (score >= 3000) return 'MVP';
    if (score >= 1500) return 'ALL-STAR';
    if (score >= 700) return 'MAJOR';
    if (score >= 200) return 'MINOR';
    return 'PROSPECT';
  }
}
