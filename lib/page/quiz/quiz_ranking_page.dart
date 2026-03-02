import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/model/ranking_team_model.dart';
import 'package:lockerroom/model/ranking_user_model.dart';

import 'package:lockerroom/provider/quiz_ranking_provider.dart';
import 'package:lockerroom/provider/team_provider.dart';
import 'package:provider/provider.dart';

class QuizRankingPage extends StatefulWidget {
  const QuizRankingPage({super.key});

  @override
  State<QuizRankingPage> createState() => _QuizRankingPageState();
}

class _QuizRankingPageState extends State<QuizRankingPage> {
  // 카테고리 목록
  final List<Map<String, String>> _categories = [
    {'value': 'all', 'label': '전체'},
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

  void _showCategoryPicker(BuildContext context, QuizRankingProvider qrp) {
    int selectedIndex = _categories.indexWhere(
      (c) => c['value'] == qrp.selectedCategory,
    );
    if (selectedIndex == -1) selectedIndex = 0;

    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) {
        return Container(
          height: 250,
          color: CupertinoColors.systemBackground.resolveFrom(context),
          child: Column(
            children: [
              // 상단 바
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
                              .watch<TeamProvider>()
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
                              .watch<TeamProvider>()
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
                    qrp.setCategory(_categories[index]['value']!);
                  },
                  itemExtent: 40,
                  children: _categories.map((category) {
                    return Center(
                      child: Text(
                        category['label']!,
                        style: const TextStyle(fontSize: 20),
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

  String _getCategoryLabel(String value) {
    final category = _categories.firstWhere(
      (c) => c['value'] == value,
      orElse: () => {'value': 'all', 'label': '전체'},
    );
    return category['label']!;
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final teamProvider = context.read<TeamProvider>();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.grey[100],
        appBar: AppBar(
          scrolledUnderElevation: 0,
          backgroundColor: Colors.grey[100],
          title: Consumer<QuizRankingProvider>(
            builder: (context, qrp, child) {
              return Row(
                children: [
                  const Text(
                    '퀴즈 랭킹',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'kbo',
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () => _showCategoryPicker(context, qrp),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: WHITE,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: GRAYSCALE_LABEL_300),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _getCategoryLabel(qrp.selectedCategory),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Icon(Icons.keyboard_arrow_down, size: 20),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          centerTitle: false,
          elevation: 0,
          actions: [
            IconButton(
              onPressed: () {
                context.read<QuizRankingProvider>().fetchRankings(true);
              },
              icon: const Icon(Icons.refresh),
            ),
          ],
          bottom: TabBar(
            labelColor: Colors.black,
            labelStyle: TextStyle(color: BLACK, fontWeight: FontWeight.bold),
            unselectedLabelColor: Colors.grey,
            indicatorColor: teamProvider.selectedTeam?.color,
            indicatorSize: TabBarIndicatorSize.tab,
            indicatorWeight: 3.0,
            tabs: [
              Tab(text: '개인 랭킹'),
              Tab(text: '팀 랭킹'),
            ],
          ),
        ),
        body: Consumer<QuizRankingProvider>(
          builder: (context, qrp, child) {
            if (qrp.isLoading) {
              return const Center(
                child: CircularProgressIndicator(color: BUTTON),
              );
            }

            if (qrp.errorMessage != null) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 48,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      qrp.errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red),
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
            // 내 순위 표시 (항상 표시)
            if (myRanking != null) _buildMyRankingCard(myRanking),

            // Top 3 포디움
            if (topThree.length >= 3)
              Transform.translate(
                offset: const Offset(0, -10),
                child: _buildPodium(topThree),
              )
            else
              _buildIncompletedPodium(topThree),

            const SizedBox(height: 30),

            // 4위 이하 순위
            if (restRankings.isNotEmpty)
              _buildRankingList(restRankings, currentUserId, topThree.length),

            const SizedBox(height: 20),
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

    return RefreshIndicator(
      color: RED_DANGER_TEXT_50,
      onRefresh: () => qrp.fetchRankings(true),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          children: [
            const SizedBox(height: 20),

            // Top 3 포디움 (팀)
            if (topThree.length >= 3)
              _buildTeamPodium(topThree)
            else
              _buildIncompletedTeamPodium(topThree),

            const SizedBox(height: 30),

            // 4위 이하 순위 (팀)
            if (restRankings.isNotEmpty)
              _buildTeamRankingList(restRankings, topThree.length),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // 내 순위 카드 (상단 고정)
  Widget _buildMyRankingCard(RankingUserModel myRanking) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade400, Colors.blue.shade600],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.emoji_events, color: Colors.white, size: 32),
          const SizedBox(width: 12),
          const Text(
            '내 순위',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          Text(
            '${myRanking.rank}위',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${myRanking.score}점',
            style: const TextStyle(color: Colors.white70, fontSize: 16),
          ),
        ],
      ),
    );
  }

  // Top 3 포디움 (개인)
  Widget _buildPodium(List<RankingUserModel> topThree) {
    final first = topThree.firstWhere((user) => user.rank == 1);
    final second = topThree.firstWhere((user) => user.rank == 2);
    final third = topThree.firstWhere((user) => user.rank == 3);

    return Container(
      height: 400,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // 2위 (왼쪽)
          _buildPodiumBar(
            second,
            LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.grey.shade300, Colors.grey.shade500],
            ),
            180,
          ),
          const SizedBox(width: 10),
          // 1위 (가운데)
          _buildPodiumBar(
            first,
            const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFFFE57F), // 샴페인 골드
                Color(0xFFFFD700), // 리얼 골드
                Color(0xFFFFB300), // 앰버 골드
                Color(0xFFD4AF37), // 메탈릭
                Color(0xFFFFD700),
              ],
              stops: [0.0, 0.2, 0.5, 0.8, 1.0],
            ),
            230,
            isFirst: true,
          ),
          const SizedBox(width: 10),
          // 3위 (오른쪽)
          _buildPodiumBar(
            third,
            LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.brown.shade200, Colors.brown.shade400],
            ),
            160,
          ),
        ],
      ),
    );
  }

  // 포디움이 완성되지 않은 경우 (개인)
  Widget _buildIncompletedPodium(List<RankingUserModel> rankings) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: rankings.map((user) {
          return _buildRankingListItem(user, null);
        }).toList(),
      ),
    );
  }

  Widget _buildPodiumBar(
    RankingUserModel user,
    Gradient gradient,
    double height, {
    bool isFirst = false,
  }) {
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // 프로필 사진
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isFirst
                    ? const Color(0xFFFFD700)
                    : (gradient is LinearGradient
                          ? gradient.colors.first
                          : Colors.grey),
                width: 3,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: CircleAvatar(
              radius: 35,
              backgroundImage: user.profileUrl != null
                  ? NetworkImage(user.profileUrl!)
                  : null,
              backgroundColor: Colors.grey.shade300,
              child: user.profileUrl == null
                  ? Icon(Icons.person, size: 35, color: Colors.grey.shade600)
                  : null,
            ),
          ),
          const SizedBox(height: 8),
          // 닉네임
          Text(
            user.name,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          if (user.teamName != null)
            Builder(
              builder: (context) {
                final team = context.read<TeamProvider>().findTeamByName(
                  user.teamName!,
                );
                return Text(
                  user.teamName!,
                  style: TextStyle(
                    fontSize: 11,
                    color: team?.color ?? Colors.grey.shade600,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                );
              },
            ),
          const SizedBox(height: 4),
          // 점수
          Text(
            '${user.score}점',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 8),
          // 포디움 막대
          Container(
            height: height,
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    user.rank == 1 ? Icons.emoji_events : Icons.military_tech,
                    color: Colors.white,
                    size: 40,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${user.rank}위',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRankingList(
    List<RankingUserModel> rankings,
    String? currentUserId,
    int podiumCount,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        itemCount: rankings.length,
        itemBuilder: (context, index) {
          final user = rankings[index];
          // 포디엄 이후의 순위이므로, 실제 순위는 index + podiumCount + 1
          final int actualRank = index + podiumCount + 1;

          return _buildRankingListItem(
            user.copyWith(rank: actualRank), // 강제 랭크 보정
            currentUserId,
            isCard: false,
            isLast: index == rankings.length - 1,
          );
        },
      ),
    );
  }

  Widget _buildRankingListItem(
    RankingUserModel user,
    String? currentUserId, {
    bool isCard = true,
    bool isLast = false,
  }) {
    final isMe = currentUserId != null && user.userId == currentUserId;

    final rowContent = Row(
      children: [
        // 순위
        SizedBox(
          width: 40,
          child: Text(
            '${user.rank}',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isMe ? Colors.blue.shade700 : Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(width: 12),
        // 프로필 사진
        CircleAvatar(
          radius: 25,
          backgroundImage: user.profileUrl != null
              ? NetworkImage(user.profileUrl!)
              : null,
          backgroundColor: Colors.grey.shade300,
          child: user.profileUrl == null
              ? Icon(Icons.person, color: Colors.grey.shade600)
              : null,
        ),
        const SizedBox(width: 12),
        // 닉네임
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user.name,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: isMe ? Colors.blue.shade700 : Colors.black,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 3),
              if (user.teamName != null)
                Builder(
                  builder: (context) {
                    final team = context.read<TeamProvider>().findTeamByName(
                      user.teamName!,
                    );
                    return Text(
                      user.teamName!,
                      style: TextStyle(
                        fontSize: 12,
                        color: team?.color ?? Colors.grey.shade600,
                        fontWeight: FontWeight.bold,
                      ),
                    );
                  },
                ),
              if (isMe)
                Text(
                  '나',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blue.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
        ),
        // 점수
        Text(
          '${user.score}점',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade700,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 12),
        // 순위 변동 화살표
        _buildRankChangeIndicator(user.rankChange, user.rank),
      ],
    );

    if (isCard) {
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isMe ? Colors.blue.shade50 : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: isMe
              ? Border.all(color: Colors.blue.shade300, width: 2)
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: rowContent,
      );
    } else {
      return Container(
        color: isMe ? Colors.blue.shade50 : Colors.transparent,
        child: Column(
          children: [
            Padding(padding: const EdgeInsets.all(16), child: rowContent),
            if (!isLast)
              Divider(height: 1, thickness: 1, color: Colors.grey.shade200),
          ],
        ),
      );
    }
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

    return Container(
      height: 380,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (second != null) ...[
            _buildTeamPodiumBar(
              second,
              LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.grey.shade300, Colors.grey.shade500],
              ),
              180,
            ),
            const SizedBox(width: 10),
          ],
          _buildTeamPodiumBar(
            first,
            const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFFFE57F),
                Color(0xFFFFD700),
                Color(0xFFFFB300),
                Color(0xFFD4AF37),
                Color(0xFFFFD700),
              ],
              stops: [0.0, 0.2, 0.5, 0.8, 1.0],
            ),
            230,
            isFirst: true,
          ),
          if (third != null) ...[
            const SizedBox(width: 10),
            _buildTeamPodiumBar(
              third,
              LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.brown.shade200, Colors.brown.shade400],
              ),
              160,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildIncompletedTeamPodium(List<RankingTeamModel> rankings) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: rankings.map((team) {
          return _buildTeamRankingListItem(team, isCard: true, isLast: true);
        }).toList(),
      ),
    );
  }

  Widget _buildTeamPodiumBar(
    RankingTeamModel team,
    Gradient gradient,
    double height, {
    bool isFirst = false,
  }) {
    // 팀 정보 가져오기
    final teamModel = context.read<TeamProvider>().findTeamByName(
      team.teamName,
    );

    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // 팀 로고
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isFirst
                    ? const Color(0xFFFFD700)
                    : (gradient is LinearGradient
                          ? gradient.colors.first
                          : Colors.grey),
                width: 3,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.all(4), // 로고 패딩
            child: CircleAvatar(
              radius: 35,
              backgroundColor: Colors.white,
              backgroundImage: teamModel?.logoPath != null
                  ? AssetImage(teamModel!.logoPath)
                  : null,
              child: teamModel?.logoPath == null
                  ? const Icon(
                      Icons.sports_baseball,
                      size: 35,
                      color: Colors.grey,
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 8),
          // 팀 이름
          Text(
            teamModel?.name ?? team.teamName,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          // 점수
          Text(
            '${team.totalScore}점',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 8),
          // 포디움 막대
          Container(
            height: height,
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    team.rank == 1 ? Icons.emoji_events : Icons.military_tech,
                    color: Colors.white,
                    size: 40,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${team.rank}위',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamRankingList(
    List<RankingTeamModel> rankings,
    int podiumCount,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        itemCount: rankings.length,
        itemBuilder: (context, index) {
          final team = rankings[index];
          // 포디엄 이후 순위 보정
          final int actualRank = index + podiumCount + 1;

          return _buildTeamRankingListItem(
            team.copyWith(rank: actualRank), // 강제 랭크 보정
            isCard: false,
            isLast: index == rankings.length - 1,
          );
        },
      ),
    );
  }

  Widget _buildTeamRankingListItem(
    RankingTeamModel team, {
    bool isCard = true,
    bool isLast = false,
  }) {
    final teamModel = context.read<TeamProvider>().findTeamByName(
      team.teamName,
    );

    final rowContent = Row(
      children: [
        // 순위
        SizedBox(
          width: 40,
          child: Text(
            '${team.rank}',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(width: 12),
        // 팀 로고
        CircleAvatar(
          radius: 25,
          backgroundColor: Colors.white,
          backgroundImage: teamModel?.logoPath != null
              ? AssetImage(teamModel!.logoPath)
              : null,
          child: teamModel?.logoPath == null
              ? const Icon(Icons.sports_baseball, color: Colors.grey)
              : null,
        ),
        const SizedBox(width: 12),
        // 팀 이름
        Expanded(
          child: Text(
            teamModel?.name ?? team.teamName,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        // 점수
        Text(
          '${team.totalScore}점',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade700,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 12),
        // 순위 변동 (팀은 초기 0일 수 있으니 표시)
        _buildRankChangeIndicator(team.rankChange, team.rank),
      ],
    );

    if (isCard) {
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: rowContent,
      );
    } else {
      return Container(
        color: Colors.transparent,
        child: Column(
          children: [
            Padding(padding: const EdgeInsets.all(16), child: rowContent),
            if (!isLast)
              Divider(height: 1, thickness: 1, color: Colors.grey.shade200),
          ],
        ),
      );
    }
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
}
