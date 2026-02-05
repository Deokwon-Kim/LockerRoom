import 'package:flutter/material.dart';
import 'package:lockerroom/bottom_tab_bar/bottom_tab_bar.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/page/quiz/cheer_song_category_page.dart';
import 'package:lockerroom/page/quiz/quiz_play_page.dart';
import 'package:lockerroom/provider/quiz_ranking_provider.dart';
import 'package:lockerroom/widgets/team_battle_dialog.dart';
import 'package:provider/provider.dart';

class QuizStartPage extends StatefulWidget {
  const QuizStartPage({super.key});

  @override
  State<QuizStartPage> createState() => _QuizStartPageState();
}

class _QuizStartPageState extends State<QuizStartPage> {
  @override
  void initState() {
    super.initState();
    // 랭킹 데이터 사전 로드 (다이얼로그 표시용)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<QuizRankingProvider>().fetchRankings();
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
        title: const Text(
          '야구 덕력 테스트',
          style: TextStyle(
            fontFamily: 'kbo',
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder: (context) => const BottomTabBar(initialIndex: 0),
                ),
                (route) => false,
              );
            }
          },
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 헤더 섹션
            _buildHeader(context),
            const SizedBox(height: 24),

            // 카테고리 리스트
            ..._buildCategoryList(context),
          ],
        ),
      ),
    );
  }

  // 헤더 위젯
  Widget _buildHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              '야구 없인 못 살아?',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                fontFamily: 'kbo',
                height: 1.2,
              ),
            ),
            SizedBox(height: 4),
            Text(
              '그럼 풀어봐~',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                fontFamily: 'kbo',
                height: 1.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Text(
          '오늘도 야구 덕력을 증명해보세요 ⚾',
          style: TextStyle(
            fontSize: 15,
            color: GRAYSCALE_LABEL_600,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  // 카테고리 리스트 빌더
  List<Widget> _buildCategoryList(BuildContext context) {
    final categories = _getCategories();

    return categories.map((category) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12.0),
        child: _QuizCategoryCard(
          title: category['title'] as String,
          category: category['category'] as String,
          gradientColors: category['colors'] as List<Color>,
          icon: category['icon'] as IconData?,
          onTap: () {
            // 응원가 카테고리일 경우 별도 선택 페이지로 이동
            if (category['category'] == '응원가') {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CheerSongCategoryPage(),
                ),
              );
              return;
            }

            // 그 외 다이얼로그 띄우기 -> 도전 -> 페이지 이동
            showDialog(
              context: context,
              builder: (context) => TeamBattleDialog(
                onStart: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => QuizPlayPage(
                        category: category['category'] as String,
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      );
    }).toList();
  }

  // 카테고리 데이터
  List<Map<String, dynamic>> _getCategories() {
    return [
      {
        'title': 'KBO 역사',
        'category': 'KBO역사',
        'colors': [Samsung, Samsung.withOpacity(0.7)],
        'icon': Icons.history_edu,
      },
      {
        'title': '응원가',
        'category': '응원가',
        'colors': [BLUE_SECONDARY_700, BLUE_SECONDARY_600],
        'icon': Icons.music_note_sharp,
      },
      {
        'title': '야구 룰',
        'category': '야구룰',
        'colors': [ORANGE_PRIMARY_500, ORANGE_PRIMARY_600],
        'icon': Icons.gavel,
      },
      {
        'title': '선수 퀴즈',
        'category': '선수퀴즈',
        'colors': [Kia, Kia.withOpacity(0.7)],
        'icon': Icons.person,
      },
      {
        'title': '기록과 통계',
        'category': '기록',
        'colors': [GREEN_SECONDARY_700, GREEN_SECONDARY_600],
        'icon': Icons.analytics,
      },

      {
        'title': '랜덤',
        'category': '랜덤',
        'colors': [Colors.purple.shade400, Colors.purple.shade600],
        'icon': Icons.shuffle,
      },
    ];
  }
}

// 퀴즈 카테고리 카드 위젯
class _QuizCategoryCard extends StatelessWidget {
  final String title;
  final String category;
  final List<Color> gradientColors;
  final IconData? icon;
  final VoidCallback onTap;

  const _QuizCategoryCard({
    required this.title,
    required this.category,
    required this.gradientColors,
    this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: gradientColors[0].withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // 아이콘
            if (icon != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: WHITE.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: WHITE, size: 28),
              ),
              const SizedBox(width: 16),
            ],

            // 제목
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: WHITE,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'kbo',
                ),
              ),
            ),

            // 화살표 아이콘
            Icon(
              Icons.arrow_forward_ios,
              color: WHITE.withOpacity(0.8),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
