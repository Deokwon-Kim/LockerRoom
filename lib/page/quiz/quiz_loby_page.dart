import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:lockerroom/bottom_tab_bar/bottom_tab_bar.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/const/firestore_constants.dart';
import 'package:lockerroom/model/quiz_result_model.dart';
import 'package:lockerroom/page/quiz/cheer_song_category_page.dart';
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

  // 티어 승급 오버레이 상태
  bool _showTierUpOverlay = false;
  String _oldTier = "";
  String _newTier = "";

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      _prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      final rankProvider = context.read<QuizRankingProvider>();

      // 0. 로컬 캐시 즉시 로드 (깜빡임 방지)
      rankProvider.loadMyOverallFromLocal();

      // 1. 기본 데이터 로드
      context.read<QuizProvider>().fetchMyHistory();
      context.read<UserProvider>().loadNickname();

      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        context.read<ProfileProvider>().subscribeMyProfileImage(uid);
      }

      // 2. 오버레이 시퀀스를 위해 지난 시즌 랭킹 데이터 먼저 로드
      final prevSeasonId = QuizSeasonUtils.getPreviousSeasonId();
      if (prevSeasonId != null) {
        await rankProvider.setSeason(prevSeasonId);
      }

      // 3. 오버레이 시퀀스 실행 (결과 -> 챔피언 -> 시작)
      if (mounted) {
        await _checkAndShowSeasonSequence();
      }

      // 4. 다시 현재 시즌 데이터를 로드하여 로비 정보 갱신
      if (mounted) {
        await rankProvider.setSeason(QuizSeasonUtils.getCurrentSeasonId());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final teamProvider = context.watch<TeamProvider>();
    final teamLogo = teamProvider.selectedTeam?.logoPath;
    final isDarkMode =
        MediaQuery.of(context).platformBrightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode
          ? const Color(0xFF0F172A)
          : const Color(0xFFF8F9FA),
      body: Stack(
        children: [
          // 기존 콘텐츠는 SafeArea 안에 유지
          SafeArea(
            child: Stack(
              children: [
                // 배경: 우측 상단 은은한 팀 로고 워터마크
                if (teamLogo != null)
                  Positioned(
                    top: -30,
                    right: -30,
                    child: Opacity(
                      opacity: 0.12,
                      child: Image.asset(teamLogo, width: 200),
                    ),
                  ),

                SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 10),
                      // 1️⃣ 상단 프로필 섹션 (뒤로가기 포함)
                      _buildTopHeader(),
                      const SizedBox(height: 25),

                      // 2️⃣ 시즌 정보 카드
                      _buildSeasonCard(),
                      const SizedBox(height: 16),

                      // 3️⃣ 메인 티어 카드 (다크 게임 카드 컨셉)
                      _buildHeroTierCard(),
                      const SizedBox(height: 25),

                      // 4️⃣ 오늘의 미션 섹션
                      _buildMissionSection(),
                      const SizedBox(height: 16),
                      _buildFixedPlayButton(),
                    ],
                  ),
                ),
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

  // 1️⃣ 상단 헤더 (뒤로가기 + 프로필)
  Widget _buildTopHeader() {
    return Consumer<UserProvider>(
      builder: (context, up, child) {
        final profileProvider = Provider.of<ProfileProvider>(context);
        final teamProvider = context.read<TeamProvider>();
        final isDarkMode =
            MediaQuery.of(context).platformBrightness == Brightness.dark;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            children: [
              // 뒤로가기 버튼
              IconButton(
                icon: Icon(
                  Icons.arrow_back_ios_new,
                  color: isDarkMode ? WHITE : Colors.black87,
                  size: 20,
                ),
                onPressed: () => Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => BottomTabBar()),
                  (route) => false,
                ),
              ),
              const SizedBox(width: 4),
              // 프로필 사진
              CircleAvatar(
                backgroundColor: GRAYSCALE_LABEL_300,
                radius: 20,
                backgroundImage: profileProvider.image != null
                    ? FileImage(profileProvider.image!)
                    : (profileProvider.imageUrl != null
                          ? NetworkImage(profileProvider.imageUrl!)
                          : null),
                child:
                    (profileProvider.image == null &&
                        profileProvider.imageUrl == null)
                    ? Icon(Icons.person, size: 20, color: GRAYSCALE_LABEL_500)
                    : null,
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    up.nickname ?? '야구팬',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? WHITE : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    teamProvider.selectedTeam?.name ?? 'dd',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDarkMode
                          ? WHITE
                          : teamProvider.selectedTeam?.color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // 2️⃣ 시즌 정보 카드
  Widget _buildSeasonCard() {
    final isDarkMode =
        MediaQuery.of(context).platformBrightness == Brightness.dark;
    final currentSeasonId = QuizSeasonUtils.getCurrentSeasonId();
    final seasonLabel = QuizSeasonUtils.getSeasonLabel(currentSeasonId);

    // 1️⃣ 시즌 종료일 계산 로직 (유틸리티 정책 반영)
    DateTime getEndDate() {
      final now = DateTime.now();
      if (currentSeasonId == '2026_04') {
        return DateTime(2026, 4, 30, 23, 59, 59);
      }
      if (now.day <= 15) {
        return DateTime(now.year, now.month, 15, 23, 59, 59);
      } else {
        return DateTime(now.year, now.month + 1, 0, 23, 59, 59);
      }
    }

    final seasonEndDate = getEndDate();
    final remaining = seasonEndDate.difference(DateTime.now());
    final remainingText = remaining.isNegative
        ? "시즌 종료됨"
        : "${remaining.inDays}일 ${remaining.inHours % 24}시간 ${remaining.inMinutes % 60}분";

    return Consumer<QuizRankingProvider>(
      builder: (context, qrp, child) {
        // 2️⃣ 실제 도전자 수 (전체 랭킹 카운트)
        final totalParticipants = qrp.rankings.length;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDarkMode ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(20),

              boxShadow: [
                BoxShadow(
                  color: isDarkMode
                      ? Colors.black.withOpacity(0.2)
                      : Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
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
                      '$seasonLabel 진행 중 🔥',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.white : Colors.black,
                      ),
                    ),
                    Text(
                      '시즌 종료까지',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDarkMode
                            ? Colors.white.withOpacity(0.4)
                            : Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '현재 $totalParticipants명이 도전 중 ⚾',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDarkMode
                            ? Colors.white.withOpacity(0.6)
                            : Colors.grey.shade600,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      remainingText,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.white : Colors.black,
                        fontFamily: 'kbo',
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

  // 3️⃣ 메인 티어 카드 (다크 게임 카드 컨셉)
  Widget _buildHeroTierCard() {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    return Consumer<QuizRankingProvider>(
      builder: (context, qrp, child) {
        // [수정] 카테고리 필터와 상관없이 항상 '종합' 데이터 사용
        final score = currentUserId != null
            ? qrp.getOverallScore(currentUserId)
            : 0;
        final rank = currentUserId != null
            ? qrp.getOverallRank(currentUserId)
            : 0;
        final tierName = currentUserId != null
            ? qrp.getOverallTier(currentUserId)
            : 'PROSPECT';

        final tierColor = QuizTierUtils.getTierColor(tierName);
        final emblemPath = QuizTierUtils.getTierEmblem(tierName);
        final progress = QuizTierUtils.getTierProgress(score);

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B), // 시안 느낌의 다크 배경
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1️⃣ 상단 레이아웃 (엠블럼 + 랭킹)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 90,
                      height: 90,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A).withOpacity(0.4),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Image.asset(emblemPath),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          rank > 0 ? '${rank}위' : '-',
                          style: const TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            fontFamily: 'kbo',
                          ),
                        ),
                        Text(
                          '내 종합 순위',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withOpacity(0.4),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 30),
                // 2️⃣ 티어 이름 및 현재 점수
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      tierName.toUpperCase(),
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: tierColor,
                        fontFamily: 'kbo',
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      '${score}P',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // 3️⃣ 글로잉 게이지 바
                Stack(
                  children: [
                    Container(
                      height: 10,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A).withOpacity(0.5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: progress.progress.clamp(0.05, 1.0),
                      child: Container(
                        height: 10,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [tierColor, tierColor.withOpacity(0.8)],
                          ),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: tierColor.withOpacity(0.6),
                              blurRadius: 10,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // 4️⃣ 하단 목표 텍스트
                Text(
                  progress.remainingScore > 0
                      ? '${progress.nextTier}까지 ${progress.remainingScore}P'
                      : '최고 등급 달성! 🔥',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.6),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // 4️⃣ 오늘의 미션 섹션
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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '오늘의 미션',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: isDarkMode ? Colors.white : Colors.black,
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
                  '매일 자정 초기화',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDarkMode
                        ? Colors.white.withOpacity(0.4)
                        : Colors.grey.shade500,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          ...missions.map((mission) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _buildMissionItem(mission),
            );
          }),
        ],
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
                        '보상 +${mission.rewardPts}P',
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
          score: mission.rewardPts, // PTS 부여
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
              content: Text('🎉 미션 보상 획득! 랭킹 점수 +${mission.rewardPts}P'),
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

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDarkMode
              ? [
                  const Color(0xFF0F172A).withOpacity(0),
                  const Color(0xFF0F172A),
                ]
              : [Colors.white.withOpacity(0), Colors.white],
          stops: const [0, 0.4],
        ),
      ),
      child: InkWell(
        onTap: () => _showCategorySheet(context),
        child: Container(
          width: double.infinity,
          height: 60,
          decoration: BoxDecoration(
            color: isDarkMode ? Colors.white : const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: isDarkMode
                    ? Colors.black.withOpacity(0.3)
                    : Colors.black.withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            '퀴즈 도전하기 ⚾',
            style: TextStyle(
              color: isDarkMode ? Colors.black : Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              fontFamily: 'kbo',
            ),
          ),
        ),
      ),
    );
  }

  // 카테고리 선택 바텀시트
  void _showCategorySheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(25, 15, 25, 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 45,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 30),
              const Text(
                '어떤 퀴즈에 도전할까요?',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'kbo',
                ),
              ),
              const SizedBox(height: 30),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 15,
                crossAxisSpacing: 15,
                childAspectRatio: 1.6,
                children: [
                  _buildCategoryCard(
                    context,
                    '🏟️ 전체 랜덤',
                    '랜덤',
                    Colors.blueGrey,
                  ),
                  _buildCategoryCard(context, '🎵 응원가', '응원가', Colors.orange),
                  _buildCategoryCard(
                    context,
                    '📜 KBO 역사',
                    'KBO역사',
                    Colors.indigo,
                  ),
                  _buildCategoryCard(context, '⚾ 야구 규칙', '야구룰', Colors.green),
                  _buildCategoryCard(
                    context,
                    '🥇 기록들',
                    '기록',
                    Colors.deepOrange,
                  ),
                  _buildCategoryCard(
                    context,
                    '👤 선수 퀴즈',
                    '선수퀴즈',
                    Colors.purple,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCategoryCard(
    BuildContext context,
    String title,
    String category,
    Color color,
  ) {
    return InkWell(
      onTap: () {
        Navigator.pop(context);
        if (category == '응원가') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const CheerSongCategoryPage(),
            ),
          );
          return;
        }
        showDialog(
          context: context,
          builder: (context) => TeamBattleDialog(
            onStart: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => QuizPlayPage(category: category),
                ),
              );
            },
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withOpacity(0.2), width: 1.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: color,
                fontSize: 15,
                fontWeight: FontWeight.w800,
                fontFamily: 'kbo',
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- 시즌 오버레이 로직 ---

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
}
