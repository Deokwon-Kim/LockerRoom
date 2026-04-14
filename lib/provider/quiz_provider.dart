import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:lockerroom/model/quiz_question_model.dart';
import 'package:lockerroom/model/quiz_result_model.dart';
import 'package:lockerroom/page/quiz/quiz_data.dart';
import 'package:lockerroom/utils/quiz_season_utils.dart';
import 'package:lockerroom/const/firestore_constants.dart';

class QuizProvider extends ChangeNotifier {
  List<QuizQuestionModel> _allQuestions = [];
  List<QuizQuestionModel> _currentQuestions = [];
  List<QuizResultModel> _myHistory = [];
  int _currentQuestionIndex = 0;
  Map<int, int> _userAnswers = {};
  Map<int, bool> _answerCorrectness = {};
  bool _isLoading = false;
  String? _selectedCategory;
  DateTime? _quizStartTime;
  DateTime? _questionStartTime;
  int _speedBonus = 0;
  bool _showExplanation = false;

  // 점수 상세
  int _currentCombo = 0;
  int _maxCombo = 0;
  int _baseScore = 0; // 맞힌 개수 * 10
  int _difficultyBonus = 0; // hard:+10, medium:+5
  int _comboBonus = 0; // 3콤보:+5, 5콤보:+10, 10콤보:+30

  // Firestroe
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // 게터
  List<QuizQuestionModel> get currentQuestions => _currentQuestions;
  List<QuizResultModel> get myHistory => _myHistory;
  int get currentQuestionsIndex => _currentQuestionIndex;
  QuizQuestionModel? get currentQuestion => _currentQuestions.isNotEmpty
      ? _currentQuestions[_currentQuestionIndex]
      : null;
  int get totalQuestions => _currentQuestions.length;
  bool get isLoading => _isLoading;
  String? get selectedCategory => _selectedCategory;
  bool get showExplanation => _showExplanation;

  // 점수 세부 정보 게터
  int get currentCombo => _currentCombo;
  int get maxCombo => _maxCombo;
  int get baseScore => _baseScore;
  int get difficultyBonus => _difficultyBonus;
  int get comboBonus => _comboBonus;

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

  // 최종 점수 (모든 보너스 합산)
  int get score {
    return _baseScore + _difficultyBonus + _comboBonus + _speedBonus;
  }

