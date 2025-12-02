import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:lockerroom/model/quiz_question_model.dart';
import 'package:lockerroom/model/quiz_result_model.dart';
import 'package:lockerroom/page/quiz/quiz_data.dart';

class QuizProvider extends ChangeNotifier {
  List<QuizQuestionModel> _allQuestions = [];
  List<QuizQuestionModel> _currentQuestions = [];
  int _currentQuestionIndex = 0;
  Map<int, int> _userAnswers = {};
  Map<int, bool> _answerCorrectness = {};
  bool _isLoading = false;
  String? _selectedCategory;
  DateTime? _quizStartTime;
  bool _showExplanation = false;

  // Firestroe
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // 게터
  List<QuizQuestionModel> get currentQuestions => _currentQuestions;
  int get currentQuestionsIndex => _currentQuestionIndex;
  QuizQuestionModel? get currentQuestion => _currentQuestions.isNotEmpty
      ? _currentQuestions[_currentQuestionIndex]
      : null;
  int get totalQuestions => _currentQuestions.length;
  bool get isLoading => _isLoading;
  String? get selectedCategory => _selectedCategory;
  bool get showExplanation => _showExplanation;

  // 진행도 (0.0 ~ 1.0)
  double get progress {
    if (_currentQuestions.isEmpty) return 0.0;
    return (_currentQuestionIndex + 1) / _currentQuestions.length;
  }

  // 퀴즈 완료 여부
  bool get isQuizCompleted => _currentQuestionIndex >= _currentQuestions.length;

  // 현재 문제의 사용자 답변
  int? get currentAnswer => _userAnswers[_currentQuestionIndex];

  // 현재 문제 정답 여부
  bool? get isCurrentAnswerCorrect => _answerCorrectness[_currentQuestionIndex];

  // 정답 개수
  int get correctCount =>
      _answerCorrectness.values.where((v) => v == true).length;

  // 오답 개수
  int get incorrectCount =>
      _answerCorrectness.values.where((v) => v == false).length;

  // 점수 (100점 만점)
  int get score {
    if (_currentQuestions.isEmpty) return 0;
    return QuizResultModel.calculateScore(correctCount, totalQuestions);
  }

