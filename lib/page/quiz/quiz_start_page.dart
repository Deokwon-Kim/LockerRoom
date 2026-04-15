import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lockerroom/bottom_tab_bar/bottom_tab_bar.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/model/quiz_trophy_model.dart';
import 'package:lockerroom/page/quiz/cheer_song_category_page.dart';
import 'package:lockerroom/page/quiz/quiz_play_page.dart';
import 'package:lockerroom/provider/quiz_ranking_provider.dart';
import 'package:lockerroom/provider/team_provider.dart';
import 'package:lockerroom/utils/quiz_season_utils.dart';
import 'package:lockerroom/utils/quiz_tier_utils.dart';
import 'package:lockerroom/widgets/champion_overlay.dart';
import 'package:lockerroom/provider/badge_provider.dart';
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
      if (prevSeasonId != null) {
        rankProvider.setSeason(prevSeasonId); // 이전 시즌으로 설정하여 데이터 조회
        await rankProvider.fetchRankings(true);
      }

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

    // 실제 서비스 로직: 지난 시즌 결과 노출 여부에 따라 결정
    bool shouldShow = lastResultShownSeason != currentSeasonId;

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

    bool shouldShow = lastShownSeason != currentSeasonId;

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

    // 이전 시즌이 없으면 (예: 앱 완전 최초 시작 시) 다이얼로그 노출 건너뜀
    if (prevSeasonId == null) return;

    final prevSeasonLabel = QuizSeasonUtils.getSeasonLabel(prevSeasonId);

    // 0. 지난 시즌 랭킹 데이터 필터링
    final myRanking = currentUserId != null
        ? rankProvider.getMyRanking(currentUserId)
        : null;

    // [QA 보강] 랭킹 데이터에 사진이 없으면 현재 로그인 유저의 사진을 폴백으로 사용
    final currentUserPhotoUrl = FirebaseAuth.instance.currentUser?.photoURL;
    final fallbackAvatarUrl = myRanking?.profileUrl ?? currentUserPhotoUrl;

    final myTeamRanking = selectedTeamName != null
        ? rankProvider.getMyTeamRanking(selectedTeamName)
        : null;

    final bool isIndividualChampion = (myRanking?.rank == 1);
    final bool isTeamChampion = (myTeamRanking?.rank == 1);
    final bool isChampion = isIndividualChampion || isTeamChampion;

    // Top 50 여부 체크 (1위 포함)
    final bool isTop50 = (myRanking != null && myRanking.rank <= 50);

    // [New] 뱃지 획득 여부도 함께 체크 (Top 50 클럽 및 MVP 뱃지 동기화)
    if (myRanking != null) {
      context.read<BadgeProvider>().checkSeasonalBadges(myRanking.rank);
    }

    // 0.5. Top 50 클럽 트로피 자동 수집 (1위~50위 모두 해당)
    if (isTop50 && currentUserId != null && mounted) {
      rankProvider.saveTrophy(
        QuizTrophyModel(
          id: '',
          userId: currentUserId,
          seasonId: prevSeasonId,
          seasonLabel: prevSeasonLabel,
          userName: myRanking.name,
          teamName: selectedTeamName,
          teamLogoUrl: teamProvider.selectedTeam?.logoPath,
          score: myRanking.score,
          rank: myRanking.rank,
          type: TrophyType.individual,
          earnedAt: DateTime.now(),
        ),
      );
    }

    // 1. 시즌 리포트 오버레이 (1위가 아닐 때만 노출)
    if (!isChampion && mounted && myRanking != null) {
      await showGeneralDialog<void>(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.black.withOpacity(0.95),
        transitionDuration: const Duration(milliseconds: 400),
        useRootNavigator: true,
        pageBuilder: (context, animation, secondaryAnimation) {
          return SeasonResultOverlay(
            seasonLabel: prevSeasonLabel,
            totalScore: myRanking.score,
            finalRank: '${myRanking.rank}위',
            onDismiss: () => Navigator.of(context, rootNavigator: true).pop(),
          );
        },
      );
    }

    // 2. 개인 챔피언 오버레이 (1위일 때만)
    if (isIndividualChampion && mounted && myRanking != null) {
      // 트로피 자동 수집 (영구 저장)
      if (currentUserId != null) {
        rankProvider.saveTrophy(
          QuizTrophyModel(
            id: '',
            userId: currentUserId,
            seasonId: prevSeasonId,
            seasonLabel: prevSeasonLabel,
            userName: myRanking.name,
            teamName: selectedTeamName,
            teamLogoUrl: teamProvider.selectedTeam?.logoPath,
            score: myRanking.score,
            type: TrophyType.individual,
            earnedAt: DateTime.now(),
          ),
        );
      }

      await showGeneralDialog<void>(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.black.withOpacity(0.95),
        transitionDuration: const Duration(milliseconds: 400),
        useRootNavigator: true,
        pageBuilder: (context, animation, secondaryAnimation) {
          return ChampionOverlay(
            winnerName: myRanking.name,
            teamName: selectedTeamName,
            totalScore: myRanking.score,
            currentRank: '1위',
            seasonLabel: prevSeasonLabel,
            avatarUrl: fallbackAvatarUrl,
            teamLogoUrl: teamProvider.selectedTeam?.logoPath,
            type: ChampionType.individual,
            onDismiss: () => Navigator.of(context, rootNavigator: true).pop(),
          );
        },
      );
    }

    // 3. 팀 우승 오버레이 (구단 1위일 때만)
    if (isTeamChampion && mounted && myTeamRanking != null) {
      if (currentUserId != null) {
        rankProvider.saveTrophy(
          QuizTrophyModel(
            id: '',
            userId: currentUserId,
            seasonId: prevSeasonId,
            seasonLabel: prevSeasonLabel,
            userName: myRanking?.name ?? '익명 팬',
            teamName: selectedTeamName ?? '내 팀',
            teamLogoUrl: teamProvider.selectedTeam?.logoPath,
            score: myTeamRanking.totalScore,
            type: TrophyType.team,
            earnedAt: DateTime.now(),
          ),
        );
      }

      await showGeneralDialog<void>(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.black.withOpacity(0.95),
        transitionDuration: const Duration(milliseconds: 400),
        useRootNavigator: true,
        pageBuilder: (context, animation, secondaryAnimation) {
          return ChampionOverlay(
            winnerName: selectedTeamName ?? '내 팀',
            teamName: selectedTeamName,
            totalScore: myTeamRanking.totalScore,
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
                const SizedBox(height: 16),
                // 내 티어 & 시즌 카드
                _buildMyTierCard(context),
                const SizedBox(height: 20),

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
    final seasonLabel = QuizSeasonUtils.getSeasonLabel(
      QuizSeasonUtils.getCurrentSeasonId(),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '야구 없인 못 살아?',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            fontFamily: 'kbo',
            height: 1.2,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          '그럼 풀어봐~',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            fontFamily: 'kbo',
            height: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            // 시즌 진행 중 배지
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.orange.shade400, Colors.orange.shade600],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.orange.withOpacity(0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.stars, color: Colors.white, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    '$seasonLabel 진행 중! 🔥',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'kbo',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMyTierCard(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final teamColor =
        context.read<TeamProvider>().selectedTeam?.color ?? BUTTON;

    return Consumer<QuizRankingProvider>(
      builder: (context, qrp, child) {
        final myRanking = currentUserId != null
            ? qrp.getMyRanking(currentUserId)
            : null;
        final score = myRanking?.score ?? 0;
        final tierName = QuizTierUtils.getTierName(score);
        final tierColor = QuizTierUtils.getTierColor(tierName);
        final emblemPath = QuizTierUtils.getTierEmblem(tierName);
        final progress = QuizTierUtils.getTierProgress(score);

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: tierColor.withOpacity(0.4), width: 1),
            boxShadow: [
              BoxShadow(
                color: tierColor.withOpacity(0.15),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // 티어 엠블럼
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: tierColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Image.asset(emblemPath, width: 36, height: 36),
              ),
              const SizedBox(width: 14),
              // 티어 정보
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          tierName,
                          style: TextStyle(
                            color: tierColor,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${score}P',
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // 다음 티어 진행률 바
                    Stack(
                      children: [
                        Container(
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        TweenAnimationBuilder<double>(
                          tween: Tween<double>(
                            begin: 0,
                            end: progress.progress,
                          ),
                          duration: const Duration(milliseconds: 1000),
                          curve: Curves.easeOutCubic,
                          builder: (context, value, _) {
                            return FractionallySizedBox(
                              widthFactor: value.clamp(0.01, 1.0),
                              child: Container(
                                height: 4,
                                decoration: BoxDecoration(
                                  color: tierColor,
                                  borderRadius: BorderRadius.circular(2),
                                  boxShadow: [
                                    BoxShadow(
                                      color: tierColor.withOpacity(0.5),
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      progress.remainingScore > 0
                          ? '${progress.nextTier}까지 ${progress.remainingScore}P'
                          : '최고 등급 달성! 🔥',
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              // 랭킹 순위 (있을 경우)
              if (myRanking != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${myRanking.rank}위',
                      style: TextStyle(
                        color: WHITE,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'kbo',
                      ),
                    ),
                    const Text(
                      '내 순위',
                      style: TextStyle(color: Colors.white38, fontSize: 11),
                    ),
                  ],
                ),
            ],
          ),
        );
      },
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
