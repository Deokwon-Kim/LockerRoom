import 'dart:math';
import 'package:lockerroom/model/quiz_result_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum MissionType {
  playCount, // 퀴즈 참여 횟수
  totalCorrect, // 누적 안타 개수
  totalScore, // 연속 안타(연타) 달성
  perfectGame, // 홈런(스피드 정답) 달성
  highscoreGame, // 한 경기 타율 .700 이상 달성
}

class QuizMission {
  final String id;
  final MissionType type;
  final String title;
  final int targetValue;
  final int currentValue;
  final int rewardPts;
  final String rewardLabel;
  final bool isClaimed;

  QuizMission({
    required this.id,
    required this.type,
    required this.title,
    required this.targetValue,
    required this.currentValue,
    required this.rewardPts,
    this.rewardLabel = '보너스 +1안타',
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

    // 현재 플레이어의 누적 경험치 기반으로 난이도 설정
    int difficultyLevel = 0;
    if (userTotalScore >= 10000) {
      difficultyLevel = 5;
    } else if (userTotalScore >= 5000) {
      difficultyLevel = 4;
    } else if (userTotalScore >= 2500) {
      difficultyLevel = 3;
    } else if (userTotalScore >= 1200) {
      difficultyLevel = 2;
    } else if (userTotalScore >= 400) {
      difficultyLevel = 1;
    }

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
              prefs.getInt('v2_${userId}_target_play_$dateKey') ??
              (1 + (difficultyLevel / 2).floor());
          reward = 30 + (difficultyLevel * 10);
          current = todayHistory.length;
          title = '오늘 퀴즈 $target경기 완주하기';
          break;

        case MissionType.totalCorrect:
          typeSuffix = 'correct';
          target =
              prefs.getInt('v2_${userId}_target_correct_$dateKey') ??
              (5 + (difficultyLevel * 3));
          reward = 40 + (difficultyLevel * 15);
          current = todayHistory.fold(
            0,
            (sum, item) => sum + item.hits,
          );
          title = '오늘 안타 $target개 때려내기';
          break;

        case MissionType.totalScore:
          typeSuffix = 'streak';
          target =
              prefs.getInt('v2_${userId}_target_streak_$dateKey') ??
              (difficultyLevel >= 3 ? 5 : 3);
          reward = 50 + (difficultyLevel * 20);
          current = todayHistory.isEmpty
              ? 0
              : todayHistory
                    .map((e) => e.boxScore?.maxCombo ?? e.hits)
                    .reduce(max);
          title = '연속 안타 $target연타+ 달성';
          break;

        case MissionType.perfectGame:
          typeSuffix = 'homerun';
          target =
              prefs.getInt('v2_${userId}_target_homerun_$dateKey') ?? 1;
          reward = 80 + (difficultyLevel * 20);
          current = todayHistory.isEmpty
              ? 0
              : todayHistory
                    .map((e) => e.boxScore?.homeRuns ?? 0)
                    .reduce(max);
          title = '홈런(스피드 정답) $target개+ 달성';
          break;

        case MissionType.highscoreGame:
          typeSuffix = 'avg700';
          target =
              prefs.getInt('v2_${userId}_target_avg700_$dateKey') ?? 1;
          reward = 80 + (difficultyLevel * 25);
          current = todayHistory.any(
            (r) => r.atBats > 0 && r.battingAverage >= 0.700,
          )
              ? 1
              : 0;
          title = '한 경기 타율 .700 이상 달성';
          break;
      }

      missionId = 'v2_${userId}_mission_${dateKey}_$typeSuffix';

      // 처음 생성된 날이면 로컬 저장소에 당일 목표치 캐싱
      if (!prefs.containsKey('v2_${userId}_target_${typeSuffix}_$dateKey')) {
        prefs.setInt('v2_${userId}_target_${typeSuffix}_$dateKey', target);
        prefs.setInt(
          'v2_${userId}_target_${typeSuffix}_${dateKey}_reward',
          reward,
        );
      } else {
        target = prefs.getInt('v2_${userId}_target_${typeSuffix}_$dateKey')!;
        reward =
            prefs.getInt(
              'v2_${userId}_target_${typeSuffix}_${dateKey}_reward',
            ) ??
            reward;
      }

      return QuizMission(
        id: missionId,
        type: type,
        title: title,
        targetValue: target,
        currentValue: current,
        rewardPts: reward,
        rewardLabel: '보너스 +1안타',
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

    final suffixes = ['play', 'correct', 'streak', 'homerun', 'avg700'];

    for (var suffix in suffixes) {
      final missionId = 'v2_${userId}_mission_${dateKey}_$suffix';
      await prefs.remove('${missionId}_claimed');
      await prefs.remove('v2_${userId}_target_${suffix}_$dateKey');
      await prefs.remove('v2_${userId}_target_${suffix}_${dateKey}_reward');
    }
  }
}
