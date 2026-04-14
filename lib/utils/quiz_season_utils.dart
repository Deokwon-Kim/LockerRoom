import 'package:lockerroom/utils/quiz_tier_utils.dart';

class QuizSeasonUtils {
  static const int seasonBufferDays = 3;

  // 현재 시각 기준 시즌 ID 생성 (운영 정책 반영)
  static String getCurrentSeasonId() {
    final now = DateTime.now();
    int year = now.year;
    int month = now.month;

    // 1. 2026년 3월 및 4월 예외 처리 (단일 시즌)
    if (year == 2026 && (month == 3 || month == 4)) {
      return '${year}_${month.toString().padLeft(2, '0')}';
    }

    // 2. 2026년 5월부터 보름(15일) 주기 적용
    if (year > 2026 || (year == 2026 && month >= 5)) {
      int period = now.day > 15 ? 2 : 1;
      return '${year}_${month.toString().padLeft(2, '0')}_$period';
    }

    // 기본값 (과거 데이터 호환용)
    return '${year}_${month.toString().padLeft(2, '0')}';
  }

  // 이전 시즌 ID 가져오기 (2026_04 최초 시작 정책 반영)
  static String? getPreviousSeasonId() {
    final now = DateTime.now();
    final currentSeasonId = getCurrentSeasonId();

    // --- 4월 런칭을 위한 완전한 초기화 스위치 ---
    // 현재가 4월 시즌이라면, 3월(이전) 데이터 정산이나 오버레이를 아예 띄우지 않음
    if (currentSeasonId == '2026_04') {
      return null;
    }

    // 2026년 5월 전반기인 경우 -> 이전 시즌은 2026년 4월 전체 시즌
    if (now.year == 2026 && now.month == 5 && now.day <= 15) {
      if (now.day <= seasonBufferDays) return '2026_04';
      return '2026_04';
    }

    // 일반적인 15일 주기 로직 (5월 이후)
    if (now.year > 2026 || (now.year == 2026 && now.month > 5)) {
      if (now.day <= 15) {
        if (now.day <= seasonBufferDays) {
          final prevMonthDate = DateTime(now.year, now.month - 1);
          // 이전 달이 2026년 4월이면 단일 시즌, 아니면 15일 주기
          if (prevMonthDate.year == 2026 && prevMonthDate.month == 4) return '2026_04';
          return '${prevMonthDate.year}_${prevMonthDate.month.toString().padLeft(2, '0')}_2';
        }
        final prevMonthDate = DateTime(now.year, now.month - 1);
        if (prevMonthDate.year == 2026 && prevMonthDate.month == 4) return '2026_04';
        return '${prevMonthDate.year}_${prevMonthDate.month.toString().padLeft(2, '0')}_2';
      } else {
        if (now.day <= 15 + seasonBufferDays) {
          return '${now.year}_${now.month.toString().padLeft(2, '0')}_1';
        }
        return '${now.year}_${now.month.toString().padLeft(2, '0')}_1';
      }
    }

    // 기본 한 달 주기 이전 시즌 계산
    final prevMonthDate = DateTime(now.year, now.month - 1);
    return '${prevMonthDate.year}_${prevMonthDate.month.toString().padLeft(2, '0')}';
  }

  static String getSeasonIdFromDate(DateTime date) {
    if (date.year == 2026 && (date.month == 3 || date.month == 4)) {
      return '${date.year}_${date.month.toString().padLeft(2, '0')}';
    }
    if (date.year > 2026 || (date.year == 2026 && date.month >= 5)) {
      int period = date.day > 15 ? 2 : 1;
      return '${date.year}_${date.month.toString().padLeft(2, '0')}_$period';
    }
    return '${date.year}_${date.month.toString().padLeft(2, '0')}';
  }

  static String getSeasonLabel(String seasonId) {
    final parts = seasonId.split('_');
    if (parts.length < 2) return seasonId;
    
    String label = '${parts[0]}년 ${int.parse(parts[1])}월';
    if (parts.length == 3) {
      label += parts[2] == '1' ? ' 전반기' : ' 후반기';
    }
    return '$label 시즌';
  }

  static String getTier(int score) {
    return QuizTierUtils.getTierName(score);
  }
}
