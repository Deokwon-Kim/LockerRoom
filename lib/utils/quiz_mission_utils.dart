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

    // 고정된 시드로 난수 생성하여 매일 똑같은 조합이 나오도록 함 (옵션)
    // 여기서는 매일 고정 3개의 미션을 스케일링해서 제공하는 방식으로 구현
    
    // 미션 1: 플레이 횟수
    int targetPlay = 1 + (difficultyLevel / 2).floor(); // 1~3회
    int currentPlay = todayHistory.length;
    int rewardPlay = 30 + (difficultyLevel * 10);
    
    // 미션 2: 정답 개수
    int targetCorrect = 5 + (difficultyLevel * 5); // 5개 ~ 30개
    int currentCorrect = todayHistory.fold(0, (sum, item) => sum + item.correctAnswers);
    int rewardCorrect = 40 + (difficultyLevel * 15);

    // 미션 3: 누적 점수
    int targetScore = 150 + (difficultyLevel * 200); // 150점 ~ 1150점
    int currentScore = todayHistory.fold(0, (sum, item) => sum + item.score);
    int rewardScore = 50 + (difficultyLevel * 20);

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
}
