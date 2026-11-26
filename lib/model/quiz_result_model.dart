import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lockerroom/utils/quiz_season_utils.dart';

class QuizBoxScoreModel {
  final int atBats;
  final int hits;
  final int doubles;
  final int triples;
  final int homeRuns;
  final int rbi;
  final int runs;
  final int maxCombo;
  final int inningsReached;
  final int clutchHits;
  final String title;

  const QuizBoxScoreModel({
    required this.atBats,
    required this.hits,
    this.doubles = 0,
    this.triples = 0,
    this.homeRuns = 0,
    this.rbi = 0,
    this.runs = 0,
    this.maxCombo = 0,
    this.inningsReached = 1,
    this.clutchHits = 0,
    this.title = '⚾ 육성 선수',
  });

  int get singles => (hits - doubles - triples - homeRuns).clamp(0, hits);

  double get battingAverage => atBats > 0 ? hits / atBats : 0.0;

  String get formattedAvg {
    if (atBats == 0) return '.000';
    final avg = battingAverage;
    if (avg >= 1.0) return '1.000';
    return '.${(avg * 1000).round().toString().padLeft(3, '0')}';
  }

  double get sluggingPercentage {
    if (atBats == 0) return 0.0;
    final totalBases = singles + (doubles * 2) + (triples * 3) + (homeRuns * 4);
    return totalBases / atBats;
  }

  String get formattedSlg => sluggingPercentage.toStringAsFixed(3);

  Map<String, dynamic> toJson() {
    return {
      'atBats': atBats,
      'hits': hits,
      'doubles': doubles,
      'triples': triples,
      'homeRuns': homeRuns,
      'rbi': rbi,
      'runs': runs,
      'maxCombo': maxCombo,
      'inningsReached': inningsReached,
      'clutchHits': clutchHits,
      'title': title,
    };
  }

  factory QuizBoxScoreModel.fromJson(Map<String, dynamic> json) {
    return QuizBoxScoreModel(
      atBats: json['atBats'] as int? ?? 0,
      hits: json['hits'] as int? ?? 0,
      doubles: json['doubles'] as int? ?? 0,
      triples: json['triples'] as int? ?? 0,
      homeRuns: json['homeRuns'] as int? ?? 0,
      rbi: json['rbi'] as int? ?? 0,
      runs: json['runs'] as int? ?? 0,
      maxCombo: json['maxCombo'] as int? ?? 0,
      inningsReached: json['inningsReached'] as int? ?? 1,
      clutchHits: json['clutchHits'] as int? ?? 0,
      title: json['title'] as String? ?? '⚾ 육성 선수',
    );
  }
}

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
  final String mode; // 'normal' | 'threeOut'
  final int? outsCount;
  final QuizBoxScoreModel? boxScore;
  final int atBats;
  final int hits;

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
    this.mode = 'normal',
    this.outsCount,
    this.boxScore,
    int? atBats,
    int? hits,
  }) : atBats = atBats ?? boxScore?.atBats ?? totalQuestions,
       hits = hits ?? boxScore?.hits ?? correctAnswers;

  double get battingAverage => atBats > 0 ? hits / atBats : 0.0;

  String get formattedBattingAverage =>
      formatBattingAverage(battingAverage, atBats);

  static String formatBattingAverage(double avg, int atBats) {
    if (atBats <= 0) return '.000';
    if (avg >= 1.0) return '1.000';
    return '.${(avg * 1000).round().toString().padLeft(3, '0')}';
  }

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
      'mode': mode,
      'atBats': atBats,
      'hits': hits,
      if (outsCount != null) 'outsCount': outsCount,
      if (boxScore != null) 'boxScore': boxScore!.toJson(),
    };
  }

  factory QuizResultModel.fromJson(Map<String, dynamic> json) {
    final parsedTotal = json['totalQuestions'] as int;
    final parsedCorrect = json['correctAnswers'] as int;
    final parsedBox = json['boxScore'] is Map<String, dynamic>
        ? QuizBoxScoreModel.fromJson(json['boxScore'] as Map<String, dynamic>)
        : null;
    return QuizResultModel(
      userId: json['userId'] as String,
      userNickName: json['userNickName'] as String?, // nullable 처리
      category: json['category'] as String,
      totalQuestions: parsedTotal,
      correctAnswers: parsedCorrect,
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
      mode: json['mode'] as String? ?? 'normal',
      outsCount: json['outsCount'] as int?,
      boxScore: parsedBox,
      atBats: json['atBats'] as int? ?? parsedBox?.atBats ?? parsedTotal,
      hits: json['hits'] as int? ?? parsedBox?.hits ?? parsedCorrect,
    );
  }

  // 소요 시간 포맷팅
  String get formattedTime {
    final minutes = timeTakenSeconds ~/ 60;
    final seconds = timeTakenSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}: ${seconds.toString().padLeft(2, '0')}';
  }
}
