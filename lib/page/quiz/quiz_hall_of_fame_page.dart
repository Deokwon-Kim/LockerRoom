import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:lockerroom/model/ranking_user_model.dart';
import 'package:lockerroom/provider/quiz_ranking_provider.dart';
import 'package:lockerroom/provider/team_provider.dart';
import 'package:lockerroom/utils/quiz_season_utils.dart';
import 'package:lockerroom/utils/quiz_tier_utils.dart';
import 'package:lockerroom/widgets/team_champion_badges.dart';
import 'package:provider/provider.dart';

class QuizHallOfFamePage extends StatefulWidget {
  const QuizHallOfFamePage({super.key});

  @override
  State<QuizHallOfFamePage> createState() => _QuizHallOfFamePageState();
}

class _QuizHallOfFamePageState extends State<QuizHallOfFamePage>
    with SingleTickerProviderStateMixin {
  // 2026_04 이하: 프리시즌 (전체), 초과: 정규시즌 (Top 3)
  static const String _lastOpenSeason = '2026_04';
  late TabController _tabController;
  bool _myRecordsOnly = false;

  static const Color _bgObsidian = Color(0xFF070910);
  static const Color _surfaceMuseum = Color(0xFF0D111D);
  static const Color _surfaceCard = Color(0xFF121728);
  static const Color _goldLight = Color(0xFFFFF3C4);
  static const Color _gold = Color(0xFFF7E09B);
  static const Color _goldMid = Color(0xFFD4AF37);

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

    return Scaffold(
      backgroundColor: _bgObsidian,
      appBar: AppBar(
        title: const Text(
          '명예의 전당',
          style: TextStyle(
            fontFamily: 'kbo',
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        backgroundColor: _bgObsidian,
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
      ),
      body: Consumer<QuizRankingProvider>(
        builder: (context, qrp, child) {
          final currentSeason = QuizSeasonUtils.getCurrentSeasonId();

          final regularSeasons =
              qrp.hallOfFameBySeasons.entries
                  .where(
                    (e) =>
                        _isRestricted(e.key) &&
                        e.key != '2026_03' &&
                        e.key != '2026_04' &&
                        e.key != '2026-04' &&
                        e.key != currentSeason,
                  )
                  .toList()
                ..sort((a, b) => b.key.compareTo(a.key));

          final preSeasons =
              qrp.hallOfFameBySeasons.entries
                  .where(
                    (e) =>
                        !_isRestricted(e.key) &&
                        e.key != '2026_03' &&
                        e.key != '2026_04' &&
                        e.key != '2026-04' &&
                        e.key != currentSeason,
                  )
                  .toList()
                ..sort((a, b) => b.key.compareTo(a.key));

          // 내 통산 헌액 요약 계산 (정규시즌 기준 1위 횟수 / TOP 3 횟수)
          int kingCount = 0;
          int top3Count = 0;
          if (currentUserId != null) {
            for (final season in regularSeasons) {
              for (final u in season.value) {
                if (u.userId == currentUserId) {
                  if (u.rank == 1) kingCount++;
                  if (u.rank <= 3) top3Count++;
                }
              }
            }
          }

          return Column(
            children: [
              // ── KBO Hall of Fame 옵시디언 뮤지엄 히어로 ──
              _buildMuseumHero(kingCount: kingCount, top3Count: top3Count),

              // ── 탭 바 + 내 기록만 필터 토글 ──
              _buildNavControls(),

              // ── 본문 ──
              Expanded(
                child: qrp.isHallOfFameLoading
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(color: _goldMid),
                            SizedBox(height: 16),
                            Text(
                              '시즌 기록을 불러오는 중...',
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      )
                    : qrp.hallOfFameBySeasons.isEmpty
                    ? const Center(
                        child: Text(
                          '기록이 없습니다.',
                          style: TextStyle(color: Colors.white70),
                        ),
                      )
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          // 0번 기본 탭: 정규시즌
                          _buildSeasonList(
                            seasons: regularSeasons,
                            isRegular: true,
                            currentUserId: currentUserId,
                            teamProvider: teamProvider,
                          ),
                          // 1번 탭: 프리시즌
                          _buildSeasonList(
                            seasons: preSeasons,
                            isRegular: false,
                            currentUserId: currentUserId,
                            teamProvider: teamProvider,
                          ),
                        ],
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMuseumHero({required int kingCount, required int top3Count}) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 4, 14, 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF151B2E), Color(0xFF0A0D16)],
        ),
        border: Border.all(color: _goldMid.withValues(alpha: 0.42)),
        boxShadow: [
          BoxShadow(
            color: _goldMid.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: const Color(0xFF06070B),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _gold.withValues(alpha: 0.45)),
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.asset(
                  'assets/images/batting_king_trophy.jpg',
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '2026 ILU ARCHIVE',
                      style: TextStyle(
                        color: _goldMid,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2.0,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'KBO HALL OF FAME',
                      style: TextStyle(
                        fontFamily: 'kbo',
                        color: _gold,
                        fontSize: 18.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      '시즌별 최강 타격왕 영구 헌액관',
                      style: TextStyle(color: Colors.white60, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 11),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
            decoration: BoxDecoration(
              color: _goldMid.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: _gold.withValues(alpha: 0.45)),
            ),
            child: Text(
              '👑 타격왕 $kingCount회 · 🏅 TOP 3 $top3Count회',
              style: const TextStyle(
                color: _goldLight,
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavControls() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 40,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: TabBar(
                controller: _tabController,
                labelColor: _bgObsidian,
                unselectedLabelColor: Colors.white60,
                labelStyle: const TextStyle(
                  fontFamily: 'kbo',
                  fontWeight: FontWeight.w900,
                  fontSize: 12.5,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontFamily: 'kbo',
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                ),
                indicator: BoxDecoration(
                  gradient: const LinearGradient(colors: [_gold, _goldMid]),
                  borderRadius: BorderRadius.circular(9),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                tabs: const [
                  Tab(text: '정규시즌'),
                  Tab(text: '프리시즌'),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: () => setState(() => _myRecordsOnly = !_myRecordsOnly),
            borderRadius: BorderRadius.circular(11),
            child: Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _myRecordsOnly
                    ? _goldMid.withValues(alpha: 0.18)
                    : Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(11),
                border: Border.all(
                  color: _myRecordsOnly
                      ? _goldMid
                      : Colors.white.withValues(alpha: 0.1),
                ),
              ),
              child: Text(
                _myRecordsOnly ? '✓ 내 기록만' : '내 기록만',
                style: TextStyle(
                  color: _myRecordsOnly ? _gold : Colors.white70,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeasonList({
    required List<MapEntry<String, List<RankingUserModel>>> seasons,
    required bool isRegular,
    required String? currentUserId,
    required TeamProvider teamProvider,
  }) {
    final visibleSeasons = _myRecordsOnly && currentUserId != null
        ? seasons
              .where((s) => s.value.any((u) => u.userId == currentUserId))
              .toList()
        : seasons;

    if (visibleSeasons.isEmpty) {
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
              _myRecordsOnly
                  ? '내 헌액 기록이 없습니다.'
                  : (isRegular ? '아직 정규시즌 기록이 없습니다.' : '프리시즌 기록이 없습니다.'),
              style: const TextStyle(color: Colors.white54, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(14, 2, 14, 28),
      itemCount: visibleSeasons.length,
      itemBuilder: (context, idx) {
        final seasonId = visibleSeasons[idx].key;
        final users = visibleSeasons[idx].value;
        return _buildSeasonCard(
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

  Widget _buildSeasonCard({
    required String seasonId,
    required String label,
    required List<RankingUserModel> users,
    required bool isRegular,
    required String? currentUserId,
    required TeamProvider teamProvider,
  }) {
    final chipLabel = isRegular
        ? 'TOP 3'
        : (seasonId == 'legacy' ? 'LEGACY' : 'PRE-SEASON');

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: _surfaceMuseum,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // 풀폭 시즌 헤더
          Container(
            padding: const EdgeInsets.only(bottom: 10),
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.white.withValues(alpha: 0.07)),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Text(
                      'SEASON',
                      style: TextStyle(
                        color: _goldMid,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      label,
                      style: const TextStyle(
                        fontFamily: 'kbo',
                        color: Colors.white,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: _goldMid.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: _gold.withValues(alpha: 0.45)),
                  ),
                  child: Text(
                    chipLabel,
                    style: const TextStyle(
                      color: _gold,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 유저 행들
          ...users.map((u) {
            final isSpotlight =
                isRegular && u.rank == 1 && seasonId != 'legacy';
            if (isSpotlight) {
              return _buildSpotlightCard(
                seasonId: seasonId,
                user: u,
                currentUserId: currentUserId,
                teamProvider: teamProvider,
              );
            }
            return _buildSubRow(
              user: u,
              currentUserId: currentUserId,
              teamProvider: teamProvider,
            );
          }),
        ],
      ),
    );
  }

  Widget _buildSpotlightCard({
    required String seasonId,
    required RankingUserModel user,
    required String? currentUserId,
    required TeamProvider teamProvider,
  }) {
    final isMe = currentUserId != null && user.userId == currentUserId;
    final teamModel = user.teamName != null
        ? teamProvider.findTeamByName(user.teamName!)
        : null;
    final teamAccent = teamModel?.color ?? _goldMid;
    final kingCode = QuizSeasonUtils.getSeasonShortCode(seasonId);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A1C2E), Color(0xFF0E111B)],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _gold.withValues(alpha: isMe ? 0.78 : 0.52),
          width: isMe ? 1.4 : 1.0,
        ),
        boxShadow: isMe
            ? [
                BoxShadow(
                  color: _goldMid.withValues(alpha: 0.22),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: IntrinsicHeight(
          child: Row(
            children: [
              Container(width: 4.5, color: teamAccent),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 11,
                  ),
                  child: Row(
                    children: [
                      _buildMedalBadge(1),
                      const SizedBox(width: 9),
                      _buildTeamAvatar(teamModel?.logoPath),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  user.name,
                                  style: const TextStyle(
                                    fontFamily: 'kbo',
                                    color: Colors.white,
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w900,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                BattingKingTitlePill(
                                  label: '$kingCode 타격왕',
                                  fontSize: 9.5,
                                ),
                                if (isMe) _buildMyBadge(),
                              ],
                            ),
                            if (user.teamName != null) ...[
                              const SizedBox(height: 3),
                              Text(
                                user.teamName!,
                                style: const TextStyle(
                                  color: Colors.white60,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _isBattingRecord(user)
                                ? _formatBattingAvg(user.seasonAvg!)
                                : '${user.score}',
                            style: const TextStyle(
                              fontFamily: 'kbo',
                              color: _gold,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            _isBattingRecord(user)
                                ? '${user.totalAtBats}타수 ${user.totalHits ?? 0}안타'
                                : user.tier,
                            style: TextStyle(
                              color: _isBattingRecord(user)
                                  ? Colors.white70
                                  : QuizTierUtils.getTierColor(user.tier),
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
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

  bool _isBattingRecord(RankingUserModel user) =>
      user.seasonAvg != null && (user.totalAtBats ?? 0) > 0;

  String _formatBattingAvg(double avg) {
    if (avg >= 1.0) return avg.toStringAsFixed(3);
    final str = avg.toStringAsFixed(3);
    return str.startsWith('0.') ? str.substring(1) : str;
  }

  Widget _buildSubRow({
    required RankingUserModel user,
    required String? currentUserId,
    required TeamProvider teamProvider,
  }) {
    final isMe = currentUserId != null && user.userId == currentUserId;
    final teamModel = user.teamName != null
        ? teamProvider.findTeamByName(user.teamName!)
        : null;
    final tierName = user.tier;
    final tierColor = QuizTierUtils.getTierColor(tierName);

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: isMe ? const Color(0xFF192036) : _surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isMe
              ? _gold.withValues(alpha: 0.55)
              : Colors.white.withValues(alpha: 0.07),
        ),
      ),
      child: Row(
        children: [
          _buildMedalBadge(user.rank),
          const SizedBox(width: 9),
          _buildTeamAvatar(teamModel?.logoPath),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        user.name,
                        style: const TextStyle(
                          fontFamily: 'kbo',
                          color: Colors.white,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isMe) ...[const SizedBox(width: 6), _buildMyBadge()],
                  ],
                ),
                if (user.teamName != null)
                  Text(
                    user.teamName!,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 10.5,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _isBattingRecord(user)
                    ? _formatBattingAvg(user.seasonAvg!)
                    : '${user.score}',
                style: TextStyle(
                  fontFamily: 'kbo',
                  color: isMe ? _gold : Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                _isBattingRecord(user)
                    ? '${user.totalAtBats}타수 ${user.totalHits ?? 0}안타'
                    : tierName,
                style: TextStyle(
                  color: _isBattingRecord(user) ? Colors.white60 : tierColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMyBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
      decoration: BoxDecoration(
        color: const Color(0xFF3B82F6).withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: const Color(0xFF60A5FA).withValues(alpha: 0.55),
        ),
      ),
      child: const Text(
        'MY',
        style: TextStyle(
          color: Color(0xFFBFDBFE),
          fontSize: 9,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _buildTeamAvatar(String? logoPath) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: logoPath != null
          ? Padding(
              padding: const EdgeInsets.all(4),
              child: Image.asset(logoPath, fit: BoxFit.contain),
            )
          : const Icon(Icons.sports_baseball, color: Colors.white38, size: 17),
    );
  }

  Widget _buildMedalBadge(int rank) {
    if (rank > 3) {
      return SizedBox(
        width: 30,
        child: Center(
          child: Text(
            '$rank',
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      );
    }

    final List<Color> gradientColors = rank == 1
        ? const [Color(0xFFFFF3C4), Color(0xFFD4AF37)]
        : (rank == 2
              ? const [Color(0xFFF1F5F9), Color(0xFF94A3B8)]
              : const [Color(0xFFFDBA74), Color(0xFFB45309)]);
    final Color textColor = rank == 2
        ? const Color(0xFF0F172A)
        : const Color(0xFF161105);

    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: gradientColors),
        borderRadius: BorderRadius.circular(9),
      ),
      alignment: Alignment.center,
      child: Text(
        '$rank',
        style: TextStyle(
          fontFamily: 'kbo',
          color: textColor,
          fontSize: 13.5,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
