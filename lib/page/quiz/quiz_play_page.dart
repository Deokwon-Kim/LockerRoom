import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/page/quiz/quiz_result_page.dart';
import 'package:lockerroom/provider/quiz_provider.dart';
import 'package:provider/provider.dart';

import 'package:shared_preferences/shared_preferences.dart';

class QuizPlayPage extends StatefulWidget {
  final String category;
  const QuizPlayPage({super.key, required this.category});

  @override
  State<QuizPlayPage> createState() => _QuizPlayPageState();
}

class _QuizPlayPageState extends State<QuizPlayPage> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

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
        });
      }
    });

    // 퀴즈 시작
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<QuizProvider>();
      provider.startQuiz(widget.category);

      // 응원가 카테고리일 때 설명 팝업 표시 (팝업 확인 후 오디오 재생)
      if (widget.category == '응원가') {
        _checkAndShowCheerSongPopup();
      } else {
        // 응원가 외 카테고리: 첫 문제에 오디오가 있으면 자동 재생
        if (provider.currentQuestion?.audioPath != null) {
          _playAudio(provider.currentQuestion!.audioPath!);
        }
      }
    });
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
            backgroundColor: WHITE,
            title: Row(
              children: [
                Icon(Icons.music_note, color: BUTTON, size: 28),
                SizedBox(width: 8),
                Text(
                  '응원가 퀴즈 안내',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'kbo',
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildGuideItem('🎵', '응원가는 자동으로 재생됩니다'),
                SizedBox(height: 12),
                _buildGuideItem('⏱️', '응원가는 1초~5초 정도로 짧아요'),
                SizedBox(height: 12),
                _buildGuideItem('🔊', '이어폰 또는 스피커로 들으시면 더 좋아요'),
                SizedBox(height: 12),
                _buildGuideItem('🤔', '응원가를 듣고 어느 팀의 응원가인지 맞춰보세요'),
                SizedBox(height: 12),
                _buildGuideItem('🔁', '여러 번 재생할 수 있어요'),
                SizedBox(height: 20),
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
                          activeColor: BUTTON,
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
                      SizedBox(width: 8),
                      Text(
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
                      await prefs.setBool('dontShowCheerSongPopup', true);
                    }
                    if (!context.mounted) return;
                    Navigator.pop(context);
                    // 팝업 닫은 후 첫 문제 오디오 재생
                    final provider = this.context.read<QuizProvider>();
                    if (provider.currentQuestion?.audioPath != null) {
                      _playAudio(provider.currentQuestion!.audioPath!);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: BUTTON,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(
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

  // 가이드 아이템 빌더
  Widget _buildGuideItem(String emoji, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(emoji, style: TextStyle(fontSize: 20)),
        SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              height: 1.4,
              color: GRAYSCALE_LABEL_800,
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
    return Consumer<QuizProvider>(
      builder: (context, quizProvider, child) {
        if (quizProvider.isLoading) {
          return Scaffold(
            backgroundColor: BACKGROUND_COLOR,
            body: Center(child: CircularProgressIndicator(color: BUTTON)),
          );
        }

        final question = quizProvider.currentQuestion;
        if (question == null) {
          return Scaffold(
            backgroundColor: BACKGROUND_COLOR,
            body: Center(child: Text('문제를 불러올 수 없습니다.')),
          );
        }

        return Scaffold(
          backgroundColor: BACKGROUND_COLOR,
          appBar: AppBar(
            backgroundColor: BACKGROUND_COLOR,
            elevation: 0,
            scrolledUnderElevation: 0,
            title: Text(
              widget.category,
              style: TextStyle(fontFamily: 'kbo', fontWeight: FontWeight.bold),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 16.0),
                child: Center(
                  child: Text(
                    '${quizProvider.currentQuestionsIndex + 1}/${quizProvider.totalQuestions}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'kbo',
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
                value: quizProvider.progress,
                backgroundColor: GRAYSCALE_LABEL_200,
                valueColor: AlwaysStoppedAnimation<Color>(BUTTON),
                minHeight: 6,
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 난이도 배지
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _getDifficultyColor(question.difficulty),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _getDifficultyText(question.difficulty),
                          style: TextStyle(
                            color: WHITE,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),

                      SizedBox(height: 20),

                      // 문제
                      Text(
                        question.question,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'kbo',
                          height: 1.4,
                        ),
                      ),

                      SizedBox(height: 30),

                      // 이미지 (있는 경우)
                      if (question.imageUrl != null) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            question.imageUrl!,
                            width: double.infinity,
                            height: 200,
                            fit: BoxFit.cover,
                          ),
                        ),
                        SizedBox(height: 20),
                      ],

                      // 응원가 플레이어 (있는 경우)
                      if (question.audioPath != null) ...[
                        _buildAudioPlayer(question.audioPath!),
                        SizedBox(height: 20),
                      ],

                      // 답변 옵션들
                      ...List.generate(
                        question.options.length,
                        (index) => _buildOptionButton(
                          context,
                          quizProvider,
                          index,
                          question.options[index],
                        ),
                      ),

                      // 해설 (답변 후 표시)
                      if (quizProvider.showExplanation) ...[
                        SizedBox(height: 20),
                        Container(
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: quizProvider.isCurrentAnswerCorrect == true
                                ? GREEN_SUCCESS_BORDER_10
                                : RED_DANGER_SURFACE_5,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: quizProvider.isCurrentAnswerCorrect == true
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
                                    quizProvider.isCurrentAnswerCorrect == true
                                        ? Icons.check_circle
                                        : Icons.cancel,
                                    color:
                                        quizProvider.isCurrentAnswerCorrect ==
                                            true
                                        ? GREEN_SUCCESS_TEXT_50
                                        : RED_DANGER_TEXT_50,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    quizProvider.isCurrentAnswerCorrect == true
                                        ? '정답입니다!'
                                        : '오답입니다',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'kbo',
                                      color:
                                          quizProvider.isCurrentAnswerCorrect ==
                                              true
                                          ? GREEN_SUCCESS_TEXT_50
                                          : RED_DANGER_TEXT_50,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 12),
                              Text(
                                question.explanation,
                                style: TextStyle(
                                  fontSize: 14,
                                  height: 1.5,
                                  color: GRAYSCALE_LABEL_900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // 하단 버튼
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: WHITE,
                  boxShadow: [
                    BoxShadow(
                      color: GRAYSCALE_LABEL_200,
                      blurRadius: 4,
                      offset: Offset(0, -2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // 이전 버튼
                    if (quizProvider.currentQuestionsIndex > 0)
                      Expanded(
                        child: GestureDetector(
                          onTap: () => quizProvider.previousQuestion(),
                          child: Container(
                            alignment: Alignment.center,
                            width: double.infinity,
                            height: 58,
                            decoration: BoxDecoration(
                              color: WHITE,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: GRAYSCALE_LABEL_300),
                            ),
                            child: Text(
                              '이전',
                              style: TextStyle(
                                fontFamily: 'kbo',
                                color: Colors.black,
                              ),
                            ),
                          ),
                        ),
                      ),

                    if (quizProvider.currentQuestionsIndex > 0)
                      SizedBox(width: 12),

                    // 다음 또는 완료 버튼
                    Expanded(
                      flex: quizProvider.currentQuestionsIndex > 0 ? 1 : 2,
                      child: GestureDetector(
                        onTap: quizProvider.showExplanation
                            ? () => _handleNextOrFinish(context, quizProvider)
                            : null,
                        child: Container(
                          alignment: Alignment.center,
                          width: double.infinity,
                          height: 58,
                          decoration: BoxDecoration(
                            color: quizProvider.showExplanation
                                ? BUTTON
                                : GRAYSCALE_LABEL_200,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            quizProvider.currentQuestionsIndex ==
                                    quizProvider.totalQuestions - 1
                                ? '완료'
                                : '다음',
                            style: TextStyle(
                              color: quizProvider.showExplanation
                                  ? WHITE
                                  : GRAYSCALE_LABEL_500,
                              fontSize: 16,
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
            ],
          ),
        );
      },
    );
  }

  // 옵션 버튼 빌더
  Widget _buildOptionButton(
    BuildContext context,
    QuizProvider quizProvider,
    int index,
    String option,
  ) {
    final isSelected = quizProvider.currentAnswer == index;
    final isCorrect = quizProvider.currentQuestion!.correctIndex == index;
    final showResult = quizProvider.showExplanation;

    Color backgroundColor = WHITE;
    Color borderColor = GRAYSCALE_LABEL_300;
    Color textColor = GRAYSCALE_LABEL_900;

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
    } else if (isSelected) {
      backgroundColor = BLUE_SECONDARY_200;
      borderColor = BLUE_SECONDARY_600;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: GestureDetector(
        onTap: showResult ? null : () => quizProvider.selectAnswer(index),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor, width: 2),
          ),
          child: Row(
            children: [
              // 문제 번호
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: showResult && isCorrect
                      ? GREEN_SUCCESS_TEXT_50
                      : showResult && isSelected
                      ? RED_DANGER_TEXT_50
                      : isSelected
                      ? BLUE_SECONDARY_600
                      : GRAYSCALE_LABEL_300,
                ),
                child: Center(
                  child: Text(
                    String.fromCharCode(65 + index),
                    style: TextStyle(
                      color: WHITE,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'kbo',
                    ),
                  ),
                ),
              ),
              SizedBox(width: 12),

              // 옵션 텍스트
              Expanded(
                child: Text(
                  option,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: textColor,
                  ),
                ),
              ),

              // 정답/오답 아이콘
              if (showResult && (isCorrect || isSelected))
                Icon(
                  isCorrect ? Icons.check_circle : Icons.cancel,
                  color: isCorrect ? GREEN_SUCCESS_TEXT_50 : RED_DANGER_TEXT_50,
                ),
            ],
          ),
        ),
      ),
    );
  }

  // 다음 또는 완료 처리
  void _handleNextOrFinish(
    BuildContext context,
    QuizProvider quizProvider,
  ) async {
    if (quizProvider.currentQuestionsIndex == quizProvider.totalQuestions - 1) {
      // 퀴즈 완료
      final result = await quizProvider.completeQuiz();
      if (context.mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => QuizResultPage(result: result),
          ),
        );
      }
    } else {
      // 다음 문제
      quizProvider.nextQuestion();

      // 다음 문제에 오디오가 있으면 자동 재생
      if (quizProvider.currentQuestion?.audioPath != null) {
        _playAudio(quizProvider.currentQuestion!.audioPath!);
      }
    }
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
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: WHITE,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: GRAYSCALE_LABEL_300),
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
              Icon(Icons.music_note, color: BUTTON, size: 20),
              SizedBox(width: 8),
              Text(
                '응원가 힌트',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'kbo',
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
                    color: BUTTON,
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
                        activeColor: BUTTON,
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
