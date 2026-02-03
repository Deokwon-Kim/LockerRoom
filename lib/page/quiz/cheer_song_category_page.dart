import 'package:flutter/material.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/page/quiz/quiz_play_page.dart';
import 'package:lockerroom/widgets/team_battle_dialog.dart';

class CheerSongCategoryPage extends StatelessWidget {
  const CheerSongCategoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BACKGROUND_COLOR,
      appBar: AppBar(
        backgroundColor: BACKGROUND_COLOR,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          '응원가 퀴즈 선택',
          style: TextStyle(
            fontFamily: 'kbo',
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
        child: Column(
          children: [
            _buildSelectionCard(
              context,
              title: '응원가 (인트로)',
              subtitle: '짧은 노래를 듣고 주인공을 맞춰보세요!',
              category: '응원가(인트로)',
              icon: Icons.music_note,
              colors: [BLUE_SECONDARY_700, BLUE_SECONDARY_600],
            ),
            const SizedBox(height: 16),
            _buildSelectionCard(
              context,
              title: '응원가 (가사)',
              subtitle: '가사 빈칸에 들어갈 내용을 맞춰보세요!',
              category: '응원가(가사)',
              icon: Icons.lyrics_rounded,
              colors: [Colors.teal.shade700, Colors.teal.shade600],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectionCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required String category,
    required IconData icon,
    required List<Color> colors,
  }) {
    return GestureDetector(
      onTap: () {
        showDialog(
          context: context,
          builder: (context) => TeamBattleDialog(
            onStart: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => QuizPlayPage(category: category),
                ),
              );
            },
          ),
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: colors[0].withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.white, size: 32),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'kbo',
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 20),
          ],
        ),
      ),
    );
  }
}