  // ====== 퀴즈 시작 ======
  void startQuiz(String category, {int questionCount = 10}) {
    _isLoading = true;
    notifyListeners();

    try {
      _selectedCategory = category;

      // 로컬 데이터에서 문제 가져오기
      _allQuestions = QuizData.getByCategory(category);

      // 문제 섞기
      _allQuestions.shuffle();

      // 지정된 개수만큼 선택
      _currentQuestions = _allQuestions.take(questionCount).toList();

      // 상태 초기화
      _currentQuestionIndex = 0;
      _userAnswers.clear();
      _answerCorrectness.clear();
      _quizStartTime = DateTime.now();
      _showExplanation = false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ==== 랜덤 퀴즈 시작(오늘의 퀴즈) ====
  void startRandomQuiz({int questionCount = 10}) {
    _isLoading = true;
    notifyListeners();

    try {
      _selectedCategory = '랜덤';

      // 모든 카테고리에서 랜덤 문제 가져오기
      _currentQuestions = QuizData.getRandomQuestions(questionCount);

      // 상태 초기화
      _currentQuestionIndex = 0;
      _userAnswers.clear();
      _answerCorrectness.clear();
      _quizStartTime = DateTime.now();
      _showExplanation = false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ==== 답변 선택 ====
  void selectAnswer(int optionIndex) {
    if (currentQuestion == null) return;

    // 답변 저장
    _userAnswers[_currentQuestionIndex] = optionIndex;

    // 정답 체크
    final isCorrect = optionIndex == currentQuestion!.correctIndex;
    _answerCorrectness[_currentQuestionIndex] = isCorrect;

    // 해설 표시
    _showExplanation = true;

    notifyListeners();
  }

  // ==== 다음 문제로 ====
  void nextQuestion() {
    if (_currentQuestionIndex < _currentQuestions.length - 1) {
      _currentQuestionIndex++;
      _showExplanation = false;
      notifyListeners();
    }
  }

  // ==== 이전 문제로 ====
  void previousQuestion() {
    if (_currentQuestionIndex > 0) {
      _currentQuestionIndex--;
      _showExplanation = _userAnswers.containsKey(_currentQuestionIndex);
      notifyListeners();
    }
  }

  // ==== 특정 문제로 이동 ====
  void goToQuestion(int index) {
    if (index >= 0 && index < _currentQuestions.length) {
      _currentQuestionIndex = index;
      _showExplanation = _userAnswers.containsKey(_currentQuestionIndex);
      notifyListeners();
    }
  }

  // ==== 퀴즈 완료 및 결과 저장 ====
  Future<QuizResultModel> completeQuiz() async {
    if (_quizStartTime == null || _selectedCategory == null) {
      throw Exception('퀴즈가 시작되지 않았습니다');
    }

    // 소요 시간 계산
    final timeTaken = DateTime.now().difference(_quizStartTime!);

    // 문제 ID 목록
    final questionIds = _currentQuestions.map((q) => q.quizId).toList();

    // 답변 결과 맵
    final answerResults = <String, bool>{};
    _answerCorrectness.forEach((index, isCorrect) {
      answerResults[_currentQuestions[index].quizId] = isCorrect;
    });

    // 결과 객체 생성
    final result = QuizResultModel(
      userId: _auth.currentUser?.uid ?? '',
      category: _selectedCategory!,
      totalQuestions: totalQuestions,
      correctAnswers: correctCount,
      score: score,
      completedAt: DateTime.now(),
      timeTakenSeconds: timeTaken.inSeconds,
      questionIds: questionIds,
      answerResults: answerResults,
    );

    // Firestore에 저장
    try {
      await _firestore.collection('quiz_results').add(result.toJson());
    } catch (e) {
      debugPrint('퀴즈 결과 저장 실패: $e');
    }

    return result;
  }

  // ==== 사용자 퀴즈 기록 조회 ====
  Future<List<QuizResultModel>> getUserQuizHistory({int limit = 20}) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return [];

    try {
      final snapshot = await _firestore
          .collection('quiz_results')
          .where('userId', isEqualTo: userId)
          .orderBy('completedAt', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => QuizResultModel.fromJson(doc.data()))
          .toList();
    } catch (e) {
      debugPrint('퀴즈 기록 조회 실패: $e');
      return [];
    }
  }

  // ==== 카테고리별 최고 점수 조회 ====
  Future<QuizResultModel?> getBestScoreByCategory(String category) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return null;

    try {
      final snapshot = await _firestore
          .collection('quiz_results')
          .where('userId', isEqualTo: userId)
          .where('category', isEqualTo: category)
          .orderBy('score', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;
      return QuizResultModel.fromJson(snapshot.docs.first.data());
    } catch (e) {
      debugPrint('최고 점수 조회 실패:$e');
      return null;
    }
  }

  // ===== 카테고리별 평균 점수 =====
  Future<double> getAverageScoreByCategory(String category) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return 0.0;

    try {
      final snapshot = await _firestore
          .collection('quiz_results')
          .where('userId', isEqualTo: userId)
          .where('category', isEqualTo: category)
          .get();

      if (snapshot.docs.isEmpty) return 0.0;

      final scores = snapshot.docs
          .map((doc) => (doc.data()['score'] as num).toDouble())
          .toList();

      return scores.reduce((a, b) => a + b) / scores.length;
    } catch (e) {
      debugPrint('평균 점수 조회 실패: $e');
      return 0.0;
    }
  }

  // ===== 퀴즈 리셋 =====
  void resetQuiz() {
    _currentQuestions.clear();
    _currentQuestionIndex = 0;
    _userAnswers.clear();
    _answerCorrectness.clear();
    _selectedCategory = null;
    _quizStartTime = null;
    _showExplanation = false;
    notifyListeners();
  }

  // ===== 해설 토글 =====
  void toggleExplanation() {
    _showExplanation = !_showExplanation;
    notifyListeners();
  }
}
