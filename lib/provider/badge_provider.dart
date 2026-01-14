import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:lockerroom/model/badge_model.dart';
import 'package:lockerroom/model/quiz_result_model.dart';
import 'package:lockerroom/page/quiz/quiz_data.dart';

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
      description: '20문제 연속 정답',
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
      description: '밤 11시 이후에\n 퀴즈 참여',
      icon: Icons.nightlight_round,
      isLocked: true,
    ),

    // 2. 실력 & 기록
    BadgeModel(
      id: 'perfect_game',
      name: '퍼펙트 게임',
      description: '30문제 연속 정답',
      icon: Icons.stars,
      isLocked: true,
    ),
    BadgeModel(
      id: 'clutch_hitter',
      name: '해결사',
      description: '난이도 [상] 문제\n 50회 정답',
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
    BadgeModel(
      id: 'cheer_captain',
      name: '응원 단장',
      description: '[응원가] 카테고리\n 50문제 정답',
      icon: Icons.campaign,
      isLocked: true,
    ),
    BadgeModel(
      id: 'sing_along_master',
      name: '떼창 유발자',
      description: '[응원가] 카테고리\n 100문제 정답',
      icon: Icons.mic,
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
          final isViewed = data['isViewed'] ?? true;

          return badge.copyWith(
            isLocked: false,
            acquiredAt: acquiredAt,
            isViewed: isViewed,
          );
        }
        return badge;
      }).toList();

      notifyListeners();
    } catch (e) {
      print('뱃지 로드 실패: $e');
    }
  }

  Future<void> markBadgeAsViewed(String badgeId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('badges')
          .doc(badgeId)
          .set({'isViewed': true}, SetOptions(merge: true));

      final index = _badges.indexWhere((b) => b.id == badgeId);
      if (index != -1) {
        _badges[index] = _badges[index].copyWith(isViewed: true);
        notifyListeners();
      }
    } catch (e) {
      print('뱃지 확인 표시 실패: $e');
    }
  }

  // 미확인 뱃지 목록 가져오기
  List<BadgeModel> get unviewedBadges =>
      _badges.where((b) => !b.isLocked && !b.isViewed).toList();

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
            'isViewed': false,
          });

      // 2. 로컬 상태 업데이트
      _badges[index] = _badges[index].copyWith(
        isLocked: false,
        acquiredAt: DateTime.now(),
        isViewed: false,
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
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    // 유저의 현재 총 누적 점수 가져오기
    int currentTotalScore = 0;
    try {
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

    // [조건 4] 출석왕: 7일 연속 퀴즈 참여
    try {
      final lastQuizDateTimestamp =
          userDoc.data()?['lastQuizDate'] as Timestamp?;
      int quizStreak = userDoc.data()?['quizStreak'] ?? 0;

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      // 마지막 참여 날짜 확인
      DateTime? lastDate;
      if (lastQuizDateTimestamp != null) {
        final d = lastQuizDateTimestamp.toDate();
        lastDate = DateTime(d.year, d.month, d.day);
      }

      int newQuizStreak = 1; // 기본값 (오늘 처음)

      if (lastDate != null) {
        final difference = today.difference(lastDate).inDays;
        if (difference == 0) {
          // 오늘 이미 참여함 -> 스트릭 유지
          newQuizStreak = quizStreak;
        } else if (difference == 1) {
          // 어제 참여함 -> 스트릭 증가
          newQuizStreak = quizStreak + 1;
        } else {
          // 연속 끊김 -> 1부터 시작
          newQuizStreak = 1;
        }
      } else {
        // 기록 없음 -> 1부터 시작
        newQuizStreak = 1;
      }

      // DB 업데이트 (스트릭이 변했거나, 날짜가 바뀌었을 때)
      if (lastDate != today || newQuizStreak != quizStreak) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({
              'lastQuizDate': FieldValue.serverTimestamp(),
              'quizStreak': newQuizStreak,
            });

        // 7일 연속 달성 체크
        if (newQuizStreak >= 7) {
          if (_isLocked('attendance_king')) {
            await unlockBadge('attendance_king');
            newBadges.add('출석왕');
          }
        }
      }
    } catch (e) {
      print('출석왕 체크 실패: $e');
    }

    // [조건 2] 퍼펙트 게임 30문제 연속 정답 (오답없이 스트릭 유지)
    int currentStreak = 0;
    try {
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

    // [조건 3-1] 해결사: 난이도 'hard' 50회 정답
    try {
      int highDifficultyCorrectCount = 0;
      final allQuestions = QuizData.getAllQuestions().values
          .expand((x) => x)
          .toList();

      for (final qId in result.questionIds) {
        // 문제 찾기
        final question = allQuestions.firstWhere(
          (q) => q.quizId == qId,
          orElse: () => allQuestions.first,
        ); // orElse는 에러 방지용 더미

        // 난이도가 hard이고 정답을 맞췄는지 확인
        if (question.quizId == qId && question.difficulty == 'hard') {
          if (result.answerResults[qId] == true) {
            highDifficultyCorrectCount++;
          }
        }
      }

      if (highDifficultyCorrectCount > 0) {
        int totalHighDifficulty =
            userDoc.data()?['totalHighDifficultyCorrect'] ?? 0;
        int newTotalHigh = totalHighDifficulty + highDifficultyCorrectCount;

        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({'totalHighDifficultyCorrect': newTotalHigh});

        if (newTotalHigh >= 50) {
          if (_isLocked('clutch_hitter')) {
            await unlockBadge('clutch_hitter');
            newBadges.add('해결사');
          }
        }
      }
    } catch (e) {
      print('해결사 뱃지 체크 실패: $e');
    }

    // [조건 7] 홈런왕 20문제 연속 정답 시

    try {
      currentStreak = userDoc.data()?['consecutiveCorrectCount'] ?? 0;
    } catch (_) {}

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

    // 20문제 이상 연속 정답이면 뱃지 획득
    if (newStreak >= 20) {
      if (_isLocked('homerun_king')) {
        await unlockBadge('homerun_king');
        newBadges.add('홈런왕');
      }
    }

    // [조건 8] 야구 백과사전: 누적 정답 100개
    int currentTotalCorrect = 0;
    try {
      currentTotalCorrect = userDoc.data()?['totalCorrectAnswers'] ?? 0;
    } catch (_) {}

    // 이번 퀴즈의 정답 수를 합산
    int newTotalCorrect = currentTotalCorrect + result.correctAnswers;

    // Firestore 업데이트
    FirebaseFirestore.instance.collection('users').doc(user.uid).update({
      'totalCorrectAnswers': newTotalCorrect,
    });

    if (newTotalCorrect >= 100) {
      if (_isLocked('quiz_master')) {
        await unlockBadge('quiz_master');
        newBadges.add('야구 백과사전');
      }
    }

    // [조건 9] 카테고리별 누적 정답 수 체크
    // 1. 현재 카테고리의 기존 누적 정답 수 가져오기
    Map<String, dynamic> existingCategoryStatus = {};
    try {
      existingCategoryStatus = userDoc.data()?['existingCategoryStatus'] ?? {};
    } catch (_) {}

    int currentCategoryCorrect = existingCategoryStatus[result.category] ?? 0;

    // 2. 이번 퀴즈 정답 수 더하기
    int newCategoryCorrect = currentCategoryCorrect + result.correctAnswers;

    // 3. Firestore 업데이트
    FirebaseFirestore.instance.collection('users').doc(user.uid).update({
      'existingCategoryStatus.${result.category}': newCategoryCorrect,
    });

    // 4. 뱃지 조건 체크
    String? targetBadgeId;
    if (result.category == 'KBO역사') targetBadgeId = 'history_buff'; // 역사 선생님
    if (result.category == '야구룰') targetBadgeId = 'rule_master'; // 심판장
    if (result.category == '기록') targetBadgeId = 'record_breaker'; // 기록 제조기
    if (result.category == '응원가') targetBadgeId = 'cheer_captain'; // 응원단장

    if (targetBadgeId != null && newCategoryCorrect >= 50) {
      if (_isLocked(targetBadgeId)) {
        await unlockBadge(targetBadgeId);

        final badgeName = _badges.firstWhere((b) => b.id == targetBadgeId).name;
        newBadges.add(badgeName);
      }
    }

    // [조건 9-1] 떼창 유발자: [응원가] 카테고리 100문제 정답
    if (result.category == '응원가' && newCategoryCorrect >= 100) {
      if (_isLocked('sing_along_master')) {
        await unlockBadge('sing_along_master');
        newBadges.add('떼창 유발자');
      }
    }

    return newBadges;
  }

  // 기존 유저 대상 뱃지 소급 적용
  Future<void> grantRetroactiveBadges() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      print('=== 소급 뱃지 체크 시작 ===');

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (!userDoc.exists) return;
      final data = userDoc.data()!;

      // 퀴즈 기록 전체 조회
      final quizResult = await FirebaseFirestore.instance
          .collection('quiz_results')
          .doc(user.uid)
          .collection('results')
          .get();
      print('총 퀴즈 기록 수: ${quizResult.docs.length}');

      // 퀴즈 기록에서 집계 데이터 계산
      int totalCorrect = 0;
      int totalScore = 0;
      int totalHighDifficultyCorrect = 0;
      Map<String, int> categoryCorrect = {};

      for (var doc in quizResult.docs) {
        final result = doc.data();

        // 정답 수 누적
        final correctAnswers = result['correctAnswers'] ?? 0;
        totalCorrect += correctAnswers as int;

        // 점수 누적
        final score = result['score'] ?? 0;
        totalScore += score as int;

        // 카테고리별 정답 누적
        final category = result['category'] ?? '';
        if (category.isNotEmpty) {
          categoryCorrect[category] =
              (categoryCorrect[category] ?? 0) + correctAnswers;
        }

        // 난이도 상 문제 정답 수 개선
        final questionIds = List<String>.from(result['questionIds'] ?? []);
        final answerResults = Map<String, dynamic>.from(
          result['answerResults'] ?? {},
        );

        final allQuestions = QuizData.getAllQuestions().values
            .expand((x) => x)
            .toList();

        for (final qId in questionIds) {
          final question = allQuestions.firstWhere(
            (q) => q.quizId == qId,
            orElse: () => allQuestions.first,
          );

          if (question.quizId == qId &&
              question.difficulty == 'hard' &&
              answerResults[qId] == true) {
            totalHighDifficultyCorrect++;
          }
        }
      }

      print('계산된 총 정답 수: $totalCorrect');
      print('계산된 총 점수: $totalScore');
      print('계산된 난이도 상 정답: $totalHighDifficultyCorrect');
      print('카테고리별 정답: $categoryCorrect');

      // Firestore 필드가 없으면 개선된 값 사용, 있으면 기존 값 사용
      totalCorrect = data['totalCorrectAnswers'] ?? totalCorrect;
      totalScore = data['totalQuizScore'] ?? totalScore;
      totalHighDifficultyCorrect =
          data['totalHighDifficultyCorrect'] ?? totalHighDifficultyCorrect;

      final existingCategoryStatus =
          data['existingCategoryStatus'] as Map<String, dynamic>? ?? {};
      for (var entry in categoryCorrect.entries) {
        if (!existingCategoryStatus.containsKey(entry.key)) {
          existingCategoryStatus[entry.key] = entry.value;
        }
      }

      // 계산된 값으로 Firestroe 업데이트 (없는 필드인 경우)
      Map<String, dynamic> updateData = {};
      if (!data.containsKey('totalCorrectAnswers')) {
        updateData['totalCorrectAnswers'] = totalCorrect;
      }
      if (!data.containsKey('totalQuizScore')) {
        updateData['totalQuizScore'] = totalScore;
      }
      if (!data.containsKey('totalHighDifficultyCorrect')) {
        updateData['totalHighDifficultyCorrect'] = totalHighDifficultyCorrect;
      }
      if (!data.containsKey('existingCategoryStatus')) {
        updateData['existingCategoryStatus'] = existingCategoryStatus;
      }

      if (updateData.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update(updateData);
        print('누락된 필드 업데이트 완료: ${updateData.keys}');
      }

      // 1. 총 정답 수 체크 -> 야구 백과사전

      if (totalCorrect >= 100 && _isLocked('quiz_master')) {
        await unlockBadge('quiz_master');
        print('야구 백과사전 뱃지 소급 지급');
      }
      // 2. 난이도 상 정답 수 체크 -> 해결사

      if (totalHighDifficultyCorrect >= 50 && _isLocked('clutch_hitter')) {
        await unlockBadge('clutch_hitter');
        print('해결사 뱃지 소급 지급');
      }
      // 3. 공유 횟수 체크 -> 인플루언서
      final shareCount = data['shareCount'] ?? 0;
      if (shareCount >= 10 && _isLocked('influencer')) {
        await unlockBadge('influencer');
        print('인플루언서 뱃지 소급 지급');
      }
      // 4. 카테고리별 누적 정답 체크

      // KBO역사
      if ((existingCategoryStatus['KBO역사'] ?? 0) >= 50 &&
          _isLocked('history_buff')) {
        await unlockBadge('history_buff');
        print('역사 선생님 뱃지 소급 지급');
      }

      // 야구룰
      if ((existingCategoryStatus['야구룰'] ?? 0) >= 50 &&
          _isLocked('rule_master')) {
        await unlockBadge('rule_master');
        print('심판장 뱃지 소급 지급');
      }

      // 기록
      if ((existingCategoryStatus['기록'] ?? 0) >= 50 &&
          _isLocked('record_breaker')) {
        await unlockBadge('record_breaker');
        print('기록 제조기 뱃지 소급 지급');
      }

      // 응원가 50문제
      if ((existingCategoryStatus['응원가'] ?? 0) >= 50 &&
          _isLocked('cheer_captain')) {
        await unlockBadge('cheer_captain');
        print('응원 단장 뱃지 소급 지급');
      }

      // 응원가 100문제
      if ((existingCategoryStatus['응원가'] ?? 0) >= 100 &&
          _isLocked('sing_along_master')) {
        await unlockBadge('sing_along_master');
        print('떼창 유발자 뱃지 소급 지급');
      }
      // 5. 연속 정답 체크는 현재 스트릭으로만 판단 가능
      final consecutiveCorrect = data['consecutiveCorrectCount'] ?? 0;

      // 홈런왕 (20문제 연속)
      if (consecutiveCorrect >= 20 && _isLocked('homerun_king')) {
        await unlockBadge('homerun_king');
        print('홈런왕 뱃지 소급 지급');
      }

      // 퍼펙트 게임 (30문제 연속)
      if (consecutiveCorrect >= 30 && _isLocked('perfect_game')) {
        await unlockBadge('perfect_game');
        print('퍼펙트 게임 뱃지 소급 지급');
      }
      // 6. 총점 체크 -> 행운의 7
      if (totalScore >= 777 && _isLocked('lucky_seven')) {
        await unlockBadge('lucky_seven');
        print('행운의 7 뱃지 소급 지급');
      }
      // 7. 출석왕은 현재 스트릭으로만 판단
      final quizStreak = data['quizStreak'] ?? 0;
      if (quizStreak >= 7 && _isLocked('attendance_king')) {
        await unlockBadge('attendance_king');
        print('출석왕 뱃지 소급 지급');
      }
      print('=== 소급 뱃지 체크 완료 ===');
      // 소급 적용 로그 저장
      await FirebaseFirestore.instance
          .collection('badge_retroactive_logs')
          .doc(user.uid)
          .set({
            'userId': user.uid,
            'appliedAt': FieldValue.serverTimestamp(),
            'totalCorrect': totalCorrect,
            'totalScore': totalScore,
            'totalHighDifficultyCorrect': totalHighDifficultyCorrect,
            'categoryStatus': existingCategoryStatus,
            'badgesGranted': _badges
                .where((b) => !b.isLocked)
                .map((b) => b.id)
                .toList(),
          });
    } catch (e) {
      print('소급 뱃지 지급 실패: $e');
    }
  }

  bool _isLocked(String id) {
    final index = _badges.indexWhere((b) => b.id == id);
    return index != -1 && _badges[index].isLocked;
  }

  // 공유 횟수 증가 및 뱃지 체크
  Future<void> incrementShareCount() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final userRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid);

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snapshot = await transaction.get(userRef);

        if (!snapshot.exists) return;

        int currentShareCount = snapshot.data()?['shareCount'] ?? 0;
        int newShareCount = currentShareCount + 1;

        transaction.update(userRef, {'shareCount': newShareCount});

        // 10회 달성 시 뱃지 획득
        if (newShareCount >= 10) {
          // 트랜잭션 내에서 비동기 함수 호출(unlockBadge)은 지양하는 것이 좋으므로
          // 뱃지 획득 로직은 트랜잭션 밖에서 처리하거나, 직접 업데이트.
          // 여기서는 로컬 상태 확인 후 트랜잭션 완료 후 처리하도록 함.
        }
      });

      // 트랜잭션 후 최신 카운트 다시 조회 혹은 예측하여 뱃지 체크
      final snapshot = await userRef.get();
      int updatedCount = snapshot.data()?['shareCount'] ?? 0;

      if (updatedCount >= 10) {
        if (_isLocked('influencer')) {
          await unlockBadge('influencer');
        }
      }
    } catch (e) {
      print('공유 카운트 증가 실패: $e');
    }
  }
}
