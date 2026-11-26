import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:lockerroom/model/quiz_question_model.dart';
import 'package:lockerroom/model/quiz_result_model.dart';
import 'package:lockerroom/page/quiz/quiz_data.dart';
import 'package:lockerroom/utils/quiz_season_utils.dart';
import 'package:lockerroom/const/firestore_constants.dart';

enum QuizMode { normal, threeOut }

enum HitType { none, single, double, triple, homeRun, out }

class QuizProvider extends ChangeNotifier {
  static const int defaultQuestionSeconds = 15;

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
  int _runBonus = 0; // 홈인 득점 보너스 (+15 per run)
  int _clutchBonus = 0; // 9회말 2사 만루 2X 클러치 보너스

  // 야구 게임화 상태
  QuizMode _mode = QuizMode.normal;
  int _outs = 0;
  List<bool> _bases = [false, false, false]; // 1루, 2루, 3루
  int _inning = 1;
  int _atBats = 0;
  int _hits = 0;
  int _doubles = 0;
  int _triples = 0;
  int _homeRuns = 0;
  int _rbi = 0;
  int _runs = 0;
  int _clutchHits = 0;
  int _twoOutSurvivalStreak = 0;
  double _totalResponseSeconds = 0.0;
  HitType _lastHitType = HitType.none;
  int _lastRunsScored = 0;
  bool _lastWasClutch = false;

  // 타이머 & 찬스 카드 (게임당 각 1회)
  Timer? _questionTimer;
  int _remainingSeconds = defaultQuestionSeconds;
  int _extraTimeSeconds = 0;
  bool _isTimedOut = false;
  bool _usedTimeout = false;
  int _videoReviewUseCount = 0;
  bool _isDefendingBattingKing = false;
  bool _usedPinchHitter = false;
  String? _lastRechargedChanceName;
  Set<int> _eliminatedOptions = {};
  final Set<String> _sessionQuestionIds = {};
  bool _isReplenishing = false;

  // Firestroe
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // 게터
  List<QuizQuestionModel> get currentQuestions => _currentQuestions;
  List<QuizResultModel> get myHistory => _myHistory;
  int get currentQuestionsIndex => _currentQuestionIndex;
  QuizQuestionModel? get currentQuestion =>
      _currentQuestions.isNotEmpty &&
          _currentQuestionIndex < _currentQuestions.length
      ? _currentQuestions[_currentQuestionIndex]
      : null;
  int get totalQuestions => _currentQuestions.length;
  bool get isLoading => _isLoading;
  String? get selectedCategory => _selectedCategory;
  bool get showExplanation => _showExplanation;

  // 게임화 게터
  QuizMode get mode => _mode;
  bool get isThreeOutMode => _mode == QuizMode.threeOut;
  int get outs => _outs;
  List<bool> get bases => List.unmodifiable(_bases);
  int get inning => _inning;
  int get remainingSeconds => _remainingSeconds;
  bool get isTimedOut => _isTimedOut;
  bool get isGameOver => _mode == QuizMode.threeOut && _outs >= 3;
  bool get isTwoOuts => _outs == 2;
  bool get isBasesLoaded => _bases[0] && _bases[1] && _bases[2];
  bool get isClutchTime => isTwoOuts && isBasesLoaded;
  bool get isDefendingBattingKing => _isDefendingBattingKing;
  int get maxVideoReviewUses => _isDefendingBattingKing ? 2 : 1;
  int get remainingVideoReviewUses =>
      (maxVideoReviewUses - _videoReviewUseCount).clamp(0, maxVideoReviewUses);
  bool get usedVideoReview => _videoReviewUseCount >= maxVideoReviewUses;
  bool get usedPinchHitter => _usedPinchHitter;
  bool get usedTimeout => _usedTimeout;
  String? get lastRechargedChanceName => _lastRechargedChanceName;
  Set<int> get eliminatedOptions => Set.unmodifiable(_eliminatedOptions);
  HitType get lastHitType => _lastHitType;
  int get lastRunsScored => _lastRunsScored;
  bool get lastWasClutch => _lastWasClutch;
  int get runs => _runs;
  int get rbi => _rbi;
  int get homeRuns => _homeRuns;
  int get hits => _hits;
  int get atBats => _atBats;
  int get currentAtBats => _atBats;
  int get currentHits => _hits;
  double get currentBattingAverage => _atBats > 0 ? _hits / _atBats : 0.0;
  String get formattedBattingAverage =>
      QuizResultModel.formatBattingAverage(currentBattingAverage, _atBats);

