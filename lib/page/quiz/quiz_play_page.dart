import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/page/quiz/quiz_result_page.dart';
import 'package:lockerroom/provider/quiz_provider.dart';
import 'package:lockerroom/provider/team_provider.dart';
import 'package:lockerroom/provider/user_provider.dart';
import 'package:provider/provider.dart';

import 'package:shared_preferences/shared_preferences.dart';

class QuizPlayPage extends StatefulWidget {
  final String category;
  final QuizMode mode;
  const QuizPlayPage({
    super.key,
    required this.category,
    this.mode = QuizMode.normal,
  });

  @override
  State<QuizPlayPage> createState() => _QuizPlayPageState();
}

class _QuizPlayPageState extends State<QuizPlayPage> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _isQuestionVisible = true; // 가사 퀴즈용 시퀀셜 노출 제어
  bool _isFinishing = false;
  bool _autoFinishScheduled = false;
  bool _showThreeOutBriefing = false;
  bool _showPlayBallOverlay = false;
  bool _dontShowBriefingAgain = false;

  // 스트림 구독 저장
  StreamSubscription? _durationSubscription;
  StreamSubscription? _positionSubscription;
  StreamSubscription? _stateSubscription;
  StreamSubscription? _completeSubscription;

  @override
  void initState() {
    super.initState();

    // 오디오 플레이어 리스너 설정
    _durationSubscription = _audioPlayer.onDurationChanged.listen((duration) {
      if (mounted) setState(() => _duration = duration);
    });

    _positionSubscription = _audioPlayer.onPositionChanged.listen((position) {
      if (mounted) setState(() => _position = position);
    });

    _stateSubscription = _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _isPlaying = state == PlayerState.playing);
    });

    _completeSubscription = _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _position = Duration.zero;
          _isQuestionVisible = true; // 노래 끝나면 문제 노출
        });
      }
    });

    // 퀴즈 시작
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      if (widget.mode == QuizMode.threeOut) {
        final prefs = await SharedPreferences.getInstance();
        final skipBriefing = prefs.getBool('skip_three_out_briefing') ?? false;
        if (!mounted) return;
        if (!skipBriefing) {
          setState(() => _showThreeOutBriefing = true);
          return;
        }
        await _triggerPlayBallAndStart();
      } else {
        await _beginQuizSession();
      }
    });
  }

  Future<void> _triggerPlayBallAndStart() async {
    if (!mounted) return;
    if (_dontShowBriefingAgain) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('skip_three_out_briefing', true);
    }
    setState(() {
      _showThreeOutBriefing = false;
      _showPlayBallOverlay = true;
    });

    try {
      await _audioPlayer.stop();
      await _audioPlayer.play(AssetSource('audio/playball.m4a'));
    } catch (e) {
      debugPrint('PLAYBALL 사운드 재생 오류: $e');
    }

    await Future.delayed(const Duration(milliseconds: 1100));
    if (!mounted) return;
    setState(() => _showPlayBallOverlay = false);
    await _beginQuizSession();
  }

  Future<void> _beginQuizSession() async {
    if (!mounted) return;
    final provider = context.read<QuizProvider>();
    await provider.startQuiz(widget.category, mode: widget.mode);
    if (!mounted) return;

    // 카테고리별 팝업 및 재생 설정
    if (widget.category == '응원가(인트로)') {
      _checkAndShowCheerSongPopup();
    } else if (widget.category == '응원가(가사)') {
      setState(() => _isQuestionVisible = false); // 시작 시 숨김
      _checkAndShowLyricsQuizPopup();
    } else {
      // 기타 카테고리: 첫 문제에 오디오가 있으면 자동 재생
      if (provider.currentQuestion?.audioPath != null) {
        _playAudio(provider.currentQuestion!.audioPath!);
      }
    }
  }

  // 팝업 표시 여부 확인 및 표시
  Future<void> _checkAndShowCheerSongPopup() async {
    final prefs = await SharedPreferences.getInstance();
    final bool dontShowAgain = prefs.getBool('dontShowCheerSongPopup') ?? false;

    if (!dontShowAgain) {
      if (mounted) _showCheerSongGuidePopup();
    } else {
      // 팝업 안 띄우는 경우 바로 재생
      final provider = context.read<QuizProvider>();
      if (provider.currentQuestion?.audioPath != null) {
        _playAudio(provider.currentQuestion!.audioPath!);
      }
    }
  }

  // 응원가 퀴즈 설명 팝업
  void _showCheerSongGuidePopup() {
    final isDarkMode =
        MediaQuery.of(context).platformBrightness == Brightness.dark;
    bool isChecked = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            backgroundColor: isDarkMode ? const Color(0xFF1E293B) : WHITE,
            title: Row(
              children: [
                Icon(
                  Icons.music_note,
                  color: context.read<TeamProvider>().selectedTeam?.color,
                  size: 28,
                ),
                const SizedBox(width: 8),
                Text(
                  '응원가 퀴즈 안내',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'kbo',
                    color: isDarkMode ? WHITE : BLACK,
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildGuideItem('🎵', '응원가는 자동으로 재생됩니다'),
                  const SizedBox(height: 12),
                  _buildGuideItem('⏱️', '응원가는 1초~5초 정도로 짧아요'),
                  const SizedBox(height: 12),
                  _buildGuideItem('🔊', '이어폰 또는 스피커로 들으시면 더 좋아요'),
                  const SizedBox(height: 12),
                  _buildGuideItem('🤔', '응원가를 듣고 어느 팀의 응원가인지 맞춰보세요'),
                  const SizedBox(height: 12),
                  _buildGuideItem('🔁', '여러 번 재생할 수 있어요'),
                  const SizedBox(height: 20),
                  // 다시 보지 않기 체크박스
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        isChecked = !isChecked;
                      });
                    },
                    child: Row(
                      children: [
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: Checkbox(
                            value: isChecked,
                            activeColor: context
                                .read<TeamProvider>()
                                .selectedTeam
                                ?.color,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                            onChanged: (value) {
                              setState(() {
                                isChecked = value ?? false;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          '다시 보지 않기',
                          style: TextStyle(
                            color: GRAYSCALE_LABEL_600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    if (isChecked) {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setBool('dontShowCheerSongPopup', true);
                    }
                    if (!context.mounted) return;
                    Navigator.pop(context);
                    // 팝업 닫은 후 첫 문제 오디오 재생
                    final provider = context.read<QuizProvider>();
                    if (provider.currentQuestion?.audioPath != null) {
                      _playAudio(provider.currentQuestion!.audioPath!);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context
                        .read<TeamProvider>()
                        .selectedTeam
                        ?.color,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text(
                    '확인',
                    style: TextStyle(
                      color: WHITE,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'kbo',
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // 가사 퀴즈 팝업 확인
  Future<void> _checkAndShowLyricsQuizPopup() async {
    final prefs = await SharedPreferences.getInstance();
    final bool dontShowAgain =
        prefs.getBool('dontShowLyricsQuizPopup') ?? false;

    if (!dontShowAgain) {
      if (mounted) _showLyricsQuizGuidePopup();
    } else {
      // 팝업 안 띄우는 경우 바로 재생
      final provider = context.read<QuizProvider>();
      if (provider.currentQuestion?.audioPath != null) {
        _playAudio(provider.currentQuestion!.audioPath!);
      }
    }
  }

  // 가사 퀴즈 설명 팝업
  void _showLyricsQuizGuidePopup() {
    final isDarkMode =
        MediaQuery.of(context).platformBrightness == Brightness.dark;
    bool isChecked = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            backgroundColor: isDarkMode ? const Color(0xFF1E293B) : WHITE,
            title: Row(
              children: [
                Icon(
                  Icons.lyrics,
                  color: context.read<TeamProvider>().selectedTeam?.color,
                  size: 28,
                ),
                const SizedBox(width: 8),
                Text(
                  '가사 퀴즈 안내',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'kbo',
                    color: isDarkMode ? WHITE : BLACK,
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildGuideItem('🎵', '노래가 자동으로 재생됩니다'),
                const SizedBox(height: 12),
                _buildGuideItem('👂', '가사를 잘 듣고 빈칸을 맞춰보세요'),
                const SizedBox(height: 12),
                _buildGuideItem('⌨️', '주관식이 아닌 객관식으로 진행됩니다'),
                const SizedBox(height: 20),
                // 다시 보지 않기 체크박스
                GestureDetector(
                  onTap: () {
                    setState(() {
                      isChecked = !isChecked;
                    });
                  },
                  child: Row(
                    children: [
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: Checkbox(
                          value: isChecked,
                          activeColor: context
                              .read<TeamProvider>()
                              .selectedTeam
                              ?.color,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                          onChanged: (value) {
                            setState(() {
                              isChecked = value ?? false;
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        '다시 보지 않기',
                        style: TextStyle(
                          color: GRAYSCALE_LABEL_600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    if (isChecked) {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setBool('dontShowLyricsQuizPopup', true);
                    }
                    if (!context.mounted) return;
                    Navigator.pop(context);
                    // 팝업 닫은 후 첫 문제 오디오 재생
                    final provider = context.read<QuizProvider>();
                    if (provider.currentQuestion?.audioPath != null) {
                      _playAudio(provider.currentQuestion!.audioPath!);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context
                        .read<TeamProvider>()
                        .selectedTeam
                        ?.color,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text(
                    '시작하기',
                    style: TextStyle(
                      color: WHITE,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'kbo',
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // 가이드 아이템 빌더
  Widget _buildGuideItem(String emoji, String text) {
    final isDarkMode =
        MediaQuery.of(context).platformBrightness == Brightness.dark;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 20)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              height: 1.4,
              color: isDarkMode ? Colors.white70 : GRAYSCALE_LABEL_800,
            ),
          ),
        ),
      ],
    );
  }

  @override
  void didUpdateWidget(QuizPlayPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 카테고리가 변경되면 오디오 정지
    if (oldWidget.category != widget.category) {
      _audioPlayer.stop();
    }
  }

  // 오디오 재생 헬퍼 메서드
  Future<void> _playAudio(String audioPath) async {
    await _audioPlayer.stop(); // 기존 재생 중지
    await _audioPlayer.play(AssetSource(audioPath));
  }

  @override
  void dispose() {
    // 스트림 구독 취소
    _durationSubscription?.cancel();
    _positionSubscription?.cancel();
    _stateSubscription?.cancel();
    _completeSubscription?.cancel();

    _audioPlayer.dispose(); // 메모리 누수 방지
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode =
        MediaQuery.of(context).platformBrightness == Brightness.dark;
    final teamProvider = context.read<TeamProvider>();
    final selectedTeamColor = teamProvider.selectedTeam?.color;
    if (_showPlayBallOverlay) {
      return _buildPlayBallOverlay(selectedTeamColor ?? BUTTON);
    }
    if (_showThreeOutBriefing) {
      return _buildThreeOutBriefingScreen(
        selectedTeamColor ?? BUTTON,
        isDarkMode,
      );
    }
    return Consumer<QuizProvider>(
      builder: (context, quizProvider, child) {
        if (quizProvider.isLoading) {
          return Scaffold(
            backgroundColor: isDarkMode
                ? const Color(0xFF0F172A)
                : BACKGROUND_COLOR,
            body: Center(child: CircularProgressIndicator(color: BUTTON)),
          );
        }

        final question = quizProvider.currentQuestion;
        if (question == null) {
          return Scaffold(
            backgroundColor: isDarkMode
                ? const Color(0xFF0F172A)
                : BACKGROUND_COLOR,
            body: const Center(child: Text('문제를 불러올 수 없습니다.')),
          );
        }

        if (quizProvider.isGameOver && !_isFinishing && !_autoFinishScheduled) {
          _autoFinishScheduled = true;
          Future.delayed(const Duration(milliseconds: 800), () {
            if (mounted && !_isFinishing) {
              _finishQuiz(this.context, quizProvider);
            }
          });
        }

        return Scaffold(
          backgroundColor: isDarkMode
              ? const Color(0xFF090D16)
              : BACKGROUND_COLOR,
          appBar: AppBar(
            toolbarHeight: 46,
            backgroundColor: isDarkMode
                ? const Color(0xFF090D16)
                : BACKGROUND_COLOR,
            elevation: 0,
            scrolledUnderElevation: 0,
            title: Text(
              widget.category,
              style: TextStyle(
                fontSize: 17,
                fontFamily: 'kbo',
                fontWeight: FontWeight.bold,
                color: isDarkMode ? WHITE : BLACK,
              ),
            ),
            leading: IconButton(
              onPressed: () {
                Navigator.pop(context);
              },
              icon: Icon(
                Icons.arrow_back_ios,
                size: 19,
                color: isDarkMode ? WHITE : BLACK,
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 16.0),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isDarkMode
                          ? Colors.white.withValues(alpha: 0.06)
                          : GRAYSCALE_LABEL_100,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      quizProvider.isThreeOutMode
                          ? '${quizProvider.inning}회 · AVG ${quizProvider.formattedBattingAverage}'
                          : '${quizProvider.currentQuestionsIndex + 1}/${quizProvider.totalQuestions}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'kbo',
                        color: isDarkMode ? const Color(0xFFF5C451) : BLACK,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          body: Column(
            children: [
              // 진행도 바
              LinearProgressIndicator(
                value: quizProvider.isThreeOutMode
                    ? (quizProvider.remainingSeconds /
                              QuizProvider.defaultQuestionSeconds)
                          .clamp(0.0, 1.0)
                    : quizProvider.progress,
                backgroundColor: isDarkMode
                    ? Colors.white10
                    : GRAYSCALE_LABEL_200,
                valueColor: AlwaysStoppedAnimation<Color>(
                  quizProvider.isThreeOutMode &&
                          quizProvider.remainingSeconds <= 5
                      ? RED_DANGER_TEXT_50
                      : (selectedTeamColor ?? BLUE_SECONDARY_600),
                ),
                minHeight: 4,
              ),
              _buildBaseballHud(quizProvider, isDarkMode),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final needsScroll =
                        constraints.maxHeight < 410 ||
                        question.imageUrl != null ||
                        quizProvider.showExplanation;

                    final content = Padding(
                      padding: const EdgeInsets.fromLTRB(14, 6, 14, 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 난이도 배지 + 문제 번호
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 9,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: _getDifficultyColor(
                                    question.difficulty,
                                  ),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  _getDifficultyText(question.difficulty),
                                  style: const TextStyle(
                                    color: WHITE,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '타석 #${quizProvider.currentQuestionsIndex + 1}',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: isDarkMode
                                      ? Colors.white54
                                      : GRAYSCALE_LABEL_500,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          if (_isQuestionVisible ||
                              quizProvider.showExplanation) ...[
                            Builder(
                              builder: (context) {
                                String questionDisplay = question.question;
                                final isLyricType =
                                    widget.category == '응원가(가사)';

                                if (isLyricType &&
                                    quizProvider.showExplanation) {
                                  final correctOption =
                                      question.options[question.correctIndex];
                                  if (questionDisplay.contains('(')) {
                                    questionDisplay = questionDisplay
                                        .replaceAll(
                                          RegExp(r'\(.*?\)'),
                                          '[$correctOption]',
                                        );
                                  } else {
                                    questionDisplay =
                                        '$questionDisplay\n👉 정답: $correctOption';
                                  }
                                }

                                return Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 11,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isDarkMode
                                        ? const Color(0xFF131B2E)
                                        : WHITE,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: isDarkMode
                                          ? Colors.white10
                                          : GRAYSCALE_LABEL_200,
                                    ),
                                  ),
                                  child: Text(
                                    questionDisplay,
                                    maxLines: needsScroll ? null : 4,
                                    overflow: needsScroll
                                        ? TextOverflow.visible
                                        : TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: isLyricType ? 16.5 : 17.5,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'kbo',
                                      height: 1.35,
                                      color: isDarkMode ? WHITE : BLACK,
                                    ),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 10),

                            if (question.imageUrl != null) ...[
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(
                                  question.imageUrl!,
                                  width: double.infinity,
                                  height: 140,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              const SizedBox(height: 10),
                            ],
                          ],

                          if (question.audioPath != null) ...[
                            _buildAudioPlayer(question.audioPath!),
                            const SizedBox(height: 8),
                          ],

                          if (_isQuestionVisible ||
                              quizProvider.showExplanation) ...[
                            if (needsScroll)
                              Column(
                                children: List.generate(
                                  question.options.length,
                                  (index) => _buildOptionButton(
                                    context,
                                    quizProvider,
                                    index,
                                    question.options[index],
                                  ),
                                ),
                              )
                            else
                              Expanded(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: List.generate(
                                    question.options.length,
                                    (index) => Expanded(
                                      child: _buildOptionButton(
                                        context,
                                        quizProvider,
                                        index,
                                        question.options[index],
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                            // 야구 찬스 카드 3종 (비디오 판독, 대타 기용, 작전 타임)
                            _buildChanceCardsRow(quizProvider, isDarkMode),

                            if (quizProvider.showExplanation) ...[
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      quizProvider.isCurrentAnswerCorrect ==
                                          true
                                      ? GREEN_SUCCESS_SURFACE_5
                                      : RED_DANGER_SURFACE_5,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color:
                                        quizProvider.isCurrentAnswerCorrect ==
                                            true
                                        ? GREEN_SUCCESS_BORDER_10
                                        : RED_DANGER_BORDER_10,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          quizProvider.isCurrentAnswerCorrect ==
                                                  true
                                              ? Icons.check_circle
                                              : Icons.cancel,
                                          size: 17,
                                          color:
                                              quizProvider
                                                      .isCurrentAnswerCorrect ==
                                                  true
                                              ? GREEN_SUCCESS_TEXT_50
                                              : RED_DANGER_TEXT_50,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          quizProvider.isCurrentAnswerCorrect ==
                                                  true
                                              ? '정답입니다!'
                                              : '오답입니다',
                                          style: TextStyle(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.bold,
                                            fontFamily: 'kbo',
                                            color:
                                                quizProvider
                                                        .isCurrentAnswerCorrect ==
                                                    true
                                                ? GREEN_SUCCESS_TEXT_50
                                                : RED_DANGER_TEXT_50,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      question.explanation,
                                      style: const TextStyle(
                                        fontSize: 12.5,
                                        height: 1.4,
                                        color: GRAYSCALE_LABEL_900,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 6),
                            ],
                          ],
                        ],
                      ),
                    );

                    if (needsScroll) {
                      return SingleChildScrollView(child: content);
                    }
                    return content;
                  },
                ),
              ),

              // 하단 버튼
              SafeArea(
                top: false,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
                  decoration: BoxDecoration(
                    color: isDarkMode ? const Color(0xFF090D16) : WHITE,
                    border: Border(
                      top: BorderSide(
                        color: isDarkMode
                            ? Colors.white10
                            : GRAYSCALE_LABEL_100,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      // 이전 버튼 (3아웃 서바이벌 모드에서는 숨김)
                      if (!quizProvider.isThreeOutMode &&
                          quizProvider.currentQuestionsIndex > 0)
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              quizProvider.previousQuestion();
                              if (widget.category == '응원가(가사)') {
                                setState(() => _isQuestionVisible = true);
                              }
                            },
                            child: Container(
                              alignment: Alignment.center,
                              width: double.infinity,
                              height: 48,
                              decoration: BoxDecoration(
                                color: isDarkMode
                                    ? const Color(0xFF151E32)
                                    : WHITE,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isDarkMode
                                      ? Colors.white12
                                      : GRAYSCALE_LABEL_300,
                                ),
                              ),
                              child: Text(
                                '이전',
                                style: TextStyle(
                                  fontFamily: 'kbo',
                                  fontWeight: FontWeight.bold,
                                  color: isDarkMode
                                      ? Colors.white
                                      : Colors.black,
                                ),
                              ),
                            ),
                          ),
                        ),

                      if (!quizProvider.isThreeOutMode &&
                          quizProvider.currentQuestionsIndex > 0)
                        const SizedBox(width: 10),

                      // 다음 또는 완료 버튼
                      Expanded(
                        flex:
                            (!quizProvider.isThreeOutMode &&
                                quizProvider.currentQuestionsIndex > 0)
                            ? 1
                            : 2,
                        child: GestureDetector(
                          onTap: quizProvider.showExplanation
                              ? () => _handleNextOrFinish(context, quizProvider)
                              : null,
                          child: Container(
                            alignment: Alignment.center,
                            width: double.infinity,
                            height: 48,
                            decoration: BoxDecoration(
                              color: quizProvider.showExplanation
                                  ? selectedTeamColor
                                  : (isDarkMode
                                        ? Colors.white10
                                        : GRAYSCALE_LABEL_200),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Text(
                              (quizProvider.isGameOver ||
                                      (!quizProvider.isThreeOutMode &&
                                          quizProvider.currentQuestionsIndex ==
                                              quizProvider.totalQuestions - 1))
                                  ? (quizProvider.isGameOver
                                        ? '경기 종료 · 기록지 보기'
                                        : '완료')
                                  : '다음 타석',
                              style: TextStyle(
                                color: quizProvider.showExplanation
                                    ? WHITE
                                    : (isDarkMode
                                          ? Colors.white38
                                          : GRAYSCALE_LABEL_500),
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'kbo',
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPlayBallOverlay(Color teamColor) {
    final teamGradEnd =
        Color.lerp(teamColor, const Color(0xFF070B14), 0.72) ??
        const Color(0xFF070B14);

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -0.15),
            radius: 0.95,
            colors: [
              teamColor.withValues(alpha: 0.9),
              teamGradEnd,
              const Color(0xFF070B14),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.22),
                  ),
                ),
                child: const Text(
                  '1회초 · 3아웃 무한이닝',
                  style: TextStyle(
                    color: Color(0xFFE2E8F0),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.75, end: 1.0),
                duration: const Duration(milliseconds: 550),
                curve: Curves.elasticOut,
                builder: (context, scale, child) {
                  return Transform.scale(scale: scale, child: child);
                },
                child: Container(
                  width: 82,
                  height: 82,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.08),
                    border: Border.all(
                      color: const Color(0xFFF5C451).withValues(alpha: 0.55),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFF5C451).withValues(alpha: 0.3),
                        blurRadius: 28,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.sports_baseball_rounded,
                    color: Color(0xFFFFD875),
                    size: 40,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Container(
                width: 140,
                height: 3,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  gradient: const LinearGradient(
                    colors: [
                      Colors.transparent,
                      Color(0xFFF5C451),
                      Color(0xFFFF5B37),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'PLAY BALL!',
                style: TextStyle(
                  fontSize: 44,
                  fontWeight: FontWeight.w900,
                  fontStyle: FontStyle.italic,
                  fontFamily: 'kbo',
                  color: Color(0xFFFFD875),
                  letterSpacing: 1.5,
                  shadows: [
                    Shadow(
                      color: Colors.black54,
                      blurRadius: 18,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Container(
                width: 140,
                height: 3,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  gradient: const LinearGradient(
                    colors: [
                      Colors.transparent,
                      Color(0xFFF5C451),
                      Color(0xFFFF5B37),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThreeOutBriefingScreen(Color teamColor, bool isDarkMode) {
    final teamGradEnd =
        Color.lerp(teamColor, const Color(0xFF242C5E), 0.45) ?? teamColor;

    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF0F172A) : BACKGROUND_COLOR,
      appBar: AppBar(
        backgroundColor: isDarkMode
            ? const Color(0xFF0F172A)
            : BACKGROUND_COLOR,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 19,
            color: isDarkMode ? WHITE : BUTTON,
          ),
        ),
        title: Text(
          widget.category,
          style: TextStyle(
            fontFamily: 'kbo',
            fontWeight: FontWeight.w800,
            fontSize: 17,
            color: isDarkMode ? WHITE : BUTTON,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [teamColor, teamGradEnd],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: teamColor.withValues(alpha: 0.25),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.16),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: const Text(
                                  '⚾ 3아웃 무한이닝',
                                  style: TextStyle(
                                    color: WHITE,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 9,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.24),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  '경기 전 규칙 안내',
                                  style: TextStyle(
                                    color: Color(0xFFFFD875),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            '타석 입장 전 규칙 브리핑',
                            style: TextStyle(
                              color: WHITE,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              fontFamily: 'kbo',
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '‘경기 시작하기’를 누르면 15초 타이머가 시작됩니다.',
                            style: TextStyle(
                              color: WHITE.withValues(alpha: 0.84),
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildBriefingRuleCard(
                      emoji: '❌',
                      title: '3아웃 서바이벌',
                      desc: '오답 또는 15초 시간 초과 시 1 OUT! 3아웃이 되면 경기가 즉시 종료되고 타격 기록지가 집계됩니다.',
                      isDarkMode: isDarkMode,
                    ),
                    const SizedBox(height: 9),
                    _buildBriefingRuleCard(
                      emoji: '🚀',
                      title: '정답 = 진루 · 장타 · 홈런',
                      desc: '정답 시 1루타 진루! 3초 이내 스피드 정답 또는 어려움 난이도는 2루타·홈런으로 주자가 득점합니다.',
                      isDarkMode: isDarkMode,
                    ),
                    const SizedBox(height: 9),
                    _buildBriefingRuleCard(
                      emoji: '🔥',
                      title: '9회말 2사 만루 클러치 (2X)',
                      desc: '2아웃 만루 상황에서 황금 클러치 배너가 점등되며 안타 시 기록 임팩트가 2배로 반영됩니다.',
                      isDarkMode: isDarkMode,
                    ),
                    const SizedBox(height: 9),
                    _buildBriefingRuleCard(
                      emoji: '🃏',
                      title: '야구 찬스 카드 3종 (경기당 1회)',
                      desc: '비디오 판독(50:50), 대타 기용(타수 제외 패스), 작전 타임(+5초)을 전략적으로 사용하세요.',
                      isDarkMode: isDarkMode,
                    ),
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: () => setState(
                        () => _dontShowBriefingAgain = !_dontShowBriefingAgain,
                      ),
                      child: Row(
                        children: [
                          Checkbox(
                            value: _dontShowBriefingAgain,
                            activeColor: teamColor,
                            onChanged: (val) => setState(
                              () => _dontShowBriefingAgain = val ?? false,
                            ),
                          ),
                          Text(
                            '다음부터 이 안내 보지 않기',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isDarkMode
                                  ? Colors.white70
                                  : GRAYSCALE_LABEL_600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _triggerPlayBallAndStart,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: teamColor,
                    foregroundColor: WHITE,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  child: const Text(
                    '경기 시작하기 · PLAY BALL ⚾',
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'kbo',
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBriefingRuleCard({
    required String emoji,
    required String title,
    required String desc,
    required bool isDarkMode,
  }) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF151E32) : WHITE,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDarkMode ? Colors.white10 : GRAYSCALE_LABEL_100,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.white10 : BACKGROUND_COLOR,
              borderRadius: BorderRadius.circular(11),
            ),
            alignment: Alignment.center,
            child: Text(emoji, style: const TextStyle(fontSize: 17)),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'kbo',
                    color: isDarkMode ? WHITE : BUTTON,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  desc,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: isDarkMode ? Colors.white60 : GRAYSCALE_LABEL_600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 옵션 버튼 빌더
  Widget _buildOptionButton(
    BuildContext context,
    QuizProvider quizProvider,
    int index,
    String option,
  ) {
    final isDarkMode =
        MediaQuery.of(context).platformBrightness == Brightness.dark;
    final isSelected = quizProvider.currentAnswer == index;
    final isCorrect = quizProvider.currentQuestion!.correctIndex == index;
    final showResult = quizProvider.showExplanation;
    final isEliminated = quizProvider.eliminatedOptions.contains(index);

    Color backgroundColor = isDarkMode ? const Color(0xFF1E293B) : WHITE;
    Color borderColor = isDarkMode ? Colors.white12 : GRAYSCALE_LABEL_300;
    Color textColor = isDarkMode ? WHITE : GRAYSCALE_LABEL_900;

    if (showResult) {
      if (isCorrect) {
        backgroundColor = GREEN_SUCCESS_SURFACE_5;
        borderColor = GREEN_SUCCESS_BORDER_10;
        textColor = GREEN_SUCCESS_TEXT_50;
      } else if (isSelected && !isCorrect) {
        backgroundColor = RED_DANGER_SURFACE_5;
        borderColor = RED_DANGER_BORDER_10;
        textColor = RED_DANGER_TEXT_50;
      }
    } else if (isEliminated) {
      backgroundColor = isDarkMode
          ? Colors.white.withOpacity(0.03)
          : GRAYSCALE_LABEL_100;
      borderColor = isDarkMode ? Colors.white10 : GRAYSCALE_LABEL_200;
      textColor = GRAYSCALE_LABEL_400;
    } else if (isSelected) {
      backgroundColor = BLUE_SECONDARY_200;
      borderColor = BLUE_SECONDARY_600;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 7.0),
      child: Opacity(
        opacity: isEliminated && !showResult ? 0.45 : 1.0,
        child: GestureDetector(
          onTap: (showResult || isEliminated)
              ? null
              : () => quizProvider.selectAnswer(index),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor, width: 1.5),
            ),
            child: Row(
              children: [
                // 문제 번호
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: showResult && isCorrect
                        ? GREEN_SUCCESS_TEXT_50
                        : showResult && isSelected
                        ? RED_DANGER_TEXT_50
                        : isSelected
                        ? BLUE_SECONDARY_600
                        : (isDarkMode
                              ? GRAYSCALE_LABEL_500
                              : GRAYSCALE_LABEL_300),
                  ),
                  child: Center(
                    child: Text(
                      String.fromCharCode(65 + index),
                      style: TextStyle(
                        fontSize: 12.5,
                        color: isDarkMode ? BLACK : WHITE,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'kbo',
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // 옵션 텍스트
                Expanded(
                  child: Text(
                    option,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.w500,
                      color: textColor,
                    ),
                  ),
                ),

                // 정답/오답 아이콘
                if (showResult && (isCorrect || isSelected))
                  Icon(
                    isCorrect ? Icons.check_circle : Icons.cancel,
                    size: 19,
                    color: isCorrect
                        ? GREEN_SUCCESS_TEXT_50
                        : RED_DANGER_TEXT_50,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _finishQuiz(
    BuildContext _,
    QuizProvider quizProvider,
  ) async {
    if (_isFinishing) return;
    _isFinishing = true;
    final stateContext = this.context;
    final userNickName = stateContext.read<UserProvider>().nickname;
    final result = await quizProvider.completeQuiz(userNickName);
    if (mounted) {
      Navigator.pushReplacement(
        stateContext,
        MaterialPageRoute(
          builder: (context) => QuizResultPage(result: result),
        ),
      );
    }
  }

  // 다음 또는 완료 처리
  void _handleNextOrFinish(
    BuildContext context,
    QuizProvider quizProvider,
  ) async {
    final isFinished =
        quizProvider.isGameOver ||
        (!quizProvider.isThreeOutMode &&
            quizProvider.currentQuestionsIndex ==
                quizProvider.totalQuestions - 1);
    if (isFinished) {
      await _finishQuiz(context, quizProvider);
    } else {
      // 다음 문제
      quizProvider.nextQuestion();

      // 가사 퀴즈인 경우 다음 문제 시작 시 다시 숨김
      if (widget.category == '응원가(가사)') {
        setState(() => _isQuestionVisible = false);
      }

      // 다음 문제에 오디오가 있으면 자동 재생
      if (quizProvider.currentQuestion?.audioPath != null) {
        _playAudio(quizProvider.currentQuestion!.audioPath!);
      }
    }
  }

  Widget _buildBaseballHud(QuizProvider quizProvider, bool isDarkMode) {
    final cardBg = isDarkMode ? const Color(0xFF151E32) : WHITE;
    final borderCol = isDarkMode ? Colors.white12 : GRAYSCALE_LABEL_200;
    final bases = quizProvider.bases;

    String hitBadgeText = '타석 대기 중';
    Color hitBadgeColor = isDarkMode ? Colors.white60 : GRAYSCALE_LABEL_600;
    if (quizProvider.showExplanation) {
      switch (quizProvider.lastHitType) {
        case HitType.homeRun:
          hitBadgeText = '🚀 홈런! (+${quizProvider.lastRunsScored}득점)';
          hitBadgeColor = const Color(0xFF34D399);
          break;
        case HitType.double:
          hitBadgeText = quizProvider.lastRunsScored > 0
              ? '💥 2루타! (+${quizProvider.lastRunsScored}득점)'
              : '💥 2루타! 장타 진루';
          hitBadgeColor = const Color(0xFFF5C451);
          break;
        case HitType.triple:
          hitBadgeText = quizProvider.lastRunsScored > 0
              ? '⚡ 3루타! (+${quizProvider.lastRunsScored}득점)'
              : '⚡ 3루타! 3루 진루';
          hitBadgeColor = const Color(0xFFF5C451);
          break;
        case HitType.single:
          hitBadgeText = quizProvider.lastRunsScored > 0
              ? '⚾ 1루타! (+${quizProvider.lastRunsScored}득점)'
              : '⚾ 1루타! 진루';
          hitBadgeColor = const Color(0xFF38BDF8);
          break;
        case HitType.out:
          hitBadgeText = quizProvider.isTimedOut ? '⏱ 시간 초과 아웃!' : '❌ 아웃!';
          hitBadgeColor = RED_DANGER_TEXT_50;
          break;
        case HitType.none:
          break;
      }
      if (quizProvider.lastWasClutch) {
        hitBadgeText = '$hitBadgeText · 2X';
      }
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 2),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderCol),
            ),
            child: Row(
              children: [
                // 미니 다이아몬드 (1루, 2루, 3루)
                SizedBox(
                  width: 44,
                  height: 38,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned(
                        top: 2,
                        child: _buildBasePad(bases[1], isDarkMode),
                      ),
                      Positioned(
                        right: 4,
                        top: 13,
                        child: _buildBasePad(bases[0], isDarkMode),
                      ),
                      Positioned(
                        left: 4,
                        top: 13,
                        child: _buildBasePad(bases[2], isDarkMode),
                      ),
                      Positioned(
                        bottom: 2,
                        child: Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            color: Color(0xFFF5C451),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                // 타격/콤보 상태
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hitBadgeText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'kbo',
                          color: hitBadgeColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${quizProvider.runs}득점 · ${quizProvider.currentCombo}연속 안타',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDarkMode
                              ? Colors.white60
                              : GRAYSCALE_LABEL_600,
                        ),
                      ),
                    ],
                  ),
                ),
                // 3아웃 LED + 타이머
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'OUT ',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: isDarkMode
                                ? Colors.white60
                                : GRAYSCALE_LABEL_600,
                          ),
                        ),
                        ...List.generate(3, (i) {
                          final active = i < quizProvider.outs;
                          return Container(
                            width: 10,
                            height: 10,
                            margin: const EdgeInsets.only(left: 4),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: active
                                  ? const Color(0xFFFF5B37)
                                  : (isDarkMode
                                        ? Colors.white12
                                        : GRAYSCALE_LABEL_300),
                            ),
                          );
                        }),
                      ],
                    ),
                    if (quizProvider.isThreeOutMode) ...[
                      const SizedBox(height: 4),
                      Text(
                        '⏱ ${quizProvider.remainingSeconds}s',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: quizProvider.remainingSeconds <= 5
                              ? RED_DANGER_TEXT_50
                              : const Color(0xFFF5C451),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (quizProvider.lastRechargedChanceName != null) ...[
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFF5B37).withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFFFF5B37).withValues(alpha: 0.55),
                ),
              ),
              child: Text(
                '🔥 5연속 안타! [${quizProvider.lastRechargedChanceName}] 찬스 충전!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isDarkMode
                      ? const Color(0xFFFFD875)
                      : const Color(0xFFBE123C),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'kbo',
                ),
              ),
            ),
          ],
          if (quizProvider.isClutchTime) ...[
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFF5C451), Color(0xFFFF5B37)],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '🔥 9회말 2사 만루 · CLUTCH TIME',
                    style: TextStyle(
                      color: Color(0xFF090D16),
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'kbo',
                    ),
                  ),
                  Text(
                    '2X SCORE',
                    style: TextStyle(
                      color: Color(0xFF090D16),
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBasePad(bool occupied, bool isDarkMode) {
    return Transform.rotate(
      angle: 0.785398,
      child: Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: occupied
              ? const Color(0xFFF5C451)
              : (isDarkMode ? Colors.white12 : GRAYSCALE_LABEL_200),
          border: Border.all(
            color: occupied
                ? const Color(0xFFF5C451)
                : (isDarkMode ? Colors.white24 : GRAYSCALE_LABEL_400),
            width: 1,
          ),
        ),
      ),
    );
  }

  Widget _buildChanceCardsRow(QuizProvider quizProvider, bool isDarkMode) {
    final canUse = !quizProvider.showExplanation;
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 2),
      child: Row(
        children: [
          Expanded(
            child: _buildChanceCardButton(
              icon: '📺',
              label: '비디오 판독',
              subLabel: '50:50',
              enabled: canUse && !quizProvider.usedVideoReview,
              isDarkMode: isDarkMode,
              onTap: () => quizProvider.useVideoReview(),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildChanceCardButton(
              icon: '🔄',
              label: '대타 기용',
              subLabel: '패스',
              enabled: canUse && !quizProvider.usedPinchHitter,
              isDarkMode: isDarkMode,
              onTap: () async {
                await _audioPlayer.stop();
                if (!mounted) return;
                setState(() {
                  _isPlaying = false;
                  _position = Duration.zero;
                });
                final replaced = await quizProvider.usePinchHitter();
                if (!replaced || !mounted) return;
                if (widget.category == '응원가(가사)') {
                  setState(() => _isQuestionVisible = false);
                }
                final nextAudio = quizProvider.currentQuestion?.audioPath;
                if (nextAudio != null) {
                  await _playAudio(nextAudio);
                }
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildChanceCardButton(
              icon: '⏱',
              label: '작전 타임',
              subLabel: '+5초',
              enabled:
                  canUse &&
                  quizProvider.isThreeOutMode &&
                  !quizProvider.usedTimeout,
              isDarkMode: isDarkMode,
              onTap: () => quizProvider.useTimeout(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChanceCardButton({
    required String icon,
    required String label,
    required String subLabel,
    required bool enabled,
    required bool isDarkMode,
    required VoidCallback onTap,
  }) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.38,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
          decoration: BoxDecoration(
            color: isDarkMode
                ? const Color(0xFF151E32)
                : GRAYSCALE_LABEL_50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: enabled
                  ? const Color(0xFFF5C451).withOpacity(0.55)
                  : (isDarkMode ? Colors.white12 : GRAYSCALE_LABEL_200),
            ),
          ),
          child: Column(
            children: [
              Text(
                '$icon $label',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isDarkMode ? WHITE : GRAYSCALE_LABEL_900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subLabel,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFF5C451),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 난이도 색상
  Color _getDifficultyColor(String difficulty) {
    switch (difficulty) {
      case 'easy':
        return Colors.green;
      case 'medium':
        return ORANGE_PRIMARY_500;
      case 'hard':
        return RED_DANGER_TEXT_50;
      default:
        return GRAYSCALE_LABEL_500;
    }
  }

  // 난이도 텍스트
  String _getDifficultyText(String difficulty) {
    switch (difficulty) {
      case 'easy':
        return '쉬움';
      case 'medium':
        return '중간';
      case 'hard':
        return '어려움';
      default:
        return difficulty;
    }
  }

  // 오디오 플레이어 UI
  Widget _buildAudioPlayer(String audioPath) {
    final isDarkMode =
        MediaQuery.of(context).platformBrightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E293B) : WHITE,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDarkMode ? Colors.white10 : GRAYSCALE_LABEL_300,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // 제목
          Row(
            children: [
              Icon(
                Icons.music_note,
                color: context.watch<TeamProvider>().selectedTeam?.color,
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                '응원가 힌트',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'kbo',
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),

          // 재생 컨트롤
          Row(
            children: [
              // 재생/일시정지 버튼
              GestureDetector(
                onTap: () async {
                  if (_isPlaying) {
                    await _audioPlayer.pause();
                  } else {
                    await _audioPlayer.play(AssetSource(audioPath));
                  }
                },
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: context.watch<TeamProvider>().selectedTeam?.color,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isPlaying ? Icons.pause : Icons.play_arrow,
                    color: WHITE,
                    size: 28,
                  ),
                ),
              ),
              SizedBox(width: 12),

              // 진행바와 시간
              Expanded(
                child: Column(
                  children: [
                    // 진행바
                    SliderTheme(
                      data: SliderThemeData(
                        trackHeight: 4,
                        thumbShape: RoundSliderThumbShape(
                          enabledThumbRadius: 6,
                        ),
                        overlayShape: RoundSliderOverlayShape(
                          overlayRadius: 12,
                        ),
                      ),
                      child: Slider(
                        value: _position.inMilliseconds.toDouble().clamp(
                          0.0,
                          _duration.inMilliseconds.toDouble(),
                        ),
                        max: _duration.inMilliseconds.toDouble() > 0
                            ? _duration.inMilliseconds.toDouble()
                            : 1.0,
                        activeColor: context
                            .watch<TeamProvider>()
                            .selectedTeam
                            ?.color,
                        inactiveColor: GRAYSCALE_LABEL_200,
                        onChanged: (value) async {
                          await _audioPlayer.seek(
                            Duration(milliseconds: value.toInt()),
                          );
                        },
                      ),
                    ),

                    // 시간 표시
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _formatDuration(_position),
                            style: TextStyle(
                              fontSize: 12,
                              color: GRAYSCALE_LABEL_600,
                            ),
                          ),
                          Text(
                            _formatDuration(_duration),
                            style: TextStyle(
                              fontSize: 12,
                              color: GRAYSCALE_LABEL_600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 시간 포맷팅 (0:05 형식)
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    return '$minutes:${twoDigits(seconds)}';
  }
}
