import 'package:lockerroom/model/quiz_question_model.dart';
import 'package:lockerroom/page/quiz/kbo_history_quiz.dart';

class QuizData {
  static const String version = '1.0.0';
  static final DateTime lastUpdated = DateTime(2025, 12, 01);

  static Map<String, List<QuizQuestionModel>> getAllQuestions() {
    return {
      'KBO역사': kboHistoryQuestions,
      '야구 룰': baseballRuelQuestions,
      '선수퀴즈': playerQuestions,
      '기록과 통계': statsQuestions,
      '구장': stadiumQuestions,
    };
  }

  // 카테고리별 문제 가져오기
  static List<QuizQuestionModel> getByCategory(String category) {
    return getAllQuestions()[category] ?? [];
  }

  // 랜덤 문제 가져오기
  static List<QuizQuestionModel> getRandomQuestions(int count) {
    final allQuestions = <QuizQuestionModel>[];
    getAllQuestions().values.forEach((questions) {
      allQuestions.addAll(questions);
    });

    allQuestions.shuffle();
    return allQuestions.take(count).toList();
  }

  // 난이도별 문제 가져오기
  static List<QuizQuestionModel> getByDifficulty(String difficulty) {
    final allQuestions = <QuizQuestionModel>[];
    getAllQuestions().values.forEach((questions) {
      allQuestions.addAll(questions.where((q) => q.difficulty == difficulty));
    });

    return allQuestions;
  }

  // 전체 문제 개수
  static int getTotalQuestionCount() {
    return getAllQuestions().values.fold(0, (sum, list) => sum + list.length);
  }

  // 카테고리별 문제 개수
  static int getCategoryQuestionCount(String category) {
    return getByCategory(category).length;
  }
}
