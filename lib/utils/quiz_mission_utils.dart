import 'dart:math';
import 'package:lockerroom/model/quiz_result_model.dart';
import 'package:lockerroom/utils/quiz_tier_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum MissionType { playCount, totalCorrect, totalScore }

class QuizMission {
  final String id;
  final MissionType type;
  final String title;
  final int targetValue;
  final int currentValue;
  final int rewardPts;
  final bool isClaimed;

  QuizMission({
    required this.id,
    required this.type,
    required this.title,
    required this.targetValue,
    required this.currentValue,
    required this.rewardPts,
    required this.isClaimed,
  });

  bool get isCompleted => currentValue >= targetValue;
}

class QuizMissionUtils {
  static List<QuizMission> getDailyMissions(
    String userId,
    int userTotalScore,
    List<QuizResultModel> history,
    SharedPreferences prefs,
  ) {
    final now = DateTime.now();
    final dateKey = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    
    // 오늘 완료한 퀴즈 기록만 필터링
    final todayHistory = history.where((result) {
      return result.completedAt.year == now.year &&
             result.completedAt.month == now.month &&
             result.completedAt.day == now.day;
    }).toList();

    // 현재 플레이어의 티어 기반으로 난이도 설정 (0: PROSPECT ~ 5: LEGEND)
    int difficultyLevel = 0;
    if (userTotalScore >= 10000) difficultyLevel = 5; // LEGEND
    else if (userTotalScore >= 5000) difficultyLevel = 4; // MVP
    else if (userTotalScore >= 2500) difficultyLevel = 3; // ALL-STAR
    else if (userTotalScore >= 1200) difficultyLevel = 2; // MAJOR
    else if (userTotalScore >= 400) difficultyLevel = 1; // MINOR

    // 당일 미션 목표치가 실시간으로 갱신되어 완료 후 진행도가 꼬이는 현상 방지를 위해 하루 동안 고정
    final targetPlayKey = '${userId}_target_play_$dateKey';
    final targetCorrectKey = '${userId}_target_correct_$dateKey';
    final targetScoreKey = '${userId}_target_score_$dateKey';
    
    int targetPlay = prefs.getInt(targetPlayKey) ?? (1 + (difficultyLevel / 2).floor());
    int rewardPlay = prefs.getInt('${targetPlayKey}_reward') ?? (30 + (difficultyLevel * 10));
    
    int targetCorrect = prefs.getInt(targetCorrectKey) ?? (5 + (difficultyLevel * 5));
    int rewardCorrect = prefs.getInt('${targetCorrectKey}_reward') ?? (40 + (difficultyLevel * 15));

    int targetScore = prefs.getInt(targetScoreKey) ?? (150 + (difficultyLevel * 200));
    int rewardScore = prefs.getInt('${targetScoreKey}_reward') ?? (50 + (difficultyLevel * 20));

    // 처음 생성된 날이면 로컬 저장소에 당일 목표치 캐싱 (이후 승격해도 당일은 목표 고정)
    if (!prefs.containsKey(targetPlayKey)) {
      prefs.setInt(targetPlayKey, targetPlay);
      prefs.setInt('${targetPlayKey}_reward', rewardPlay);
      prefs.setInt(targetCorrectKey, targetCorrect);
      prefs.setInt('${targetCorrectKey}_reward', rewardCorrect);
      prefs.setInt(targetScoreKey, targetScore);
      prefs.setInt('${targetScoreKey}_reward', rewardScore);
    }

    int currentPlay = todayHistory.length;
    int currentCorrect = todayHistory.fold(0, (sum, item) => sum + item.correctAnswers);
    int currentScore = todayHistory.fold(0, (sum, item) => sum + item.score);

    return [
      QuizMission(
        id: '${userId}_mission_${dateKey}_play',
        type: MissionType.playCount,
        title: '퀴즈 $targetPlay회 참여하기',
        targetValue: targetPlay,
        currentValue: currentPlay,
        rewardPts: rewardPlay,
        isClaimed: prefs.getBool('${userId}_mission_${dateKey}_play_claimed') ?? false,
      ),
      QuizMission(
        id: '${userId}_mission_${dateKey}_correct',
        type: MissionType.totalCorrect,
        title: '오늘 정답 $targetCorrect개 맞히기',
        targetValue: targetCorrect,
        currentValue: currentCorrect,
        rewardPts: rewardCorrect,
        isClaimed: prefs.getBool('${userId}_mission_${dateKey}_correct_claimed') ?? false,
      ),
      QuizMission(
        id: '${userId}_mission_${dateKey}_score',
        type: MissionType.totalScore,
        title: '오늘 누적 $targetScore점 획득',
        targetValue: targetScore,
        currentValue: currentScore,
        rewardPts: rewardScore,
        isClaimed: prefs.getBool('${userId}_mission_${dateKey}_score_claimed') ?? false,
      ),
    ];
  }

  // 개발/테스트용: 오늘 수령한 미션 상태 및 목표치 초기화
  static Future<void> resetDailyMissions(String userId, SharedPreferences prefs) async {
    final now = DateTime.now();
    final dateKey = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    
    // 수령 상태 초기화
    await prefs.remove('${userId}_mission_${dateKey}_play_claimed');
    await prefs.remove('${userId}_mission_${dateKey}_correct_claimed');
    await prefs.remove('${userId}_mission_${dateKey}_score_claimed');
    
    // 캐시된 당일 목표치 초기화 (난이도 재계산 용도)
    await prefs.remove('${userId}_target_play_$dateKey');
    await prefs.remove('${userId}_target_play_${dateKey}_reward');
    await prefs.remove('${userId}_target_correct_$dateKey');
    await prefs.remove('${userId}_target_correct_${dateKey}_reward');
    await prefs.remove('${userId}_target_score_$dateKey');
    await prefs.remove('${userId}_target_score_${dateKey}_reward');
  }
}
