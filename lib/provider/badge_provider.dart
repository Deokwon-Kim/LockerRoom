import 'package:flutter/material.dart';
import 'package:lockerroom/model/badge_model.dart';

class BadgeProvider extends ChangeNotifier {
  // 전체 뱃지 목록
  List<BadgeModel> _badges = [
    BadgeModel(
      id: 'first_hit',
      name: '첫 안타',
      description: '퀴즈 첫 정답',
      icon: Icons.sports_baseball,
      isLocked: true,
    ),
    BadgeModel(
      id: 'homerun_king',
      name: '홈런왕',
      description: '10문제 연속 정답',
      icon: Icons.whatshot,
      isLocked: true,
    ),
    BadgeModel(
      id: 'quiz_master',
      name: '야구 백과사전',
      description: '누적 100문제 정답',
      icon: Icons.auto_stories,
      isLocked: true,
    ),
    BadgeModel(
      id: 'attendance_king',
      name: '출석왕',
      description: '7일 연속 퀴즈 참여',
      icon: Icons.calendar_month,
      isLocked: true,
    ),
    // 1. 성실함 & 끈기
    BadgeModel(
      id: 'early_bird',
      name: '얼리버드',
      description: '아침 9시 이전에\n 퀴즈 참여',
      icon: Icons.wb_sunny,
      isLocked: true,
    ),
    BadgeModel(
      id: 'night_owl',
      name: '야간 자율학습',
      description: '밤 12시 이후에\n 퀴즈 참여',
      icon: Icons.nightlight_round,
      isLocked: true,
    ),

    // 2. 실력 & 기록
    BadgeModel(
      id: 'perfect_game',
      name: '퍼펙트 게임',
      description: '한 번도 틀리지 않고 30문제 연속 정답',
      icon: Icons.stars,
      isLocked: true,
    ),
    BadgeModel(
      id: 'clutch_hitter',
      name: '해결사',
      description: '난이도 [상] 문제\n 10회 정답',
      icon: Icons.flash_on,
      isLocked: true,
    ),
    BadgeModel(
      id: 'lucky_seven',
      name: '행운의 7',
      description: '총점 777점 달성',
      icon: Icons.casino,
      isLocked: true,
    ),

    // 3. 전문가 (특정 카테고리)
    BadgeModel(
      id: 'history_buff',
      name: '역사 선생님',
      description: '[KBO역사]카테고리\n50문제 정답',
      icon: Icons.history_edu,
      isLocked: true,
    ),
    BadgeModel(
      id: 'rule_master',
      name: '심판장',
      description: '[야구룰] 카테고리 50문제 정답',
      icon: Icons.gavel,
      isLocked: true,
    ),
    BadgeModel(
      id: 'record_breaker',
      name: '기록 제조기',
      description: '[기록] 카테고리\n 50문제 정답',
      icon: Icons.bar_chart,
      isLocked: true,
    ),

    // 4. 소셜 & 활동
    BadgeModel(
      id: 'influencer',
      name: '인플루언서',
      description: '퀴즈 결과 공유 10회',
      icon: Icons.share,
      isLocked: true,
    ),
  ];

  List<BadgeModel> get badges => _badges;

  // 내가 획득한 뱃지 개수
  int get unlockedCount => _badges.where((b) => !b.isLocked).length;

  // 데이터 로드 함수
  Future<void> fetchMyBadges(String userId) async {
    // TODO: Firestore에서 userId로 획득한 뱃지 ID 목록 가져오기

    // 더미: 2초 뒤 일부 뱃지 획득 처리
    await Future.delayed(const Duration(seconds: 1));

    final dummyUnlockedIds = ['first_hit']; // '첫 타석 안타'만 획득했다고 가정
    _badges = _badges.map((badge) {
      if (dummyUnlockedIds.contains(badge.id)) {
        return badge.copyWith(isLocked: false, acquiredAt: DateTime.now());
      }
      return badge;
    }).toList();

    notifyListeners();
  }
}
