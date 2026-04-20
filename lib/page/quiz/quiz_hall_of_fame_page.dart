import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:lockerroom/model/ranking_user_model.dart';
import 'package:lockerroom/provider/quiz_ranking_provider.dart';
import 'package:lockerroom/provider/team_provider.dart';
import 'package:lockerroom/utils/quiz_season_utils.dart';
import 'package:lockerroom/utils/quiz_tier_utils.dart';
import 'package:provider/provider.dart';

class QuizHallOfFamePage extends StatefulWidget {
  const QuizHallOfFamePage({super.key});

  @override
  State<QuizHallOfFamePage> createState() => _QuizHallOfFamePageState();
}

class _QuizHallOfFamePageState extends State<QuizHallOfFamePage>
    with SingleTickerProviderStateMixin {
  // 2026-04 이하: 프리시즌 (전체), 초과: 정규시즌 (Top 3)
  static const String _lastOpenSeason = '2026-04';
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<QuizRankingProvider>().fetchHallOfFameBySeasons();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _getSeasonLabel(String seasonId) {
    if (seasonId == 'legacy') return '시즌제 이전';
    return QuizSeasonUtils.getSeasonLabel(seasonId);
  }

  bool _isRestricted(String seasonId) =>
      seasonId != 'legacy' && seasonId.compareTo(_lastOpenSeason) > 0;

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final teamProvider = context.read<TeamProvider>();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFF0B1A38),
        appBar: AppBar(
          title: const Text(
            '명예의 전당',
            style: TextStyle(
              fontFamily: 'kbo',
              color: Colors.white,
              fontSize: 18,
            ),
          ),
          backgroundColor: const Color(0xFF0B1A38),
          foregroundColor: Colors.white,
          elevation: 0,
          actions: [
            IconButton(
              onPressed: () => context
                  .read<QuizRankingProvider>()
                  .fetchHallOfFameBySeasons(true),
              icon: const Icon(Icons.refresh, color: Colors.white70),
            ),
          ],
          bottom: PreferredSize(
            // 헤더(72) + 탭바(48) 합산
            preferredSize: const Size.fromHeight(120),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── HALL OF FAME 헤더 배너 ──
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.amber.shade800, Colors.amber.shade500],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.workspace_premium,
                        color: Colors.white,
                        size: 28,
                      ),
                      SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'HALL OF FAME',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'kbo',
                              letterSpacing: 1.5,
                            ),
                          ),
                          Text(
                            '시즌별 최강자 기록',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // ── 탭 바 ──
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    padding: const EdgeInsets.all(3),
                    labelColor: Colors.black,
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      fontFamily: 'kbo',
                    ),
                    unselectedLabelColor: Colors.white54,
                    unselectedLabelStyle: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      fontFamily: 'kbo',
                    ),
                    indicator: BoxDecoration(
                      color: Colors.amber,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    tabs: const [
                      Tab(text: '프리시즌'),
                      Tab(text: '정규시즌'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        body: Consumer<QuizRankingProvider>(
          builder: (context, qrp, child) {
            if (qrp.isHallOfFameLoading) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Colors.amber),
                    SizedBox(height: 16),
                    Text(
                      '시즌 기록을 불러오는 중...',
                      style: TextStyle(color: Colors.white54, fontSize: 13),
                    ),
                  ],
                ),
              );
            }

            if (qrp.hallOfFameBySeasons.isEmpty) {
              return const Center(
                child: Text(
                  '기록이 없습니다.',
                  style: TextStyle(color: Colors.white70),
                ),
              );
            }

            // 프리시즌: 2026-04 이하 (legacy 포함)
            final preSeasons =
                qrp.hallOfFameBySeasons.entries
                    .where((e) => !_isRestricted(e.key))
                    .toList()
                  ..sort((a, b) => b.key.compareTo(a.key));

            // 정규시즌: 2026-04 초과
            final regularSeasons =
                qrp.hallOfFameBySeasons.entries
                    .where((e) => _isRestricted(e.key))
                    .toList()
                  ..sort((a, b) => b.key.compareTo(a.key));

            return TabBarView(
              controller: _tabController,
              children: [
                // ── 탭 1: 프리시즌 ──
                _buildSeasonList(
                  seasons: preSeasons,
                  isRegular: false,
                  currentUserId: currentUserId,
                  teamProvider: teamProvider,
                ),
                // ── 탭 2: 정규시즌 ──
                _buildSeasonList(
                  seasons: regularSeasons,
                  isRegular: true,
                  currentUserId: currentUserId,
                  teamProvider: teamProvider,
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ── 시즌 목록 스크롤 뷰 ──
  Widget _buildSeasonList({
    required List<MapEntry<String, List<RankingUserModel>>> seasons,
    required bool isRegular,
    required String? currentUserId,
    required TeamProvider teamProvider,
  }) {
    if (seasons.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isRegular ? Icons.emoji_events : Icons.history,
              color: Colors.white24,
              size: 48,
            ),
            const SizedBox(height: 12),
            Text(
              isRegular ? '아직 정규시즌 기록이 없습니다.' : '프리시즌 기록이 없습니다.',
              style: const TextStyle(color: Colors.white38, fontSize: 14),
            ),
            if (isRegular)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  '2026년 5월 이후 시즌 종료 시 Top 3가 등록됩니다.',
                  style: TextStyle(color: Colors.white24, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 32),
      itemCount: seasons.length,
      itemBuilder: (context, idx) {
        final seasonId = seasons[idx].key;
        final users = seasons[idx].value;
        return _buildSeasonBlock(
          seasonId: seasonId,
          label: _getSeasonLabel(seasonId),
          users: users,
          isRegular: isRegular,
          currentUserId: currentUserId,
          teamProvider: teamProvider,
        );
      },
    );
  }

  // ── 시즌 블록 (라벨 + 유저 행들) ──
  Widget _buildSeasonBlock({
    required String seasonId,
    required String label,
    required List<RankingUserModel> users,
    required bool isRegular,
    required String? currentUserId,
    required TeamProvider teamProvider,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 왼쪽: 시즌 라벨 ──
          SizedBox(
            width: 82,
            child: Padding(
              padding: const EdgeInsets.only(top: 14, right: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SEASON',
                    style: TextStyle(
                      color: isRegular
                          ? Colors.amber.shade300
                          : Colors.blueGrey.shade300,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'kbo',
                      height: 1.1,
                    ),
                  ),
                  if (isRegular)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: Colors.amber.withOpacity(0.5),
                          ),
                        ),
                        child: const Text(
                          'TOP 3',
                          style: TextStyle(
                            color: Colors.amber,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // ── 오른쪽: 유저 행 목록 ──
          Expanded(
            child: Column(
              children: users
                  .map(
                    (u) => _buildUserRow(
                      user: u,
                      isRegular: isRegular,
                      currentUserId: currentUserId,
                      teamProvider: teamProvider,
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  // ── 유저 행 ──
  Widget _buildUserRow({
    required RankingUserModel user,
    required bool isRegular,
    required String? currentUserId,
    required TeamProvider teamProvider,
  }) {
    final isMe = user.userId == currentUserId;
    final teamModel = user.teamName != null
        ? teamProvider.findTeamByName(user.teamName!)
        : null;
    final tierColor = QuizTierUtils.getTierColor(
      QuizTierUtils.getTierName(user.score),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: isMe ? const Color(0xFF1E3A6E) : const Color(0xFF112244),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isMe
              ? Colors.amber.withOpacity(0.6)
              : Colors.white.withOpacity(0.06),
          width: isMe ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          // 메달
          _buildMedal(user.rank),
          const SizedBox(width: 8),

          // 팀 로고
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: teamModel?.logoPath != null
                ? Padding(
                    padding: const EdgeInsets.all(4),
                    child: Image.asset(
                      teamModel!.logoPath,
                      fit: BoxFit.contain,
                    ),
                  )
                : const Icon(
                    Icons.sports_baseball,
                    color: Colors.white30,
                    size: 18,
                  ),
          ),
          const SizedBox(width: 10),

          // 이름 + 팀
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'kbo',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (user.teamName != null)
                  Text(
                    user.teamName!,
                    style: TextStyle(
                      color:
                          teamModel?.color?.withOpacity(0.8) ?? Colors.white38,
                      fontSize: 10,
                    ),
                  ),
              ],
            ),
          ),

          // 점수 + 티어
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                children: [
                  const Text(
                    'SCORE ',
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Text(
                    '${user.score}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'kbo',
                    ),
                  ),
                ],
              ),
              Text(
                QuizTierUtils.getTierName(user.score),
                style: TextStyle(
                  color: tierColor,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(width: 10),

          // 우측 아이콘
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isRegular
                  ? Colors.amber.withOpacity(0.12)
                  : Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isRegular
                    ? Colors.amber.withOpacity(0.3)
                    : Colors.white.withOpacity(0.08),
              ),
            ),
            child: Icon(
              isRegular ? Icons.workspace_premium : Icons.emoji_events,
              color: isRegular ? Colors.amber : Colors.white24,
              size: 18,
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }

  // ── 메달 위젯 ──
  Widget _buildMedal(int rank) {
    if (rank > 3) {
      return SizedBox(
        width: 36,
        child: Center(
          child: Text(
            '$rank',
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    }

    final medalColors = {
      1: [const Color(0xFFFFD700), const Color(0xFFB8860B)],
      2: [const Color(0xFFD0D0D0), const Color(0xFF808080)],
      3: [const Color(0xFFCD7F32), const Color(0xFF8B4513)],
    };
    final ribColors = {
      1: const Color(0xFFCC0000),
      2: const Color(0xFF6600CC),
      3: const Color(0xFF8B4513),
    };
    final colors = medalColors[rank]!;
    final ribColor = ribColors[rank]!;

    return SizedBox(
      width: 36,
      height: 44,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 리본
          Positioned(
            top: 0,
            child: Container(
              width: 6,
              height: 12,
              decoration: BoxDecoration(
                color: ribColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(3),
                ),
              ),
            ),
          ),
          // 메달 원
          Positioned(
            bottom: 0,
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: colors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(color: colors[0].withOpacity(0.5), blurRadius: 6),
                ],
              ),
              child: Center(
                child: Text(
                  '$rank',
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
