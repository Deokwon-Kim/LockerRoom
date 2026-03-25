import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lockerroom/utils/quiz_season_utils.dart';

class QuizResultModel {
  final String userId;
  final String? userNickName; // nullable로 변경 (기존 데이터 호환성)
  final String category;
  final int totalQuestions;
  final int correctAnswers;
  final int score;
  final int baseScore; // 기본 점수 (맞힌 개수 * 10)
  final int difficultyBonus; // 난이도 가중치 점수
  final int comboBonus; // 콤보 보너스 점수
  final int speedBonus;
  final DateTime completedAt;
  final int timeTakenSeconds;
  final List<String> questionIds;
  final Map<String, bool> answerResults;
  final String? teamName; // 추가: 퀴즈 당시의 소속 팀
  final String seasonId;

  QuizResultModel({
    required this.userId,
    this.userNickName, // nullable
    required this.category,
    required this.totalQuestions,
    required this.correctAnswers,
    required this.score,
    this.baseScore = 0,
    this.difficultyBonus = 0,
    this.comboBonus = 0,
    this.speedBonus = 0,
    required this.completedAt,
    required this.timeTakenSeconds,
    required this.questionIds,
    required this.answerResults,
    this.teamName,
    required this.seasonId,
  });

  // 점수 계산 헬퍼
  static int calculateScore(int correct, int total) {
    if (total == 0) return 0;
    return ((correct / total) * 100).round();
  }

  // 등급 계산 (정확도 기반)
  String get grade {
    final accuracy = totalQuestions > 0
        ? (correctAnswers / totalQuestions) * 100
        : 0;
    if (accuracy >= 100) return 'S';
    if (accuracy >= 90) return 'A';
    if (accuracy >= 80) return 'B';
    if (accuracy >= 70) return 'C';
    return 'D';
  }

  // 통과 여부 (정확도 60% 이상)
  bool get isPassed {
    final accuracy = totalQuestions > 0
        ? (correctAnswers / totalQuestions) * 100
        : 0;
    return accuracy >= 60;
  }

  // Firestore 변환
  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'userNickName': userNickName,
      'category': category,
      'totalQuestions': totalQuestions,
      'correctAnswers': correctAnswers,
      'score': score,
      'baseScore': baseScore,
      'difficultyBonus': difficultyBonus,
      'comboBonus': comboBonus,
      'speedBonus': speedBonus,
      'completedAt': completedAt,
      'timeTakenSeconds': timeTakenSeconds,
      'questionIds': questionIds,
      'answerResults': answerResults,
      'teamName': teamName,
      'seasonId': seasonId,
    };
  }

  factory QuizResultModel.fromJson(Map<String, dynamic> json) {
    return QuizResultModel(
      userId: json['userId'] as String,
      userNickName: json['userNickName'] as String?, // nullable 처리
      category: json['category'] as String,
      totalQuestions: json['totalQuestions'] as int,
      correctAnswers: json['correctAnswers'] as int,
      score: json['score'] as int,
      baseScore: json['baseScore'] as int? ?? 0,
      difficultyBonus: json['difficultyBonus'] as int? ?? 0,
      comboBonus: json['comboBonus'] as int? ?? 0,
      speedBonus: json['speedBonus'] as int? ?? 0,
      completedAt: (json['completedAt'] as Timestamp).toDate(),
      timeTakenSeconds: json['timeTakenSeconds'] as int,
      questionIds: List<String>.from(json['questionIds'] as List),
      answerResults: Map<String, bool>.from(json['answerResults'] as Map),
      teamName: json['teamName'] as String?,
      seasonId:
          json['seasonId'] as String? ??
          QuizSeasonUtils.getSeasonIdFromDate(
            (json['completedAt'] as Timestamp).toDate(),
          ),
    );
  }

  // 소요 시간 포맷팅
  String get formattedTime {
    final minutes = timeTakenSeconds ~/ 60;
    final seconds = timeTakenSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}: ${seconds.toString().padLeft(2, '0')}';
  }
}
