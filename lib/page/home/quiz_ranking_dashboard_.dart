import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:lockerroom/bottom_tab_bar/quiz_tab_bar.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/model/ranking_user_model.dart';
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

        final top3Individuals = rankProvider.rankings.take(3).toList();
        final myIndividualRanking = currentUserId != null
            ? rankProvider.getMyRanking(currentUserId)
            : null;

        return Container(
          width: double.infinity,
          height: 131,
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
            borderRadius: BorderRadius.circular(12),
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
                Positioned(
                  top: -10,
                  left: 210,
                  child: Transform.rotate(
                    angle: 0.25,
                    child: Opacity(
                      opacity: 0.15,
                      child: Image.asset(
                        'assets/images/quiz/quiz_trophy_champion2.png',
                        height: 150, // 전체 대시보드 내에서 적절한 크기로 조정
                      ),
                    ),
                  ),
                ),
                // 콘텐츠
                Column(
                  children: [
                    SizedBox(
                      height: 115,
                      child: PageView(
                        controller: _pageController,
                        onPageChanged: (index) =>
                            setState(() => _currentPage = index),
                        children: [
                          // 1번째 화면: 퀴즈 배너 (현재 화면)
                          GestureDetector(
                            onTap: () =>
                                Navigator.of(context, rootNavigator: true).push(
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        QuizTabBar(initialIndex: 0),
                                  ),
                                ),
                            child: Container(
                              color: Colors.transparent,
                              padding: const EdgeInsets.fromLTRB(5, 5, 5, 5),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.emoji_events,
                                    color: goldColor,
                                    size: 60,
                                  ),
                                  const SizedBox(width: 5),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                          ),
                                          decoration: BoxDecoration(
                                            color: goldColor,
                                            borderRadius: BorderRadius.circular(
                                              30,
                                            ),
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
                                        const SizedBox(height: 5),
                                        const Text(
                                          '야잘알 테스트',
                                          style: TextStyle(
                                            color: WHITE,
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        const Text(
                                          '야구 상식을 뽐내고 팬 랭킹에 도전해 보세요!',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: WHITE,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(
                                    Icons.arrow_forward_ios_rounded,
                                    color: goldColor,
                                    size: 28,
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // 2번째 화면: 랭킹 배너
                          _buildRankingBanner(
                            context,
                            goldColor,
                            rankProvider,
                            top3Individuals,
                            myIndividualRanking,
                          ),
                        ],
                      ),
                    ),

                    // 인디케이터
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10.0),
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

  Widget _buildRankingBanner(
    BuildContext context,
    Color goldColor,
    QuizRankingProvider rankProvider,
    List<RankingUserModel> top3Individuals,
    RankingUserModel? myIndividualRanking,
  ) {
    return GestureDetector(
      onTap: () => Navigator.of(
        context,
        rootNavigator: true,
      ).push(MaterialPageRoute(builder: (_) => QuizTabBar(initialIndex: 3))),
      child: Container(
        color: Colors.transparent,
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: goldColor,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: const Text(
                      'FAN RANKING TOP 3',
                      style: TextStyle(
                        color: Color(0xFF1A1A1A),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    '퀴즈 명예의 전당',
                    style: TextStyle(
                      color: WHITE,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    myIndividualRanking != null
                        ? '내 순위: ${myIndividualRanking.rank}위 (${myIndividualRanking.score}점)'
                        : '지금 도전하고 랭킹을 올려보세요!',
                    style: const TextStyle(fontSize: 11, color: WHITE),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (rankProvider.isLoading && top3Individuals.isEmpty)
              SizedBox(
                width: 60,
                child: Center(
                  child: SizedBox(
                    width: 10,
                    height: 10,
                    child: CircularProgressIndicator(
                      color: goldColor,
                      strokeWidth: 2,
                    ),
                  ),
                ),
              )
            else if (top3Individuals.isNotEmpty)
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (top3Individuals.length > 1)
                    _buildCompactTopItem(
                      top3Individuals[1].name,
                      top3Individuals[1].score,
                      2,
                      top3Individuals[1].profileUrl,
                    ),
                  if (top3Individuals.isNotEmpty) ...[
                    const SizedBox(width: 4),
                    _buildCompactTopItem(
                      top3Individuals[0].name,
                      top3Individuals[0].score,
                      1,
                      top3Individuals[0].profileUrl,
                    ),
                  ],
                  if (top3Individuals.length > 2) ...[
                    const SizedBox(width: 4),
                    _buildCompactTopItem(
                      top3Individuals[2].name,
                      top3Individuals[2].score,
                      3,
                      top3Individuals[2].profileUrl,
                    ),
                  ],
                ],
              )
            else
              Icon(Icons.military_tech_rounded, color: goldColor, size: 36),
            const SizedBox(width: 8),
            Icon(Icons.arrow_forward_ios_rounded, color: goldColor, size: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactTopItem(
    String name,
    int score,
    int rank,
    String? profileUrl,
  ) {
    final double avatarSize = rank == 1 ? 36 : 30;
    final Color medalColor = rank == 1
        ? const Color(0xFFFFD700)
        : (rank == 2 ? const Color(0xFFC0C0C0) : const Color(0xFFCD7F32));

    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.end,
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
                    color: medalColor.withValues(alpha: 0.2),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: ClipOval(
                child: profileUrl != null && profileUrl.isNotEmpty
                    ? Image.network(
                        profileUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(
                              Icons.person,
                              size: 16,
                              color: Colors.white70,
                            ),
                      )
                    : const Icon(Icons.person, size: 16, color: Colors.white70),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(2),
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
        const SizedBox(height: 2),
        SizedBox(
          width: 38,
          child: Text(
            name,
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ),
        Text(
          '$score점',
          style: const TextStyle(fontSize: 8, color: Colors.white70),
        ),
      ],
    );
  }
}
