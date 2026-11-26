import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:lockerroom/bottom_tab_bar/bottom_tab_bar.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/const/firestore_constants.dart';
import 'package:lockerroom/model/quiz_result_model.dart';
import 'package:lockerroom/page/quiz/quiz_play_page.dart';
import 'package:lockerroom/model/quiz_trophy_model.dart';
import 'package:lockerroom/provider/badge_provider.dart';
import 'package:lockerroom/provider/profile_provider.dart';
import 'package:lockerroom/provider/quiz_provider.dart';
import 'package:lockerroom/provider/quiz_ranking_provider.dart';
import 'package:lockerroom/provider/team_provider.dart';
import 'package:lockerroom/provider/user_provider.dart';
import 'package:lockerroom/utils/quiz_season_utils.dart';
import 'package:lockerroom/utils/quiz_mission_utils.dart';
import 'package:lockerroom/utils/quiz_tier_utils.dart';
import 'package:lockerroom/widgets/champion_overlay.dart';
import 'package:lockerroom/widgets/season_result_overlay.dart';
import 'package:lockerroom/widgets/season_start_overlay.dart';
import 'package:lockerroom/widgets/team_battle_dialog.dart';
import 'package:lockerroom/widgets/team_champion_badges.dart';
import 'package:lockerroom/widgets/team_champion_overlay.dart';
import 'package:lockerroom/widgets/tier_up_overlay.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class QuizLobyPage extends StatefulWidget {
  const QuizLobyPage({super.key});

  @override
  State<QuizLobyPage> createState() => _QuizLobyPageState();
}

class _QuizLobyPageState extends State<QuizLobyPage> {
  SharedPreferences? _prefs;
  QuizMode _selectedMode = QuizMode.normal;

  // 티어 승급 오버레이 상태
  bool _showTierUpOverlay = false;
  String _oldTier = "";
  String _newTier = "";

  // 타격왕/구단 챔피언 시상식 오버레이 미리보기 ON/OFF 상태 (디버그/개발자 전용)
  bool _ceremonyPreviewEnabled = false;
  bool _teamChampionPreviewEnabled = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      _prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      final rankProvider = context.read<QuizRankingProvider>();
      final currentSeasonId = QuizSeasonUtils.getCurrentSeasonId();

      // 0. 현재 시즌 로컬 캐시 즉시 로드 (새 시즌이면 PROSPECT / 0P / -)
      await rankProvider.loadMyOverallFromLocal(currentSeasonId);