  // 점수 세부 정보 게터
  int get currentCombo => _currentCombo;
  int get maxCombo => _maxCombo;
  int get baseScore => _baseScore;
  int get difficultyBonus => _difficultyBonus;
  int get comboBonus => _comboBonus;
  int get runBonus => _runBonus;
  int get clutchBonus => _clutchBonus;

  // 진행도 (0.0 ~ 1.0)
  double get progress {
    if (_currentQuestions.isEmpty) return 0.0;
    return (_currentQuestionIndex + 1) / _currentQuestions.length;
  }

  // 퀴즈 완료 여부
  bool get isQuizCompleted =>
      isGameOver || _currentQuestionIndex >= _currentQuestions.length;

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
    return _baseScore +
        _difficultyBonus +
        _comboBonus +
        _speedBonus +
        _runBonus +
        _clutchBonus;
  }

  void setDefendingBattingKing(bool value) {
    if (_isDefendingBattingKing == value) return;
    _isDefendingBattingKing = value;
    notifyListeners();
  }

  void _resetSessionState(QuizMode mode) {
    _stopQuestionTimer();
    _mode = mode;
    _currentQuestionIndex = 0;
    _userAnswers.clear();
    _answerCorrectness.clear();
    _quizStartTime = DateTime.now();
    _showExplanation = false;

    _currentCombo = 0;
    _maxCombo = 0;
    _baseScore = 0;
    _difficultyBonus = 0;
    _comboBonus = 0;
    _speedBonus = 0;
    _runBonus = 0;
    _clutchBonus = 0;
    _questionStartTime = DateTime.now();

    _outs = 0;
    _bases = [false, false, false];
    _inning = 1;
    _atBats = 0;
    _hits = 0;
    _doubles = 0;
    _triples = 0;
    _homeRuns = 0;
    _rbi = 0;
    _runs = 0;
    _clutchHits = 0;
    _twoOutSurvivalStreak = 0;
    _totalResponseSeconds = 0.0;
    _lastHitType = HitType.none;
    _lastRunsScored = 0;
    _lastWasClutch = false;

    _remainingSeconds = defaultQuestionSeconds;
    _extraTimeSeconds = 0;
    _isTimedOut = false;
    _videoReviewUseCount = 0;
    _usedPinchHitter = false;
    _usedTimeout = false;
    _lastRechargedChanceName = null;
    _eliminatedOptions.clear();
  }

  void _startQuestionTimer() {
    _stopQuestionTimer();
    if (_mode != QuizMode.threeOut) return;
    _remainingSeconds = defaultQuestionSeconds;
    _extraTimeSeconds = 0;
    _isTimedOut = false;
    _questionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_showExplanation || isGameOver) {
        timer.cancel();
        return;
      }
      if (_remainingSeconds > 1) {
        _remainingSeconds--;
        notifyListeners();
      } else {
        _remainingSeconds = 0;
        timer.cancel();
        _handleTimeout();
      }
    });
  }

  void _stopQuestionTimer() {
    _questionTimer?.cancel();
    _questionTimer = null;
  }

  void _handleTimeout() {
    if (_showExplanation || isGameOver || currentQuestion == null) return;
    _isTimedOut = true;
    _atBats++;
    _answerCorrectness[_currentQuestionIndex] = false;
    _currentCombo = 0;
    _outs++;
    _lastHitType = HitType.out;
    _lastRunsScored = 0;
    _lastWasClutch = false;
    _showExplanation = true;
    notifyListeners();
  }

  // ====== 퀴즈 시작 ======
  Future<void> startQuiz(
    String category, {
    int questionCount = 10,
    QuizMode mode = QuizMode.normal,
    bool? isDefendingBattingKing,
  }) async {
    if (isDefendingBattingKing != null) {
      _isDefendingBattingKing = isDefendingBattingKing;
    }
    if (category == '랜덤') {
      await startRandomQuiz(
        questionCount: mode == QuizMode.threeOut ? 20 : questionCount,
        mode: mode,
        isDefendingBattingKing: _isDefendingBattingKing,
      );
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      _selectedCategory = category;
      final targetCount = mode == QuizMode.threeOut ? 20 : questionCount;

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
      var candidates = _allQuestions
          .where((q) => !lastPlayedIds.contains(q.quizId))
          .toList();

      // 응원가 카테고리의 경우 최신(리스트 뒷부분) 문제 우선순위 부여
      if (category.contains('응원가')) {
        // 원래 리스트에서 뒤에 있을수록 최선이므로, 역순으로 정렬해서 최신 30문제를 후보군으로 선정
        candidates = candidates.reversed.toList();
        if (candidates.length > 30) {
          candidates = candidates.take(30).toList();
        }
      }

      // 문제 섞기
      if (!category.contains('응원가')) {
        candidates.shuffle();
      }

      // 문제 선택 (후보가 부족하면 제외했던 것 중에서 보충)
      if (candidates.length >= targetCount) {
        _currentQuestions = candidates.take(targetCount).toList();
      } else {
        _currentQuestions = [...candidates];

        // 제외했던 문제들 가져와서 섞음
        final excluded = _allQuestions
            .where((q) => lastPlayedIds.contains(q.quizId))
            .toList();
        excluded.shuffle();

        // 부족한 만큼 채우기
        final needed = targetCount - candidates.length;
        _currentQuestions.addAll(excluded.take(needed).toList());
      }

      _sessionQuestionIds
        ..clear()
        ..addAll(_currentQuestions.map((q) => q.quizId));

      _resetSessionState(mode);
      _startQuestionTimer();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ==== 랜덤 퀴즈 시작(오늘의 퀴즈) ====
  Future<void> startRandomQuiz({
    int questionCount = 10,
    QuizMode mode = QuizMode.normal,
    bool? isDefendingBattingKing,
  }) async {
    if (isDefendingBattingKing != null) {
      _isDefendingBattingKing = isDefendingBattingKing;
    }
    _isLoading = true;
    notifyListeners();

    try {
      _selectedCategory = '랜덤';
      final targetCount = mode == QuizMode.threeOut ? 20 : questionCount;

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
      _allQuestions = allQuestions;

      // 직전에 푼 문제 제외
      final candidates = allQuestions
          .where((q) => !lastPlayedIds.contains(q.quizId))
          .toList();

      candidates.shuffle();

      if (candidates.length >= targetCount) {
        _currentQuestions = candidates.take(targetCount).toList();
      } else {
        _currentQuestions = [...candidates];
        final excluded = allQuestions
            .where((q) => lastPlayedIds.contains(q.quizId))
            .toList();
        excluded.shuffle();
        final needed = targetCount - candidates.length;
        _currentQuestions.addAll(excluded.take(needed));
      }

      _sessionQuestionIds
        ..clear()
        ..addAll(_currentQuestions.map((q) => q.quizId));

      _resetSessionState(mode);
      _startQuestionTimer();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ==== 답변 선택 ====
  void selectAnswer(int optionIndex) {
    if (currentQuestion == null || _showExplanation || isGameOver) return;
    _stopQuestionTimer();
    _lastRechargedChanceName = null;

    // 답변 저장
    _userAnswers[_currentQuestionIndex] = optionIndex;
    _atBats++;

    final elapsedRaw = _questionStartTime != null
        ? DateTime.now().difference(_questionStartTime!).inMilliseconds / 1000.0
        : 10.0;
    final elapsed = (elapsedRaw - _extraTimeSeconds).clamp(0.0, 60.0);
    _totalResponseSeconds += elapsed;

    // 정답 체크
    final isCorrect = optionIndex == currentQuestion!.correctIndex;
    _answerCorrectness[_currentQuestionIndex] = isCorrect;

    // === 점수 및 진루 계산 로직 ===
    if (isCorrect) {
      final wasClutch = isClutchTime;
      final difficulty = currentQuestion!.difficulty;

      // 1. 기본 점수 (+10)
      int questionPoints = 10;
      _baseScore += 10;

      // 2. 난이도 보너스 (hard:+10, medium:+5)
      if (difficulty == 'hard') {
        _difficultyBonus += 10;
        questionPoints += 10;
      } else if (difficulty == 'medium') {
        _difficultyBonus += 5;
        questionPoints += 5;
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

      // 4. 스피드 보너스
      if (_questionStartTime != null) {
        if (elapsed <= 5) {
          _speedBonus += 10;
          questionPoints += 10;
        } else if (elapsed <= 10) {
          _speedBonus += 5;
          questionPoints += 5;
        }
      }

      // 5. 타격 판정 및 주자 진루
      // - 10연속 안타: 홈런 (4루타)
      // - 3연속 안타 이상: 진루 가속 (최소 2루타 이상)
      // - hard + 3초 이내: 홈런 / hard 또는 3초 이내: 2루타 / 그 외 1루타
      final HitType hitType;
      final int basesToAdvance;
      if (_currentCombo >= 10 || (difficulty == 'hard' && elapsed <= 3.0)) {
        hitType = HitType.homeRun;
        basesToAdvance = 4;
      } else if (_currentCombo >= 3 ||
          difficulty == 'hard' ||
          elapsed <= 3.0) {
        hitType = HitType.double;
        basesToAdvance = 2;
      } else {
        hitType = HitType.single;
        basesToAdvance = 1;
      }

      // 5연속 안타 마일스톤 달성 시 소모한 찬스 카드 1장 재충전
      if (_currentCombo >= 5 && _currentCombo % 5 == 0) {
        if (_videoReviewUseCount > 0) {
          _videoReviewUseCount--;
          _lastRechargedChanceName = '비디오 판독';
        } else if (_usedPinchHitter) {
          _usedPinchHitter = false;
          _lastRechargedChanceName = '대타 기용';
        } else if (_mode == QuizMode.threeOut && _usedTimeout) {
          _usedTimeout = false;
          _lastRechargedChanceName = '작전 타임';
        }
      }

      _hits++;
      if (hitType == HitType.double) _doubles++;
      if (hitType == HitType.homeRun) _homeRuns++;

      final runsScored = _advanceRunners(basesToAdvance);
      _rbi += runsScored;
      _runs += runsScored;
      final runPts = runsScored * 15;
      _runBonus += runPts;
      questionPoints += runPts;

      // 6. 9회말 2사 만루 클러치 2X 보너스
      if (wasClutch) {
        _clutchHits++;
        _clutchBonus += questionPoints;
        _lastWasClutch = true;
      } else {
        _lastWasClutch = false;
      }

      if (_outs == 2) {
        _twoOutSurvivalStreak++;
      }

      _lastHitType = hitType;
      _lastRunsScored = runsScored;

      if (_mode == QuizMode.threeOut) {
        _inning = 1 + (_hits ~/ 3);
      }
    } else {
      // 오답 시 콤보 리셋 및 아웃 증가
      _currentCombo = 0;
      _outs++;
      _lastHitType = HitType.out;
      _lastRunsScored = 0;
      _lastWasClutch = false;
    }

    // 해설 표시
    _showExplanation = true;

    notifyListeners();
  }

  int _advanceRunners(int basesToAdvance) {
    int runsScored = 0;
    final nextBases = [false, false, false];

    for (int i = 2; i >= 0; i--) {
      if (_bases[i]) {
        final nextPos = i + basesToAdvance;
        if (nextPos >= 3) {
          runsScored++;
        } else {
          nextBases[nextPos] = true;
        }
      }
    }

    if (basesToAdvance >= 4) {
      runsScored++;
    } else {
      nextBases[basesToAdvance - 1] = true;
    }

    _bases = nextBases;
    return runsScored;
  }

  // ==== 야구 찬스 카드 3종 (경기당 각 1회, 디펜딩 타격왕은 비디오 판독 2회) ====
  bool useVideoReview() {
    if (isGameOver ||
        usedVideoReview ||
        _showExplanation ||
        currentQuestion == null) {
      return false;
    }
    final correctIdx = currentQuestion!.correctIndex;
    final wrongIndices = <int>[];
    for (int i = 0; i < currentQuestion!.options.length; i++) {
      if (i != correctIdx) wrongIndices.add(i);
    }
    wrongIndices.shuffle(Random());
    _eliminatedOptions = wrongIndices.take(2).toSet();
    _videoReviewUseCount++;
    notifyListeners();
    return true;
  }

  Future<bool> usePinchHitter() async {
    if (isGameOver ||
        _usedPinchHitter ||
        _showExplanation ||
        currentQuestion == null) {
      return false;
    }
    _stopQuestionTimer();
    _usedPinchHitter = true;

    // 무한 풀 또는 대체 문제 확보
    if (_currentQuestionIndex >= _currentQuestions.length - 1) {
      _replenishQuestionsIfNeeded(force: true);
    }
    if (_currentQuestionIndex < _currentQuestions.length - 1) {
      _currentQuestions.removeAt(_currentQuestionIndex);
    }
    _eliminatedOptions.clear();
    _lastRechargedChanceName = null;
    _extraTimeSeconds = 0;
    _questionStartTime = DateTime.now();
    _startQuestionTimer();
    notifyListeners();
    return true;
  }

  bool useTimeout() {
    if (isGameOver ||
        _usedTimeout ||
        _showExplanation ||
        _mode != QuizMode.threeOut) {
      return false;
    }
    _usedTimeout = true;
    _remainingSeconds += 5;
    _extraTimeSeconds += 5;
    notifyListeners();
    return true;
  }

  void _replenishQuestionsIfNeeded({bool force = false}) {
    if (_isReplenishing || _allQuestions.isEmpty) return;
    if (!force && _currentQuestions.length - _currentQuestionIndex > 5) return;

    _isReplenishing = true;
    try {
      var pool = _allQuestions
          .where((q) => !_sessionQuestionIds.contains(q.quizId))
          .toList();
      if (pool.isEmpty) {
        pool = List<QuizQuestionModel>.from(_allQuestions);
      }
      pool.shuffle();
      final batch = pool.take(15).toList();
      _currentQuestions.addAll(batch);
      _sessionQuestionIds.addAll(batch.map((q) => q.quizId));
    } finally {
      _isReplenishing = false;
    }
  }

  // ==== 다음 문제로 ====
  void nextQuestion() {
    if (isGameOver) return;
    if (_mode == QuizMode.threeOut) {
      _replenishQuestionsIfNeeded();
    }
    if (_currentQuestionIndex < _currentQuestions.length - 1) {
      _currentQuestionIndex++;
      _showExplanation = false;
      _eliminatedOptions.clear();
      _lastRechargedChanceName = null;
      _extraTimeSeconds = 0;
      _isTimedOut = false;
      _questionStartTime = DateTime.now();
      _startQuestionTimer();
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

  String _computeBoxScoreTitle() {
    final avg = _atBats > 0 ? _hits / _atBats : 0.0;
    final singles = (_hits - _doubles - _triples - _homeRuns).clamp(0, _hits);
    final slg = _atBats > 0
        ? (singles + _doubles * 2 + _triples * 3 + _homeRuns * 4) / _atBats
        : 0.0;
    final avgResp = _atBats > 0 ? _totalResponseSeconds / _atBats : 99.0;

    if (_mode == QuizMode.threeOut &&
        _inning >= 9 &&
        avg >= 0.8 &&
        _homeRuns >= 3) {
      return '🏆 미스터 옥토버';
    }
    if (_homeRuns >= 3 || (_atBats >= 5 && slg >= 2.0)) {
      return '💣 거포 클린업';
    }
    if (_clutchHits > 0 || _rbi >= 3) {
      return '🔥 클러치 히터';
    }
    if (avg >= 0.7 && avgResp <= 5.0) {
      return '⚡ 테이블 세터';
    }
    if (_twoOutSurvivalStreak >= 5) {
      return '🛡️ 끈질긴 승부사';
    }
    return '⚾ 육성 선수';
  }

  QuizBoxScoreModel buildBoxScore() {
    return QuizBoxScoreModel(
      atBats: _atBats,
      hits: _hits,
      doubles: _doubles,
      triples: _triples,
      homeRuns: _homeRuns,
      rbi: _rbi,
      runs: _runs,
      maxCombo: _maxCombo,
      inningsReached: _mode == QuizMode.threeOut ? _inning : 9,
      clutchHits: _clutchHits,
      title: _computeBoxScoreTitle(),
    );
  }

  // ==== 퀴즈 완료 및 결과 저장 ====
  Future<QuizResultModel> completeQuiz(String? userNickName) async {
    if (_quizStartTime == null || _selectedCategory == null) {
      throw Exception('퀴즈가 시작되지 않았습니다');
    }
    _stopQuestionTimer();

    // 소요 시간 계산
    final timeTaken = DateTime.now().difference(_quizStartTime!);

    // 실제 푼 문제 ID 목록 (서바이벌 모드에서 미출제 잔여 문제 제외)
    final answeredQuestionIds = <String>[];
    final answerResults = <String, bool>{};
    _answerCorrectness.forEach((index, isCorrect) {
      if (index >= 0 && index < _currentQuestions.length) {
        final qId = _currentQuestions[index].quizId;
        answeredQuestionIds.add(qId);
        answerResults[qId] = isCorrect;
      }
    });
    final questionIds = answeredQuestionIds.isNotEmpty
        ? answeredQuestionIds
        : _currentQuestions.map((q) => q.quizId).toList();

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

    final boxScore = buildBoxScore();
    final effectiveTotal = _mode == QuizMode.threeOut
        ? (_atBats > 0 ? _atBats : questionIds.length)
        : totalQuestions;
    final effectiveAtBats = _atBats > 0 ? _atBats : effectiveTotal;
    final effectiveHits = (_atBats > 0 || _hits > 0) ? _hits : correctCount;

    // 결과 객체 생성 (다시하기를 위해 원본 카테고리 보존)
    final result = QuizResultModel(
      userId: _auth.currentUser?.uid ?? '',
      userNickName: userNickName ?? '',
      category: _selectedCategory!, // 원본 카테고리 (인트로/가사 등)
      totalQuestions: effectiveTotal,
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
      mode: _mode == QuizMode.threeOut ? 'threeOut' : 'normal',
      outsCount: _outs,
      boxScore: boxScore,
      atBats: effectiveAtBats,
      hits: effectiveHits,
    );

    // Firestore에 저장
    try {
      final userId = _auth.currentUser?.uid;
      if (userId != null) {
        final firestoreData = result.toJson();
        firestoreData['category'] =
            finalCategory; // Firestore에는 랭킹용 통합 카테고리로 저장

        // 1. 개별 결과 저장 (일반/3아웃 모두 quizResultsSub에 저장하되 mode 필드로 구분)
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

          // 너무 많으면 오래된 것부터 삭제 (최대 180개 추적)
          if (currentIds.length > 180) {
            currentIds = currentIds.sublist(currentIds.length - 180);
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
          .where((result) => result.category != '일일미션 보상')
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
    _sessionQuestionIds.clear();
    _selectedCategory = null;
    _resetSessionState(QuizMode.normal);
    notifyListeners();
  }

  @override
  void dispose() {
    _stopQuestionTimer();
    super.dispose();
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

      _myHistory = snapshot.docs
          .map((doc) {
            return QuizResultModel.fromJson(doc.data());
          })
          .where((result) => result.category != '일일미션 보상')
          .toList();
    } catch (e) {
      print('퀴즈 기록 가져오기 실패: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
