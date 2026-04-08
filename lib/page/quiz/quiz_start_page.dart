import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lockerroom/bottom_tab_bar/bottom_tab_bar.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/page/quiz/cheer_song_category_page.dart';
import 'package:lockerroom/page/quiz/quiz_play_page.dart';
import 'package:lockerroom/provider/quiz_ranking_provider.dart';
import 'package:lockerroom/provider/team_provider.dart';
import 'package:lockerroom/utils/quiz_season_utils.dart';
import 'package:lockerroom/widgets/champion_overlay.dart';
import 'package:lockerroom/widgets/season_result_overlay.dart';
import 'package:lockerroom/widgets/season_start_overlay.dart';
import 'package:lockerroom/widgets/team_battle_dialog.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class QuizStartPage extends StatefulWidget {
  const QuizStartPage({super.key});

  @override
  State<QuizStartPage> createState() => _QuizStartPageState();
}

class _QuizStartPageState extends State<QuizStartPage> {
  @override
  void initState() {
    super.initState();
    // 랭킹 데이터 사전 로드 (다이얼로그 표시용 - 지난 시즌 성과 분석)
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final rankProvider = context.read<QuizRankingProvider>();

      // 1. 방금 종료된 시즌의 데이터 먼저 로드 (챔피언 여부 판정용)
      final prevSeasonId = QuizSeasonUtils.getPreviousSeasonId();
      rankProvider.setSeason(prevSeasonId); // 이전 시즌으로 설정하여 데이터 조회
      await rankProvider.fetchRankings(true);

      // 2. 오버레이 시퀀스 실행 (결과창 -> 시작창)
      await _checkAndShowSeasonSequence();

      // 3. 다시 현재 시즌 데이터를 로드하여 홈 화면 정보 갱신
      if (mounted) {
        rankProvider.setSeason(QuizSeasonUtils.getCurrentSeasonId());
        await rankProvider.fetchRankings(true);
      }
    });
  }

  Future<void> _checkAndShowSeasonSequence() async {
    // 1. 시즌 종료 결과 오버레이 (Season Result / Champion)
    await _checkAndShowSeasonResultOverlay();

    // 2. 새 시즌 시작 오버레이 (Season Start)
    await _checkAndShowSeasonStartOverlay();
  }

  Future<void> _checkAndShowSeasonResultOverlay() async {
    final prefs = await SharedPreferences.getInstance();
    final lastResultShownSeason = prefs.getString('last_result_shown_season');
    final currentSeasonId = QuizSeasonUtils.getCurrentSeasonId();

    debugPrint(
      "[SeasonOverlay] Result Check - Last: $lastResultShownSeason, Current: $currentSeasonId",
    );

    // QA를 위해 디버그 모드에서는 조건이 맞지 않더라도 강제로 확인할 수 있는 로직을 고려
    bool shouldShow = (lastResultShownSeason != currentSeasonId);

    // [QA 전용] 만약 아무것도 안 뜬다면 아래 주석을 풀어서 강제로 확인해 보세요.
    // shouldShow = true;

    if (shouldShow && mounted) {
      debugPrint("[SeasonOverlay] Showing Result Overlay...");
      await _showSeasonResultDialog(context);
      await prefs.setString('last_result_shown_season', currentSeasonId);
    }
  }

  Future<void> _checkAndShowSeasonStartOverlay() async {
    final prefs = await SharedPreferences.getInstance();
    final currentSeasonId = QuizSeasonUtils.getCurrentSeasonId();
    final userId = FirebaseAuth.instance.currentUser?.uid ?? 'guest';
    final key = 'last_shown_season_$userId';
    final lastShownSeason = prefs.getString(key);

    debugPrint(
      "[SeasonOverlay] Start Check - Last: $lastShownSeason, Current: $currentSeasonId",
    );

    bool shouldShow = (lastShownSeason != currentSeasonId);

    if (shouldShow && mounted) {
      debugPrint("[SeasonOverlay] Showing Start Overlay...");
      await _showSeasonOverlayDialog(context);
      await prefs.setString(key, currentSeasonId);
    }
  }

  // 시즌 결과 및 성과 다이얼로그 노출 (결과 -> 개인 우승 -> 팀 우승 순차 노출)
  Future<void> _showSeasonResultDialog(BuildContext context) async {
    final rankProvider = context.read<QuizRankingProvider>();
    final teamProvider = context.read<TeamProvider>();
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final selectedTeamName = teamProvider.selectedTeam?.name;
    final prevSeasonId = QuizSeasonUtils.getPreviousSeasonId();
    final prevSeasonLabel = QuizSeasonUtils.getSeasonLabel(prevSeasonId);

    // 0. 지난 시즌 랭킹 데이터 필터링
    final myRanking = currentUserId != null
        ? rankProvider.getMyRanking(currentUserId)
        : null;
    final myTeamRanking = selectedTeamName != null
        ? rankProvider.getMyTeamRanking(selectedTeamName)
        : null;

    final bool isIndividualChampion = (myRanking?.rank == 1);
    final bool isTeamChampion = (myTeamRanking?.rank == 1);
    final bool isChampion = isIndividualChampion || isTeamChampion;

    // 1. 시즌 리포트 오버레이 (1위가 아닐 때만 노출)
    if (!isChampion && mounted) {
      await showGeneralDialog<void>(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.black.withOpacity(0.95),
        transitionDuration: const Duration(milliseconds: 400),
        useRootNavigator: true,
        pageBuilder: (context, animation, secondaryAnimation) {
          return SeasonResultOverlay(
            seasonLabel: prevSeasonLabel,
            totalScore: myRanking?.score ?? 0,
            finalRank: '${myRanking?.rank ?? "-"}위',
            onDismiss: () => Navigator.of(context, rootNavigator: true).pop(),
          );
        },
      );
    }

    // 2. 개인 챔피언 오버레이 (1위일 때만)
    if (isIndividualChampion && mounted) {
      await showGeneralDialog<void>(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.black.withOpacity(0.95),
        transitionDuration: const Duration(milliseconds: 400),
        useRootNavigator: true,
        pageBuilder: (context, animation, secondaryAnimation) {
          return ChampionOverlay(
            winnerName: myRanking?.name ?? '익명 야구팬',
            teamName: selectedTeamName,
            totalScore: myRanking?.score ?? 0,
            currentRank: '1위',
            seasonLabel: prevSeasonLabel,
            teamLogoUrl: teamProvider.selectedTeam?.logoPath,
            type: ChampionType.individual,
            onDismiss: () => Navigator.of(context, rootNavigator: true).pop(),
          );
        },
      );
    }

    // 3. 팀 챔피언 오버레이 (구단 1위일 때만)
    if (isTeamChampion && mounted) {
      await showGeneralDialog<void>(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.black.withOpacity(0.95),
        transitionDuration: const Duration(milliseconds: 400),
        useRootNavigator: true,
        pageBuilder: (context, animation, secondaryAnimation) {
          return ChampionOverlay(
            winnerName: selectedTeamName ?? '우리 팀',
            teamName: selectedTeamName,
            totalScore: myTeamRanking?.totalScore ?? 0,
            currentRank: '1위',
            seasonLabel: prevSeasonLabel,
            teamLogoUrl: teamProvider.selectedTeam?.logoPath,
            type: ChampionType.team,
            onDismiss: () => Navigator.of(context, rootNavigator: true).pop(),
          );
        },
      );
    }
  }

  Future<void> _showSeasonOverlayDialog(BuildContext context) async {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.92), // 배경 어둡게
      transitionDuration: const Duration(milliseconds: 300),
      useRootNavigator: true,
      pageBuilder: (context, animation, secondaryAnimation) {
        return Consumer2<QuizRankingProvider, TeamProvider>(
          builder: (context, rankProvider, teamProvider, child) {
            final selectedTeam = teamProvider.selectedTeam;

            // 새 시즌 시작 시에는 모든 유저가 0점(PROSPECT 티어)에서 출발하므로
            // 점수와 순위를 초기화하여 전달합니다.
            return SeasonStartOverlay(
              seasonLabel: QuizSeasonUtils.getSeasonLabel(
                QuizSeasonUtils.getCurrentSeasonId(),
              ),
              userScore: 0,
              userRank: null,
              totalUsers: rankProvider.rankings.length,
              teamColor: selectedTeam?.color,
              onDismiss: () => Navigator.of(context, rootNavigator: true).pop(),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
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
          body: Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 헤더 섹션
                _buildHeader(context),
                const SizedBox(height: 24),

                // 카테고리 그리드
                Expanded(
                  child: GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 1.1,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                    itemCount: _getCategories().length,
                    itemBuilder: (context, index) {
                      final category = _getCategories()[index];
                      return _QuizCategoryCard(
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
                                builder: (context) =>
                                    const CheerSongCategoryPage(),
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
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    final seasonId = QuizSeasonUtils.getCurrentSeasonId();
    final seasonLabel = QuizSeasonUtils.getSeasonLabel(seasonId);

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
        const SizedBox(height: 16),
        // 시즌 진행 중 배지
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.orange.shade400, Colors.orange.shade600],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.orange.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.stars, color: Colors.white, size: 16),
              const SizedBox(width: 6),
              Text(
                '$seasonLabel 진행 중! 🔥',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'kbo',
                ),
              ),
            ],
          ),
        ),
      ],
    );
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
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: gradientColors[0].withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              // 1. Watermark Icon (Large & Rotated)
              if (icon != null)
                Positioned(
                  right: -20,
                  bottom: -20,
                  child: Transform.rotate(
                    angle: -0.2, // Slight rotation
                    child: Icon(
                      icon,
                      size: 100, // Large size
                      color: Colors.white.withOpacity(0.15),
                    ),
                  ),
                ),

              // 2. Content
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Top Icon (Small)
                    if (icon != null)
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icon, color: Colors.white, size: 20),
                      ),

                    // Title & Action
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'kbo',
                              height: 1.2,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.arrow_circle_right_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