  // ====== 퀴즈 시작 ======
  Future<void> startQuiz(String category, {int questionCount = 10}) async {
    _isLoading = true;
    notifyListeners();

    try {
      _selectedCategory = category;

      // 로컬 데이터에서 문제 가져오기
      _allQuestions = QuizData.getByCategory(category);

      final user = _auth.currentUser;
      List<String> lastPlayedIds = [];

      // Firestore에서 직전에 푼 문제 ID 조회
      if (user != null) {
        try {
          final doc = await _firestore
              .collection('users')
              .doc(user.uid)
              .collection('quiz_data')
              .doc('last_played')
              .get();

          if (doc.exists) {
            lastPlayedIds = List<String>.from(doc.data()?['ids'] ?? []);
          }
        } catch (e) {
          print('직전 기록 조회 실패:$e');
        }
      }

      // 직전에 푼 문제 제외히고 후보 추리기
      final candidates = _allQuestions
          .where((q) => !lastPlayedIds.contains(q.quizId))
          .toList();

      // 문제 섞기
      candidates.shuffle();

      // 문제 선책 (후보가 부족하면 제외했던 것 중에서 보충)
      if (candidates.length >= questionCount) {
        _currentQuestions = candidates.take(questionCount).toList();
      } else {
        _currentQuestions = [...candidates];

        // 제외했던 문제들 가져와서 섞음
        final excluded = _allQuestions
            .where((q) => lastPlayedIds.contains(q.quizId))
            .toList();
        excluded.shuffle();

        // 부족한 만큼 채우기
        final needed = questionCount - candidates.length;
        _currentQuestions.addAll(excluded.take(needed));
      }

      // 상태 초기화
      _currentQuestionIndex = 0;
      _userAnswers.clear();
      _answerCorrectness.clear();
      _quizStartTime = DateTime.now();
      _showExplanation = false;

      // 점수 초기화
      _currentCombo = 0;
      _maxCombo = 0;
      _baseScore = 0;
      _difficultyBonus = 0;
      _comboBonus = 0;
      _speedBonus = 0;
      _questionStartTime = DateTime.now();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ==== 랜덤 퀴즈 시작(오늘의 퀴즈) ====
  Future<void> startRandomQuiz({int questionCount = 10}) async {
    _isLoading = true;
    notifyListeners();

    try {
      _selectedCategory = '랜덤';

      final user = _auth.currentUser;
      List<String> lastPlayedIds = [];

      // Firestore에서 직전 기록 조회
      if (user != null) {
        try {
          final doc = await _firestore
              .collection('users')
              .doc(user.uid)
              .collection('quiz_data')
              .doc('last_played')
              .get();

          if (doc.exists) {
            lastPlayedIds = List<String>.from(doc.data()?['ids'] ?? []);
          }
        } catch (e) {
          debugPrint('직전 기록 조회 실패: $e');
        }
      }

      // 모든 카테고리에서 가져오기
      final allQuestions = <QuizQuestionModel>[];
      QuizData.getAllQuestions().values.forEach((questions) {
        allQuestions.addAll(questions);
      });

      // 직전에 푼 문제 제외
      final candidates = allQuestions
          .where((q) => !lastPlayedIds.contains(q.quizId))
          .toList();

      candidates.shuffle();

      if (candidates.length >= questionCount) {
        _currentQuestions = candidates.take(questionCount).toList();
      } else {
        _currentQuestions = [...candidates];
        final excluded = allQuestions
            .where((q) => lastPlayedIds.contains(q.quizId))
            .toList();
        excluded.shuffle();
        final needed = questionCount - candidates.length;
        _currentQuestions.addAll(excluded.take(needed));
      }

      // 상태 초기화
      _currentQuestionIndex = 0;
      _userAnswers.clear();
      _answerCorrectness.clear();
      _quizStartTime = DateTime.now();
      _showExplanation = false;

      // 점수 초기화
      _currentCombo = 0;
      _maxCombo = 0;
      _baseScore = 0;
      _difficultyBonus = 0;
      _comboBonus = 0;
      _speedBonus = 0;
      _questionStartTime = DateTime.now();
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

    // === 점수 계산 로직 추가 ===
    if (isCorrect) {
      // 1. 기본 점수 (+10)
      _baseScore += 10;

      // 2. 난이도 보너스 (hard:+10, medium:+5)
      if (currentQuestion!.difficulty == 'hard') {
        _difficultyBonus += 10;
      } else if (currentQuestion!.difficulty == 'medium') {
        _difficultyBonus += 5;
      }

      // 3. 콤보 보너스
      _currentCombo++;
      if (_currentCombo > _maxCombo) _maxCombo = _currentCombo;

      if (_currentCombo == 3) {
        _comboBonus += 5;
      } else if (_currentCombo == 5) {
        _comboBonus += 10;
      } else if (_currentCombo == 10) {
        _comboBonus += 30;
      }

      if (_questionStartTime != null) {
        final elapsed = DateTime.now()
            .difference(_questionStartTime!)
            .inSeconds;

        if (elapsed <= 5) {
          _speedBonus += 10;
        } else if (elapsed <= 10) {
          _speedBonus += 5;
        }
      }
    } else {
      // 오답 시 콤보 리셋
      _currentCombo = 0;
    }

    // 해설 표시
    _showExplanation = true;

    notifyListeners();
  }

  // ==== 다음 문제로 ====
  void nextQuestion() {
    if (_currentQuestionIndex < _currentQuestions.length - 1) {
      _currentQuestionIndex++;
      _showExplanation = false;
      _questionStartTime = DateTime.now();
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
  Future<QuizResultModel> completeQuiz(String? userNickName) async {
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

    // 카테고리 매핑 (인트로/가사 모두 '응원가' 랭킹에 합산되도록)
    String finalCategory = _selectedCategory!;
    if (finalCategory.startsWith('응원가')) {
      finalCategory = '응원가';
    }

    // 유저의 현재 팀 정보 가져오기
    String? currentTeam;
    try {
      final userId = _auth.currentUser?.uid;
      if (userId != null) {
        final userDoc = await _firestore.collection('users').doc(userId).get();
        currentTeam = userDoc.data()?['team'] as String?;
      }
    } catch (e) {
      debugPrint('팀 정보 조회 실패: $e');
    }

    // 결과 객체 생성 (다시하기를 위해 원본 카테고리 보존)
    final result = QuizResultModel(
      userId: _auth.currentUser?.uid ?? '',
      userNickName: userNickName ?? '',
      category: _selectedCategory!, // 원본 카테고리 (인트로/가사 등)
      totalQuestions: totalQuestions,
      correctAnswers: correctCount,
      score: score,
      baseScore: _baseScore,
      difficultyBonus: _difficultyBonus,
      comboBonus: _comboBonus,
      speedBonus: _speedBonus,
      completedAt: DateTime.now(),
      timeTakenSeconds: timeTaken.inSeconds,
      questionIds: questionIds,
      answerResults: answerResults,
      teamName: currentTeam, // 현재 팀 저장
      seasonId: QuizSeasonUtils.getCurrentSeasonId(),
    );

    // Firestore에 저장 (userId별 서브컬렉션 구조)
    try {
      final userId = _auth.currentUser?.uid;
      if (userId != null) {
        // 1. 개별 결과 저장 (랭킹 시스템을 위해 카테고리 매핑 적용)
        final firestoreData = result.toJson();
        firestoreData['category'] =
            finalCategory; // Firestore에는 랭킹용 통합 카테고리로 저장

        await _firestore
            .collection(FirestoreConstants.quizResults)
            .doc(userId)
            .collection(FirestoreConstants.quizResultsSub)
            .add(firestoreData);

        // 2. 유저 총점 업데이트: 이제 Cloud Function(onQuizResultCreated)에서 트랜잭션으로 처리함
        // (동시성 문제 및 순위 역전 알림의 정확도를 위해 서버측으로 로직 이동)

        // 직전 문제 리스트 저장 (중복방지)
        final docRef = _firestore
            .collection('users')
            .doc(userId)
            .collection('quiz_data')
            .doc('last_played');

        await _firestore.runTransaction((transaction) async {
          final snapshot = await transaction.get(docRef);
          List<String> currentIds = [];
          if (snapshot.exists) {
            currentIds = List<String>.from(snapshot.data()?['ids'] ?? []);
          }

          // 이번 문제 ID들 뒤에 추가
          currentIds.addAll(questionIds);

          // 너무 많으면 오래된 것부터 삭제 (최대 150개 추적)
          if (currentIds.length > 150) {
            currentIds = currentIds.sublist(currentIds.length - 150);
          }

          transaction.set(docRef, {'ids': currentIds});
        });
      }
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
          .collection(FirestoreConstants.quizResults)
          .doc(userId)
          .collection(FirestoreConstants.quizResultsSub)
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
          .collection(FirestoreConstants.quizResults)
          .doc(userId)
          .collection(FirestoreConstants.quizResultsSub)
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
          .collection(FirestoreConstants.quizResults)
          .doc(userId)
          .collection(FirestoreConstants.quizResultsSub)
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

  // 자신의 퀴즈 기록 불러오기
  Future<void> fetchMyHistory() async {
    final user = _auth.currentUser;
    if (user == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      final snapshot = await _firestore
          .collection(FirestoreConstants.quizResults)
          .doc(user.uid)
          .collection(FirestoreConstants.quizResultsSub)
          .orderBy('completedAt', descending: true)
          .get();

      _myHistory = snapshot.docs.map((doc) {
        return QuizResultModel.fromJson(doc.data());
      }).toList();
    } catch (e) {
      print('퀴즈 기록 가져오기 실패: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
