import 'package:lockerroom/model/quiz_question_model.dart';
import 'package:lockerroom/page/quiz/kbo_history_quiz.dart';

class QuizData {
  static const String version = '1.0.0';
  static final DateTime lastUpdated = DateTime(2025, 12, 01);

  static Map<String, List<QuizQuestionModel>> getAllQuestions() {
    return {
      'KBO역사': kboHistoryQuestions,
      '야구룰': baseballRuelQuestions,
      '선수퀴즈': playerQuestions,
      '기록': statsQuestions,
      '응원가(인트로)': cheerSongQuestions
          .where((q) => q.category == '응원가(인트로)')
          .toList(),
      '응원가(가사)': cheerSongQuestions
          .where((q) => q.category == '응원가(가사)')
          .toList(),
      '랜덤': randomQuestions,
    };
  }

  // 카테고리별 문제 가져오기
  static List<QuizQuestionModel> getByCategory(String category) {
    if (category == '응원가(인트로)' || category == '응원가(가사)') {
      return cheerSongQuestions.where((q) => q.category == category).toList();
    }
    if (category == '응원가') {
      return cheerSongQuestions;
    }
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
