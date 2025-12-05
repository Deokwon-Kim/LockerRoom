import 'package:cloud_firestore/cloud_firestore.dart';

class QuizResultModel {
  final String userId;
  final String? userNickName; // nullable로 변경 (기존 데이터 호환성)
  final String category;
  final int totalQuestions;
  final int correctAnswers;
  final int score;
  final DateTime completedAt;
  final int timeTakenSeconds;
  final List<String> questionIds;
  final Map<String, bool> answerResults;

  QuizResultModel({
    required this.userId,
    this.userNickName, // nullable
    required this.category,
    required this.totalQuestions,
    required this.correctAnswers,
    required this.score,
    required this.completedAt,
    required this.timeTakenSeconds,
    required this.questionIds,
    required this.answerResults,
  });

  // 점수 계산 헬퍼
  static int calculateScore(int correct, int total) {
    if (total == 0) return 0;
    return ((correct / total) * 100).round();
  }

  // 등급 계산
  String get grade {
    if (score >= 90) return 'S';
    if (score >= 80) return 'A';
    if (score >= 70) return 'B';
    if (score >= 60) return 'C';
    return 'D';
  }

  // 통과 여부
  bool get isPassed => score >= 60;

  // Firestore 변환
  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'userNickName': userNickName,
      'category': category,
      'totalQuestions': totalQuestions,
      'correctAnswers': correctAnswers,
      'score': score,
      'completedAt': completedAt,
      'timeTakenSeconds': timeTakenSeconds,
      'questionIds': questionIds,
      'answerResults': answerResults,
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
      completedAt: (json['completedAt'] as Timestamp).toDate(),
      timeTakenSeconds: json['timeTakenSeconds'] as int,
      questionIds: List<String>.from(json['questionIds'] as List),
      answerResults: Map<String, bool>.from(json['answerResults'] as Map),
    );
  }

  // 소요 시간 포맷팅
  String get formattedTime {
    final minutes = timeTakenSeconds ~/ 60;
    final seconds = timeTakenSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}: ${seconds.toString().padLeft(2, '0')}';
  }
}
