import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/model/quiz_result_model.dart';
import 'package:lockerroom/provider/team_provider.dart';
import 'package:provider/provider.dart';

class QuizDetailPage extends StatelessWidget {
  final QuizResultModel result;
  const QuizDetailPage({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final teamColor =
        context.read<TeamProvider>().selectedTeam?.color ?? BUTTON;
    final formattedDate = result.completedAt != null
        ? DateFormat('yyyy년 MM월 dd일 HH:mm').format(result.completedAt!)
        : '-';

    return Scaffold(
      backgroundColor: BACKGROUND_COLOR,
      appBar: AppBar(
        backgroundColor: BACKGROUND_COLOR,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          '기록 상세내역',
          style: TextStyle(fontFamily: 'kbo', fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // 1. 헤더 카드 (점수 및 카테고리)
            _buildHeaderCard(teamColor),
            const SizedBox(height: 20),

            // 2. 성과 통계 (정확도, 시간)
            _buildStatsGrid(),
            const SizedBox(height: 20),

            // 3. 점수 브레이크다운
            _buildScoreBreakdown(teamColor),
            const SizedBox(height: 20),

            // 4. 완료 일시 정보
            Text(
              '완료 일시: $formattedDate',
              style: const TextStyle(color: GRAYSCALE_LABEL_500, fontSize: 13),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // 등급 계산
  String _getGrade(int score) {
    if (score >= 320) return 'S';
    if (score >= 240) return 'A';
    if (score >= 160) return 'B';
    if (score >= 80) return 'C';
    return 'F';
  }

  // 등급 색상
  Color _getGradeColor(String grade) {
    switch (grade) {
      case 'S':
        return Colors.amber.shade300;
      case 'A':
        return Colors.grey.shade300;
      case 'B':
        return Colors.orange.shade300;
      case 'C':
        return Colors.blue.shade200;
      default:
        return Colors.grey.shade400;
    }
  }

  // 헤더 카드: 점수와 카테고리
  Widget _buildHeaderCard(Color teamColor) {
    final grade = _getGrade(result.score);
    final gradeColor = _getGradeColor(grade);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [teamColor, teamColor.withOpacity(0.8)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: teamColor.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                result.category,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontFamily: 'kbo',
                ),
              ),
              const SizedBox(width: 8),
              if (grade != 'F')
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    grade,
                    style: TextStyle(
                      color: teamColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'kbo',
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${result.score}점',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 48,
              fontWeight: FontWeight.w900,
              fontFamily: 'kbo',
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${result.correctAnswers} / ${result.totalQuestions} 정답',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 성과 통계 그리드
  Widget _buildStatsGrid() {
    final accuracy = (result.correctAnswers / result.totalQuestions * 100)
        .toInt();
    final avgTime = result.timeTakenSeconds / result.totalQuestions;

    return Row(
      children: [
        _buildStatItem(Icons.track_changes, '정확도', '$accuracy%', Colors.blue),
        const SizedBox(width: 12),
        _buildStatItem(
          Icons.timer,
          '소요 시간',
          '${result.timeTakenSeconds}초',
          Colors.orange,
        ),
        const SizedBox(width: 12),
        _buildStatItem(
          Icons.speed,
          '평균 시간',
          '${avgTime.toStringAsFixed(1)}초',
          Colors.green,
        ),
      ],
    );
  }

  Widget _buildStatItem(
    IconData icon,
    String label,
    String value,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: GRAYSCALE_LABEL_100),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: GRAYSCALE_LABEL_500),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                fontFamily: 'kbo',
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 점수 내역 상세 리스트
  Widget _buildScoreBreakdown(Color teamColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: GRAYSCALE_LABEL_100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '점수 획득 내역',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              fontFamily: 'kbo',
            ),
          ),
          const SizedBox(height: 20),
          _buildBreakdownItem(
            '기본 점수',
            result.baseScore,
            Icons.check_circle_outline,
            Colors.blue,
          ),
          _buildDivider(),
          _buildBreakdownItem(
            '난이도 보너스',
            result.difficultyBonus,
            Icons.stars_outlined,
            Colors.purple,
          ),
          _buildDivider(),
          _buildBreakdownItem(
            '콤보 보너스',
            result.comboBonus,
            Icons.auto_awesome,
            Colors.orange,
          ),
          _buildDivider(),
          _buildBreakdownItem(
            '스피드 보너스',
            result.speedBonus,
            Icons.bolt,
            Colors.green,
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildBreakdownItem(
    String label,
    int score,
    IconData icon,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(fontSize: 14, color: GRAYSCALE_LABEL_800),
          ),
          const Spacer(),
          Text(
            '+$score P',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: score > 0 ? color : GRAYSCALE_LABEL_300,
              fontFamily: 'kbo',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Divider(color: GRAYSCALE_LABEL_100, height: 1),
    );
  }
}
