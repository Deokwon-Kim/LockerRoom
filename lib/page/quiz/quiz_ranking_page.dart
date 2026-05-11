import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/model/ranking_team_model.dart';
import 'package:lockerroom/model/ranking_user_model.dart';

import 'package:lockerroom/provider/quiz_ranking_provider.dart';
import 'package:lockerroom/provider/team_provider.dart';
import 'package:lockerroom/utils/quiz_season_utils.dart';
import 'package:lockerroom/utils/quiz_tier_utils.dart';
import 'package:lockerroom/page/quiz/quiz_hall_of_fame_page.dart';
import 'package:provider/provider.dart';

class QuizRankingPage extends StatefulWidget {
  const QuizRankingPage({super.key});

  @override
  State<QuizRankingPage> createState() => _QuizRankingPageState();
}

class _QuizRankingPageState extends State<QuizRankingPage> {
  // 카테고리 목록
  final List<Map<String, String>> _categories = [
    {'value': 'all', 'label': '종합'},
    {'value': 'KBO역사', 'label': 'KBO역사'},
    {'value': '야구룰', 'label': '야구룰'},
    {'value': '선수퀴즈', 'label': '선수퀴즈'},
    {'value': '기록', 'label': '기록'},
    {'value': '응원가', 'label': '응원가'},
    {'value': '랜덤', 'label': '랜덤'},
  ];

