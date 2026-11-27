import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:lockerroom/bottom_tab_bar/intution_tab_bar.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/model/meetup_model.dart';
import 'package:lockerroom/model/post_model.dart';
import 'package:lockerroom/model/schedule_model.dart';
// import 'package:lockerroom/model/stadium_weather_model.dart';
import 'package:lockerroom/model/team_model.dart';
import 'package:lockerroom/page/feed/feed_detail_page.dart';
import 'package:lockerroom/page/home/quiz_ranking_dashboard_.dart';
import 'package:lockerroom/page/intution_record/all_users_intution_record_page.dart';
import 'package:lockerroom/page/intution_record/intution_record_upload_page.dart';
import 'package:lockerroom/page/intution_record/ticker_camera_scan_page.dart';
import 'package:lockerroom/provider/ticket_scan_provider.dart';
import 'package:lockerroom/services/feature_announcement_service.dart';
import 'package:lockerroom/utils/media_utils.dart';
import 'package:lockerroom/widgets/feature_announcement_dialog.dart';
import 'package:lockerroom/widgets/network_video_player.dart';
import 'package:lockerroom/widgets/team_news_section.dart';
import 'package:lockerroom/page/meetup/meetup_detail_page.dart';
import 'package:lockerroom/page/meetup/meetup_page.dart';
import 'package:lockerroom/page/schedule/schedule.dart';
import 'package:lockerroom/provider/block_provider.dart';
import 'package:lockerroom/provider/feed_provider.dart';
import 'package:lockerroom/provider/meetup_provider.dart';
// import 'package:lockerroom/provider/food_store_provider.dart';
import 'package:lockerroom/provider/notification_provider.dart';
import 'package:lockerroom/provider/profile_provider.dart';
import 'package:lockerroom/provider/schdule_Provider.dart';
import 'package:lockerroom/provider/team_provider.dart';
import 'package:lockerroom/provider/video_provider.dart';
import 'package:lockerroom/provider/quiz_ranking_provider.dart';
// import 'package:lockerroom/provider/schdule_Provider.dart';
// import 'package:lockerroom/provider/weather_provider.dart';
// import 'package:lockerroom/utils/quiz_season_utils.dart';
import 'package:lockerroom/provider/intution_record_list_provider.dart';
import 'package:lockerroom/provider/weather_provider.dart';
import 'package:provider/provider.dart';
import 'package:badges/badges.dart' as badges;
import 'package:url_launcher/url_launcher.dart';

class HomePage extends StatefulWidget {
  final TeamModel teamModel;
  final TeamModel selectedTeam;
  final void Function(int) onTabTab;
  const HomePage({
    super.key,
    required this.teamModel,
    required this.onTabTab,
    required this.selectedTeam,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  TeamModel? _lastFetchedTeam;
  BlockProvider? _blockProvider;
  VoidCallback? _blockListener;
  late final FeedProvider _feedProvider;
  bool _hasCheckedFeatureDialog = false;

  @override
  void initState() {
    super.initState();
    _feedProvider = context.read<FeedProvider>();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _feedProvider.listenRecentPosts();
      context.read<MeetupProvider>().fetchMeetups();
      context.read<QuizRankingProvider>().fetchRankings();
      _checkFeatureAnnouncement();
      // context.read<WeatherProvider>().fetchAllStadiumsWeather();

      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      if (currentUserId != null) {
        context.read<ProfileProvider>().subscribeMyProfileImage(currentUserId);
        context.read<ProfileProvider>().subscribeUserProfile(currentUserId);
      }

      _blockProvider = context.read<BlockProvider>();
      final feedProvider = context.read<FeedProvider>();
      feedProvider.setBlockedUsers(_blockProvider!.blockedUserIds);
      feedProvider.setBlockedByUsers(_blockProvider!.blockedByUserIds);

      _blockListener = () {
        if (mounted) {
          feedProvider.setBlockedUsers(_blockProvider!.blockedUserIds);
          feedProvider.setBlockedByUsers(_blockProvider!.blockedByUserIds);
        }
      };
      _blockProvider!.addListener(_blockListener!);
    });
  }

  @override
  void dispose() {
    if (_blockProvider != null && _blockListener != null) {
      _blockProvider!.removeListener(_blockListener!);
    }
    _feedProvider.cancelRecentPostSubscription();
    super.dispose();
  }

  Future<void> _checkFeatureAnnouncement() async {
    if (_hasCheckedFeatureDialog) return;
    _hasCheckedFeatureDialog = true;

    final announcement = await FeatureAnnouncementService()
        .fetchActiveAnnouncement();
    if (!mounted || announcement == null) return;

    await FeatureAnnouncementDialog.show(
      context,
      announcement: announcement,
      onNavigate: _handleFeatureCtaNavigation,
    );
  }

