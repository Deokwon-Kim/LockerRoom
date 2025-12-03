import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/provider/quiz_provider.dart';
import 'package:provider/provider.dart';

class QuizRecordPage extends StatefulWidget {
  const QuizRecordPage({super.key});

  @override
  State<QuizRecordPage> createState() => _QuizRecordPageState();
}

class _QuizRecordPageState extends State<QuizRecordPage> {
  @override
  void initState() {
    super.initState();
    // 페이지 진입 시 데이터 로드
    Future.microtask(() {
      context.read<QuizProvider>().fetchMyHistory();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BACKGROUND_COLOR,
      appBar: AppBar(
        backgroundColor: BACKGROUND_COLOR,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          '나의 기록',
          style: TextStyle(
            fontFamily: 'kbo',
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: Consumer<QuizProvider>(
        builder: (context, quizProvider, child) {
          if (quizProvider.isLoading) {
            return const Center(
              child: CircularProgressIndicator(color: BUTTON),
            );
          }

          if (quizProvider.myHistory.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 80, color: GRAYSCALE_LABEL_300),
                  SizedBox(height: 16),
                  Text(
                    '아직 푼 퀴즈가 없습니다',
                    style: TextStyle(
                      fontSize: 16,
                      color: GRAYSCALE_LABEL_600,
                      fontFamily: 'kbo',
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '퀴즈글 풀고 기록을 남겨보세요!',
                    style: TextStyle(fontSize: 14, color: GRAYSCALE_LABEL_500),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: EdgeInsets.fromLTRB(20, 10, 20, 100),
            itemCount: quizProvider.myHistory.length,
            separatorBuilder: (context, index) => SizedBox(height: 12),
            itemBuilder: (context, index) {
              final result = quizProvider.myHistory[index];
              return _buildHistoryCard(result);
            },
          );
        },
      ),
    );
  }

  Widget _buildHistoryCard(result) {
    // 날짜 포맷팅(예: 2025.12.03 15:30)
    String formattedDate = '';
    if (result.completedAt != null) {
      formattedDate = DateFormat(
        'yyyy.MM.dd HH:mm',
      ).format(result.completedAt!);
    }

    // 점수에 따른 색상
    Color scoreColor = result.score >= 80
        ? GREEN_SUCCESS_TEXT_50
        : result.score >= 50
        ? Colors.orange
        : RED_DANGER_TEXT_50;

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: WHITE,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // 점수 뱃지
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: scoreColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              '${result.score}',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: scoreColor,
                fontFamily: 'kbo',
              ),
            ),
          ),
          SizedBox(width: 16),
          // 상세정보
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  result.category,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  formattedDate,
                  style: TextStyle(fontSize: 12, color: GRAYSCALE_LABEL_500),
                ),
              ],
            ),
          ),
          // 정답 개수 표시
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${result.correctAnswers}/${result.totalQuestions}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              Text(
                '정답',
                style: TextStyle(fontSize: 12, color: GRAYSCALE_LABEL_500),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