      // 1. 기본 데이터 로드
      if (!mounted) return;
      context.read<QuizProvider>().fetchMyHistory();
      context.read<UserProvider>().loadNickname();

      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        context.read<ProfileProvider>().subscribeMyProfileImage(uid);
      }

      // 2. 지난 시즌 결과 오버레이 확인 (필요한 경우에만 지난 시즌 랭킹 로드)
      final lastResultShownSeason = _prefs?.getString(
        'last_result_shown_season',
      );
      final prevSeasonId = QuizSeasonUtils.getPreviousSeasonId();
      final bool needShowResultOverlay =
          prevSeasonId != null && lastResultShownSeason != currentSeasonId;

      if (needShowResultOverlay) {
        // 지난 시즌 결과 오버레이 표시를 위해 지난 시즌 랭킹 로드
        await rankProvider.setSeason(prevSeasonId);
        if (mounted) {
          await _checkAndShowSeasonResultOverlay();
        }
      }

      // 3. 현재 시즌으로 복귀/설정 및 랭킹 데이터 최신화
      if (mounted) {
        if (rankProvider.selectedSeason != currentSeasonId) {
          await rankProvider.setSeason(currentSeasonId);
        } else {
          await rankProvider.fetchRankings(true);
        }
        await rankProvider.loadDefendingBattingKing();
      }

      // 4. 새 시즌 시작 오버레이 실행 (현재 시즌 기준)
      if (mounted) {
        await _checkAndShowSeasonStartOverlay();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode =
        MediaQuery.of(context).platformBrightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF0F172A) : BACKGROUND_COLOR,
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 10),
                        // 1️⃣ 상단 프로필 + LIVE 시즌 배지 행
                        _buildTopHeader(),
                        const SizedBox(height: 14),

                        // 2️⃣ 구단 컬러 그라데이션 히어로 카드 (티어 + 시즌 D-Day 통합)
                        _buildHeroTierCard(),
                        const SizedBox(height: 14),

                        // 3️⃣ 순백 에디토리얼 기록 요약 Bento 카드
                        _buildSeasonCard(),
                        const SizedBox(height: 14),

                        // 4️⃣ 순백 에디토리얼 오늘의 미션 카드
                        _buildMissionSection(),

                        // 🛠️ 타격왕/구단 챔피언/뱃지·리본·칭호·트로피 ON/OFF 테스트 스위치 (개발자 계정 전용)
                        if (QuizRankingProvider.isDevPreviewAccount) ...[
                          const SizedBox(height: 14),
                          _buildRewardsMasterPreviewToggle(isDarkMode),
                          const SizedBox(height: 8),
                          _buildCeremonyPreviewToggle(isDarkMode),
                          _buildTeamChampionPreviewToggle(isDarkMode),
                        ],
                      ],
                    ),
                  ),
                ),
                // 5️⃣ 하단 고정 도전하기 CTA 버튼
                _buildFixedPlayButton(),
              ],
            ),
          ),

          // 5. 티어 상승 오버레이 — SafeArea 바깥에서 풀스크린으로 표시
          if (_showTierUpOverlay)
            Positioned.fill(
              child: TierUpOverlay(
                oldTier: _oldTier,
                newTier: _newTier,
                onDismiss: () {
                  setState(() {
                    _showTierUpOverlay = false;
                  });
                },
              ),
            ),
        ],
      ),
    );
  }

  // 1️⃣ 상단 헤더 (뒤로가기 + 프로필 + LIVE 시즌 배지)
  Widget _buildTopHeader() {
    final currentSeasonId = QuizSeasonUtils.getCurrentSeasonId();
    final seasonLabel = QuizSeasonUtils.getSeasonLabel(currentSeasonId);
    return Consumer<UserProvider>(
      builder: (context, up, child) {
        final profileProvider = Provider.of<ProfileProvider>(context);
        final teamProvider = context.read<TeamProvider>();
        final isDarkMode =
            MediaQuery.of(context).platformBrightness == Brightness.dark;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 0, 16, 0),
              child: Row(
                children: [
                  // 뒤로가기 버튼
                  IconButton(
                    icon: Icon(
                      Icons.arrow_back_ios_new,
                      color: isDarkMode ? WHITE : BUTTON,
                      size: 19,
                    ),
                    onPressed: () => Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (context) => BottomTabBar()),
                      (route) => false,
                    ),
                  ),
                  // 프로필 사진
                  CircleAvatar(
                    backgroundColor: GRAYSCALE_LABEL_200,
                    radius: 19,
                    backgroundImage: profileProvider.image != null
                        ? FileImage(profileProvider.image!)
                        : (profileProvider.imageUrl != null
                              ? NetworkImage(profileProvider.imageUrl!)
                              : null),
                    child:
                        (profileProvider.image == null &&
                            profileProvider.imageUrl == null)
                        ? const Icon(
                            Icons.person,
                            size: 19,
                            color: GRAYSCALE_LABEL_500,
                          )
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          up.nickname ?? '야구팬',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w800,
                            color: isDarkMode ? WHITE : BUTTON,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          teamProvider.selectedTeam?.name ?? 'ILU 팬',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: isDarkMode
                                ? Colors.white70
                                : (teamProvider.selectedTeam?.color ?? BUTTON),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: isDarkMode ? const Color(0xFF1E293B) : WHITE,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: isDarkMode
                            ? Colors.white12
                            : GRAYSCALE_LABEL_100,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Color(0xFF10B981),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          '$seasonLabel · LIVE',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: isDarkMode ? WHITE : BUTTON,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Consumer<QuizRankingProvider>(
              builder: (context, qrp, _) {
                final kingTitle = qrp.myDisplayKingTitle;
                final teamChampTitle = qrp.defendingTeamChampionTitle;
                final showKing = kingTitle != null;
                final showTeam =
                    qrp.isDefendingChampionTeam(
                      teamProvider.selectedTeam?.name,
                    ) &&
                    teamChampTitle != null;
                if (!showKing && !showTeam) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (showKing)
                        BattingKingTitlePill(label: kingTitle, fontSize: 10),
                      if (showTeam)
                        TeamFanTitlePill(
                          label: teamChampTitle,
                          teamColor: teamProvider.selectedTeam?.color ?? BUTTON,
                        ),
                    ],
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  // 3️⃣ 순백 에디토리얼 내 타격 리포트 Bento 카드 (타율 중심 개편)
  Widget _buildSeasonCard() {
    final isDarkMode =
        MediaQuery.of(context).platformBrightness == Brightness.dark;
    final quizProvider = context.watch<QuizProvider>();
    final history = quizProvider.myHistory;
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    return Consumer<QuizRankingProvider>(
      builder: (context, qrp, child) {
        final totalAb = currentUserId != null
            ? qrp.getTotalAtBats(currentUserId)
            : 0;
        final totalHits = currentUserId != null
            ? qrp.getTotalHits(currentUserId)
            : 0;
        final seasonAvg = currentUserId != null
            ? qrp.getFormattedSeasonBattingAverage(currentUserId)
            : '.000';
        final isQualified = currentUserId != null
            ? qrp.isQualifiedForBattingKing(currentUserId)
            : false;
        const qualAb = QuizRankingProvider.qualifyingAtBats;
        final qualProgress = (totalAb / qualAb).clamp(0.0, 1.0);

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDarkMode ? const Color(0xFF151E32) : WHITE,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDarkMode ? Colors.white10 : GRAYSCALE_LABEL_100,
              ),
              boxShadow: [
                BoxShadow(
                  color: BLACK.withValues(alpha: isDarkMode ? 0.25 : 0.035),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '내 타격 리포트',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'kbo',
                        color: isDarkMode ? WHITE : BUTTON,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: isQualified
                            ? GREEN_SUCCESS_SURFACE_5
                            : YELLOW_INFO_SURFACE_5,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: isQualified
                              ? GREEN_SUCCESS_BORDER_10
                              : YELLOW_INFO_BORDER_10,
                        ),
                      ),
                      child: Text(
                        isQualified ? '규정타석 달성 ✓' : '규정타석 $totalAb/$qualAb타수',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: isQualified
                              ? GREEN_SUCCESS_TEXT_50
                              : YELLOW_INFO_TEXT_50,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDarkMode
                              ? Colors.white.withValues(alpha: 0.04)
                              : BACKGROUND_COLOR,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isDarkMode
                                ? Colors.white10
                                : GRAYSCALE_LABEL_100,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '시즌 타율 ($totalAb타수 $totalHits안타)',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isDarkMode
                                    ? Colors.white54
                                    : GRAYSCALE_LABEL_600,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              seasonAvg,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                fontFamily: 'kbo',
                                color: ACCENT_CORAL,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDarkMode
                              ? Colors.white.withValues(alpha: 0.04)
                              : BACKGROUND_COLOR,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isDarkMode
                                ? Colors.white10
                                : GRAYSCALE_LABEL_100,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '누적 안타 · 총 ${history.length}경기',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isDarkMode
                                    ? Colors.white54
                                    : GRAYSCALE_LABEL_600,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              totalAb > 0
                                  ? '$totalHits안타 ($totalAb타수)'
                                  : '첫 타석 대기',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 16.5,
                                fontWeight: FontWeight.w900,
                                fontFamily: 'kbo',
                                color: isDarkMode ? WHITE : BUTTON,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '규정타석 진행도 (최소 $qualAb타수)',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isDarkMode
                            ? Colors.white54
                            : GRAYSCALE_LABEL_600,
                      ),
                    ),
                    Text(
                      '$totalAb / $qualAb 타수',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: isDarkMode ? WHITE : BUTTON,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: qualProgress,
                    minHeight: 7,
                    backgroundColor: isDarkMode
                        ? Colors.white10
                        : GRAYSCALE_LABEL_100,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isQualified ? const Color(0xFF10B981) : ACCENT_CORAL,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // 3️⃣ 구단 컬러 그라데이션 히어로 카드 (시안 v3)
  Widget _buildHeroTierCard() {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final teamProvider = context.read<TeamProvider>();
    final teamColor = teamProvider.selectedTeam?.color ?? BUTTON;
    final teamGradEnd =
        Color.lerp(teamColor, const Color(0xFF1E2C56), 0.45) ?? teamColor;
    final daysLeft = QuizSeasonUtils.getSeasonRemainingDays();
    final dDayText = daysLeft == 0 ? '오늘 마감' : '종료 D-$daysLeft';

    return Consumer<QuizRankingProvider>(
      builder: (context, qrp, child) {
        final rank = currentUserId != null
            ? qrp.getOverallRank(currentUserId)
            : 0;
        final tierProgress = currentUserId != null
            ? qrp.getBattingTierProgress(currentUserId)
            : QuizTierUtils.getBattingTierProgress(0, 0.0);
        final tierName = currentUserId != null
            ? qrp.getBattingTier(currentUserId)
            : tierProgress.currentTier;
        final seasonAvg = currentUserId != null
            ? qrp.getFormattedSeasonBattingAverage(currentUserId)
            : '.000';

        final emblemPath = QuizTierUtils.getTierEmblem(tierName);
        final totalParticipants = qrp.rankings.length;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [teamColor, teamGradEnd],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: teamColor.withValues(alpha: 0.28),
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (qrp.isDefendingChampionTeam(
                      teamProvider.selectedTeam?.name,
                    ) &&
                    qrp.defendingKingSeasonId != null) ...[
                  DefendingTeamRibbonBanner(
                    teamName: teamProvider.selectedTeam?.name ?? '내 구단',
                    seasonChipText:
                        '${QuizSeasonUtils.getSeasonShortCode(qrp.defendingKingSeasonId!)} 우승',
                    teamColor: teamColor,
                  ),
                  const SizedBox(height: 12),
                ],
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Image.asset(emblemPath, width: 16, height: 16),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                'MY TIER · ${tierName.toUpperCase()}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        dDayText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFFFFD875),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tierName.toUpperCase(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              fontFamily: 'kbo',
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            rank > 0
                                ? '종합 $rank위 · $totalParticipants명 도전 중'
                                : '$totalParticipants명이 시즌 도전 중',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.78),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      seasonAvg,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFFFFD875),
                        fontFamily: 'kbo',
                      ),
                    ),
                  ],
                ),
                if (qrp.isDefendingBattingKing) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.fromLTRB(5, 4, 10, 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: const Color(0xFFFDE68A).withValues(alpha: 0.6),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF06070B),
                            border: Border.all(
                              color: const Color(0xFFFDE68A),
                              width: 0.8,
                            ),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Image.asset(
                            'assets/images/batting_king_trophy.jpg',
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Flexible(
                          child: Text(
                            '디펜딩 타격왕 특전 · 비디오 판독 찬스 +1회 활성',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Color(0xFFFEF3C7),
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Stack(
                  children: [
                    Container(
                      height: 7,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: tierProgress.progress.clamp(0.05, 1.0),
                      child: Container(
                        height: 7,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFFD875), Color(0xFFFF8A3D)],
                          ),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      tierProgress.nextTier.isNotEmpty
                          ? '다음 등급 ${tierProgress.nextTier}까지'
                          : '최고 등급 LEGEND 달성',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Colors.white.withValues(alpha: 0.8),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        tierProgress.statusMessage,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
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

  void _launchQuizCategory(String category) {
    final mode = _selectedMode;
    if (category == '응원가') {
      _showCheerSongDialog(mode);
      return;
    }
    showDialog(
      context: context,
      builder: (context) => TeamBattleDialog(
        onStart: () {
          Navigator.push(
            this.context,
            MaterialPageRoute(
              builder: (context) =>
                  QuizPlayPage(category: category, mode: mode),
            ),
          );
        },
      ),
    );
  }

  void _showCheerSongDialog(QuizMode mode) {
    final isDarkMode =
        MediaQuery.of(context).platformBrightness == Brightness.dark;
    final teamColor =
        context.read<TeamProvider>().selectedTeam?.color ?? BUTTON;
    final teamGradEnd =
        Color.lerp(teamColor, const Color(0xFF242C5E), 0.45) ?? teamColor;
    final modeLabel = mode == QuizMode.threeOut
        ? '🔥 3아웃 무한이닝'
        : 'CLASSIC 10문제';
    String selectedSubCategory = '응원가(인트로)';

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            final isIntro = selectedSubCategory == '응원가(인트로)';
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 22),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(26),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 구단 컬러 상단 헤더
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [teamColor, teamGradEnd],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.16),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: const Text(
                                  '🎵 응원가 퀴즈',
                                  style: TextStyle(
                                    color: WHITE,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 9,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.25),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  modeLabel,
                                  style: const TextStyle(
                                    color: Color(0xFFFFD875),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            '어떤 방식으로 도전할까요?',
                            style: TextStyle(
                              color: WHITE,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              fontFamily: 'kbo',
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '선택한 경기 모드로 즉시 타석에 입장합니다.',
                            style: TextStyle(
                              color: WHITE.withValues(alpha: 0.82),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // 본문: 인트로 vs 가사 선택 타일 + 액션
                    Container(
                      color: isDarkMode
                          ? const Color(0xFF0F172A)
                          : BACKGROUND_COLOR,
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildCheerSongOptionTile(
                            emoji: '🎵',
                            title: '응원가 인트로',
                            tag: '음원 재생',
                            subtitle: '1~5초 전주를 듣고 팀·선수 맞히기',
                            tintBg: const Color(0xFFFFF7ED),
                            tagFg: const Color(0xFFC2410C),
                            isSelected: isIntro,
                            isDarkMode: isDarkMode,
                            accentColor: teamColor,
                            onTap: () => setDialogState(
                              () => selectedSubCategory = '응원가(인트로)',
                            ),
                          ),
                          const SizedBox(height: 10),
                          _buildCheerSongOptionTile(
                            emoji: '📝',
                            title: '응원가 가사',
                            tag: '빈칸 추론',
                            subtitle: '가사 빈칸에 들어갈 핵심 구절 맞히기',
                            tintBg: const Color(0xFFEFF6FF),
                            tagFg: const Color(0xFF1D4ED8),
                            isSelected: !isIntro,
                            isDarkMode: isDarkMode,
                            accentColor: teamColor,
                            onTap: () => setDialogState(
                              () => selectedSubCategory = '응원가(가사)',
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                flex: 1,
                                child: SizedBox(
                                  height: 46,
                                  child: OutlinedButton(
                                    onPressed: () => Navigator.pop(dialogCtx),
                                    style: OutlinedButton.styleFrom(
                                      backgroundColor: isDarkMode
                                          ? const Color(0xFF151E32)
                                          : WHITE,
                                      foregroundColor: isDarkMode
                                          ? Colors.white70
                                          : GRAYSCALE_LABEL_600,
                                      side: BorderSide(
                                        color: isDarkMode
                                            ? Colors.white12
                                            : GRAYSCALE_LABEL_200,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                    child: const Text(
                                      '취소',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 9),
                              Expanded(
                                flex: 2,
                                child: SizedBox(
                                  height: 46,
                                  child: ElevatedButton(
                                    onPressed: () {
                                      Navigator.pop(dialogCtx);
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => QuizPlayPage(
                                            category: selectedSubCategory,
                                            mode: mode,
                                          ),
                                        ),
                                      );
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: teamColor,
                                      foregroundColor: WHITE,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                    child: Text(
                                      isIntro ? '인트로 시작하기 ⚾' : '가사 시작하기 ⚾',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontFamily: 'kbo',
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
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCheerSongOptionTile({
    required String emoji,
    required String title,
    required String tag,
    required String subtitle,
    required Color tintBg,
    required Color tagFg,
    required bool isSelected,
    required bool isDarkMode,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF151E32) : WHITE,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected
                ? accentColor
                : (isDarkMode ? Colors.white12 : GRAYSCALE_LABEL_100),
            width: isSelected ? 1.8 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: accentColor.withValues(alpha: 0.12),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isDarkMode ? Colors.white10 : tintBg,
                borderRadius: BorderRadius.circular(13),
              ),
              alignment: Alignment.center,
              child: Text(emoji, style: const TextStyle(fontSize: 20)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'kbo',
                          color: isDarkMode ? WHITE : BUTTON,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: isDarkMode ? Colors.white10 : tintBg,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          tag,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: isDarkMode ? Colors.white70 : tagFg,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: isDarkMode ? Colors.white60 : GRAYSCALE_LABEL_600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              isSelected
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: isSelected
                  ? accentColor
                  : (isDarkMode ? Colors.white24 : GRAYSCALE_LABEL_300),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  // 5️⃣ 오늘의 미션 섹션
  Widget _buildMissionSection() {
    final isDarkMode =
        MediaQuery.of(context).platformBrightness == Brightness.dark;
    final quizProvider = context.watch<QuizProvider>();
    final rankProvider = context.watch<QuizRankingProvider>();
    final currentUser = FirebaseAuth.instance.currentUser;

    if (_prefs == null || currentUser == null) {
      return const SizedBox(
        height: 100,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    // [수정] 미션 기준 점수도 종합 점수를 사용
    final userScore = rankProvider.getOverallScore(currentUser.uid);

    // 동적 시드 및 티어 기반 미션 생성
    final missions = QuizMissionUtils.getDailyMissions(
      currentUser.uid,
      userScore,
      quizProvider.myHistory,
      _prefs!,
    );

    final completedCount = missions.where((m) => m.isCompleted).length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF151E32) : WHITE,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDarkMode ? Colors.white10 : GRAYSCALE_LABEL_100,
          ),
          boxShadow: [
            BoxShadow(
              color: BLACK.withValues(alpha: isDarkMode ? 0.25 : 0.035),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '오늘의 미션',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: isDarkMode ? WHITE : BUTTON,
                    fontFamily: 'kbo',
                  ),
                ),
                GestureDetector(
                  onLongPress: () async {
                    if (_prefs != null) {
                      await QuizMissionUtils.resetDailyMissions(
                        currentUser.uid,
                        _prefs!,
                      );
                      setState(() {});
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('테스트용: 오늘 미션 수령 상태가 초기화되었습니다.'),
                            backgroundColor: Colors.blueGrey,
                            duration: Duration(seconds: 2),
                          ),
                        );
                      }
                    }
                  },
                  child: Text(
                    '$completedCount / ${missions.length} 완료',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: isDarkMode ? Colors.white54 : GRAYSCALE_LABEL_500,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...missions.map((mission) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _buildMissionItem(mission),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildMissionItem(QuizMission mission) {
    // 진행도 보정 (목표를 초과하지 않게)
    final progressVal = mission.currentValue > mission.targetValue
        ? mission.targetValue
        : mission.currentValue;
    final statusText = '($progressVal/${mission.targetValue})';

    final isDarkMode =
        MediaQuery.of(context).platformBrightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: mission.isClaimed
            ? (isDarkMode
                  ? Colors.white.withOpacity(0.05)
                  : Colors.grey.shade50)
            : (isDarkMode ? const Color(0xFF1B2436) : Colors.white),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: mission.isCompleted && !mission.isClaimed
              ? Colors.green.shade400
              : (isDarkMode
                    ? Colors.white.withOpacity(0.1)
                    : Colors.grey.shade200),
          width: mission.isCompleted && !mission.isClaimed ? 1.5 : 1.0,
        ),
      ),
      child: Row(
        children: [
          Icon(
            mission.isCompleted
                ? Icons.check_circle
                : Icons.radio_button_unchecked,
            color: mission.isCompleted
                ? Colors.green
                : (isDarkMode ? Colors.white24 : Colors.grey.shade300),
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mission.title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: mission.isClaimed
                        ? (isDarkMode ? Colors.white24 : Colors.grey.shade500)
                        : (isDarkMode ? Colors.white : Colors.black87),
                    decoration: mission.isClaimed
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      statusText,
                      style: TextStyle(
                        fontSize: 12,
                        color: mission.isCompleted
                            ? Colors.green
                            : (isDarkMode
                                  ? Colors.white54
                                  : Colors.grey.shade500),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: isDarkMode
                            ? Colors.orange.withOpacity(0.1)
                            : Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        mission.rewardLabel,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode
                              ? Colors.orange.shade300
                              : Colors.orange.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // 보상 받기 버튼
          if (mission.isCompleted && !mission.isClaimed)
            ElevatedButton(
              onPressed: () => _claimMissionReward(mission),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 0,
                ),
                minimumSize: const Size(60, 32),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                elevation: 0,
              ),
              child: const Text(
                '받기',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            )
          else if (mission.isClaimed)
            Text(
              '완료됨',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade400,
                fontWeight: FontWeight.bold,
              ),
            ),
        ],
      ),
    );
  }

  // 보상 지급 처리
  Future<void> _claimMissionReward(QuizMission mission) async {
    if (_prefs == null) return;

    // 1. 상태 즉시 업데이트 방지 로직 (더블 클릭 방지용 임시 처리)
    setState(() {
      _prefs!.setBool('${mission.id}_claimed', true);
    });

    // 2. Firestore에 보상 결과 추가 (별도 퀴즈 완료가 아닌 Pts 직접 부여)
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userProvider = context.read<UserProvider>();
        final nameToSave = userProvider.nickname ?? '미션달성자';

        final rankProvider = context.read<QuizRankingProvider>();
        final myCurrentRank = rankProvider.getMyRanking(user.uid);
        final scoreBefore = myCurrentRank?.score ?? 0;
        final tierBefore = QuizSeasonUtils.getTier(scoreBefore);

        // 팀 정보 확보용
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        final teamName = userDoc.data()?['team'] as String?;

        final rewardResult = QuizResultModel(
          userId: user.uid,
          userNickName: nameToSave,
          category: '일일미션', // 카테고리를 미션으로 분리
          totalQuestions: 0,
          correctAnswers: 0,
          atBats: 0,
          hits: 1,
          score: mission.rewardPts,
          completedAt: DateTime.now(),
          timeTakenSeconds: 0,
          questionIds: [],
          answerResults: {},
          teamName: teamName,
          seasonId: QuizSeasonUtils.getCurrentSeasonId(),
        );

        final firestoreData = rewardResult.toJson();
        // 랭킹 시스템 합산용 category
        firestoreData['category'] = '일일미션 보상';

        await FirebaseFirestore.instance
            .collection(FirestoreConstants.quizResults)
            .doc(user.uid)
            .collection(FirestoreConstants.quizResultsSub)
            .add(firestoreData);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('⚾ 미션 달성! 타격 보너스 +1안타가 기록되었습니다.'),
              backgroundColor: Colors.green.shade700,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );

          // 점수 부여 후 랭킹 강제 업데이트 반영
          await context.read<QuizRankingProvider>().fetchRankings(true);

          // 승급 여부 체크 (SharedPreferences 기반 - 중복 방지)
          if (mounted) {
            final myNewRank = rankProvider.getMyRanking(user.uid);
            final scoreAfter = myNewRank?.score ?? 0;
            final tierAfter = QuizSeasonUtils.getTier(scoreAfter);

            final lastShownTier =
                _prefs?.getString('last_shown_tier_${user.uid}') ?? '';

            if (lastShownTier != tierAfter && tierBefore != tierAfter) {
              // 새로운 승격일 때만 오버레이 표시
              await _prefs?.setString('last_shown_tier_${user.uid}', tierAfter);
              setState(() {
                _oldTier = tierBefore;
                _newTier = tierAfter;
                _showTierUpOverlay = true;
              });
            }
          }
        }
      }
    } catch (e) {
      debugPrint('미션 보상 지급 에러: $e');
      // 실패 시 다시 되돌림
      setState(() {
        _prefs!.setBool('${mission.id}_claimed', false);
      });
    }
  }

  // 5️⃣ 하단 고정 플레이 버튼
  Widget _buildFixedPlayButton() {
    final isDarkMode =
        MediaQuery.of(context).platformBrightness == Brightness.dark;
    final teamProvider = context.read<TeamProvider>();
    final teamColor = teamProvider.selectedTeam?.color ?? BUTTON;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF0F172A) : BACKGROUND_COLOR,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showCategorySheet(context),
        child: Container(
          width: double.infinity,
          height: 54,
          decoration: BoxDecoration(
            color: isDarkMode ? Colors.white : teamColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: (isDarkMode ? Colors.black : teamColor).withValues(
                  alpha: 0.24,
                ),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            '도전하기 ⚾',
            style: TextStyle(
              color: isDarkMode ? Colors.black : Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w800,
              fontFamily: 'kbo',
            ),
          ),
        ),
      ),
    );
  }

  // 새로 디자인된 2단계 도전하기 바텀시트 (시안 v3)
  void _showCategorySheet(BuildContext context) {
    final isDarkMode =
        MediaQuery.of(context).platformBrightness == Brightness.dark;
    final teamColor =
        context.read<TeamProvider>().selectedTeam?.color ?? BUTTON;
    String selectedCategory = '랜덤';
    String selectedCategoryLabel = '전체 랜덤';

    final categories =
        <({String emoji, String label, String value, Color tint})>[
          (
            emoji: '🏟️',
            label: '전체 랜덤',
            value: '랜덤',
            tint: const Color(0xFFEFF6FF),
          ),
          (
            emoji: '🎵',
            label: '응원가',
            value: '응원가',
            tint: const Color(0xFFFFF7ED),
          ),
          (
            emoji: '📜',
            label: 'KBO 역사',
            value: 'KBO역사',
            tint: const Color(0xFFEEF2FF),
          ),
          (
            emoji: '⚾',
            label: '야구 규칙',
            value: '야구룰',
            tint: const Color(0xFFECFDF5),
          ),
          (
            emoji: '🥇',
            label: '기록들',
            value: '기록',
            tint: const Color(0xFFFFF1F2),
          ),
          (
            emoji: '👤',
            label: '선수 퀴즈',
            value: '선수퀴즈',
            tint: const Color(0xFFF5F3FF),
          ),
        ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDarkMode ? const Color(0xFF0F172A) : WHITE,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (sheetCtx, setSheetState) {
            final modeLabel = _selectedMode == QuizMode.threeOut
                ? '🔥 3아웃 무한이닝'
                : 'CLASSIC 10문제';
            return SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: isDarkMode
                              ? Colors.white24
                              : GRAYSCALE_LABEL_200,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '출전 모드 & 종목 선택',
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'kbo',
                            color: isDarkMode ? WHITE : BUTTON,
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(sheetCtx),
                          icon: Icon(
                            Icons.close_rounded,
                            color: isDarkMode
                                ? Colors.white60
                                : GRAYSCALE_LABEL_500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '1단계 · 경기 모드 선택',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: isDarkMode
                            ? Colors.white60
                            : GRAYSCALE_LABEL_600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _buildModeOptionCard(
                            badge: 'CLASSIC',
                            title: '📋 일반 10문제',
                            subtitle: '시즌 랭킹 · 티어 반영',
                            isSelected: _selectedMode == QuizMode.normal,
                            isDarkMode: isDarkMode,
                            accentColor: teamColor,
                            onTap: () {
                              setSheetState(
                                () => _selectedMode = QuizMode.normal,
                              );
                              setState(() {});
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildModeOptionCard(
                            badge: 'SURVIVAL',
                            title: '🔥 3아웃 무한이닝',
                            subtitle: '15초 · 진루/홈런 · 2X',
                            isSelected: _selectedMode == QuizMode.threeOut,
                            isDarkMode: isDarkMode,
                            accentColor: ACCENT_CORAL,
                            onTap: () {
                              setSheetState(
                                () => _selectedMode = QuizMode.threeOut,
                              );
                              setState(() {});
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '2단계 · 퀴즈 종목 선택',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: isDarkMode
                            ? Colors.white60
                            : GRAYSCALE_LABEL_600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: categories.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 8,
                            crossAxisSpacing: 8,
                            childAspectRatio: 2.75,
                          ),
                      itemBuilder: (context, index) {
                        final item = categories[index];
                        final isSelected = selectedCategory == item.value;
                        return InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () {
                            setSheetState(() {
                              selectedCategory = item.value;
                              selectedCategoryLabel = item.label;
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? (isDarkMode
                                        ? const Color(0xFF1E293B)
                                        : WHITE)
                                  : (isDarkMode
                                        ? const Color(0xFF151E32)
                                        : BACKGROUND_COLOR),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isSelected
                                    ? ACCENT_CORAL
                                    : (isDarkMode
                                          ? Colors.white12
                                          : GRAYSCALE_LABEL_100),
                                width: isSelected ? 1.6 : 1.0,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 30,
                                  height: 30,
                                  decoration: BoxDecoration(
                                    color: isDarkMode
                                        ? Colors.white10
                                        : item.tint,
                                    borderRadius: BorderRadius.circular(9),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    item.emoji,
                                    style: const TextStyle(fontSize: 15),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    item.label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      fontFamily: 'kbo',
                                      color: isDarkMode ? WHITE : BUTTON,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(sheetCtx);
                          _launchQuizCategory(selectedCategory);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: teamColor,
                          foregroundColor: WHITE,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        child: Text(
                          '$modeLabel · $selectedCategoryLabel 시작하기 ⚾',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            fontFamily: 'kbo',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildModeOptionCard({
    required String badge,
    required String title,
    required String subtitle,
    required bool isSelected,
    required bool isDarkMode,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: isSelected
              ? accentColor.withValues(alpha: isDarkMode ? 0.16 : 0.1)
              : (isDarkMode ? const Color(0xFF151E32) : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? accentColor
                : (isDarkMode ? Colors.white12 : Colors.grey.shade300),
            width: isSelected ? 1.8 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: accentColor.withValues(alpha: 0.18),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2.5,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? accentColor.withValues(alpha: 0.22)
                        : (isDarkMode ? Colors.white10 : Colors.grey.shade200),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    badge,
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                      color: isSelected
                          ? (isDarkMode ? accentColor : Colors.black87)
                          : (isDarkMode
                                ? Colors.white54
                                : Colors.grey.shade600),
                    ),
                  ),
                ),
                Icon(
                  isSelected
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  size: 16,
                  color: isSelected
                      ? accentColor
                      : (isDarkMode ? Colors.white24 : Colors.grey.shade400),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                fontFamily: 'kbo',
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                color: isDarkMode ? Colors.white60 : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- 시즌 오버레이 로직 ---

  Future<void> _checkAndShowSeasonResultOverlay() async {
    final prefs = await SharedPreferences.getInstance();
    final lastResultShownSeason = prefs.getString('last_result_shown_season');
    final currentSeasonId = QuizSeasonUtils.getCurrentSeasonId();

    debugPrint(
      "[SeasonOverlay] Result Check - Last: $lastResultShownSeason, Current: $currentSeasonId",
    );

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

    // 4월은 테스트 시즌이므로 시작 오버레이를 표시하지 않음
    if (currentSeasonId == '2026_04') return;

    bool shouldShow = lastShownSeason != currentSeasonId;

    if (shouldShow && mounted) {
      debugPrint("[SeasonOverlay] Showing Start Overlay...");
      await _showSeasonOverlayDialog(context);
      await prefs.setString(key, currentSeasonId);
    }
  }

  Future<void> _showSeasonResultDialog(BuildContext context) async {
    final rankProvider = context.read<QuizRankingProvider>();
    final teamProvider = context.read<TeamProvider>();
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final selectedTeamName = teamProvider.selectedTeam?.name;
    final prevSeasonId = QuizSeasonUtils.getPreviousSeasonId();

    if (prevSeasonId == null) return;

    final prevSeasonLabel = QuizSeasonUtils.getSeasonLabel(prevSeasonId);

    final myRanking = currentUserId != null
        ? rankProvider.getMyRanking(currentUserId)
        : null;
    final currentUserPhotoUrl = FirebaseAuth.instance.currentUser?.photoURL;
    final fallbackAvatarUrl = myRanking?.profileUrl ?? currentUserPhotoUrl;
    final myTeamRanking = selectedTeamName != null
        ? rankProvider.getMyTeamRanking(selectedTeamName)
        : null;

    final bool isIndividualChampion = (myRanking?.rank == 1);
    final bool isTeamChampion = (myTeamRanking?.rank == 1);
    final bool isChampion = isIndividualChampion || isTeamChampion;
    final bool isTop50 = (myRanking != null && myRanking.rank <= 50);

    if (myRanking != null) {
      context.read<BadgeProvider>().checkSeasonalBadges(myRanking.rank);
    }

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
    final myBattingEntry = currentUserId != null
        ? rankProvider.battingKingRankings
              .where((e) => e.userId == currentUserId)
              .firstOrNull
        : null;

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
            seasonAvg: myBattingEntry?.seasonBattingAverage,
            totalHits: myBattingEntry?.totalHits,
            totalAtBats: myBattingEntry?.totalAtBats,
            seasonId: prevSeasonId,
            rankNum: myRanking.rank,
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
            seasonAvg: myBattingEntry?.seasonBattingAverage,
            totalHits: myBattingEntry?.totalHits,
            totalAtBats: myBattingEntry?.totalAtBats,
            titleLabel:
                '${QuizSeasonUtils.getSeasonShortCode(prevSeasonId)} 타격왕',
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
            seasonAvg: myBattingEntry?.seasonBattingAverage,
            totalHits: myBattingEntry?.totalHits,
            totalAtBats: myBattingEntry?.totalAtBats,
            titleLabel:
                '${QuizSeasonUtils.getSeasonShortCode(prevSeasonId)} 타격왕',
            onDismiss: () => Navigator.of(context, rootNavigator: true).pop(),
          );
        },
      );
    }

    // 3. 팀 우승 오버레이 (구단 1위 + 시즌 최소 참여 유저)
    final bool hasSeasonParticipation =
        (myBattingEntry?.totalAtBats ?? 0) >= 10 || myRanking != null;
    if (isTeamChampion &&
        hasSeasonParticipation &&
        mounted &&
        myTeamRanking != null) {
      context.read<BadgeProvider>().unlockTeamChampionBadge();
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
            seasonAvg: myTeamRanking.battingAverage,
            totalHits: myTeamRanking.totalHits,
            totalAtBats: myTeamRanking.totalAtBats,
            titleLabel:
                '${QuizSeasonUtils.getSeasonShortCode(prevSeasonId)} 우승 구단 팬',
          ),
        );
      }

      final resolvedTeamName = selectedTeamName ?? '내 팀';
      await showGeneralDialog<void>(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.black.withValues(alpha: 0.95),
        transitionDuration: const Duration(milliseconds: 400),
        useRootNavigator: true,
        pageBuilder: (dialogCtx, animation, secondaryAnimation) {
          return TeamChampionOverlay(
            teamName: resolvedTeamName,
            seasonLabel: prevSeasonLabel,
            seasonShortCode: QuizSeasonUtils.getSeasonShortCode(prevSeasonId),
            teamAvg: myTeamRanking.battingAverage,
            teamHits: myTeamRanking.totalHits,
            teamAtBats: myTeamRanking.totalAtBats,
            teamLogoPath: teamProvider.selectedTeam?.logoPath,
            topContributors: rankProvider.getTeamTopContributors(
              resolvedTeamName,
            ),
            onDismiss: () => Navigator.of(dialogCtx, rootNavigator: true).pop(),
          );
        },
      );
    }
  }

  Future<void> _showSeasonOverlayDialog(BuildContext context) async {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.92),
      transitionDuration: const Duration(milliseconds: 300),
      useRootNavigator: true,
      pageBuilder: (context, animation, secondaryAnimation) {
        return Consumer2<QuizRankingProvider, TeamProvider>(
          builder: (context, rankProvider, teamProvider, child) {
            final selectedTeam = teamProvider.selectedTeam;
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

  Widget _buildRewardsMasterPreviewToggle(bool isDarkMode) {
    final qrp = context.watch<QuizRankingProvider>();
    final teamProvider = context.read<TeamProvider>();
    final teamColor = teamProvider.selectedTeam?.color ?? BUTTON;
    final enabled = qrp.devPreviewChampionRewards;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: enabled
              ? const Color(0xFFD4AF37)
              : (isDarkMode
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.06)),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFF0B1020),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0xFFD4AF37).withValues(alpha: 0.65),
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Image.asset(
              'assets/images/team_champion_trophy.jpg',
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '뱃지·리본·칭호·트로피 미리보기',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isDarkMode ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                Text(
                  'ON 시 로비·랭킹·뱃지함 전체 적용',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDarkMode
                        ? Colors.white60
                        : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: enabled,
            activeTrackColor: teamColor,
            onChanged: (value) {
              context.read<QuizRankingProvider>().setDevPreviewChampionRewards(
                value,
                teamName: teamProvider.selectedTeam?.name,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCeremonyPreviewToggle(bool isDarkMode) {
    final teamColor =
        context.read<TeamProvider>().selectedTeam?.color ?? BUTTON;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _ceremonyPreviewEnabled
              ? const Color(0xFFD4AF37)
              : (isDarkMode
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.06)),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFFD4AF37).withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.emoji_events_rounded,
              color: Color(0xFFD4AF37),
              size: 19,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '타격왕 시상식 오버레이 미리보기',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isDarkMode ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                Text(
                  'ON 시 5막 연출·음원·저장/공유 테스트',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDarkMode
                        ? Colors.white60
                        : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: _ceremonyPreviewEnabled,
            activeTrackColor: teamColor,
            onChanged: (value) async {
              setState(() => _ceremonyPreviewEnabled = value);
              if (value) {
                await _openChampionPreviewOverlay();
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTeamChampionPreviewToggle(bool isDarkMode) {
    final teamColor =
        context.read<TeamProvider>().selectedTeam?.color ?? BUTTON;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _teamChampionPreviewEnabled
              ? teamColor
              : (isDarkMode
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.06)),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: teamColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.flag_rounded, color: teamColor, size: 19),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '구단 챔피언 오버레이 미리보기',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isDarkMode ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                Text(
                  'ON 시 D안 하이라이트 필름·구단 트로피 테스트',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDarkMode
                        ? Colors.white60
                        : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: _teamChampionPreviewEnabled,
            activeTrackColor: teamColor,
            onChanged: (value) async {
              setState(() => _teamChampionPreviewEnabled = value);
              if (value) {
                await _openTeamChampionPreviewOverlay();
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _openTeamChampionPreviewOverlay() async {
    if (!mounted) return;
    final rankProvider = context.read<QuizRankingProvider>();
    final teamProvider = context.read<TeamProvider>();
    final currentSeasonId = QuizSeasonUtils.getCurrentSeasonId();
    final seasonLabel = QuizSeasonUtils.getSeasonLabel(currentSeasonId);
    final selectedTeamName = teamProvider.selectedTeam?.name ?? '두산 베어스';
    final myTeamRanking = rankProvider.getMyTeamRanking(selectedTeamName);

    final int teamAb = (myTeamRanking?.totalAtBats ?? 0) > 0
        ? myTeamRanking!.totalAtBats
        : 842;
    final int teamHits = (myTeamRanking?.totalAtBats ?? 0) > 0
        ? myTeamRanking!.totalHits
        : 689;
    final double teamAvg = (myTeamRanking?.totalAtBats ?? 0) > 0
        ? myTeamRanking!.battingAverage
        : 0.818;

    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.95),
      transitionDuration: const Duration(milliseconds: 350),
      useRootNavigator: true,
      pageBuilder: (dialogCtx, animation, secondaryAnimation) {
        return TeamChampionOverlay(
          teamName: selectedTeamName,
          seasonLabel: seasonLabel,
          seasonShortCode: QuizSeasonUtils.getSeasonShortCode(currentSeasonId),
          teamAvg: teamAvg,
          teamHits: teamHits,
          teamAtBats: teamAb,
          teamLogoPath: teamProvider.selectedTeam?.logoPath,
          topContributors: rankProvider.getTeamTopContributors(
            selectedTeamName,
          ),
          onDismiss: () => Navigator.of(dialogCtx, rootNavigator: true).pop(),
        );
      },
    );

    if (mounted) {
      setState(() => _teamChampionPreviewEnabled = false);
    }
  }

  Future<void> _openChampionPreviewOverlay() async {
    if (!mounted) return;
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final rankProvider = context.read<QuizRankingProvider>();
    final teamProvider = context.read<TeamProvider>();
    final userProvider = context.read<UserProvider>();
    final profileProvider = context.read<ProfileProvider>();

    final currentSeasonId = QuizSeasonUtils.getCurrentSeasonId();
    final seasonLabel = QuizSeasonUtils.getSeasonLabel(currentSeasonId);
    final selectedTeamName = teamProvider.selectedTeam?.name ?? '두산 베어스';
    final myBattingEntry = currentUserId != null
        ? rankProvider.battingKingRankings
              .where((e) => e.userId == currentUserId)
              .firstOrNull
        : null;
    final myRanking = currentUserId != null
        ? rankProvider.getMyRanking(currentUserId)
        : null;

    final int previewAtBats = (myBattingEntry?.totalAtBats ?? 0) > 0
        ? myBattingEntry!.totalAtBats
        : 28;
    final int previewHits = (myBattingEntry?.totalAtBats ?? 0) > 0
        ? myBattingEntry!.totalHits
        : 25;
    final double previewAvg = (myBattingEntry?.totalAtBats ?? 0) > 0
        ? myBattingEntry!.seasonBattingAverage
        : 0.893;

    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.95),
      transitionDuration: const Duration(milliseconds: 350),
      useRootNavigator: true,
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return ChampionOverlay(
          winnerName: myRanking?.name ?? userProvider.nickname ?? '콩콩',
          teamName: selectedTeamName,
          totalScore: myRanking?.score ?? 2500,
          currentRank: '1위',
          seasonLabel: seasonLabel,
          avatarUrl: profileProvider.imageUrl,
          teamLogoUrl: teamProvider.selectedTeam?.logoPath,
          type: ChampionType.individual,
          seasonAvg: previewAvg,
          totalHits: previewHits,
          totalAtBats: previewAtBats,
          titleLabel:
              '${QuizSeasonUtils.getSeasonShortCode(currentSeasonId)} 타격왕',
          onDismiss: () =>
              Navigator.of(dialogContext, rootNavigator: true).pop(),
        );
      },
    );

    if (mounted) {
      setState(() => _ceremonyPreviewEnabled = false);
    }
  }
}
