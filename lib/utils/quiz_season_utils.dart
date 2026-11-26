import 'package:lockerroom/utils/quiz_tier_utils.dart';

class QuizSeasonUtils {
  static const int seasonBufferDays = 3;

  // 현재 시각 기준 시즌 ID 생성 (2026년 12월부터 월간 1시즌제 적용)
  static String getCurrentSeasonId() {
    final now = DateTime.now();
    return getSeasonIdFromDate(now);
  }

  // 이전 시즌 ID 가져오기 (2026_04 최초 시작 정책 반영)
  static String? getPreviousSeasonId() {
    final now = DateTime.now();
    final currentSeasonId = getCurrentSeasonId();

    // --- 4월 런칭을 위한 완전한 초기화 스위치 ---
    if (currentSeasonId == '2026_04') {
      return null;
    }

    // 2026년 5월 전반기인 경우 -> 배포 정책상 이전 시즌 노출 안 함
    if (now.year == 2026 && now.month == 5 && now.day <= 15) {
      return null;
    }

    // 2026년 12월부터 월간 1시즌제
    if (now.year > 2026 || (now.year == 2026 && now.month >= 12)) {
      if (now.year == 2026 && now.month == 12) {
        return '2026_11_2'; // 반기제 마지막 시즌과 연결
      }
      final prevMonthDate = DateTime(now.year, now.month - 1);
      return '${prevMonthDate.year}_${prevMonthDate.month.toString().padLeft(2, '0')}';
    }

    // 2026년 5월 ~ 11월 반기(15일) 주기 로직
    if (now.year == 2026 && now.month > 5) {
      if (now.day <= 15) {
        final prevMonthDate = DateTime(now.year, now.month - 1);
        if (prevMonthDate.year == 2026 && prevMonthDate.month == 4) {
          return '2026_04';
        }
        return '${prevMonthDate.year}_${prevMonthDate.month.toString().padLeft(2, '0')}_2';
      } else {
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
    if (date.year > 2026 || (date.year == 2026 && date.month >= 12)) {
      return '${date.year}_${date.month.toString().padLeft(2, '0')}';
    }
    if (date.year == 2026 && date.month >= 5) {
      int period = date.day > 15 ? 2 : 1;
      return '${date.year}_${date.month.toString().padLeft(2, '0')}_$period';
    }
    return '${date.year}_${date.month.toString().padLeft(2, '0')}';
  }

  static String getSeasonLabel(String seasonId) {
    final parts = seasonId.split('_');
    if (parts.length < 2) return seasonId;

    String label = '${parts[0]}년 ${int.tryParse(parts[1]) ?? parts[1]}월';
    if (parts.length == 3) {
      label += parts[2] == '1' ? ' 전반기' : ' 후반기';
    }
    return '$label 시즌';
  }

  static String getSeasonShortMonthLabel(String seasonId) {
    final parts = seasonId.split('_');
    if (parts.length < 2) return seasonId;
    final m = int.tryParse(parts[1]);
    return m != null ? '$m월' : parts[1];
  }

  static String getSeasonShortCode(String seasonId) {
    final parts = seasonId.split('_');
    if (parts.length < 2) return seasonId;
    final yy = parts[0].length >= 4 ? parts[0].substring(2) : parts[0];
    return '$yy.${parts[1]}';
  }

  static int getSeasonRemainingDays([DateTime? reference]) {
    final now = reference ?? DateTime.now();
    if (now.year == 2026 && now.month >= 5 && now.month <= 11 && now.day <= 15) {
      return (15 - now.day).clamp(0, 15);
    }
    final lastDay = DateTime(now.year, now.month + 1, 0).day;
    return (lastDay - now.day).clamp(0, lastDay);
  }

  static String getTier(int score) {
    return QuizTierUtils.getTierName(score);
  }
}