  @override
  void initState() {
    super.initState();
    // 페이지 로드 시 순위 가져오기
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<QuizRankingProvider>().fetchRankings();
    });
  }

  // 카테고리 선택 바텀시트
  void _showCategoryBottomSheet(BuildContext context, QuizRankingProvider qrp) {
    final teamColor =
        context.read<TeamProvider>().selectedTeam?.color ?? BUTTON;
    final isDarkMode =
        MediaQuery.of(context).platformBrightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: isDarkMode ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                '카테고리 선택',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'kbo',
                ),
              ),
              const SizedBox(height: 16),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _categories.length,
                separatorBuilder: (context, index) =>
                    Divider(color: Colors.grey.shade100, height: 1),
                itemBuilder: (context, index) {
                  final category = _categories[index];
                  final isSelected = qrp.selectedCategory == category['value'];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    onTap: () {
                      qrp.setCategory(category['value']!);
                      Navigator.pop(context);
                    },
                    title: Text(
                      category['label']!,
                      style: TextStyle(
                        fontSize: 16,
                        fontFamily: 'kbo',
                        color: isSelected
                            ? teamColor
                            : (isDarkMode ? Colors.white : Colors.black87),
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    trailing: isSelected
                        ? Icon(Icons.check_circle, color: teamColor)
                        : const Icon(
                            Icons.circle_outlined,
                            color: Colors.grey,
                            size: 20,
                          ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showSeasonPicker(BuildContext context, QuizRankingProvider qrp) {
    // 최근 6개월 시즌 목록 생성
    final List<String> seasons = List.generate(6, (i) {
      final date = DateTime.now().subtract(Duration(days: i * 30));
      return QuizSeasonUtils.getSeasonIdFromDate(date);
    });

    int selectedIndex = seasons.indexOf(qrp.selectedSeason);
    if (selectedIndex == -1) selectedIndex = 0;

    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) {
        return Container(
          height: 250,
          color: CupertinoColors.systemBackground.resolveFrom(context),
          child: Column(
            children: [
              Container(
                height: 44,
                decoration: BoxDecoration(
                  color: CupertinoColors.systemBackground.resolveFrom(context),
                  border: Border(
                    bottom: BorderSide(
                      color: CupertinoColors.separator.resolveFrom(context),
                      width: 0.5,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    CupertinoButton(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        '취소',
                        style: TextStyle(
                          color: context
                              .read<TeamProvider>()
                              .selectedTeam
                              ?.color,
                        ),
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                    CupertinoButton(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        '완료',
                        style: TextStyle(
                          color: context
                              .read<TeamProvider>()
                              .selectedTeam
                              ?.color,
                        ),
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: CupertinoPicker(
                  scrollController: FixedExtentScrollController(
                    initialItem: selectedIndex,
                  ),
                  onSelectedItemChanged: (int index) {
                    qrp.setSeason(seasons[index]);
                  },
                  itemExtent: 40,
                  children: seasons.map((s) {
                    return Center(
                      child: Text(
                        QuizSeasonUtils.getSeasonLabel(s),
                        style: const TextStyle(fontSize: 18),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode =
        MediaQuery.of(context).platformBrightness == Brightness.dark;
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final teamProvider = context.read<TeamProvider>();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: isDarkMode
            ? const Color(0xFF0F172A)
            : Colors.grey[100],
        appBar: AppBar(
          scrolledUnderElevation: 0,
          backgroundColor: isDarkMode
              ? const Color(0xFF0F172A)
              : Colors.grey[100],
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new,
              size: 20,
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          title: Row(
            children: [
              Text(
                '퀴즈 랭킹',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'kbo',
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(width: 8),
              // 카테고리 선택 버튼
              Consumer<QuizRankingProvider>(
                builder: (context, qrp, child) {
                  final label = _categories.firstWhere(
                    (c) => c['value'] == qrp.selectedCategory,
                    orElse: () => _categories[0],
                  )['label']!;
                  return GestureDetector(
                    onTap: () => _showCategoryBottomSheet(context, qrp),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isDarkMode
                            ? Colors.white.withOpacity(0.1)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isDarkMode
                              ? Colors.white12
                              : Colors.grey.shade300,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            label,
                            style: TextStyle(
                              fontFamily: 'kbo',
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: isDarkMode ? Colors.white : BLACK,
                            ),
                          ),
                          Icon(
                            Icons.arrow_drop_down,
                            color: isDarkMode ? Colors.white : BLACK,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          centerTitle: false,
          elevation: 0,
          actions: [
            // 명예의 전당 버튼
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const QuizHallOfFamePage(),
                  ),
                ).then((_) {
                  context.read<QuizRankingProvider>().setAllTimeMode(false);
                });
              },
              child: Container(
                height: 40,
                width: 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.amber.shade300, Colors.amber.shade600],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.amber.withOpacity(0.4),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.military_tech, color: Colors.white, size: 15),
                    Text(
                      'HALL',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // 새로고침 버튼
            IconButton(
              onPressed: () {
                context.read<QuizRankingProvider>().fetchRankings(true);
              },
              icon: Icon(
                Icons.refresh,
                color: isDarkMode ? Colors.white70 : Colors.black54,
              ),
            ),
            const SizedBox(width: 8),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(60),
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              height: 48,
              decoration: BoxDecoration(
                color: isDarkMode
                    ? Colors.white.withOpacity(0.05)
                    : Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TabBar(
                padding: const EdgeInsets.all(4),
                labelColor: Colors.white,
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  fontFamily: 'kbo',
                ),
                unselectedLabelColor: isDarkMode
                    ? Colors.white38
                    : Colors.grey.shade600,
                unselectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  fontFamily: 'kbo',
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: teamProvider.selectedTeam?.color ?? BUTTON,
                ),
                dividerColor: Colors.transparent,
                tabs: const [
                  Tab(text: '개인 랭킹'),
                  Tab(text: '팀 랭킹'),
                ],
              ),
            ),
          ),
        ),
        body: Column(
          children: [
            Consumer<QuizRankingProvider>(
              builder: (context, qrp, child) {
                return _buildSlimSeasonBanner(context, qrp);
              },
            ),
            Expanded(
              child: Consumer<QuizRankingProvider>(
                builder: (context, qrp, child) {
                  if (qrp.isLoading) {
                    return Center(
                      child: CircularProgressIndicator(
                        color: teamProvider.selectedTeam?.color ?? BUTTON,
                      ),
                    );
                  }

                  if (qrp.errorMessage != null) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 48,
                            color: isDarkMode ? Colors.white38 : Colors.grey,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            qrp.errorMessage!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: isDarkMode ? Colors.white70 : Colors.black,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () => qrp.fetchRankings(),
                            child: const Text('다시 시도'),
                          ),
                        ],
                      ),
                    );
                  }

                  return TabBarView(
                    children: [
                      _buildUserRankingView(qrp, currentUserId),
                      _buildTeamRankingView(qrp),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 개인 랭킹 뷰
  Widget _buildUserRankingView(QuizRankingProvider qrp, String? currentUserId) {
    if (qrp.rankings.isEmpty) {
      return RefreshIndicator(
        color: RED_DANGER_TEXT_50,
        onRefresh: () => qrp.fetchRankings(true),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Container(
            height: 500,
            alignment: Alignment.center,
            child: const Text('아직 퀴즈 기록이 없습니다.'),
          ),
        ),
      );
    }

    final topThree = qrp.rankings.take(3).toList();
    final restRankings = qrp.rankings.skip(3).toList();
    final myRanking = currentUserId != null
        ? qrp.getMyRanking(currentUserId)
        : null;

    return RefreshIndicator(
      color: RED_DANGER_TEXT_50,
      onRefresh: () => qrp.fetchRankings(true),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          children: [
            // 내 순위 표시 (상단 고정 - 프리미엄 효과)
            if (myRanking != null)
              TweenAnimationBuilder(
                duration: const Duration(milliseconds: 800),
                tween: Tween<double>(begin: 0, end: 1),
                builder: (context, value, child) {
                  return Opacity(
                    opacity: value,
                    child: Transform.translate(
                      offset: Offset(0, 20 * (1 - value)),
                      child: _buildMyRankingCard(myRanking),
                    ),
                  );
                },
              ),

            // Top 3 포디움 (애니메이션 탑재)
            if (topThree.length >= 3)
              _buildModernPodium(topThree)
            else
              _buildIncompletedPodium(topThree),

            const SizedBox(height: 10),

            // 4위 이하 순위 (프리미엄 리스트)
            if (restRankings.isNotEmpty)
              _buildPremiumRankingList(
                restRankings,
                currentUserId,
                topThree.length,
              ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // 팀 랭킹 뷰
  Widget _buildTeamRankingView(QuizRankingProvider qrp) {
    if (qrp.teamRankings.isEmpty) {
      return RefreshIndicator(
        color: RED_DANGER_TEXT_50,
        onRefresh: () => qrp.fetchRankings(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Container(
            height: 500,
            alignment: Alignment.center,
            child: const Text('아직 팀 랭킹 기록이 없습니다.'),
          ),
        ),
      );
    }

    final topThree = qrp.teamRankings.take(3).toList();
    final restRankings = qrp.teamRankings.skip(3).toList();
    final myTeamName = context.read<TeamProvider>().selectedTeam?.name;
    final myTeamRanking = myTeamName != null
        ? qrp.teamRankings.where((t) => t.teamName == myTeamName).firstOrNull
        : null;

    return RefreshIndicator(
      color: RED_DANGER_TEXT_50,
      onRefresh: () => qrp.fetchRankings(true),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          children: [
            // 내 팀 순위 표시
            if (myTeamRanking != null)
              TweenAnimationBuilder(
                duration: const Duration(milliseconds: 800),
                tween: Tween<double>(begin: 0, end: 1),
                builder: (context, value, child) {
                  return Opacity(
                    opacity: value,
                    child: Transform.translate(
                      offset: Offset(0, 20 * (1 - value)),
                      child: _buildMyTeamRankingCard(myTeamRanking),
                    ),
                  );
                },
              ),

            // Top 3 포디움 (팀)
            if (topThree.length >= 3)
              _buildTeamPodium(topThree)
            else
              _buildIncompletedTeamPodium(topThree),

            const SizedBox(height: 10),

            // 4위 이하 팀 순위
            if (restRankings.isNotEmpty)
              _buildTeamRankingList(restRankings, topThree.length, myTeamName),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // 내 팀 순위 카드
  Widget _buildMyTeamRankingCard(RankingTeamModel myTeam) {
    final teamModel = context.read<TeamProvider>().findTeamByName(
      myTeam.teamName,
    );

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      padding: const EdgeInsets.all(1),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            teamModel?.color ?? Colors.blue,
            Colors.white.withOpacity(0.5),
            teamModel?.color ?? Colors.blue,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (teamModel?.color ?? Colors.blue).withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(19),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: CircleAvatar(
                radius: 18,
                backgroundColor: Colors.white,
                backgroundImage: teamModel?.logoPath != null
                    ? AssetImage(teamModel!.logoPath)
                    : null,
              ),
            ),
            const SizedBox(width: 15),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '나의 팀 순위',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  teamModel?.name ?? myTeam.teamName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${myTeam.rank}위',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'kbo',
                  ),
                ),
                Text(
                  '${myTeam.totalScore} pts',
                  style: TextStyle(
                    color: WHITE,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 내 순위 카드
  Widget _buildMyRankingCard(RankingUserModel myRanking) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 20, 16, 10),
      padding: const EdgeInsets.all(1),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Colors.blue, Colors.purple, Colors.blue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(19),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Consumer<QuizRankingProvider>(
                    builder: (context, qrp, _) => Image.asset(
                      QuizTierUtils.getTierEmblem(
                        qrp.getOverallTier(myRanking.userId),
                      ),
                      width: 28,
                      height: 28,
                    ),
                  ),
                ),
                const SizedBox(width: 15),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '나의 랭킹 현황',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      myRanking.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Consumer<QuizRankingProvider>(
                  builder: (context, qrp, _) {
                    final overallScore = qrp.getOverallScore(myRanking.userId);
                    final displayScore = overallScore > 0
                        ? overallScore
                        : myRanking.score;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${myRanking.rank}위',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'kbo',
                          ),
                        ),
                        Text(
                          '$displayScore pts',
                          style: const TextStyle(
                            color: Colors.blueAccent,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            Consumer<QuizRankingProvider>(
              builder: (context, qrp, _) {
                final overallScore = qrp.getOverallScore(myRanking.userId);
                // 캐시가 아직 없으면 현재 카드 점수를 fallback으로 사용
                final scoreForBar = overallScore > 0
                    ? overallScore
                    : myRanking.score;
                return _buildTierProgressBar(context, scoreForBar);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTierProgressBar(BuildContext context, int score) {
    final progressInfo = QuizTierUtils.getTierProgress(score);
    final themeColor =
        context.read<TeamProvider>().selectedTeam?.color ?? BUTTON;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${progressInfo.currentTier} 등급',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: QuizTierUtils.getTierColor(progressInfo.currentTier),
              ),
            ),
            if (progressInfo.currentTier != 'LEGEND')
              Text(
                progressInfo.remainingScore > 0
                    ? '다음 등급까지 ${progressInfo.remainingScore}P'
                    : '최대 등급 달성! 🔥',
                style: const TextStyle(
                  fontSize: 10,
                  color: Colors.white54,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
        if (progressInfo.currentTier != 'LEGEND') const SizedBox(height: 6),
        if (progressInfo.currentTier != 'LEGEND')
          Stack(
            children: [
              Container(
                width: double.infinity,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: progressInfo.progress),
                duration: const Duration(milliseconds: 1000),
                curve: Curves.easeOutCubic,
                builder: (context, value, child) {
                  return FractionallySizedBox(
                    widthFactor: value.clamp(0.01, 1.0),
                    child: Container(
                      height: 4,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [themeColor, themeColor.withOpacity(0.6)],
                        ),
                        borderRadius: BorderRadius.circular(2),
                        boxShadow: [
                          BoxShadow(
                            color: themeColor.withOpacity(0.4),
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
      ],
    );
  }

  // --- Ultra Modern Podium ---

  Widget _buildModernPodium(List<RankingUserModel> topThree) {
    final first = topThree.firstWhere((user) => user.rank == 1);
    final second = topThree.firstWhere((user) => user.rank == 2);
    final third = topThree.firstWhere((user) => user.rank == 3);

    return Transform.translate(
      offset: Offset(0, -50),
      child: Container(
        height: 500,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // 2등 바
                Expanded(
                  child: _buildAnimatedPodiumBar(second, 180, [
                    const Color(0xFF9E9E9E),
                    const Color(0xFF616161),
                  ], 2),
                ),
                const SizedBox(width: 8),
                // 1등 바
                Expanded(
                  child: _buildAnimatedPodiumBar(
                    first,
                    240,
                    [const Color(0xFFFFC107), const Color(0xFFB8860B)],
                    1,
                    isMain: true,
                  ),
                ),
                const SizedBox(width: 8),
                // 3등 바
                Expanded(
                  child: _buildAnimatedPodiumBar(third, 160, [
                    const Color(0xFF8D6E63),
                    const Color(0xFF5D4037),
                  ], 3),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedPodiumBar(
    RankingUserModel user,
    double targetHeight,
    List<Color> colors,
    int rank, {
    bool isMain = false,
  }) {
    final isDarkMode =
        MediaQuery.of(context).platformBrightness == Brightness.dark;
    return TweenAnimationBuilder(
      duration: Duration(milliseconds: 1000 + (rank * 200)),
      curve: Curves.elasticOut,
      tween: Tween<double>(begin: 0, end: targetHeight),
      builder: (context, height, child) {
        return Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            // 프로필 & 이름 (상단 배치)
            Column(
              children: [
                CircleAvatar(
                  radius: isMain ? 32 : 26,
                  backgroundColor: colors[0],
                  child: CircleAvatar(
                    radius: isMain ? 29 : 23,
                    backgroundImage: user.profileUrl != null
                        ? NetworkImage(user.profileUrl!)
                        : null,
                    backgroundColor: Colors.grey.shade100,
                    child: user.profileUrl == null
                        ? Icon(
                            Icons.person,
                            size: isMain ? 25 : 20,
                            color: Colors.grey.shade400,
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      user.name,
                      style: TextStyle(
                        fontSize: isMain ? 13 : 11,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode
                            ? Colors.white
                            : const Color(0xFF1E293B),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(width: 4),
                    Image.asset(
                      QuizTierUtils.getTierEmblem(
                        context.read<QuizRankingProvider>().getOverallTier(
                          user.userId,
                        ),
                      ),
                      width: isMain ? 22 : 18,
                      height: isMain ? 22 : 18,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                // 점수 버블 (사진처럼 상단에)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade300),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    '${user.score}P',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: isDarkMode
                          ? const Color(0xFF1E293B)
                          : Colors.grey.shade700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // 완벽하게 정렬된 3D 아이소메트릭 블록
            CustomPaint(
              size: Size(double.infinity, height + 40),
              painter: _Iso3DBlockPainter(
                baseColor: colors[0],
                sideColor: colors[1],
                height: height,
                rank: rank,
              ),
              child: SizedBox(
                height: height + 40,
                width: double.infinity,
                child: Stack(
                  children: [
                    Center(
                      child: SingleChildScrollView(
                        physics: const NeverScrollableScrollPhysics(),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(height: 15),
                            Icon(
                              rank == 1
                                  ? Icons.emoji_events
                                  : Icons.military_tech,
                              color: Colors.white.withOpacity(0.9),
                              size: isMain ? 32 : 24,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$rank',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: isMain ? 34 : 24,
                                fontWeight: FontWeight.w900,
                                fontFamily: 'kbo',
                                shadows: [
                                  Shadow(
                                    color: Colors.black.withOpacity(0.3),
                                    offset: const Offset(1, 1),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPremiumRankingList(
    List<RankingUserModel> rankings,
    String? currentUserId,
    int podiumCount,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: rankings.length,
        itemBuilder: (context, index) {
          final user = rankings[index];
          final actualRank = index + podiumCount + 1;
          return _buildPremiumRankingListItem(
            user.copyWith(rank: actualRank),
            currentUserId,
          );
        },
      ),
    );
  }

  Widget _buildPremiumRankingListItem(
    RankingUserModel user,
    String? currentUserId,
  ) {
    final isDarkMode =
        MediaQuery.of(context).platformBrightness == Brightness.dark;
    final isMe = currentUserId != null && user.userId == currentUserId;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isMe
            ? (isDarkMode ? Colors.blue.withOpacity(0.2) : Colors.blue.shade50)
            : (isDarkMode ? const Color(0xFF1E293B) : Colors.white),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
        border: isMe ? Border.all(color: Colors.blue.shade200, width: 2) : null,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            // 순위 (leading 필드 대체)
            SizedBox(
              width: 45,
              child: Center(
                child: Text(
                  '${user.rank}',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'kbo',
                    color: isMe ? Colors.blue : Colors.grey.shade400,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // 유저 정보 (title 필드 대체)
            Expanded(
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundImage: user.profileUrl != null
                        ? NetworkImage(user.profileUrl!)
                        : null,
                    backgroundColor: Colors.grey.shade200,
                    child: user.profileUrl == null
                        ? const Icon(Icons.person, color: Colors.grey)
                        : null,
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Row(
                      children: [
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.name,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: isDarkMode ? Colors.white : Colors.black,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),

                            if (user.teamName != null) ...[
                              Builder(
                                builder: (context) {
                                  final teamProvider = context
                                      .read<TeamProvider>();
                                  final teamModel = teamProvider.findTeamByName(
                                    user.teamName!,
                                  );
                                  final teamColor =
                                      teamModel?.color ?? Colors.grey.shade600;

                                  return Text(
                                    user.teamName!,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDarkMode
                                          ? GRAYSCALE_LABEL_500
                                          : teamColor,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  );
                                },
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(width: 18),
                        Transform.translate(
                          offset: Offset(0, -5),
                          child: Consumer<QuizRankingProvider>(
                            builder: (context, qrp, _) => Image.asset(
                              QuizTierUtils.getTierEmblem(
                                qrp.getOverallTier(user.userId),
                              ),
                              width: 34,
                              height: 34,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            // 점수 및 변동 (trailing 필드 대체)
            Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${user.score}P',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    color: isDarkMode ? WHITE : BLACK,
                  ),
                ),
                _buildRankChangeIndicator(user.rankChange, user.rank),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 포디움이 완성되지 않은 경우 (개인)
  Widget _buildIncompletedPodium(List<RankingUserModel> rankings) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Column(
        children: rankings.map((user) {
          return _buildPremiumRankingListItem(user, null);
        }).toList(),
      ),
    );
  }

  // --- Team Ranking Widgets ---

  Widget _buildTeamPodium(List<RankingTeamModel> topThree) {
    if (topThree.isEmpty) return const SizedBox.shrink();

    final first = topThree.firstWhere(
      (t) => t.rank == 1,
      orElse: () => topThree[0],
    ); // fallback
    final second = topThree.length > 1
        ? topThree.firstWhere((t) => t.rank == 2, orElse: () => topThree[1])
        : null;
    final third = topThree.length > 2
        ? topThree.firstWhere((t) => t.rank == 3, orElse: () => topThree[2])
        : null;

    return Transform.translate(
      offset: const Offset(0, -30),
      child: Container(
        height: 500,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (second != null)
                  Expanded(
                    child: _buildAnimatedTeamPodiumBar(second, 180, [
                      const Color(0xFF9E9E9E),
                      const Color(0xFF616161),
                    ], 2),
                  ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildAnimatedTeamPodiumBar(
                    first,
                    240,
                    [const Color(0xFFFFC107), const Color(0xFFB8860B)],
                    1,
                    isMain: true,
                  ),
                ),
                const SizedBox(width: 8),
                if (third != null)
                  Expanded(
                    child: _buildAnimatedTeamPodiumBar(third, 160, [
                      const Color(0xFF8D6E63),
                      const Color(0xFF5D4037),
                    ], 3),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedTeamPodiumBar(
    RankingTeamModel team,
    double targetHeight,
    List<Color> colors,
    int rank, {
    bool isMain = false,
  }) {
    final isDarkMode =
        MediaQuery.of(context).platformBrightness == Brightness.dark;
    final teamModel = context.read<TeamProvider>().findTeamByName(
      team.teamName,
    );

    return TweenAnimationBuilder(
      duration: Duration(milliseconds: 1000 + (rank * 200)),
      curve: Curves.elasticOut,
      tween: Tween<double>(begin: 0, end: targetHeight),
      builder: (context, height, child) {
        return Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            // 팀 로고 & 이름
            Column(
              children: [
                CircleAvatar(
                  radius: isMain ? 35 : 28,
                  backgroundColor: colors[0],
                  child: CircleAvatar(
                    radius: isMain ? 32 : 25,
                    backgroundColor: Colors.white,
                    backgroundImage: teamModel?.logoPath != null
                        ? AssetImage(teamModel!.logoPath)
                        : null,
                    child: teamModel?.logoPath == null
                        ? Icon(
                            Icons.sports_baseball,
                            size: isMain ? 25 : 20,
                            color: Colors.grey.shade400,
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  teamModel?.name ?? team.teamName,
                  style: TextStyle(
                    fontSize: isMain ? 13 : 11,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : const Color(0xFF1E293B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                // 점수 버블
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade300),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    '${team.totalScore}P',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: isDarkMode
                          ? const Color(0xFF1E293B)
                          : Colors.black,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // 3D 아이소메트릭 블록
            CustomPaint(
              size: Size(double.infinity, height + 40),
              painter: _Iso3DBlockPainter(
                baseColor: colors[0],
                sideColor: colors[1],
                height: height,
                rank: rank,
              ),
              child: SizedBox(
                height: height + 40,
                width: double.infinity,
                child: Stack(
                  children: [
                    Center(
                      child: SingleChildScrollView(
                        physics: const NeverScrollableScrollPhysics(),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(height: 15),
                            Icon(
                              rank == 1
                                  ? Icons.emoji_events
                                  : Icons.military_tech,
                              color: Colors.white.withOpacity(0.9),
                              size: isMain ? 32 : 24,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$rank',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: isMain ? 34 : 24,
                                fontWeight: FontWeight.w900,
                                fontFamily: 'kbo',
                                shadows: [
                                  Shadow(
                                    color: Colors.black.withOpacity(0.3),
                                    offset: const Offset(1, 1),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildIncompletedTeamPodium(List<RankingTeamModel> rankings) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: rankings.map((team) {
          return _buildPremiumTeamRankingListItem(team, null);
        }).toList(),
      ),
    );
  }

  Widget _buildTeamRankingList(
    List<RankingTeamModel> rankings,
    int podiumCount,
    String? myTeamName,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: rankings.length,
        itemBuilder: (context, index) {
          final team = rankings[index];
          final actualRank = index + podiumCount + 1;

          return _buildPremiumTeamRankingListItem(
            team.copyWith(rank: actualRank),
            myTeamName,
          );
        },
      ),
    );
  }

  Widget _buildPremiumTeamRankingListItem(
    RankingTeamModel team,
    String? myTeamName,
  ) {
    final isDarkMode =
        MediaQuery.of(context).platformBrightness == Brightness.dark;
    final isMyTeam = myTeamName != null && team.teamName == myTeamName;
    final teamModel = context.read<TeamProvider>().findTeamByName(
      team.teamName,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isMyTeam
            ? (teamModel?.color.withOpacity(0.1) ??
                  (isDarkMode
                      ? Colors.blue.withOpacity(0.2)
                      : Colors.blue.shade50))
            : (isDarkMode ? const Color(0xFF1E293B) : Colors.white),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
        border: isMyTeam
            ? Border.all(
                color:
                    teamModel?.color.withOpacity(0.5) ?? Colors.blue.shade200,
                width: 2,
              )
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            // 순위
            SizedBox(
              width: 45,
              child: Center(
                child: Text(
                  '${team.rank}',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'kbo',
                    color: isMyTeam
                        ? (teamModel?.color ?? Colors.blue)
                        : Colors.grey.shade400,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // 팀 정보
            Expanded(
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: Colors.white,
                    backgroundImage: teamModel?.logoPath != null
                        ? AssetImage(teamModel!.logoPath)
                        : null,
                    child: teamModel?.logoPath == null
                        ? const Icon(Icons.sports_baseball, color: Colors.grey)
                        : null,
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          teamModel?.name ?? team.teamName,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: isDarkMode ? Colors.white : Colors.black,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (teamModel?.stadium != null)
                          Text(
                            teamModel!.stadium,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            // 점수 및 변동
            Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${team.totalScore}P',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    color: isDarkMode ? Colors.white : const Color(0xFF1E293B),
                  ),
                ),
                _buildRankChangeIndicator(team.rankChange, team.rank),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRankChangeIndicator(int scoreDiff, int rank) {
    // 1위인 경우만 TOP 표시
    if (rank == 1) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.amber.withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          'TOP',
          style: TextStyle(
            color: Colors.amber.shade700,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    // 2위 이하 - 점수 차이 표시 (0점 차이라도 표시)
    final displayDiff = scoreDiff.abs();

    // 점수 차이에 따른 색상 결정
    Color diffColor;
    if (displayDiff == 0) {
      diffColor = Colors.grey; // 동점: 회색
    } else if (displayDiff <= 50) {
      diffColor = Colors.orange; // 50점 이하: 주황색 (근접)
    } else if (displayDiff <= 100) {
      diffColor = Colors.deepOrange; // 100점 이하: 진한 주황색
    } else {
      diffColor = Colors.red; // 100점 초과: 빨간색 (큰 차이)
    }

    return Row(
      children: [
        Icon(Icons.remove, color: diffColor, size: 16),
        Text(
          '$displayDiff',
          style: TextStyle(
            color: diffColor,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  // --- Season Arena Widgets ---

  // 슬림한 시즌 배너 (개편된 디자인)
  Widget _buildSlimSeasonBanner(BuildContext context, QuizRankingProvider qrp) {
    final teamColor =
        context.read<TeamProvider>().selectedTeam?.color ?? BUTTON;
    final isDarkMode =
        MediaQuery.of(context).platformBrightness == Brightness.dark;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        children: [
          // 팀 컬러 포인트 바
          Container(
            width: 4,
            height: 32,
            decoration: BoxDecoration(
              color: teamColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 14),
          // 시즌 정보
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _showSeasonPicker(context, qrp),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        QuizSeasonUtils.getSeasonLabel(qrp.selectedSeason),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode
                              ? const Color(0xFF1E293B)
                              : Colors.black,
                          fontFamily: 'kbo',
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 18,
                        color: Colors.grey.shade400,
                      ),
                    ],
                  ),
                  Text(
                    _getRemainingDaysText(),
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade500,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // 시즌 안내 간소화 버튼
          Tooltip(
            message: '시즌 규칙 및 보상 안내 보기',
            triggerMode: TooltipTriggerMode.tap,
            child: IconButton(
              onPressed: () => _showSeasonInfoDialog(context),
              icon: Icon(
                Icons.info_outline_rounded,
                color: Colors.grey.shade400,
                size: 20,
              ),
              visualDensity: VisualDensity.compact,
            ),
          ),
        ],
      ),
    );
  }

  // 시즌 상세 안내 다이얼로그
  // 시즌 및 티어 상세 안내 다이얼로그
  void _showSeasonInfoDialog(BuildContext context) {
    final teamColor =
        context.read<TeamProvider>().selectedTeam?.color ?? BUTTON;

    showDialog(
      context: context,
      builder: (context) {
        return DefaultTabController(
          length: 2,
          child: AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            backgroundColor: Colors.white,
            contentPadding: EdgeInsets.zero,
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 헤더 및 탭바
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                    child: Row(
                      children: [
                        Icon(Icons.stars_rounded, color: teamColor, size: 28),
                        const SizedBox(width: 10),
                        const Text(
                          '퀴즈 가이드',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                            fontFamily: 'kbo',
                          ),
                        ),
                      ],
                    ),
                  ),
                  TabBar(
                    labelColor: teamColor,
                    unselectedLabelColor: GRAYSCALE_LABEL_400,
                    indicatorColor: teamColor,
                    indicatorSize: TabBarIndicatorSize.tab,
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    dividerColor: Colors.grey.shade100,
                    tabs: const [
                      Tab(text: '시즌 안내'),
                      Tab(text: '티어 등급'),
                    ],
                  ),
                  // 탭 내용
                  Flexible(
                    child: SingleChildScrollView(
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        child: SizedBox(
                          height: 330, // 내용 높이 고정
                          child: TabBarView(
                            children: [
                              // 1번 탭: 시즌 안내
                              _buildSeasonTab(),
                              // 2번 탭: 티어 안내
                              _buildTierTab(),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  '확인',
                  style: TextStyle(
                    color: teamColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSeasonTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSeasonInfoRow(Icons.calendar_month, '시즌 기간', '전/후반기 운영 (15일 단위)'),
        _buildSeasonInfoRow(Icons.info_outline, '4월 시즌 예외', '4월은 통합 시즌으로 운영'),
        _buildSeasonInfoRow(
          Icons.emoji_events,
          '랭킹 산정',
          '해당 반기(또는 시즌) 누적 포인트 합산',
        ),
        _buildSeasonInfoRow(Icons.military_tech, '특별 보상', '티어별 특별 전용 뱃지'),
        _buildSeasonInfoRow(
          Icons.restart_alt,
          '시즌 초기화',
          '매월 1일 및 16일 00:00 초기화 (4월 제외)',
        ),
        const Spacer(),
        _buildTipBox(),
      ],
    );
  }

  Widget _buildTierTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTierRow('LEGEND', '10,000P ~', const Color(0xFFFFD700)),
        _buildTierRow('MVP', '5,000P ~', const Color(0xFFB19CD9)),
        _buildTierRow('ALL-STAR', '2,500P ~', const Color(0xFFFF4D4D)),
        _buildTierRow('MAJOR', '1,200P ~', const Color(0xFFFFD700)),
        _buildTierRow('MINOR', '400P ~', const Color(0xFFC0C0C0)),
        _buildTierRow('PROSPECT', '0P ~', const Color(0xFFCD7F32)),
        const Spacer(),
        _buildTipBox(),
      ],
    );
  }

  Widget _buildTierRow(String title, String score, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          // 티어 엠블럼 이미지
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Image.asset(
              QuizTierUtils.getTierEmblem(title),
              width: 24,
              height: 24,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const Spacer(),
          Text(
            score,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: GRAYSCALE_LABEL_700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTipBox() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lightbulb_outline, size: 16, color: Colors.amber),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              '정답을 빨리 맞힐수록 더 높은 포인트와 콤보 점수를 얻을 수 있습니다!',
              style: TextStyle(
                fontSize: 12,
                color: GRAYSCALE_LABEL_600,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeasonInfoRow(IconData icon, String title, String desc) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 18, color: GRAYSCALE_LABEL_400),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 11,
                  color: GRAYSCALE_LABEL_500,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                desc,
                style: const TextStyle(
                  fontSize: 13,
                  color: GRAYSCALE_LABEL_800,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getRemainingDaysText() {
    final now = DateTime.now();
    // 전반기: 1일~15일 → 15일에 종료
    // 후반기: 16일~말일 → 말일에 종료
    final DateTime seasonEnd;
    if (now.day <= 15) {
      seasonEnd = DateTime(now.year, now.month, 15);
    } else {
      seasonEnd = DateTime(now.year, now.month + 1, 0); // 해당 월의 마지막 날
    }
    final diff = seasonEnd
        .difference(DateTime(now.year, now.month, now.day))
        .inDays;
    return diff > 0 ? '시즌 종료까지 D-$diff' : '시즌 종료 임박!';
  }
}

class _Iso3DBlockPainter extends CustomPainter {
  final Color baseColor;
  final Color sideColor;
  final double height;
  final int rank;

  _Iso3DBlockPainter({
    required this.baseColor,
    required this.sideColor,
    required this.height,
    required this.rank,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const double skew = 12.0;
    const double radius = 12.0;
    final double w = size.width;
    final double h = height;

    final paint = Paint()..style = PaintingStyle.fill;

    // ── blockPath: 정면(topPath 연장) + 오른쪽 측면도 full-height ──
    final blockPath = Path()
      ..moveTo(radius + skew, 0)
      ..lineTo(w - radius, 0)
      // 오른쪽 뒤 모서리 커브 → 뒤쪽 엣지(w) 진입
      ..quadraticBezierTo(w, 0, w, skew * 0.4)
      // ★ 뒤쪽 엣지(w)를 h만큼 그대로 내려감 (측면 뒤 엣지)
      ..lineTo(w, h + skew * 1.6)
      // 오른쪽 아래: 뒤에서 정면 하단으로 꺾임
      ..quadraticBezierTo(w, h + skew * 2, w - skew - radius, h + skew * 2)
      // 바닥 직선
      ..lineTo(radius, h + skew * 2)
      // 왼쪽 아래 모서리
      ..quadraticBezierTo(0, h + skew * 2, 0, h + skew * 2 - radius)
      // 왼쪽 수직 연장
      ..lineTo(0, skew * 2)
      // 왼쪽 위 모서리 (캡)
      ..quadraticBezierTo(0, skew * 2, skew * 0.5, skew)
      ..lineTo(skew, 0)
      ..quadraticBezierTo(skew, 0, radius + skew, 0)
      ..close();

    // 1. 전체 블록 기본색 (정면색)
    canvas.drawPath(blockPath, paint..color = baseColor);

    // 2. 윗면 캡 오버레이 (밝게) - blockPath 와 동일한 상단 경로
    final capPath = Path()
      ..moveTo(radius + skew, 0)
      ..lineTo(w - radius, 0)
      ..quadraticBezierTo(w, 0, w, skew * 0.4) // blockPath 와 동일한 커브
      ..lineTo(w, skew * 2)
      ..lineTo(0, skew * 2)
      ..quadraticBezierTo(0, skew * 2, skew * 0.5, skew)
      ..lineTo(skew, 0)
      ..quadraticBezierTo(skew, 0, radius + skew, 0)
      ..close();

    canvas.save();
    canvas.clipPath(blockPath);
    canvas.drawPath(
      capPath,
      paint..color = Color.lerp(baseColor, Colors.white, 0.38)!,
    );
    canvas.restore();

    // 3. 오른쪽 측면 오버레이 (sideColor) - 뒤쪽 엣지(x=w) 전체 높이
    final sideFacePath = Path()
      ..moveTo(w - skew, skew * 2) // 정면 top-right
      ..quadraticBezierTo(w, 0, w, skew * 0.4) // 뒤쪽 top-right
      ..lineTo(w, h + skew * 1.6) // 뒤쪽 bottom-right
      ..quadraticBezierTo(w, h + skew * 2, w - skew - radius, h + skew * 2)
      ..lineTo(w - skew, h + skew * 2) // 정면 bottom-right
      ..close();

    canvas.save();
    canvas.clipPath(blockPath);
    canvas.drawPath(sideFacePath, paint..color = sideColor);
    canvas.restore();

    // 3. 대각선 광택
    canvas.save();
    canvas.clipPath(blockPath);
    canvas.drawPath(
      Path()
        ..moveTo(0, h * 0.45 + skew * 2)
        ..lineTo(w - skew, skew * 2)
        ..lineTo(w - skew, h * 0.25 + skew * 2)
        ..lineTo(0, h * 0.65 + skew * 2)
        ..close(),
      Paint()..color = Colors.white.withOpacity(0.12),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _Iso3DBlockPainter oldDelegate) =>
      oldDelegate.height != height || oldDelegate.baseColor != baseColor;
}
