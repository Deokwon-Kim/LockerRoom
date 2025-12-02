import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/page/quiz/quiz_result_page.dart';
import 'package:lockerroom/provider/quiz_provider.dart';
import 'package:provider/provider.dart';

class QuizPlayPage extends StatefulWidget {
  final String category;
  const QuizPlayPage({super.key, required this.category});

  @override
  State<QuizPlayPage> createState() => _QuizPlayPageState();
}

class _QuizPlayPageState extends State<QuizPlayPage> {
  @override
  void initState() {
    super.initState();
    // 퀴즈 시작
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<QuizProvider>().startQuiz(widget.category);
    });
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
}