  void _handleFeatureCtaNavigation(String target) {
    if (!mounted) return;
    final selectedTeam =
        context.read<TeamProvider>().selectedTeam ?? widget.teamModel;

    switch (target) {
      case 'ticket_scan':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChangeNotifierProvider(
              create: (ctx) => TicketScanProvider(
                scheduleProvider: ctx.read<ScheduleProvider>(),
              ),
              child: const TickerCameraScanPage(),
            ),
          ),
        );
        break;
      case 'intuition_record':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const IntutionTabBar()),
        );
        break;
      case 'meetup':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => MeetupPage()),
        );
        break;
      case 'schedule':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SchedulePage(teamModel: selectedTeam),
          ),
        );
        break;
      default:
        break;
    }
  }

  void _maybeFetchVideos(TeamModel team) {
    final apiKey = dotenv.env['YOUTUBE_API_KEY'] ?? '';
    if (_lastFetchedTeam?.name == team.name) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<VideoProvider>().fetchTeamVideos(team, apiKey);
    });
    _lastFetchedTeam = team;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TeamProvider>(
      builder: (context, teamProvider, child) {
        final selectedTeam = teamProvider.selectedTeam ?? widget.teamModel;
        if (teamProvider.selectedTeam != null) {
          _maybeFetchVideos(teamProvider.selectedTeam!);
        }
        final statusBarHeight = MediaQuery.of(context).padding.top;
        const headerContentHeight = 64.0;
        const overlapHeight = 20.0;
        final totalHeaderHeight =
            statusBarHeight + headerContentHeight + overlapHeight;

        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: const SystemUiOverlayStyle(
            statusBarBrightness: Brightness.dark,
            statusBarIconBrightness: Brightness.light,
            statusBarColor: Colors.transparent,
          ),
          child: Scaffold(
            backgroundColor: context.bgColor,
            body: Stack(
              children: [
                // 1. 상단 팀 컬러 멀티-스톱 그라데이션 헤더 (메쉬 글로우 + 새틴 광택)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: totalHeaderHeight,
                  child: ClipRect(
                    child: Builder(
                      builder: (context) {
                        final hsl = HSLColor.fromColor(selectedTeam.color);
                        final topHighlight = hsl
                            .withLightness(
                              (hsl.lightness + 0.14).clamp(0.18, 0.48),
                            )
                            .withSaturation(
                              (hsl.saturation + 0.08).clamp(0.15, 0.9),
                            )
                            .toColor();
                        final midTone =
                            Color.lerp(selectedTeam.color, BUTTON, 0.25) ??
                            selectedTeam.color;
                        final deepShadow =
                            Color.lerp(
                              selectedTeam.color,
                              const Color(0xFF0A0F1C),
                              0.68,
                            ) ??
                            const Color(0xFF0A0F1C);

                        return Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              stops: const [0.0, 0.48, 1.0],
                              colors: [topHighlight, midTone, deepShadow],
                            ),
                          ),
                          child: Stack(
                            children: [
                              // 우상단 메인 앰비언트 글로우
                              Positioned(
                                top: -55,
                                right: -30,
                                child: Container(
                                  width: 200,
                                  height: 200,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: RadialGradient(
                                      colors: [
                                        WHITE.withValues(alpha: 0.20),
                                        topHighlight.withValues(alpha: 0.08),
                                        WHITE.withValues(alpha: 0.0),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              // 좌하단 서브 컬러 글로우
                              Positioned(
                                bottom: -60,
                                left: -24,
                                child: Container(
                                  width: 170,
                                  height: 170,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: RadialGradient(
                                      colors: [
                                        topHighlight.withValues(alpha: 0.22),
                                        WHITE.withValues(alpha: 0.0),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              // 대각선 새틴 하이라이트 레이어
                              Positioned.fill(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: const Alignment(-0.8, -1.0),
                                      end: const Alignment(0.9, 1.0),
                                      stops: const [0.0, 0.35, 0.52, 1.0],
                                      colors: [
                                        WHITE.withValues(alpha: 0.0),
                                        WHITE.withValues(alpha: 0.08),
                                        WHITE.withValues(alpha: 0.0),
                                        Colors.black.withValues(alpha: 0.14),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),

                // 2. 상단이 둥근 바디 (헤더 위를 24px 덮고 올라옴)
                Positioned(
                  top: statusBarHeight + headerContentHeight,
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    decoration: BoxDecoration(
                      color: context.bgColor,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(24),
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(24),
                      ),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 18, 16, 36),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 1) 오늘의 경기 / 다음 경기 매치업 카드
                            _buildMatchCard(context, selectedTeam),
                            const SizedBox(height: 14),

                            // 2) 야잘알 퀴즈 & 명예의 전당 슬라이드 배너
                            QuizRankingDashboard(selectedTeam: selectedTeam),
                            const SizedBox(height: 14),

                            // 3) 나의 직관 리포트 & 원탭 티켓 스캔 카드
                            _buildIntutionRecord(),
                            const SizedBox(height: 16),

                            // 3-1) 응원팀별 주요뉴스
                            TeamNewsSection(selectedTeam: selectedTeam),
                            const SizedBox(height: 22),

                            // 4) 실시간 팬들의 이야기 (Edge-to-Edge 가로 스크롤)
                            _buildFeedSection(context, selectedTeam),
                            const SizedBox(height: 22),

                            // 5) 같이 보면 더 즐거운 직관 (Edge-to-Edge 가로 스크롤)
                            _buildMeetupSection(context, selectedTeam),
                            const SizedBox(height: 22),

                            // 6) 구단 공식 유튜브 섹션
                            GestureDetector(
                              onTap: () {
                                launchUrl(
                                  Uri.parse(selectedTeam.youtubeUrl),
                                  mode: LaunchMode.externalApplication,
                                );
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 2,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '🎬 ${selectedTeam.youtubeName}',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                          color: context.textPrimary,
                                          letterSpacing: -0.3,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      '더보기',
                                      style: TextStyle(
                                        color: GRAYSCALE_LABEL_500,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(width: 3),
                                    const Icon(
                                      Icons.arrow_forward_ios_rounded,
                                      size: 11,
                                      color: GRAYSCALE_LABEL_500,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Consumer<VideoProvider>(
                              builder: (context, videoProvider, child) {
                                if (videoProvider.isLoading) {
                                  return Center(
                                    child: Padding(
                                      padding: const EdgeInsets.all(24.0),
                                      child: CircularProgressIndicator(
                                        color: selectedTeam.color,
                                      ),
                                    ),
                                  );
                                }
                                final videos = videoProvider.videos;
                                if (videos.isEmpty) {
                                  return _buildEmptyCard('영상이 존재하지 않습니다.');
                                }

                                return Column(
                                  children: [
                                    _buildVideoItem(
                                      context,
                                      videos[0],
                                      isLarge: true,
                                    ),
                                    if (videos.length > 1) ...[
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: _buildVideoItem(
                                              context,
                                              videos[1],
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: videos.length > 2
                                                ? _buildVideoItem(
                                                    context,
                                                    videos[2],
                                                  )
                                                : const SizedBox.shrink(),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // 3. 앱바 콘텐츠 (로고 카드, 팀명/구장, 알림 버튼)
                Positioned(
                  top: statusBarHeight,
                  left: 16,
                  right: 16,
                  height: headerContentHeight,
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: WHITE.withValues(alpha: 0.95),
                          borderRadius: BorderRadius.circular(13),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.16),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Image.asset(
                          selectedTeam.logoPath,
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    selectedTeam.name,
                                    style: const TextStyle(
                                      color: WHITE,
                                      fontSize: 17.5,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.5,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6.5,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: WHITE.withValues(alpha: 0.18),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: WHITE.withValues(alpha: 0.28),
                                      width: 0.8,
                                    ),
                                  ),
                                  child: const Text(
                                    'MY TEAM',
                                    style: TextStyle(
                                      color: WHITE,
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Icon(
                                  Icons.location_on_rounded,
                                  size: 12,
                                  color: WHITE.withValues(alpha: 0.78),
                                ),
                                const SizedBox(width: 3),
                                Flexible(
                                  child: Text(
                                    '${selectedTeam.stadium} · 오늘도 승리의 함성을!',
                                    style: TextStyle(
                                      color: WHITE.withValues(alpha: 0.84),
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w500,
                                      letterSpacing: -0.2,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Consumer<NotificationProvider>(
                        builder: (context, ntp, child) {
                          return badges.Badge(
                            position: badges.BadgePosition.topEnd(
                              top: -3,
                              end: -3,
                            ),
                            badgeAnimation: const badges.BadgeAnimation.slide(
                              animationDuration: Duration(milliseconds: 300),
                            ),
                            showBadge: ntp.unreadCount > 0,
                            badgeStyle: const badges.BadgeStyle(
                              badgeColor: RED_DANGER_TEXT_50,
                              padding: EdgeInsets.all(5),
                            ),
                            badgeContent: Text(
                              '${ntp.unreadCount}',
                              style: const TextStyle(
                                color: WHITE,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () => Navigator.pushNamed(context, '알림센터'),
                              child: Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: WHITE.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: WHITE.withValues(alpha: 0.24),
                                  ),
                                ),
                                child: const Icon(
                                  CupertinoIcons.bell_fill,
                                  color: WHITE,
                                  size: 18,
                                ),
                              ),
                            ),
                          );
                        },
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
  }

  // Widget _buildMyStatusBar(TeamModel selectedTeam) {
  //   return Consumer2<ProfileProvider, QuizRankingProvider>(
  //     builder: (context, profileProvider, rankProvider, _) {
  //       final currentUserId = FirebaseAuth.instance.currentUser?.uid;
  //       final nickname = currentUserId != null
  //           ? (profileProvider.userNicknames[currentUserId] ?? '익명 야구팬')
  //           : '익명 야구팬';
  //       final profileImageUrl = profileProvider.myProfileImage;

  //       final myRanking = currentUserId != null
  //           ? rankProvider.getMyRanking(currentUserId)
  //           : null;
  //       final tierName = myRanking != null
  //           ? QuizSeasonUtils.getTier(myRanking.score)
  //           : 'PROSPECT';

  //       return Container(
  //         width: double.infinity,
  //         padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
  //         decoration: BoxDecoration(
  //           color: selectedTeam.color,
  //           boxShadow: [
  //             BoxShadow(
  //               color: Colors.black.withOpacity(0.1),
  //               blurRadius: 10,
  //               offset: const Offset(0, 4),
  //             ),
  //           ],
  //         ),
  //         child: Row(
  //           children: [
  //             Container(
  //               padding: const EdgeInsets.all(2),
  //               decoration: const BoxDecoration(
  //                 color: WHITE,
  //                 shape: BoxShape.circle,
  //               ),
  //               child: CircleAvatar(
  //                 radius: 18,
  //                 backgroundColor: BACKGROUND_COLOR,
  //                 foregroundImage: profileImageUrl != null
  //                     ? NetworkImage(profileImageUrl)
  //                     : null,
  //                 child: const Icon(Icons.person, color: GRAYSCALE_LABEL_300),
  //               ),
  //             ),
  //             const SizedBox(width: 12),
  //             Column(
  //               crossAxisAlignment: CrossAxisAlignment.start,
  //               children: [
  //                 Row(
  //                   children: [
  //                     Text(
  //                       nickname,
  //                       style: const TextStyle(
  //                         color: WHITE,
  //                         fontSize: 14,
  //                         fontWeight: FontWeight.bold,
  //                       ),
  //                     ),
  //                     const SizedBox(width: 6),
  //                     Container(
  //                       padding: const EdgeInsets.symmetric(
  //                         horizontal: 6,
  //                         vertical: 2,
  //                       ),
  //                       decoration: BoxDecoration(
  //                         color: Colors.white24,
  //                         borderRadius: BorderRadius.circular(4),
  //                       ),
  //                       child: Text(
  //                         tierName,
  //                         style: const TextStyle(
  //                           color: WHITE,
  //                           fontSize: 10,
  //                           fontWeight: FontWeight.bold,
  //                         ),
  //                       ),
  //                     ),
  //                   ],
  //                 ),
  //                 const SizedBox(height: 2),
  //                 Text(
  //                   myRanking != null
  //                       ? '시즌 ${myRanking.rank}위 | ${myRanking.score}점'
  //                       : '시즌 기록 없음',
  //                   style: TextStyle(
  //                     color: WHITE.withOpacity(0.8),
  //                     fontSize: 11,
  //                   ),
  //                 ),
  //               ],
  //             ),
  //             const Spacer(),
  //             _buildSeasonBadge(),
  //           ],
  //         ),
  //       );
  //     },
  //   );
  // }

  Widget _buildMatchCard(BuildContext context, TeamModel selectedTeam) {
    return Consumer3<ScheduleProvider, WeatherProvider, TeamProvider>(
      builder: (context, scheduleProvider, weatherProvider, teamProvider, child) {
        if (!scheduleProvider.loaded) {
          final teamColor = selectedTeam.color;
          return Container(
            width: double.infinity,
            height: 320,
            decoration: BoxDecoration(
              color: BLACK.withOpacity(0.3),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: teamColor.withOpacity(0.2),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: const Center(child: CircularProgressIndicator(color: WHITE)),
          );
        }
        final schedules = scheduleProvider.allSchedules;
        final teamName = selectedTeam.symplename;
        final now = DateTime.now();

        // 1. 응원팀의 모든 경기 필터링
        final myTeamGames = schedules.where((s) {
          return s.homeTeam == teamName ||
              s.homeTeam == selectedTeam.name ||
              s.awayTeam == teamName ||
              s.awayTeam == selectedTeam.name;
        }).toList();

        // 2. 오늘 경기 필터링
        final todayGames = myTeamGames.where((s) {
          return s.dateTimeKst.year == now.year &&
              s.dateTimeKst.month == now.month &&
              s.dateTimeKst.day == now.day;
        }).toList();

        ScheduleModel? activeGame;
        if (todayGames.isNotEmpty) {
          // 오늘 경기가 있다면: LIVE 우선 -> 아직 종료 안 된 경기 우선 -> 시간순
          todayGames.sort((a, b) {
            final aIsLive = a.status == 'LIVE' || a.status == '진행중';
            final bIsLive = b.status == 'LIVE' || b.status == '진행중';
            if (aIsLive && !bIsLive) return -1;
            if (!aIsLive && bIsLive) return 1;

            final aIsEnd =
                a.status == 'FINAL' ||
                a.status == '종료' ||
                a.status == 'PPD' ||
                a.status == '취소';
            final bIsEnd =
                b.status == 'FINAL' ||
                b.status == '종료' ||
                b.status == 'PPD' ||
                b.status == '취소';
            if (!aIsEnd && bIsEnd) return -1;
            if (aIsEnd && !bIsEnd) return 1;

            return a.dateTimeKst.compareTo(b.dateTimeKst);
          });
          activeGame = todayGames.first;
        } else {
          // 오늘 경기가 없다면: 예정된 가장 가까운 미래 경기
          final upcomingGames = myTeamGames.where((s) {
            final isEnd =
                s.status == 'FINAL' ||
                s.status == '종료' ||
                s.status == 'PPD' ||
                s.status == '취소';
            if (isEnd) return false;
            return s.dateTimeKst.isAfter(now);
          }).toList();
          upcomingGames.sort((a, b) => a.dateTimeKst.compareTo(b.dateTimeKst));
          activeGame = upcomingGames.isNotEmpty ? upcomingGames.first : null;
        }

        final isLive =
            activeGame?.status == 'LIVE' || activeGame?.status == '진행중';
        final isFinal =
            activeGame?.status == 'FINAL' || activeGame?.status == '종료';
        final isPpd = activeGame?.status == 'PPD' || activeGame?.status == '취소';

        // 경기 구장 날씨 로드
        final activeWeather = activeGame != null
            ? weatherProvider.getWeatherForStadium(activeGame.stadium)
            : null;
        if (activeGame != null && activeWeather == null) {
          weatherProvider.fetchSingleWeather(activeGame.stadium);
        }

        final homeTeam = activeGame != null
            ? teamProvider.findTeamByName(activeGame.homeTeam)
            : null;
        final awayTeam = activeGame != null
            ? teamProvider.findTeamByName(activeGame.awayTeam)
            : null;
        final teamColor =
            teamProvider.selectedTeam?.color ?? selectedTeam.color;
        final isToday =
            activeGame != null &&
            (activeGame.dateTimeKst.year == now.year &&
                activeGame.dateTimeKst.month == now.month &&
                activeGame.dateTimeKst.day == now.day);

        final bool isMyTeamHome =
            activeGame != null &&
            (activeGame.homeTeam == selectedTeam.symplename ||
                activeGame.homeTeam == selectedTeam.name);

        return GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SchedulePage(teamModel: widget.teamModel),
            ),
          ),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.cardColor,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: context.borderColor),
              boxShadow: [
                BoxShadow(
                  color: BLACK.withValues(alpha: 0.04),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                // 상단 헤더 (LIVE / 오늘의 경기 + 구장 날씨 칩 + 전체 일정)
                Row(
                  children: [
                    if (isLive) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: RED_DANGER_TEXT_50,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'LIVE · ${activeGame?.inning ?? "진행중"}',
                          style: const TextStyle(
                            color: WHITE,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ] else ...[
                      Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: context.isDarkMode
                              ? WHITE.withValues(alpha: 0.14)
                              : teamColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.sports_baseball_rounded,
                          color: context.isDarkMode ? WHITE : teamColor,
                          size: 15,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      isToday ? '오늘의 경기' : '다음 경기 일정',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: context.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    if (activeWeather != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F9FF),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${activeWeather.jikgwanEmoji} ${activeWeather.temp.toStringAsFixed(0)}°C · ${activeWeather.jikgwanLabel}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0369A1),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                SchedulePage(teamModel: selectedTeam),
                          ),
                        );
                      },
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '전체 일정',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: GRAYSCALE_LABEL_500,
                            ),
                          ),
                          SizedBox(width: 2),
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            color: GRAYSCALE_LABEL_400,
                            size: 11,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (activeGame == null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 28),
                    decoration: BoxDecoration(
                      color: BACKGROUND_COLOR,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.sports_baseball_outlined,
                          size: 32,
                          color: GRAYSCALE_LABEL_400,
                        ),
                        SizedBox(height: 8),
                        Text(
                          '예정된 경기가 없습니다',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: GRAYSCALE_LABEL_500,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: context.surfaceAltColor,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // 원정팀 (Away)
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 58,
                                height: 58,
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: context.cardColor,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: context.borderColor,
                                  ),
                                ),
                                child:
                                    (awayTeam != null &&
                                        awayTeam.logoPath.isNotEmpty)
                                    ? Image.asset(
                                        awayTeam.logoPath,
                                        fit: BoxFit.contain,
                                      )
                                    : const Icon(
                                        Icons.sports_baseball,
                                        color: GRAYSCALE_LABEL_400,
                                      ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                activeGame.awayTeam,
                                style: TextStyle(
                                  color: context.textPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const Text(
                                '원정',
                                style: TextStyle(
                                  color: GRAYSCALE_LABEL_400,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // 중앙 스코어 / 경기 시작 시간
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isLive || isFinal) ...[
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '${activeGame.awayScore}',
                                      style: GoogleFonts.bebasNeue(
                                        color: !isMyTeamHome
                                            ? teamColor
                                            : GRAYSCALE_LABEL_700,
                                        fontSize: 36,
                                        fontWeight: FontWeight.bold,
                                        height: 1.0,
                                      ),
                                    ),
                                    const Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 10.0,
                                      ),
                                      child: Text(
                                        ':',
                                        style: TextStyle(
                                          color: GRAYSCALE_LABEL_300,
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      '${activeGame.homeScore}',
                                      style: GoogleFonts.bebasNeue(
                                        color: isMyTeamHome
                                            ? teamColor
                                            : GRAYSCALE_LABEL_700,
                                        fontSize: 36,
                                        fontWeight: FontWeight.bold,
                                        height: 1.0,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isLive
                                        ? RED_DANGER_TEXT_50
                                        : GRAYSCALE_LABEL_600,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    isLive
                                        ? (activeGame.inning ?? 'LIVE')
                                        : '경기 종료',
                                    style: const TextStyle(
                                      color: WHITE,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  activeGame.stadium,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: GRAYSCALE_LABEL_500,
                                  ),
                                ),
                                if (activeGame.gameType.trim().isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 7,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: context.isDarkMode
                                          ? WHITE.withValues(alpha: 0.14)
                                          : teamColor.withValues(alpha: 0.10),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      activeGame.gameType.trim(),
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: context.isDarkMode
                                            ? WHITE
                                            : teamColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ] else if (isPpd) ...[
                                Text(
                                  'VS',
                                  style: GoogleFonts.bebasNeue(
                                    color: GRAYSCALE_LABEL_400,
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: GRAYSCALE_LABEL_500,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    '경기 취소',
                                    style: TextStyle(
                                      color: WHITE,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  activeGame.stadium,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: GRAYSCALE_LABEL_500,
                                  ),
                                ),
                                if (activeGame.gameType.trim().isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 7,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: context.isDarkMode
                                          ? WHITE.withValues(alpha: 0.14)
                                          : teamColor.withValues(alpha: 0.10),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      activeGame.gameType.trim(),
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: context.isDarkMode
                                            ? WHITE
                                            : teamColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ] else ...[
                                Text(
                                  DateFormat(
                                    'HH:mm',
                                  ).format(activeGame.dateTimeKst),
                                  style: GoogleFonts.bebasNeue(
                                    color: context.isDarkMode
                                        ? WHITE
                                        : teamColor,
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    height: 1.0,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  DateFormat(
                                    'MM.dd (E)',
                                    'ko',
                                  ).format(activeGame.dateTimeKst),
                                  style: TextStyle(
                                    color: context.textPrimary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  activeGame.stadium,
                                  style: TextStyle(
                                    color: context.textMuted,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (activeGame.gameType.trim().isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 7,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: context.isDarkMode
                                          ? WHITE.withValues(alpha: 0.14)
                                          : teamColor.withValues(alpha: 0.10),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      activeGame.gameType.trim(),
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: context.isDarkMode
                                            ? WHITE
                                            : teamColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ],
                          ),
                        ),

                        // 홈팀 (Home)
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 58,
                                height: 58,
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: context.cardColor,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: context.borderColor,
                                  ),
                                ),
                                child:
                                    (homeTeam != null &&
                                        homeTeam.logoPath.isNotEmpty)
                                    ? Image.asset(
                                        homeTeam.logoPath,
                                        fit: BoxFit.contain,
                                      )
                                    : const Icon(
                                        Icons.sports_baseball,
                                        color: GRAYSCALE_LABEL_400,
                                      ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                activeGame.homeTeam,
                                style: TextStyle(
                                  color: context.textPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const Text(
                                '홈',
                                style: TextStyle(
                                  color: GRAYSCALE_LABEL_400,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),

            // child: Stack(
            //   children: [
            //     Padding(
            //       padding: const EdgeInsets.symmetric(
            //         horizontal: 20.0,
            //         vertical: 16.0,
            //       ),
            //       child: Row(
            //         children: [
            //           Expanded(
            //             child: Column(
            //               mainAxisAlignment: MainAxisAlignment.center,
            //               crossAxisAlignment: CrossAxisAlignment.start,
            //               children: [
            //                 Row(
            //                   children: [
            //                     Container(
            //                       padding: const EdgeInsets.symmetric(
            //                         horizontal: 8,
            //                         vertical: 4,
            //                       ),
            //                       decoration: BoxDecoration(
            //                         color: isLive
            //                             ? RED_DANGER_TEXT_50
            //                             : Colors.white24,
            //                         borderRadius: BorderRadius.circular(6),
            //                       ),
            //                       child: Text(
            //                         isLive ? 'LIVE' : 'UPCOMING MATCH',
            //                         style: const TextStyle(
            //                           color: WHITE,
            //                           fontSize: 11,
            //                           fontWeight: FontWeight.bold,
            //                         ),
            //                       ),
            //                     ),
            //                     if (weather != null) ...[
            //                       const SizedBox(width: 8),
            //                       Container(
            //                         padding: const EdgeInsets.symmetric(
            //                           horizontal: 8,
            //                           vertical: 4,
            //                         ),
            //                         decoration: BoxDecoration(
            //                           color: Colors.black.withOpacity(0.2),
            //                           borderRadius: BorderRadius.circular(6),
            //                         ),
            //                         child: Row(
            //                           children: [
            //                             const SizedBox(width: 4),
            //                             Text(
            //                               '${weather.temp.toStringAsFixed(1)}°C (${weather.description})',
            //                               style: const TextStyle(
            //                                 color: WHITE,
            //                                 fontSize: 10,
            //                                 fontWeight: FontWeight.w600,
            //                               ),
            //                             ),
            //                           ],
            //                         ),
            //                       ),
            //                     ],
            //                   ],
            //                 ),
          ),
        );
      },
    );
  }

  // Map<String, dynamic> _getWeatherStyle(String condition) {
  //   switch (condition.toLowerCase()) {
  //     case 'clear':
  //       return {
  //         'icon': CupertinoIcons.sun_max_fill,
  //         'color': Colors.orangeAccent,
  //       };
  //     case 'clouds':
  //       return {'icon': CupertinoIcons.cloud_fill, 'color': Colors.blueGrey};
  //     case 'rain':
  //     case 'drizzle':
  //       return {'icon': CupertinoIcons.cloud_rain_fill, 'color': Colors.blue};
  //     case 'thunderstorm':
  //       return {
  //         'icon': CupertinoIcons.cloud_bolt_rain_fill,
  //         'color': Colors.amber,
  //       };
  //     case 'snow':
  //       return {'icon': CupertinoIcons.snow, 'color': Colors.lightBlue};
  //     default:
  //       return {
  //         'icon': CupertinoIcons.cloud_sun_fill,
  //         'color': Colors.blueGrey,
  //       };
  //   }
  // }

  // /// 직관지수 점수 → 컬러 매핑
  // Color _jikgwanColor(int score) {
  //   if (score >= 85) return const Color(0xFF22C55E); // 최상 – 초록
  //   if (score >= 70) return const Color(0xFF84CC16); // 좋음 – 연두
  //   if (score >= 50) return const Color(0xFFF59E0B); // 보통 – 주황
  //   if (score >= 30) return const Color(0xFFEF4444); // 나쁨 – 빨강
  //   return const Color(0xFF6B21A8); // 매우나쁨 – 보라
  // }

  // String _shortenStadiumName(String original) {
  //   if (original.contains('잠실')) return '잠실';
  //   if (original.contains('고척')) return '고척';
  //   if (original.contains('인천') || original.contains('랜더스필드')) return '랜더스필드';
  //   if (original.contains('수원') || original.contains('위즈파크')) return '위즈파크';
  //   if (original.contains('대전') ||
  //       original.contains('이글스파크') ||
  //       original.contains('볼파크'))
  //     return '한화생명볼파크';
  //   if (original.contains('광주') || original.contains('챔피언스')) return '챔피언스필드';
  //   if (original.contains('대구') || original.contains('라이온즈')) return '라이온즈파크';
  //   if (original.contains('사직')) return '사직';
  //   if (original.contains('창원') || original.contains('NC')) return 'NC파크';
  //   return original;
  // }

  // Widget _buildAllStadiumsWeather(BuildContext context) {
  //   return Consumer2<ScheduleProvider, WeatherProvider>(
  //     builder: (context, scheduleProvider, weatherProvider, child) {
  //       // 오늘 날짜의 경기 구장만 필터링
  //       final now = DateTime.now();
  //       final todayStadiums = scheduleProvider.allSchedules
  //           .where((s) {
  //             final d = s.dateTimeKst;
  //             return d.year == now.year &&
  //                 d.month == now.month &&
  //                 d.day == now.day &&
  //                 s.status != 'PPD';
  //           })
  //           .map((s) => s.stadium)
  //           .toSet() // 중복 구장 제거 (더블헤더 등)
  //           .toList();
  //
  //       if (todayStadiums.isEmpty) {
  //         return const SizedBox.shrink();
  //       }
  //
  //       // 오늘 경기 구장에 해당하는 날씨만 조회 / 없으면 fetch 요청
  //       final weathers = todayStadiums
  //           .map((stadium) {
  //             final w = weatherProvider.getWeatherForStadium(stadium);
  //             if (w == null) {
  //               weatherProvider.fetchSingleWeather(stadium);
  //             }
  //             return w;
  //           })
  //           .whereType<StadiumWeather>()
  //           .toList(); // null 제거
  //
  //       if (weatherProvider.isLoading && weathers.isEmpty) {
  //         return const SizedBox(
  //           height: 90,
  //           child: Center(child: CircularProgressIndicator(color: BUTTON)),
  //         );
  //       }
  //
  //       if (weathers.isEmpty) {
  //         return const SizedBox.shrink();
  //       }
  //
  //       return Column(
  //         crossAxisAlignment: CrossAxisAlignment.start,
  //         children: [
  //           Text(
  //             '오늘 경기 구장 날씨 ⛅',
  //             style: GoogleFonts.gothicA1(
  //               fontSize: 16,
  //               fontWeight: FontWeight.w800,
  //               color: GRAYSCALE_LABEL_900,
  //               letterSpacing: -0.5,
  //             ),
  //           ),
  //           const SizedBox(height: 12),
  //           SizedBox(
  //             height: 118,
  //             child: ListView.builder(
  //               scrollDirection: Axis.horizontal,
  //               itemCount: weathers.length,
  //               itemBuilder: (context, index) {
  //                 final weather = weathers[index];
  //                 final style = _getWeatherStyle(weather.condition);
  //                 final score = weather.jikgwanScore;
  //                 final scoreColor = _jikgwanColor(score);
  //
  //                 return GestureDetector(
  //                   onTap: () {
  //                     Navigator.push(
  //                       context,
  //                       MaterialPageRoute(
  //                         builder: (context) =>
  //                             WeatherDetailPage(weather: weather),
  //                       ),
  //                     );
  //                   },
  //                   child: Container(
  //                     width: 140,
  //                     margin: const EdgeInsets.only(
  //                       right: 12,
  //                       bottom: 4,
  //                       top: 4,
  //                     ),
  //                     padding: const EdgeInsets.symmetric(
  //                       horizontal: 12,
  //                       vertical: 10,
  //                     ),
  //                     decoration: BoxDecoration(
  //                       color: WHITE,
  //                       borderRadius: BorderRadius.circular(18),
  //                       border: Border.all(
  //                         color: scoreColor.withValues(alpha: 0.35),
  //                         width: 1.5,
  //                       ),
  //                       boxShadow: [
  //                         BoxShadow(
  //                           color: scoreColor.withValues(alpha: 0.08),
  //                           blurRadius: 10,
  //                           offset: const Offset(0, 4),
  //                         ),
  //                       ],
  //                     ),
  //                     child: Column(
  //                       crossAxisAlignment: CrossAxisAlignment.start,
  //                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
  //                       children: [
  //                         // 구장명 + 날씨 아이콘
  //                         Row(
  //                           mainAxisAlignment: MainAxisAlignment.spaceBetween,
  //                           children: [
  //                             Expanded(
  //                               child: Text(
  //                                 _shortenStadiumName(weather.stadiumName),
  //                                 style: const TextStyle(
  //                                   fontSize: 11,
  //                                   fontWeight: FontWeight.bold,
  //                                   color: GRAYSCALE_LABEL_700,
  //                                 ),
  //                                 maxLines: 1,
  //                                 overflow: TextOverflow.ellipsis,
  //                               ),
  //                             ),
  //                             Icon(
  //                               style['icon'] as IconData,
  //                               color: style['color'] as Color,
  //                               size: 16,
  //                             ),
  //                           ],
  //                         ),
  //                         // 직관지수 점수 + 등급
  //                         Row(
  //                           crossAxisAlignment: CrossAxisAlignment.end,
  //                           children: [
  //                             Text(
  //                               '$score',
  //                               style: TextStyle(
  //                                 fontSize: 26,
  //                                 fontWeight: FontWeight.w900,
  //                                 color: scoreColor,
  //                                 height: 1.0,
  //                               ),
  //                             ),
  //                             const SizedBox(width: 4),
  //                             Padding(
  //                               padding: const EdgeInsets.only(bottom: 2),
  //                               child: Text(
  //                                 weather.jikgwanEmoji + weather.jikgwanLabel,
  //                                 style: TextStyle(
  //                                   fontSize: 11,
  //                                   fontWeight: FontWeight.w700,
  //                                   color: scoreColor,
  //                                 ),
  //                               ),
  //                             ),
  //                           ],
  //                         ),
  //                         // 점수 바
  //                         ClipRRect(
  //                           borderRadius: BorderRadius.circular(4),
  //                           child: LinearProgressIndicator(
  //                             value: score / 100,
  //                             minHeight: 4,
  //                             backgroundColor: GRAYSCALE_LABEL_200,
  //                             valueColor: AlwaysStoppedAnimation<Color>(
  //                               scoreColor,
  //                             ),
  //                           ),
  //                         ),
  //                         // 기온 + 강수확률
  //                         Row(
  //                           mainAxisAlignment: MainAxisAlignment.spaceBetween,
  //                           children: [
  //                             Text(
  //                               '${weather.temp.toStringAsFixed(1)}°C',
  //                               style: const TextStyle(
  //                                 fontSize: 11,
  //                                 fontWeight: FontWeight.w600,
  //                                 color: GRAYSCALE_LABEL_700,
  //                               ),
  //                             ),
  //                             Text(
  //                               '💧${(weather.rainChance * 100).toInt()}%',
  //                               style: const TextStyle(
  //                                 fontSize: 11,
  //                                 fontWeight: FontWeight.w600,
  //                                 color: GRAYSCALE_LABEL_500,
  //                               ),
  //                             ),
  //                           ],
  //                         ),
  //                       ],
  //                     ),
  //                   ),
  //                 );
  //               },
  //             ),
  //           ),
  //         ],
  //       );
  //     },
  //   );
  // }

  Widget _buildSectionHeader(String title, {VoidCallback? onSeeAll}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: context.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
          if (onSeeAll != null)
            GestureDetector(
              onTap: onSeeAll,
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '더보기',
                    style: TextStyle(
                      color: GRAYSCALE_LABEL_500,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                  SizedBox(width: 3),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: GRAYSCALE_LABEL_500,
                    size: 11,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMeetupSection(BuildContext context, TeamModel selectedTeam) {
    return Consumer<MeetupProvider>(
      builder: (context, meetupProvider, child) {
        final recruitingMeetups = meetupProvider.meetups
            .where((m) => !m.isFull)
            .take(5)
            .toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(
              '🤝 같이 보면 더 즐거운 직관',
              onSeeAll: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => MeetupPage()),
                );
              },
            ),
            const SizedBox(height: 12),
            if (recruitingMeetups.isEmpty)
              _buildEmptyCard('현재 모집 중인 직관 모임이 없습니다')
            else
              SizedBox(
                height: 212,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  clipBehavior: Clip.none,
                  itemCount: recruitingMeetups.length,
                  itemBuilder: (context, index) => _buildMeetupMiniCard(
                    context,
                    recruitingMeetups[index],
                    selectedTeam,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildFeedSection(BuildContext context, TeamModel selectedTeam) {
    return Consumer<FeedProvider>(
      builder: (context, feedProvider, _) {
        final recentPosts = feedProvider.posts.take(5).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(
              '🔥 실시간 팬들의 이야기',
              onSeeAll: () => widget.onTabTab(1),
            ),
            const SizedBox(height: 12),
            if (recentPosts.isEmpty)
              _buildEmptyCard('최근 게시물이 존재하지 않습니다')
            else
              SizedBox(
                height: 238,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  clipBehavior: Clip.none,
                  itemCount: recentPosts.length,
                  itemBuilder: (context, index) =>
                      _buildFeedHighlightCard(context, recentPosts[index]),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildFeedHighlightCard(BuildContext context, PostModel post) {
    return Consumer<ProfileProvider>(
      builder: (context, profileProvider, _) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) {
            profileProvider.subscribeUserProfile(post.userId);
          }
        });

        final authorProfileUrl = profileProvider.userProfiles[post.userId];
        final authorName =
            profileProvider.userNicknames[post.userId] ?? post.userNickName;
        final hasMedia = post.mediaUrls.isNotEmpty;
        final isVideo = hasMedia && MediaUtils.isVideoFromPost(post, 0);

        return GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => FeedDetailPage(post: post)),
          ),
          child: Container(
            width: 210,
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.cardColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: context.borderColor),
              boxShadow: [
                BoxShadow(
                  color: BLACK.withValues(alpha: 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hasMedia) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: double.infinity,
                      height: 122,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          isVideo
                              ? IgnorePointer(
                                  child: NetworkVideoPlayer(
                                    videoUrl: post.mediaUrls.first,
                                    width: double.infinity,
                                    height: 122,
                                    fit: BoxFit.cover,
                                    autoPlay: true,
                                    muted: true,
                                    showControls: false,
                                  ),
                                )
                              : Image.network(
                                  post.mediaUrls.first,
                                  width: double.infinity,
                                  height: 122,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      Container(
                                        color: GRAYSCALE_LABEL_100,
                                        alignment: Alignment.center,
                                        child: const Icon(
                                          Icons.broken_image_outlined,
                                          color: GRAYSCALE_LABEL_400,
                                        ),
                                      ),
                                ),
                          if (isVideo)
                            Positioned(
                              right: 8,
                              top: 8,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.6),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Icon(
                                  Icons.videocam_rounded,
                                  color: WHITE,
                                  size: 14,
                                ),
                              ),
                            )
                          else if (post.mediaUrls.length > 1)
                            Positioned(
                              right: 8,
                              bottom: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.55),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '1/${post.mediaUrls.length}',
                                  style: const TextStyle(
                                    color: WHITE,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                Row(
                  children: [
                    CircleAvatar(
                      radius: 13,
                      backgroundColor: GRAYSCALE_LABEL_200,
                      foregroundImage: authorProfileUrl != null
                          ? NetworkImage(authorProfileUrl)
                          : null,
                      child: const Icon(
                        Icons.person,
                        size: 13,
                        color: GRAYSCALE_LABEL_600,
                      ),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        authorName,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: context.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      DateFormat('M.d').format(post.createdAt),
                      style: TextStyle(fontSize: 11, color: context.textMuted),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: Text(
                    post.text,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: context.textSecondary,
                    ),
                    maxLines: hasMedia ? 2 : 5,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Widget _buildStadiumSection(BuildContext context, TeamModel selectedTeam) {
  //   final foodStorePage = _getFoodStorePage(selectedTeam.stadium);
  //   return Column(
  //     crossAxisAlignment: CrossAxisAlignment.start,
  //     children: [
  //       _buildSectionHeader(
  //         '${selectedTeam.stadium} 현장 가이드 🌭',
  //         onSeeAll: foodStorePage != null
  //             ? () => Navigator.push(
  //                 context,
  //                 MaterialPageRoute(builder: (context) => foodStorePage),
  //               )
  //             : null,
  //       ),
  //       const SizedBox(height: 12),
  //       _buildFoodStore(selectedTeam),
  //     ],
  //   );
  // }

  Widget _buildEmptyCard(String message) {
    return Container(
      width: double.infinity,
      height: 100,
      decoration: BoxDecoration(
        color: WHITE,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: GRAYSCALE_LABEL_300.withOpacity(0.3)),
      ),
      child: Center(
        child: Text(
          message,
          style: TextStyle(color: GRAYSCALE_LABEL_500, fontSize: 13),
        ),
      ),
    );
  }

  Widget _buildSecondaryButton({
    required String label,
    required VoidCallback onPressed,
  }) {
    return InkWell(
      onTap: onPressed,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: WHITE,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: GRAYSCALE_LABEL_300),
        ),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: GRAYSCALE_LABEL_700,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMeetupMiniCard(
    BuildContext context,
    MeetupModel meetup,
    TeamModel selectedTeam,
  ) {
    final teamProvider = context.read<TeamProvider>();
    final homeTeam = teamProvider.findTeamByName(meetup.homeTeam);
    final awayTeam = teamProvider.findTeamByName(meetup.awayTeam);
    final currentCount = meetup.participants.length;
    final maxCount = meetup.maxParticipants;
    final fillRatio = maxCount > 0 ? currentCount / maxCount : 0.0;
    final gameDate = DateTime.tryParse(meetup.gameDate);
    final teamColor = teamProvider.selectedTeam?.color ?? selectedTeam.color;
    final readableAccent = context.readableColor(teamColor);
    final isAlmostFull = maxCount > 0 && (maxCount - currentCount) == 1;
    final statusColor = isAlmostFull
        ? (context.isDarkMode
              ? const Color(0xFFFBBF24)
              : const Color(0xFFD97706))
        : readableAccent;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MeetupDetailPage(meetup: meetup),
        ),
      ),
      child: Container(
        width: 228,
        margin: const EdgeInsets.only(right: 12),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: context.cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: context.borderColor),
          boxShadow: [
            BoxShadow(
              color: BLACK.withValues(alpha: 0.05),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            // 왼쪽 팀컬러 액센트 바
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Container(
                width: 4,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [teamColor, teamColor.withValues(alpha: 0.35)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),

            // 배경 로고 (희미한 워터마크)
            Positioned(
              right: -16,
              bottom: -12,
              child: Opacity(
                opacity: 0.06,
                child: homeTeam?.logoPath != null
                    ? Image.asset(homeTeam!.logoPath, width: 96, height: 96)
                    : const SizedBox.shrink(),
              ),
            ),

            // 본문
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 13, 13, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 팀 매치업 로고 (원정 vs 홈) + 상태 배지
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _buildMiniTeamBadge(context, awayTeam),
                      const SizedBox(width: 5),
                      Text(
                        'VS',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          fontStyle: FontStyle.italic,
                          color: context.textMuted,
                        ),
                      ),
                      const SizedBox(width: 5),
                      _buildMiniTeamBadge(context, homeTeam),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(
                            alpha: context.isDarkMode ? 0.16 : 0.10,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: statusColor.withValues(
                              alpha: context.isDarkMode ? 0.38 : 0.28,
                            ),
                          ),
                        ),
                        child: Text(
                          isAlmostFull ? '마감임박' : '모집중',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: statusColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // 날짜 & 시간
                  if (gameDate != null)
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today_rounded,
                          size: 11,
                          color: readableAccent,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${DateFormat('M.d (E)', 'ko').format(gameDate)} · ${meetup.gameTime}',
                          style: TextStyle(
                            fontSize: 11,
                            color: readableAccent,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 5),

                  // 제목
                  Expanded(
                    child: Text(
                      meetup.title,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: context.textPrimary,
                        height: 1.32,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),

                  // 응원팀 정보
                  if (meetup.myTeam.isNotEmpty) ...[
                    Builder(
                      builder: (context) {
                        final cheerTeam = teamProvider.findTeamByName(
                          meetup.myTeam,
                        );
                        return Row(
                          children: [
                            const Icon(
                              Icons.favorite_rounded,
                              size: 11,
                              color: Color(0xFFF43F5E),
                            ),
                            const SizedBox(width: 4),
                            if (cheerTeam?.logoPath != null) ...[
                              Image.asset(
                                cheerTeam!.logoPath,
                                width: 14,
                                height: 14,
                              ),
                              const SizedBox(width: 4),
                            ],
                            Expanded(
                              child: Text(
                                '${meetup.myTeam} 팬 모집',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: context.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                  ],

                  // 인원 바
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: fillRatio.clamp(0.0, 1.0),
                            backgroundColor: context.surfaceAltColor,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              statusColor,
                            ),
                            minHeight: 6,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$currentCount/$maxCount명',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: context.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // 경기장 (하단 구분선)
                  Container(
                    padding: const EdgeInsets.only(top: 7),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(color: context.dividerColor, width: 1),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 12,
                          color: context.textMuted,
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            meetup.stadium,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: context.textMuted,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniTeamBadge(BuildContext context, TeamModel? team) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: context.surfaceAltColor,
        shape: BoxShape.circle,
        border: Border.all(color: context.borderColor, width: 1),
      ),
      child: team?.logoPath != null
          ? Padding(
              padding: const EdgeInsets.all(4),
              child: Image.asset(team!.logoPath, fit: BoxFit.contain),
            )
          : Icon(Icons.sports_baseball, color: context.textMuted, size: 15),
    );
  }

  Widget _buildVideoItem(
    BuildContext context,
    Video video, {
    bool isLarge = false,
  }) {
    return GestureDetector(
      onTap: () {
        final youtubeUrl = 'https://www.youtube.com/watch?v=${video.id}';
        launchUrl(Uri.parse(youtubeUrl), mode: LaunchMode.externalApplication);
      },
      child: Container(
        height: isLarge ? 180 : 100,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              Positioned.fill(
                child: Image.network(
                  video.thumbnailUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: GRAYSCALE_LABEL_200,
                    child: const Icon(Icons.error_outline, color: Colors.grey),
                  ),
                ),
              ),
              if (isLarge)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.3),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              Center(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.8),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.play_arrow_rounded,
                    size: isLarge ? 32 : 24,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Widget? _getFoodStorePage(String stadium) {
  //   if (stadium.contains('잠실')) return const JamsilstorePage();
  //   if (stadium.contains('사직')) return const GiantsstroePage();
  //   if (stadium.contains('광주')) return const ChampionsfieldstorePage();
  //   if (stadium.contains('수원')) return const WizparkstorePage();
  //   if (stadium.contains('창원')) return const NcparkstorePage();
  //   if (stadium.contains('대전')) return const BallparkstorePage();
  //   if (stadium.contains('대구')) return const LionsparksstorePage();
  //   if (stadium.contains('문학')) return const LandersFieldStorePage();
  //   if (stadium.contains('고척')) return const GocheokstorePage();
  //   return null;
  // }

  // Widget _buildSeasonBadge() {
  //   final seasonId = QuizSeasonUtils.getCurrentSeasonId();
  //   final seasonLabel = QuizSeasonUtils.getSeasonLabel(seasonId);
  //   return Container(
  //     padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
  //     decoration: BoxDecoration(
  //       color: Colors.orange.shade50,
  //       borderRadius: BorderRadius.circular(20),
  //       border: Border.all(color: Colors.orange.shade200),
  //     ),
  //     child: Row(
  //       mainAxisSize: MainAxisSize.min,
  //       children: [
  //         Icon(Icons.flash_on, size: 12, color: Colors.orange.shade700),
  //         const SizedBox(width: 4),
  //         Text(
  //           seasonLabel,
  //           style: TextStyle(
  //             fontSize: 10,
  //             fontWeight: FontWeight.bold,
  //             color: Colors.orange.shade700,
  //           ),
  //         ),
  //       ],
  //     ),
  //   );
  // }

  // Widget _buildFoodStore(TeamModel selectedTeam) {
  //   return Consumer<FoodStoreProvider>(
  //     builder: (context, fsp, child) {
  //       final foodStores = fsp.getStore(selectedTeam.stadium);
  //       final displayStores = foodStores.take(5).toList();
  //       if (displayStores.isEmpty) {
  //         return const Center(child: Text('해당 경기장의 푸드존 정보가 없습니다.'));
  //       }
  //       return SizedBox(
  //         height: 200,
  //         child: ListView.builder(
  //           scrollDirection: Axis.horizontal,
  //           itemCount: displayStores.length,
  //           itemBuilder: (context, index) {
  //             final store = displayStores[index];
  //             return Container(
  //               width: 150,
  //               margin: const EdgeInsets.only(right: 12),
  //               child: Card(
  //                 color: WHITE,
  //                 child: Padding(
  //                   padding: const EdgeInsets.all(10.0),
  //                   child: Column(
  //                     crossAxisAlignment: CrossAxisAlignment.start,
  //                     children: [
  //                       if (store.storePhoto != null)
  //                         ClipRRect(
  //                           borderRadius: BorderRadius.circular(8),
  //                           child: Image.asset(
  //                             store.storePhoto!,
  //                             height: 100,
  //                             width: double.infinity,
  //                             fit: BoxFit.cover,
  //                           ),
  //                         )
  //                       else
  //                         ClipRRect(
  //                           borderRadius: BorderRadius.circular(8),
  //                           child: Container(
  //                             width: double.infinity,
  //                             height: 100,
  //                             color: GRAYSCALE_LABEL_300,
  //                             child: const Icon(Icons.restaurant_menu),
  //                           ),
  //                         ),
  //                       const SizedBox(height: 8),
  //                       Text(
  //                         store.storeName,
  //                         style: const TextStyle(
  //                           fontWeight: FontWeight.bold,
  //                           fontSize: 14,
  //                         ),
  //                         maxLines: 1,
  //                         overflow: TextOverflow.ellipsis,
  //                       ),
  //                       const SizedBox(height: 4),
  //                       Text(
  //                         store.type,
  //                         style: const TextStyle(
  //                           fontSize: 12,
  //                           color: GRAYSCALE_LABEL_500,
  //                         ),
  //                       ),
  //                       const SizedBox(height: 2),
  //                       Text(
  //                         store.location,
  //                         style: const TextStyle(
  //                           fontSize: 11,
  //                           color: GRAYSCALE_LABEL_400,
  //                         ),
  //                         maxLines: 2,
  //                         overflow: TextOverflow.ellipsis,
  //                       ),
  //                     ],
  //                   ),
  //                 ),
  //               ),
  //             );
  //           },
  //         ),
  //       );
  //     },
  //   );
  // }

  Widget _buildIntutionRecord() {
    return ChangeNotifierProvider(
      create: (_) =>
          IntutionRecordListProvider()..subscribe(autoSetYear: false),
      child: Consumer2<IntutionRecordListProvider, TeamProvider>(
        builder: (context, ip, tp, child) {
          final teamColor = tp.selectedTeam?.color ?? widget.selectedTeam.color;
          if (ip.isLoading) {
            return Container(
              width: double.infinity,
              height: 170,
              decoration: BoxDecoration(
                color: WHITE,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Center(child: CircularProgressIndicator(color: teamColor)),
            );
          }

          final items = ip.records;
          int wins = 0;
          int losses = 0;
          int draws = 0;
          int? parseScore(dynamic v) => v is int ? v : int.tryParse('$v');

          final sortedChronological = List<Map<String, dynamic>>.from(items)
            ..sort((a, b) {
              final da = (a['date'] as String?) ?? '';
              final db = (b['date'] as String?) ?? '';
              final cmp = da.compareTo(db);
              if (cmp != 0) return cmp;
              final ta = (a['time'] as String?) ?? '';
              final tb = (b['time'] as String?) ?? '';
              return ta.compareTo(tb);
            });

          for (final d in sortedChronological) {
            final int? my = parseScore(d['myScore']);
            final int? opp = parseScore(d['opponentScore']);
            if (my != null && opp != null) {
              if (my > opp) {
                wins++;
              } else if (my < opp) {
                losses++;
              } else {
                draws++;
              }
            }
          }

          final int totalGames = items.length;
          final double winRate = totalGames > 0 ? (wins / totalGames) * 100 : 0;

          int currentWinStreak = 0;
          for (int i = sortedChronological.length - 1; i >= 0; i--) {
            final r = sortedChronological[i];
            final my = parseScore(r['myScore']);
            final opp = parseScore(r['opponentScore']);
            if (my == null || opp == null) continue;
            if (my > opp) {
              currentWinStreak++;
            } else {
              break;
            }
          }

          String fairyBadge = '⚾ 설레는 첫 직관 대기 중';
          if (totalGames > 0) {
            if (currentWinStreak >= 3) {
              fairyBadge = '🔥 ${currentWinStreak}연승 폭주 승리요정';
            } else if (totalGames >= 3 && winRate >= 70) {
              fairyBadge = '🧚 확신의 승리요정';
            } else if (winRate == 100) {
              fairyBadge = '✨ 백전백승 승리요정';
            } else if (totalGames >= 5 && winRate >= 55) {
              fairyBadge = '⚾ 든든한 승리 수호신';
            } else if (totalGames >= 10 && winRate >= 50) {
              fairyBadge = '🏟️ 야구장 출근도장 승요';
            } else if (winRate >= 50) {
              fairyBadge = '🍀 기운 좋은 직관러';
            } else {
              fairyBadge = '🕯️ 반등을 노리는 직관러';
            }
          }

          final recent5 = sortedChronological.length > 5
              ? sortedChronological.sublist(sortedChronological.length - 5)
              : sortedChronological;

          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.cardColor,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: context.borderColor),
              boxShadow: [
                BoxShadow(
                  color: BLACK.withValues(alpha: 0.04),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 상단 헤더 (타이틀 + 승리요정 칭호 뱃지 + 리포트 보기)
                Row(
                  children: [
                    Text(
                      '나의 직관 리포트',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: context.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color:
                            ((context.isDarkMode &&
                                        teamColor.computeLuminance() < 0.22)
                                    ? ACCENT_CORAL
                                    : teamColor)
                                .withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        fairyBadge,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color:
                              (context.isDarkMode &&
                                  teamColor.computeLuminance() < 0.22)
                              ? ACCENT_CORAL
                              : teamColor,
                        ),
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const IntutionTabBar(),
                          ),
                        );
                      },
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '리포트 보기',
                            style: TextStyle(
                              color: GRAYSCALE_LABEL_500,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(width: 2),
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            color: GRAYSCALE_LABEL_400,
                            size: 11,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // 중단 요약 박스 (승률 & 전적 + 최근 5경기 흐름 도트)
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const IntutionTabBar(),
                      ),
                    );
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: context.surfaceAltColor,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: totalGames == 0
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '아직 기록된 직관 경기가 없어요',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: context.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '티켓 사진 한 장으로 좌석과 경기를 자동 기록해보세요!',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: context.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                              Icon(
                                CupertinoIcons.ticket_fill,
                                color: context.textMuted,
                                size: 22,
                              ),
                            ],
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    '통산 직관 승률',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: GRAYSCALE_LABEL_500,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.baseline,
                                    textBaseline: TextBaseline.alphabetic,
                                    children: [
                                      Text(
                                        '${winRate.toStringAsFixed(0)}%',
                                        style: GoogleFonts.bebasNeue(
                                          fontSize: 30,
                                          fontWeight: FontWeight.bold,
                                          color:
                                              (context.isDarkMode &&
                                                  teamColor.computeLuminance() <
                                                      0.22)
                                              ? ACCENT_CORAL
                                              : teamColor,
                                          height: 1.0,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '${totalGames}전 ${wins}승 ${draws}무 ${losses}패',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: context.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '최근 5경기 흐름',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: context.textMuted,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: recent5.asMap().entries.map((e) {
                                      final isLatest =
                                          e.key == recent5.length - 1;
                                      final my = parseScore(e.value['myScore']);
                                      final opp = parseScore(
                                        e.value['opponentScore'],
                                      );
                                      final isDark = context.isDarkMode;
                                      String label = '무';
                                      Color dotFill = isDark
                                          ? const Color(0xFF64748B)
                                          : GRAYSCALE_LABEL_500;
                                      Color dotText = isDark
                                          ? const Color(0xFF94A3B8)
                                          : GRAYSCALE_LABEL_500;
                                      if (my != null && opp != null) {
                                        if (my > opp) {
                                          label = '승';
                                          dotFill = isDark
                                              ? const Color(0xFF2563EB)
                                              : BUTTON;
                                          dotText = isDark
                                              ? const Color(0xFF60A5FA)
                                              : BUTTON;
                                        } else if (my < opp) {
                                          label = '패';
                                          dotFill = isDark
                                              ? const Color(0xFFEF4444)
                                              : Colors.redAccent;
                                          dotText = isDark
                                              ? const Color(0xFFF87171)
                                              : Colors.redAccent;
                                        }
                                      }
                                      return Container(
                                        width: 22,
                                        height: 22,
                                        margin: const EdgeInsets.only(left: 4),
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: isLatest
                                              ? dotFill
                                              : dotText.withValues(
                                                  alpha: isDark ? 0.20 : 0.14,
                                                ),
                                          border: isLatest
                                              ? null
                                              : Border.all(
                                                  color: dotText.withValues(
                                                    alpha: isDark ? 0.40 : 0.25,
                                                  ),
                                                  width: 0.8,
                                                ),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Text(
                                          label,
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: isLatest ? WHITE : dotText,
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ),
                            ],
                          ),
                  ),
                ),

                const SizedBox(height: 10),

                // 하단 원탭 퀵 액션 버튼 (스마트 티켓 스캔 / 직관 직접 기록)
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChangeNotifierProvider(
                                create: (ctx) => TicketScanProvider(
                                  scheduleProvider: ctx
                                      .read<ScheduleProvider>(),
                                ),
                                child: const TickerCameraScanPage(),
                              ),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: teamColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.document_scanner_outlined,
                                color: WHITE,
                                size: 15,
                              ),
                              SizedBox(width: 6),
                              Text(
                                '스마트 티켓 스캔',
                                style: TextStyle(
                                  color: WHITE,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const IntutionRecordUploadPage(
                                navigateToListOnSave: true,
                              ),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: context.surfaceAltColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: context.borderColor),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.edit_note_rounded,
                                color: context.textPrimary,
                                size: 17,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                '직관 직접 기록',
                                style: TextStyle(
                                  color: context.textPrimary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMiniStat(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: GRAYSCALE_LABEL_500,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 0),
        Text(
          value,
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}
