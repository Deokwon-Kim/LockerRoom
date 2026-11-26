import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/model/ranking_team_model.dart';
import 'package:lockerroom/provider/quiz_ranking_provider.dart';
import 'package:lockerroom/provider/team_provider.dart';
import 'package:lockerroom/utils/quiz_season_utils.dart';
import 'package:lockerroom/utils/quiz_tier_utils.dart';
import 'package:lockerroom/page/quiz/quiz_hall_of_fame_page.dart';
import 'package:lockerroom/widgets/team_champion_badges.dart';
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
    // 페이지 로드 시 최신 순위 강제 가져오기
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<QuizRankingProvider>().fetchRankings(true);
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
            ? const Color(0xFF090D16)
            : const Color(0xFFF9FAFC),
        appBar: AppBar(
          scrolledUnderElevation: 0,
          backgroundColor: isDarkMode
              ? const Color(0xFF090D16)
              : const Color(0xFFF9FAFC),
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new,
              size: 20,
              color: isDarkMode ? Colors.white : const Color(0xFF141B2D),
            ),
            onPressed: () => Navigator.pop(context),
          ),
          title: Row(
            children: [
              Text(
                '퀴즈 랭킹',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'kbo',
                  color: isDarkMode ? Colors.white : const Color(0xFF141B2D),
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
                        horizontal: 11,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: isDarkMode
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: isDarkMode
                              ? Colors.white12
                              : const Color(0xFFE2E8F0),
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
                              color: isDarkMode
                                  ? Colors.white
                                  : const Color(0xFF141B2D),
                            ),
                          ),
                          const SizedBox(width: 2),
                          Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: isDarkMode
                                ? Colors.white70
                                : const Color(0xFF647189),
                            size: 18,
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
                  if (mounted) {
                    context.read<QuizRankingProvider>().setAllTimeMode(false);
                  }
                });
              },
              child: Container(
                height: 36,
                width: 36,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.amber.shade300, Colors.amber.shade600],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.amber.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.military_tech, color: Colors.white, size: 14),
                    Text(
                      'HALL',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 7.5,
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
                Icons.refresh_rounded,
                color: isDarkMode ? Colors.white70 : const Color(0xFF647189),
              ),
            ),
            const SizedBox(width: 6),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(54),
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              height: 44,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: isDarkMode
                    ? Colors.white.withValues(alpha: 0.06)
                    : const Color(0xFFEEF0F3),
                borderRadius: BorderRadius.circular(14),
              ),
              child: TabBar(
                labelColor: isDarkMode ? Colors.white : const Color(0xFF141B2D),
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13.5,
                  fontFamily: 'kbo',
                ),
                unselectedLabelColor: isDarkMode
                    ? Colors.white54
                    : const Color(0xFF647189),
                unselectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5,
                  fontFamily: 'kbo',
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: isDarkMode ? const Color(0xFF1E293B) : Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF141B2D).withValues(alpha: 0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                dividerColor: Colors.transparent,
                tabs: const [
                  Tab(text: '개인 순위'),
                  Tab(text: '구단 대항전'),
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

    final battingList = qrp.battingKingRankings;
    final battingTopThree = battingList.take(3).toList();
    final battingRest = battingList.skip(3).toList();

    return RefreshIndicator(
      color: RED_DANGER_TEXT_50,
      onRefresh: () => qrp.fetchRankings(true),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          children: [
            if (battingList.isEmpty)
              Container(
                height: 360,
                alignment: Alignment.center,
                child: const Text('아직 타격 기록이 없습니다.'),
              )
            else ...[
              if (battingTopThree.length >= 3)
                _buildBattingKingPodium(battingTopThree)
              else
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: battingTopThree
                        .map((e) => _buildBattingKingListItem(e, currentUserId))
                        .toList(),
                  ),
                ),
              const SizedBox(height: 12),
              if (battingRest.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: battingRest
                        .map((e) => _buildBattingKingListItem(e, currentUserId))
                        .toList(),
                  ),
                ),
            ],
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildBattingKingPodium(List<BattingKingEntry> topThree) {
    final first = topThree[0];
    final second = topThree[1];
    final third = topThree[2];
    final qrp = context.read<QuizRankingProvider>();
    final teamColor =
        context.read<TeamProvider>().selectedTeam?.color ??
        const Color(0xFF0D0C28);
    final c1 = Color.lerp(teamColor, const Color(0xFF0B1020), 0.78)!;
    final c2 = Color.lerp(teamColor, const Color(0xFF141B2D), 0.62)!;

    Widget buildSlot(
      BattingKingEntry entry,
      Color ringColor,
      double barHeight, {
      bool isFirst = false,
    }) {
      final isDefending = qrp.isDefendingKingUser(entry.userId);
      return _buildPodiumHeroSlot(
        rank: entry.rank,
        name: entry.name,
        sub: entry.teamName ?? '${entry.totalHits}/${entry.totalAtBats}타수',
        score: entry.formattedBattingAverage,
        badgeWidget: isDefending
            ? BattingKingTitlePill(
                label: qrp.defendingKingTitle ?? '타격왕',
                fontSize: 8.5,
              )
            : null,
        tierWidget: Text(
          entry.isQualifiedForBattingKing
              ? '${entry.totalHits}/${entry.totalAtBats}타수'
              : '미달 ${entry.totalAtBats}/30',
          style: TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.w800,
            color: Colors.white.withValues(alpha: 0.9),
          ),
        ),
        imageUrl: entry.profileUrl,
        ringColor: ringColor,
        barHeight: barHeight,
        isFirst: isFirst,
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      padding: const EdgeInsets.fromLTRB(12, 18, 12, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [c1, c2],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: c1.withValues(alpha: 0.22),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            flex: 10,
            child: buildSlot(second, const Color(0xFFCBD5E1), 48),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 12,
            child: buildSlot(first, const Color(0xFFF5C451), 64, isFirst: true),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 10,
            child: buildSlot(third, const Color(0xFFD97742), 36),
          ),
        ],
      ),
    );
  }

  Widget _buildBattingKingListItem(
    BattingKingEntry entry,
    String? currentUserId,
  ) {
    final isDarkMode =
        MediaQuery.of(context).platformBrightness == Brightness.dark;
    final isMe = currentUserId != null && entry.userId == currentUserId;
    final qrp = context.read<QuizRankingProvider>();
    final teamProvider = context.read<TeamProvider>();
    final teamColor =
        (entry.teamName != null
            ? teamProvider.findTeamByName(entry.teamName!)?.color
            : null) ??
        teamProvider.selectedTeam?.color ??
        BUTTON;
    final isDefending = qrp.isDefendingKingUser(entry.userId);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF151E32) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isMe
              ? teamColor.withValues(alpha: 0.45)
              : (isDarkMode ? Colors.white10 : const Color(0xFFEEF0F3)),
          width: isMe ? 1.4 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF141B2D).withValues(alpha: 0.045),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: IntrinsicHeight(
          child: Row(
            children: [
              if (isMe) Container(width: 4.5, color: teamColor),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 13,
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 42,
                        child: Text(
                          '${entry.rank}위',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'kbo',
                            color: isMe
                                ? (isDarkMode ? Colors.white : teamColor)
                                : (isDarkMode
                                      ? Colors.white54
                                      : const Color(0xFF647189)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  entry.name,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: isDarkMode
                                        ? Colors.white
                                        : const Color(0xFF141B2D),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                if (isDefending)
                                  BattingKingTitlePill(
                                    label: qrp.defendingKingTitle ?? '타격왕',
                                    fontSize: 9,
                                  ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: entry.isQualifiedForBattingKing
                                        ? const Color(
                                            0xFF34D399,
                                          ).withValues(alpha: 0.16)
                                        : (isDarkMode
                                              ? Colors.white10
                                              : const Color(0xFFEEF0F3)),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    entry.isQualifiedForBattingKing
                                        ? '규정타석 달성'
                                        : '규정 미달 (${entry.totalAtBats}/30)',
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w800,
                                      color: entry.isQualifiedForBattingKing
                                          ? const Color(0xFF059669)
                                          : (isDarkMode
                                                ? Colors.white60
                                                : const Color(0xFF647189)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              entry.teamName != null
                                  ? '${entry.teamName} · ${entry.totalAtBats}타수 ${entry.totalHits}안타'
                                  : '${entry.totalAtBats}타수 ${entry.totalHits}안타',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDarkMode
                                    ? Colors.white54
                                    : const Color(0xFF647189),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        entry.formattedBattingAverage,
                        style: TextStyle(
                          color: isMe
                              ? const Color(0xFFFF5B37)
                              : (entry.isQualifiedForBattingKing
                                    ? (isDarkMode
                                          ? WHITE
                                          : const Color(0xFF141B2D))
                                    : (isDarkMode
                                          ? Colors.white54
                                          : const Color(0xFF647189))),
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'kbo',
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
            // Top 3 포디움 히어로 (팀)
            if (topThree.length >= 3)
              _buildTeamPodium(topThree)
            else
              _buildIncompletedTeamPodium(topThree),

            // 내 팀 순위 하이라이트 카드 (포디움 밖 4위 이하일 때만 표시)
            if (myTeamRanking != null &&
                (topThree.length < 3 || myTeamRanking.rank > 3))
              TweenAnimationBuilder(
                duration: const Duration(milliseconds: 500),
                tween: Tween<double>(begin: 0, end: 1),
                builder: (context, value, child) {
                  return Opacity(
                    opacity: value,
                    child: Transform.translate(
                      offset: Offset(0, 12 * (1 - value)),
                      child: _buildMyTeamRankingCard(myTeamRanking),
                    ),
                  );
                },
              ),

            const SizedBox(height: 12),

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
    final isDarkMode =
        MediaQuery.of(context).platformBrightness == Brightness.dark;
    final teamModel = context.read<TeamProvider>().findTeamByName(
      myTeam.teamName,
    );
    final teamColor = teamModel?.color ?? const Color(0xFF0D0C28);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF151E32) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDarkMode ? Colors.white10 : const Color(0xFFEEF0F3),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF141B2D).withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: IntrinsicHeight(
          child: Row(
            children: [
              Container(width: 4.5, color: teamColor),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 13,
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 42,
                        child: Text(
                          '${myTeam.rank}위',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'kbo',
                            color: isDarkMode ? Colors.white : teamColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      CircleAvatar(
                        radius: 17,
                        backgroundColor: Colors.white,
                        backgroundImage: teamModel?.logoPath != null
                            ? AssetImage(teamModel!.logoPath)
                            : null,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    teamModel?.name ?? myTeam.teamName,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: isDarkMode
                                          ? Colors.white
                                          : const Color(0xFF141B2D),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isDarkMode
                                        ? Colors.white10
                                        : const Color(0xFFEEF0F3),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    'MY TEAM',
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w800,
                                      color: isDarkMode
                                          ? Colors.white70
                                          : const Color(0xFF141B2D),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${myTeam.totalAtBats}타수 ${myTeam.totalHits}안타',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDarkMode
                                    ? Colors.white54
                                    : const Color(0xFF647189),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        myTeam.formattedBattingAverage,
                        style: const TextStyle(
                          color: Color(0xFFFF5B37),
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'kbo',
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
    );
  }

  Widget _buildPodiumHeroSlot({
    required int rank,
    required String name,
    required String sub,
    required String score,
    required Widget tierWidget,
    Widget? badgeWidget,
    String? imageUrl,
    String? assetLogoPath,
    required Color ringColor,
    required double barHeight,
    bool isFirst = false,
  }) {
    final avatarRadius = isFirst ? 31.0 : 24.0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isFirst)
          const Padding(
            padding: EdgeInsets.only(bottom: 4),
            child: Text('👑', style: TextStyle(fontSize: 18)),
          )
        else
          const SizedBox(height: 18),
        Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomCenter,
          children: [
            Container(
              padding: const EdgeInsets.all(2.5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: ringColor, width: 2.5),
                boxShadow: isFirst
                    ? [
                        BoxShadow(
                          color: ringColor.withValues(alpha: 0.45),
                          blurRadius: 14,
                        ),
                      ]
                    : null,
              ),
              child: CircleAvatar(
                radius: avatarRadius,
                backgroundColor: Colors.white.withValues(alpha: 0.16),
                backgroundImage: assetLogoPath != null
                    ? AssetImage(assetLogoPath)
                    : (imageUrl != null && imageUrl.isNotEmpty
                              ? NetworkImage(imageUrl)
                              : null)
                          as ImageProvider?,
                child:
                    (assetLogoPath == null &&
                        (imageUrl == null || imageUrl.isEmpty))
                    ? Text(
                        name.isNotEmpty ? name.characters.first : '?',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: isFirst ? 18 : 14,
                        ),
                      )
                    : null,
              ),
            ),
            Positioned(
              bottom: -6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: const Color(0xFF141B2D),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: ringColor, width: 1.2),
                ),
                child: Text(
                  '$rank',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: isFirst ? 13 : 12,
            fontWeight: FontWeight.w800,
          ),
        ),
        if (badgeWidget != null) ...[
          const SizedBox(height: 3),
          FittedBox(fit: BoxFit.scaleDown, child: badgeWidget),
        ],
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            sub,
            maxLines: 1,
            softWrap: false,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.78),
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 3),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            score,
            maxLines: 1,
            softWrap: false,
            style: TextStyle(
              color: const Color(0xFFFFD875),
              fontSize: isFirst ? 15 : 13.5,
              fontWeight: FontWeight.w900,
              fontFamily: 'kbo',
            ),
          ),
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(11),
            bottom: Radius.circular(5),
          ),
          child: Container(
            width: double.infinity,
            height: barHeight,
            decoration: BoxDecoration(
              gradient: isFirst
                  ? LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        const Color(0xFFFFE082).withValues(alpha: 0.72),
                        const Color(0xFFD99B16).withValues(alpha: 0.56),
                        const Color(0xFF8C5B05).withValues(alpha: 0.45),
                      ],
                    )
                  : LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: rank == 2
                          ? [
                              const Color(0xFFF1F5F9).withValues(alpha: 0.64),
                              const Color(0xFF94A3B8).withValues(alpha: 0.48),
                              const Color(0xFF475569).withValues(alpha: 0.42),
                            ]
                          : [
                              const Color(0xFFFDBA74).withValues(alpha: 0.66),
                              const Color(0xFFC26A27).withValues(alpha: 0.52),
                              const Color(0xFF6E330C).withValues(alpha: 0.44),
                            ],
                    ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(11),
                bottom: Radius.circular(5),
              ),
              border: Border.all(
                color: isFirst
                    ? const Color(0xFFFFECB3).withValues(alpha: 0.9)
                    : (rank == 2
                              ? const Color(0xFFE2E8F0)
                              : const Color(0xFFFED7AA))
                          .withValues(alpha: 0.75),
                width: isFirst ? 1.5 : 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: isFirst
                      ? const Color(0xFFFFD875).withValues(alpha: 0.38)
                      : (rank == 2
                                ? const Color(0xFFE2E8F0)
                                : const Color(0xFFEA580C))
                            .withValues(alpha: 0.22),
                  blurRadius: isFirst ? 18 : 10,
                  spreadRadius: isFirst ? 1 : 0,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: isFirst ? 3.0 : 2.0,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isFirst
                            ? const [
                                Color(0xFFFFF7D6),
                                Color(0xFFFFD875),
                                Color(0xFFFFF7D6),
                              ]
                            : [
                                Colors.white.withValues(alpha: 0.35),
                                Colors.white.withValues(alpha: 0.85),
                                Colors.white.withValues(alpha: 0.35),
                              ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: FittedBox(fit: BoxFit.scaleDown, child: tierWidget),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // --- Team Ranking Widgets ---

  // Top 3 포디움 (팀)
  Widget _buildTeamPodium(List<RankingTeamModel> topThree) {
    if (topThree.isEmpty) return const SizedBox.shrink();

    final first = topThree.firstWhere(
      (t) => t.rank == 1,
      orElse: () => topThree[0],
    );
    final second = topThree.length > 1
        ? topThree.firstWhere((t) => t.rank == 2, orElse: () => topThree[1])
        : null;
    final third = topThree.length > 2
        ? topThree.firstWhere((t) => t.rank == 3, orElse: () => topThree[2])
        : null;

    final teamColor =
        context.read<TeamProvider>().selectedTeam?.color ??
        const Color(0xFF0D0C28);
    final c1 = Color.lerp(teamColor, const Color(0xFF0B1020), 0.78)!;
    final c2 = Color.lerp(teamColor, const Color(0xFF141B2D), 0.62)!;

    Widget buildTeamSlot(
      RankingTeamModel team,
      int rank,
      Color ringColor,
      double barHeight, {
      bool isFirst = false,
    }) {
      final tm = context.read<TeamProvider>().findTeamByName(team.teamName);
      return _buildPodiumHeroSlot(
        rank: rank,
        name: tm?.name ?? team.teamName,
        sub: '${team.totalAtBats}타수 ${team.totalHits}안타',
        score: team.formattedBattingAverage,
        tierWidget: Text(
          tm?.symplename ?? 'TEAM',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: Colors.white.withValues(alpha: 0.9),
          ),
        ),
        assetLogoPath: tm?.logoPath,
        ringColor: ringColor,
        barHeight: barHeight,
        isFirst: isFirst,
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      padding: const EdgeInsets.fromLTRB(12, 18, 12, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [c1, c2],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: c1.withValues(alpha: 0.22),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (second != null)
            Expanded(
              flex: 10,
              child: buildTeamSlot(second, 2, const Color(0xFFCBD5E1), 48),
            ),
          const SizedBox(width: 8),
          Expanded(
            flex: 12,
            child: buildTeamSlot(
              first,
              1,
              const Color(0xFFF5C451),
              64,
              isFirst: true,
            ),
          ),
          const SizedBox(width: 8),
          if (third != null)
            Expanded(
              flex: 10,
              child: buildTeamSlot(third, 3, const Color(0xFFD97742), 36),
            ),
        ],
      ),
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
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isMyTeam
            ? (teamModel?.color.withValues(alpha: 0.08) ??
                  (isDarkMode
                      ? Colors.blue.withValues(alpha: 0.16)
                      : Colors.blue.shade50))
            : (isDarkMode ? const Color(0xFF151E32) : Colors.white),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: isMyTeam
              ? (teamModel?.color.withValues(alpha: 0.45) ??
                    Colors.blue.shade200)
              : (isDarkMode ? Colors.white10 : const Color(0xFFEEF0F3)),
          width: isMyTeam ? 1.5 : 1.0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          children: [
            // 순위
            SizedBox(
              width: 28,
              child: Center(
                child: Text(
                  '${team.rank}',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'kbo',
                    color: isMyTeam
                        ? (teamModel?.color ?? Colors.blue)
                        : (isDarkMode
                              ? Colors.white54
                              : const Color(0xFF647189)),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            // 팀 정보
            Expanded(
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 17,
                    backgroundColor: Colors.white,
                    backgroundImage: teamModel?.logoPath != null
                        ? AssetImage(teamModel!.logoPath)
                        : null,
                    child: teamModel?.logoPath == null
                        ? const Icon(
                            Icons.sports_baseball,
                            size: 18,
                            color: Colors.grey,
                          )
                        : null,
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 6,
                          runSpacing: 3,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              teamModel?.name ?? team.teamName,
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13.5,
                                color: isDarkMode
                                    ? Colors.white
                                    : const Color(0xFF141B2D),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (context
                                .read<QuizRankingProvider>()
                                .isDefendingChampionTeam(team.teamName))
                              TeamFanTitlePill(
                                label: '디펜딩 챔피언',
                                teamColor: teamModel?.color ?? BUTTON,
                              ),
                          ],
                        ),
                        Text(
                          '${team.totalAtBats}타수 ${team.totalHits}안타',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDarkMode
                                ? Colors.white54
                                : const Color(0xFF647189),
                            fontWeight: FontWeight.w600,
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
            // 팀 타율
            Text(
              team.formattedBattingAverage,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 15,
                fontFamily: 'kbo',
                color: isDarkMode ? Colors.white : const Color(0xFF141B2D),
              ),
            ),
          ],
        ),
      ),
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
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSeasonInfoRow(
            Icons.calendar_month,
            '월간 1시즌제',
            '매월 1일 00:00 ~ 말일 23:59 운영',
          ),
          _buildSeasonInfoRow(
            Icons.emoji_events,
            '타격왕 선정 기준',
            '월간 누적 규정타석(30타수+) 최고 타율 1위',
          ),
          _buildSeasonInfoRow(
            Icons.military_tech,
            '타격왕 칭호 · 보상',
            '👑 YY.MM 타격왕 칭호 배지 + 명예의 전당 헌액',
          ),
          _buildSeasonInfoRow(
            Icons.style_rounded,
            '디펜딩 특전',
            '다음 달 시즌 동안 비디오 판독 찬스 +1회 (총 2회)',
          ),
          _buildSeasonInfoRow(
            Icons.restart_alt,
            '시즌 초기화',
            '매월 1일 00:00 새 시즌 시작 & 순위 초기화',
          ),
          const SizedBox(height: 12),
          _buildTipBox(),
        ],
      ),
    );
  }

  Widget _buildTierTab() {
    final criteriaList = QuizTierUtils.battingTierCriteria.reversed.toList();
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '2중 승급 기준 (누적 안타 + 시즌 타율)',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: GRAYSCALE_LABEL_600,
            ),
          ),
          const SizedBox(height: 6),
          ...criteriaList.map((c) {
            final avgStr = c.minAvg <= 0
                ? '시작 등급'
                : '${c.minHits}안타 · .${(c.minAvg * 1000).round().toString().padLeft(3, '0')}+';
            return _buildTierRow(
              c.tierName,
              avgStr,
              QuizTierUtils.getTierColor(c.tierName),
            );
          }),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: GRAYSCALE_LABEL_100),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '🔥 연속 안타(콤보) 보상',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: BUTTON,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  '• 3연타: 진루 가속 (2루타 이상)\n• 5연타: 소모된 찬스 카드 1개 재충전\n• 10연타: 홈런 진루 + 동률 시 최대 연속안타 우선',
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.45,
                    color: GRAYSCALE_LABEL_700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _buildTipBox(),
        ],
      ),
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
              '3연타 2루타 · 5연타 찬스 카드 충전 · 10연타 홈런! 타격왕 동률 시 최대 연속안타가 우선합니다.',
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
          Expanded(
            child: Column(
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
