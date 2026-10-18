import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:lockerroom/bottom_tab_bar/quiz_tab_bar.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/model/ranking_team_model.dart';
import 'package:lockerroom/model/team_model.dart';
import 'package:lockerroom/provider/quiz_ranking_provider.dart';
import 'package:lockerroom/provider/team_provider.dart';
import 'package:provider/provider.dart';

class QuizRankingDashboard extends StatefulWidget {
  final TeamModel selectedTeam;
  const QuizRankingDashboard({required this.selectedTeam});

  @override
  State<QuizRankingDashboard> createState() => QuizRankingDashboardState();
}

class QuizRankingDashboardState extends State<QuizRankingDashboard> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startAutoSlide();
  }

  void _startAutoSlide() {
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_pageController.hasClients) {
        int nextPage = (_currentPage + 1) % 2;
        _pageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const goldColor = Color(0xFFE9C46A);
    return Consumer2<QuizRankingProvider, TeamProvider>(
      builder: (context, rankProvider, teamProvider, _) {
        final currentUserId = FirebaseAuth.instance.currentUser?.uid;
        final myTeam = teamProvider.selectedTeam;

        final top3Individuals = rankProvider.rankings.take(3).toList();
        final myIndividualRanking = currentUserId != null
            ? rankProvider.getMyRanking(currentUserId)
            : null;
        final top3Teams = rankProvider.teamRankings.take(3).toList();

        RankingTeamModel? myTeamRanking;
        if (myTeam != null) {
          try {
            myTeamRanking = rankProvider.teamRankings.firstWhere(
              (t) =>
                  t.teamName == myTeam.name || t.teamName == myTeam.symplename,
            );
          } catch (_) {}
        }

        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              children: [
                // 배경 그라데이션
                Positioned.fill(
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF1A1A1A), Color(0xFF2C2C2C)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
                ),
                // 배경 트로피 이미지
                Positioned.fill(
                  child: Center(
                    child: Opacity(
                      opacity: 0.15,
                      child: Image.asset(
                        'assets/images/quiz/quiz_trophy_champion2.png',
                        height: 280, // 전체 대시보드 내에서 적절한 크기로 조정
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
                // 콘텐츠
                Column(
                  children: [
                    // 상단 퀴즈 배너 영역
                    GestureDetector(
                      onTap: () =>
                          Navigator.of(context, rootNavigator: true).push(
                            MaterialPageRoute(
                              builder: (context) => QuizTabBar(initialIndex: 0),
                            ),
                          ),
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: goldColor,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'BEST FAN CHALLENGE',
                                      style: TextStyle(
                                        color: Color(0xFF1A1A1A),
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  const Text(
                                    '야구 덕력 테스트! 퀴즈 풀기',
                                    style: TextStyle(
                                      fontFamily: 'kbo',
                                      color: WHITE,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.play_circle_filled_rounded,
                              color: goldColor,
                              size: 32,
                            ),
                          ],
                        ),
                      ),
                    ),

                    // const Divider(height: 1, color: Colors.white10),

                    // // 하단 랭킹 영역
                    // SizedBox(
                    //   height: 180,
                    //   child:
                    //       rankProvider.isLoading &&
                    //           rankProvider.rankings.isEmpty
                    //       ? const Center(
                    //           child: CircularProgressIndicator(
                    //             color: goldColor,
                    //           ),
                    //         )
                    //       : PageView(
                    //           controller: _pageController,
                    //           onPageChanged: (index) =>
                    //               setState(() => _currentPage = index),
                    //           children: [
                    //             _buildRankingPage(
                    //               title: '개인 순위 TOP 3',
                    //               top3: top3Individuals
                    //                   .map(
                    //                     (e) => _RankingItemData(
                    //                       name: e.name,
                    //                       score: e.score,
                    //                       rank: e.rank,
                    //                       imageUrl: e.profileUrl,
                    //                     ),
                    //                   )
                    //                   .toList(),
                    //               myRank: myIndividualRanking != null
                    //                   ? '${myIndividualRanking.rank}위'
                    //                   : '순위 없음',
                    //               myScore: myIndividualRanking != null
                    //                   ? '${myIndividualRanking.score}점'
                    //                   : '-',
                    //               myLabel: '내 개인 순위',
                    //               isDark: true,
                    //             ),
                    //             _buildRankingPage(
                    //               title: '팀 순위 TOP 3',
                    //               top3: top3Teams.map((e) {
                    //                 final team = teamProvider.findTeamByName(
                    //                   e.teamName,
                    //                 );
                    //                 return _RankingItemData(
                    //                   name: team?.symplename ?? e.teamName,
                    //                   score: e.totalScore,
                    //                   rank: e.rank,
                    //                   imagePath: team?.logoPath,
                    //                 );
                    //               }).toList(),
                    //               myRank: myTeamRanking != null
                    //                   ? '${myTeamRanking.rank}위'
                    //                   : (myTeam == null ? '팀 선택 필요' : '기록 없음'),
                    //               myScore: myTeamRanking != null
                    //                   ? '${myTeamRanking.totalScore}점'
                    //                   : '-',
                    //               myLabel: myTeam != null
                    //                   ? '${myTeam.symplename} 순위'
                    //                   : '내 팀 순위',
                    //               isDark: true,
                    //             ),
                    //           ],
                    //         ),
                    // ),

                    // 인디케이터
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          2,
                          (index) => Container(
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _currentPage == index
                                  ? goldColor
                                  : Colors.white24,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRankingPage({
    required String title,
    required List<_RankingItemData> top3,
    required String myRank,
    required String myScore,
    required String myLabel,
    bool isDark = false,
  }) {
    return GestureDetector(
      onTap: () => Navigator.of(
        context,
        rootNavigator: true,
      ).push(MaterialPageRoute(builder: (_) => QuizTabBar(initialIndex: 3))),
      child: Container(
        color: Colors.transparent,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white70 : GRAYSCALE_LABEL_900,
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  size: 16,
                  color: isDark ? Colors.white38 : GRAYSCALE_LABEL_400,
                ),
              ],
            ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (top3.length > 1)
                  _buildTop3Item(top3[1], 2, isDark: isDark)
                else
                  const SizedBox(width: 60),
                if (top3.isNotEmpty)
                  _buildTop3Item(top3[0], 1, isDark: isDark)
                else
                  const SizedBox(width: 70),
                if (top3.length > 2)
                  _buildTop3Item(top3[2], 3, isDark: isDark)
                else
                  const SizedBox(width: 60),
              ],
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withOpacity(0.05)
                    : const Color(0xFFF8F9FA),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    myLabel,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white54 : GRAYSCALE_LABEL_500,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        myRank,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : GRAYSCALE_LABEL_900,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        myScore,
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.white38 : GRAYSCALE_LABEL_400,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTop3Item(
    _RankingItemData data,
    int rank, {
    bool isDark = false,
  }) {
    double avatarSize = rank == 1 ? 44 : 38;
    Color medalColor = rank == 1
        ? const Color(0xFFFFD700)
        : (rank == 2 ? const Color(0xFFC0C0C0) : const Color(0xFFCD7F32));
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.bottomRight,
          children: [
            Container(
              width: avatarSize,
              height: avatarSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: medalColor, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: medalColor.withOpacity(0.2),
                    blurRadius: 4,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: ClipOval(
                child: data.imagePath != null
                    ? Image.asset(data.imagePath!, fit: BoxFit.cover)
                    : (data.imageUrl != null
                          ? Image.network(
                              data.imageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  const Icon(Icons.person, size: 20),
                            )
                          : Icon(
                              Icons.person,
                              size: 20,
                              color: isDark
                                  ? Colors.white24
                                  : GRAYSCALE_LABEL_300,
                            )),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: medalColor,
                shape: BoxShape.circle,
              ),
              child: Text(
                '$rank',
                style: const TextStyle(
                  fontSize: 7,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A1A),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: 60,
          child: Text(
            data.name,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : GRAYSCALE_LABEL_800,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ),
        Text(
          '${data.score}점',
          style: TextStyle(
            fontSize: 9,
            color: isDark ? Colors.white38 : GRAYSCALE_LABEL_500,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

class _RankingItemData {
  final String name;
  final int score;
  final int rank;
  final String? imageUrl;
  final String? imagePath;
  _RankingItemData({
    required this.name,
    required this.score,
    required this.rank,
    this.imageUrl,
    this.imagePath,
  });
}
