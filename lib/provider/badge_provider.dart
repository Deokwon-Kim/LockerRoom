import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:lockerroom/model/badge_model.dart';
import 'package:lockerroom/model/quiz_result_model.dart';

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
    if (userId.isEmpty) return;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('badges')
          .get();

      // 내 획득 뱃지 ID 목록
      final unlockedIds = snapshot.docs.map((doc) => doc.id).toList();

      // 로컬 _badges 상태 업데이트
      _badges = _badges.map((badge) {
        if (unlockedIds.contains(badge.id)) {
          // Firestore에 저장된 획득 시간 가져오기 (없으면 현재 시간)
          final data = snapshot.docs
              .firstWhere((doc) => doc.id == badge.id)
              .data();
          final acquiredAt =
              (data['acquiredAt'] as Timestamp?)?.toDate() ?? DateTime.now();

          return badge.copyWith(isLocked: false, acquiredAt: acquiredAt);
        }
        return badge;
      }).toList();

      notifyListeners();
    } catch (e) {
      print('뱃지 로드 실패: $e');
    }
  }

  // Firestore 뱃지 잠금 해제 및 저장
  Future<void> unlockBadge(String badgeId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final index = _badges.indexWhere((b) => b.id == badgeId);
    // 이미 획득했거나 없는 뱃지면 패스
    if (index == -1 || !_badges[index].isLocked) return;

    try {
      // 1. Firestore에 저장
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('badges')
          .doc(badgeId)
          .set({
            'id': badgeId,
            'name': _badges[index].name,
            'acquiredAt': FieldValue.serverTimestamp(),
          });

      // 2. 로컬 상태 업데이트
      _badges[index] = _badges[index].copyWith(
        isLocked: false,
        acquiredAt: DateTime.now(),
      );
      notifyListeners();

      print('뱃지 획득 성공: ${_badges[index].name}');
    } catch (e) {
      print('뱃지 저장 실패: $e');
    }
  }

  // 퀴즈 결과에 따른 뱃지 체크 로직
  Future<List<String>> checkQuizBadges(QuizResultModel result) async {
    List<String> newBadges = [];
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];

    // 유저의 현재 총 누적 점수 가져오기
    int currentTotalScore = 0;
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      currentTotalScore = userDoc.data()?['totalQuizScore'] ?? 0;
    } catch (e) {
      print('총점 조회 실패: $e');
    }

    // [조건 1] 첫 안타 (0점 초과시)
    if (result.score > 0) {
      if (_isLocked('first_hit')) {
        await unlockBadge('first_hit');
        newBadges.add('첫 안타');
      }
    }

    // [조건 2] 퍼펙트 게임 30문제 연속 정답 (오답없이 스트릭 유지)
    int currentStreak = 0;
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      currentStreak = userDoc.data()?['consecutiveCorrectCount'] ?? 0;
    } catch (_) {}

    int newStreak = 0;

    // 이번 퀴즈에서 오답이 없었는지 확인
    if (result.score == 100) {
      newStreak = currentStreak + result.totalQuestions;
    } else {
      // 하나라도 틀렸으면 스트릭 초기화
      newStreak = 0;
    }

    // 변경 된 스트릭 정보 저장
    FirebaseFirestore.instance.collection('users').doc(user.uid).update({
      'consecutiveCorrectCount': newStreak,
    });

    // 30문제 이상 연속 정답이면 뱃지 획득
    if (newStreak >= 30) {
      if (_isLocked('perfect_game')) {
        await unlockBadge('perfect_game');
        newBadges.add('퍼펙트 게임');
      }
    }

    // [조건 3] 누적점수 777점이면 '행운의 7'
    if (currentTotalScore >= 777) {
      if (_isLocked('lucky_seven')) {
        await unlockBadge('lucky_seven');
        newBadges.add('행운의 7');
      }
    }
    // [조건 4] 카테고리별 마스터 (80점 이상)
    if (result.score >= 80) {
      String? badgeId;
      if (result.category == 'KBO역사') badgeId = 'history_buff';
      if (result.category == '야구룰') badgeId = 'rule_master';
      if (result.category == '기록') badgeId = 'record_breaker';
      if (badgeId != null && _isLocked(badgeId)) {
        await unlockBadge(badgeId);
        // 뱃지 이름 찾기
        final name = _badges.firstWhere((b) => b.id == badgeId).name;
        newBadges.add(name);
      }
    }

    final now = DateTime.now();
    final hour = now.hour;

    // [조건 5] 얼리버드: 아침 9시 이전 (06:00 ~ 08: 59)
    if (hour >= 6 && hour < 9) {
      if (_isLocked('early_bird')) {
        await unlockBadge('early_bird');
        newBadges.add('얼리버드');
      }
    }

    // [조건 6] 야간 자율학습: 밤 11시 ~ 새벽 3시 59분
    if (hour >= 23 || hour < 4) {
      if (_isLocked('night_owl')) {
        await unlockBadge('night_owl');
        newBadges.add('야간 자율학습');
      }
    }

    return newBadges;
  }

  bool _isLocked(String id) {
    final index = _badges.indexWhere((b) => b.id == id);
    return index != -1 && _badges[index].isLocked;
  }
}
