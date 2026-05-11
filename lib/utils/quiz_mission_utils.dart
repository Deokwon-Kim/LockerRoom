import 'dart:math';
import 'package:lockerroom/model/quiz_result_model.dart';
import 'package:lockerroom/utils/quiz_tier_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum MissionType {
  playCount, // 퀴즈 참여 횟수
  totalCorrect, // 누적 정답 개수
  totalScore, // 누적 점수
  perfectGame, // 만점(10/10) 달성 횟수
  highscoreGame, // 한 판에서 특정 점수 이상 달성
}

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
    final dateKey =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';

    // 오늘 완료한 퀴즈 기록만 필터링
    final todayHistory = history.where((result) {
      return result.completedAt.year == now.year &&
          result.completedAt.month == now.month &&
          result.completedAt.day == now.day;
    }).toList();

    // 현재 플레이어의 티어 기반으로 난이도 설정 (0: PROSPECT ~ 5: LEGEND)
    int difficultyLevel = 0;
    if (userTotalScore >= 10000)
      difficultyLevel = 5; // LEGEND
    else if (userTotalScore >= 5000)
      difficultyLevel = 4; // MVP
    else if (userTotalScore >= 2500)
      difficultyLevel = 3; // ALL-STAR
    else if (userTotalScore >= 1200)
      difficultyLevel = 2; // MAJOR
    else if (userTotalScore >= 400)
      difficultyLevel = 1; // MINOR

    // 1. 오늘의 미션 3개 랜덤 선정 (사용자별/날짜별 고유 시드)
    final random = Random(userId.hashCode ^ dateKey.hashCode);
    final allTypes = List<MissionType>.from(MissionType.values);
    allTypes.shuffle(random);
    final selectedTypes = allTypes.take(3).toList();

    return selectedTypes.map((type) {
      String missionId = '';
      String title = '';
      int target = 0;
      int current = 0;
      int reward = 0;
      String typeSuffix = '';

      switch (type) {
        case MissionType.playCount:
          typeSuffix = 'play';
          target =
              prefs.getInt('${userId}_target_play_$dateKey') ??
              (1 + (difficultyLevel / 2).floor());
          reward =
              prefs.getInt('${userId}_target_play_${dateKey}_reward') ??
              (30 + (difficultyLevel * 10));
          current = todayHistory.length;
          title = '퀴즈 $target회 참여하기';
          break;

        case MissionType.totalCorrect:
          typeSuffix = 'correct';
          target =
              prefs.getInt('${userId}_target_correct_$dateKey') ??
              (5 + (difficultyLevel * 5));
          reward =
              prefs.getInt('${userId}_target_correct_${dateKey}_reward') ??
              (40 + (difficultyLevel * 15));
          current = todayHistory.fold(
            0,
            (sum, item) => sum + item.correctAnswers,
          );
          title = '오늘 정답 $target개 맞히기';
          break;

        case MissionType.totalScore:
          typeSuffix = 'score';
          // 누적 점수: 티어별 200~1000점 (약 2~5판 분량)
          target =
              prefs.getInt('${userId}_target_score_$dateKey') ??
              (200 + (difficultyLevel * 160));
          reward =
              prefs.getInt('${userId}_target_score_${dateKey}_reward') ??
              (50 + (difficultyLevel * 20));
          current = todayHistory.fold(0, (sum, item) => sum + item.score);
          title = '오늘 누적 $target점 획득';
          break;

        case MissionType.perfectGame:
          typeSuffix = 'perfect';
          target =
              prefs.getInt('${userId}_target_perfect_$dateKey') ??
              1; // 만점은 기본 1회
          reward =
              prefs.getInt('${userId}_target_perfect_${dateKey}_reward') ??
              (100 + (difficultyLevel * 30));
          current = todayHistory
              .where(
                (r) =>
                    r.correctAnswers >= r.totalQuestions &&
                    r.totalQuestions >= 10,
              )
              .length;
          title = '전체 정답(10/10) $target회 달성';
          break;

        case MissionType.highscoreGame:
          typeSuffix = 'highscore';
          // 한 판 최고 점수: 티어별 100~300점 (최대 약 345점 고려)
          target =
              prefs.getInt('${userId}_target_highscore_$dateKey') ??
              (100 + (difficultyLevel * 40));
          reward =
              prefs.getInt('${userId}_target_highscore_${dateKey}_reward') ??
              (80 + (difficultyLevel * 25));
          // 오늘 기록 중 최고 점수
          current = todayHistory.isEmpty
              ? 0
              : todayHistory.map((e) => e.score).reduce(max);
          title = '한 판 점수 $target점 이상 달성';
          break;
      }

      missionId = '${userId}_mission_${dateKey}_$typeSuffix';

      // 처음 생성된 날이면 로컬 저장소에 당일 목표치 캐싱
      if (!prefs.containsKey('${userId}_target_${typeSuffix}_$dateKey')) {
        prefs.setInt('${userId}_target_${typeSuffix}_$dateKey', target);
        prefs.setInt(
          '${userId}_target_${typeSuffix}_${dateKey}_reward',
          reward,
        );
      } else {
        // 캐시된 값이 있으면 그것을 사용 (일관성 유지)
        target = prefs.getInt('${userId}_target_${typeSuffix}_$dateKey')!;
        reward = prefs.getInt(
          '${userId}_target_${typeSuffix}_${dateKey}_reward',
        )!;
      }

      return QuizMission(
        id: missionId,
        type: type,
        title: title,
        targetValue: target,
        currentValue: current,
        rewardPts: reward,
        isClaimed: prefs.getBool('${missionId}_claimed') ?? false,
      );
    }).toList();
  }

  // 개발/테스트용: 오늘 수령한 미션 상태 및 목표치 초기화
  static Future<void> resetDailyMissions(
    String userId,
    SharedPreferences prefs,
  ) async {
    final now = DateTime.now();
    final dateKey =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';

    // 사용된 모든 서픽스들
    final suffixes = ['play', 'correct', 'score', 'perfect', 'highscore'];

    for (var suffix in suffixes) {
      final missionId = '${userId}_mission_${dateKey}_$suffix';
      await prefs.remove('${missionId}_claimed');
      await prefs.remove('${userId}_target_${suffix}_$dateKey');
      await prefs.remove('${userId}_target_${suffix}_${dateKey}_reward');
    }
  }
}
