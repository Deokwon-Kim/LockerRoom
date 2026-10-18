import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:lockerroom/bottom_tab_bar/intution_tab_bar.dart';
import 'package:lockerroom/bottom_tab_bar/quiz_tab_bar.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/model/meetup_model.dart';
import 'package:lockerroom/model/post_model.dart';
// import 'package:lockerroom/model/stadium_weather_model.dart';
import 'package:lockerroom/model/team_model.dart';
import 'package:lockerroom/page/feed/feed_detail_page.dart';
import 'package:lockerroom/page/home/quiz_ranking_dashboard_.dart';
import 'package:lockerroom/page/intution_record/all_users_intution_record_page.dart';
import 'package:lockerroom/utils/media_utils.dart';
import 'package:lockerroom/widgets/network_video_player.dart';
// import 'package:lockerroom/page/food_store/ballParkStore_page.dart';
// import 'package:lockerroom/page/food_store/championsFieldStore_page.dart';
// import 'package:lockerroom/page/food_store/giantsStroe_page.dart';
// import 'package:lockerroom/page/food_store/gocheokStore_page.dart';
// import 'package:lockerroom/page/food_store/jamsilStore_page.dart';
// import 'package:lockerroom/page/food_store/landersfield_Store_page.dart';
// import 'package:lockerroom/page/food_store/lionsParksStore_page.dart';
// import 'package:lockerroom/page/food_store/ncParkStore_page.dart';
// import 'package:lockerroom/page/food_store/wizParkStore_page.dart';
import 'package:lockerroom/page/meetup/meetup_detail_page.dart';
import 'package:lockerroom/page/meetup/meetup_page.dart';
import 'package:lockerroom/page/schedule/schedule.dart';
// import 'package:lockerroom/page/schedule/schedule.dart';
// import 'package:lockerroom/page/weather/weather_detail_page.dart';
import 'package:lockerroom/provider/block_provider.dart';
import 'package:lockerroom/provider/feed_provider.dart';
import 'package:lockerroom/provider/meetup_provider.dart';
// import 'package:lockerroom/provider/food_store_provider.dart';
import 'package:lockerroom/provider/notification_provider.dart';
import 'package:lockerroom/provider/profile_provider.dart';
import 'package:lockerroom/provider/schdule_Provider.dart';
import 'package:lockerroom/provider/team_provider.dart';
import 'package:lockerroom/provider/video_provider.dart';
import 'package:lockerroom/model/ranking_team_model.dart';
import 'package:lockerroom/provider/quiz_ranking_provider.dart';
// import 'package:lockerroom/provider/schdule_Provider.dart';
// import 'package:lockerroom/provider/weather_provider.dart';
// import 'package:lockerroom/utils/quiz_season_utils.dart';
import 'package:lockerroom/provider/intution_record_list_provider.dart';
import 'package:lockerroom/page/intution_record/intution_record_upload_page.dart';
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

  @override
  void initState() {
    super.initState();
    _feedProvider = context.read<FeedProvider>();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _feedProvider.listenRecentPosts();
      context.read<MeetupProvider>().fetchMeetups();
      context.read<QuizRankingProvider>().fetchRankings();
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
        _maybeFetchVideos(selectedTeam);
        final statusBarHeight = MediaQuery.of(context).padding.top;
        const headerContentHeight = 60.0;
        const overlapHeight = 18.0;
        final totalHeaderHeight =
            statusBarHeight + headerContentHeight + overlapHeight;

        return Scaffold(
          backgroundColor: BACKGROUND_COLOR,
          body: Stack(
            children: [
              // 1. 상단 팀 헤더 이미지 (배경)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: totalHeaderHeight,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(selectedTeam.headers, fit: BoxFit.cover),
                    Container(color: Colors.black.withValues(alpha: 0.15)),
                  ],
                ),
              ),

              // 2. 상단이 둥근 바디 (헤더 위를 18px 덮고 올라옴)
              Positioned(
                top: statusBarHeight + headerContentHeight,
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  decoration: const BoxDecoration(
                    color: BACKGROUND_COLOR,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(12),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(12),
                    ),
                    child: Stack(
                      children: [
                        SingleChildScrollView(
                          child: Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  16,
                                  16,
                                  32,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildMatchCard(context, selectedTeam),
                                    const SizedBox(height: 12),
                                    _buildFeedSection(context, selectedTeam),
                                    // _buildAllStadiumsWeather(context),
                                    // const SizedBox(height: 24),
                                    QuizRankingDashboard(
                                      selectedTeam: selectedTeam,
                                    ),

                                    // _buildSectionHeader('나의 직관 기록 🏟'),
                                    const SizedBox(height: 12),
                                    _buildIntutionRecord(),
                                    const SizedBox(height: 24),
                                    _buildMeetupSection(context, selectedTeam),
                                    const SizedBox(height: 24),

                                    // const SizedBox(height: 24),
                                    // _buildStadiumSection(context, selectedTeam),
                                    const SizedBox(height: 24),
                                    GestureDetector(
                                      onTap: () {
                                        launchUrl(
                                          Uri.parse(selectedTeam.youtubeUrl),
                                          mode: LaunchMode.externalApplication,
                                        );
                                      },
                                      child: Row(
                                        children: [
                                          Text(
                                            selectedTeam.youtubeName,
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Spacer(),
                                          Text(
                                            '더보기',
                                            style: TextStyle(
                                              color: GRAYSCALE_LABEL_500,
                                              fontWeight: FontWeight.w500,
                                              fontSize: 12,
                                            ),
                                          ),
                                          SizedBox(width: 5),
                                          Icon(
                                            Icons.arrow_forward_ios,
                                            size: 10,
                                            color: GRAYSCALE_LABEL_500,
                                          ),
                                        ],
                                      ),
                                    ),
                                    SizedBox(height: 10),
                                    Consumer<VideoProvider>(
                                      builder: (context, videoProvider, child) {
                                        if (videoProvider.isLoading) {
                                          return Center(
                                            child: CircularProgressIndicator(
                                              color: selectedTeam.color,
                                            ),
                                          );
                                        }
                                        final videos = videoProvider.videos;
                                        if (videos.isEmpty) {
                                          return const Center(
                                            child: Text('영상이 존재하지 않습니다.'),
                                          );
                                        }

                                        return Column(
                                          children: [
                                            // 첫 번째 큰 영상
                                            _buildVideoItem(
                                              context,
                                              videos[0],
                                              isLarge: true,
                                            ),
                                            if (videos.length > 1) ...[
                                              const SizedBox(height: 12),
                                              Row(
                                                children: [
                                                  // 두 번째 작은 영상
                                                  Expanded(
                                                    child: _buildVideoItem(
                                                      context,
                                                      videos[1],
                                                    ),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  // 세 번째 작은 영상 (있을 경우만)
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
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // 3. 앱바 콘텐츠 (로고, 팀명/슬로건, 알림 버튼)
              Positioned(
                top: statusBarHeight,
                left: 0,
                right: 0,
                height: headerContentHeight,
                child: Row(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Image.asset(
                        selectedTeam.logoPath,
                        fit: BoxFit.contain,
                      ),
                    ),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          selectedTeam.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Text(
                          'Time To Move ON',
                          style: TextStyle(color: WHITE, fontSize: 12),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Padding(
                      padding: const EdgeInsets.only(right: 10.0),
                      child: Consumer<NotificationProvider>(
                        builder: (context, ntp, child) {
                          return badges.Badge(
                            position: badges.BadgePosition.topEnd(
                              top: 0,
                              end: 0,
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
                                fontSize: 12,
                              ),
                            ),
                            child: IconButton(
                              onPressed: () =>
                                  Navigator.pushNamed(context, '알림센터'),
                              icon: const Icon(
                                CupertinoIcons.bell,
                                color: WHITE,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
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
    return Consumer2<ScheduleProvider, WeatherProvider>(
      builder: (context, scheduleProvider, weatherProvider, child) {
        if (!scheduleProvider.loaded) {
          return Container(
            width: double.infinity,
            height: 320,
            decoration: BoxDecoration(
              color: selectedTeam.color.withOpacity(0.3),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Center(child: CircularProgressIndicator(color: WHITE)),
          );
        }
        final schedules = scheduleProvider.allSchedules;
        final teamName = selectedTeam.symplename;
        final now = DateTime.now();
        final relatedGames = schedules.where((s) {
          final isMyTeam = s.homeTeam == teamName || s.awayTeam == teamName;
          if (!isMyTeam) return false;
          if (s.status == 'FINAL' || s.status == 'PPD') return false;
          return s.status == 'LIVE' || s.dateTimeKst.isAfter(now);
        }).toList();
        relatedGames.sort((a, b) {
          if (a.status == 'LIVE' && b.status != 'LIVE') return -1;
          if (a.status != 'LIVE' && b.status == 'LIVE') return 1;
          return a.dateTimeKst.compareTo(b.dateTimeKst);
        });
        final activeGame = relatedGames.isNotEmpty ? relatedGames.first : null;
        final isLive = activeGame?.status == 'LIVE';

        // 경기 구장 날씨 로드
        if (activeGame != null) {
          final weather = weatherProvider.getWeatherForStadium(
            activeGame.stadium,
          );
          if (weather == null) {
            weatherProvider.fetchSingleWeather(activeGame.stadium);
          }
        }

        final teamProvider = Provider.of<TeamProvider>(context, listen: false);
        final homeTeam = activeGame != null
            ? teamProvider.findTeamByName(activeGame.homeTeam)
            : null;
        final awayTeam = activeGame != null
            ? teamProvider.findTeamByName(activeGame.awayTeam)
            : null;

        return GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SchedulePage(teamModel: widget.teamModel),
            ),
          ),
          child: Container(
            width: double.infinity,
            height: 200,
            decoration: BoxDecoration(
              color: WHITE,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(
                    top: 10.0,
                    left: 14,
                    right: 14,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: selectedTeam.color,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.calendar_month_outlined,
                          color: WHITE,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        '오늘의 경기',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
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
                              '전체 경기 보기',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: GRAYSCALE_LABEL_500,
                              ),
                            ),
                            SizedBox(width: 2),
                            Icon(
                              Icons.arrow_forward_ios_rounded,
                              color: GRAYSCALE_LABEL_500,
                              size: 12,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                if (activeGame == null)
                  Container(
                    width: 350,
                    height: 140,
                    decoration: BoxDecoration(
                      color: GRAYSCALE_LABEL_100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.sports_baseball_outlined,
                            size: 34,
                            color: GRAYSCALE_LABEL_400,
                          ),
                          SizedBox(height: 8),
                          Text(
                            '예정된 경기가 없습니다',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: GRAYSCALE_LABEL_500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Container(
                    width: 350,
                    height: 140,
                    decoration: BoxDecoration(
                      color: GRAYSCALE_LABEL_100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // 원정팀 (Away)
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (awayTeam != null &&
                                  awayTeam.logoPath.isNotEmpty)
                                Image.asset(
                                  awayTeam.logoPath,
                                  height: 102,
                                  fit: BoxFit.contain,
                                )
                              else
                                const SizedBox(height: 42),
                              const SizedBox(height: 6),
                              Text(
                                activeGame.awayTeam,
                                style: const TextStyle(
                                  fontFamily: 'kbo',
                                  color: BLACK,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),

                        // 중앙 스코어 / VS
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isLive) ...[
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '${activeGame.awayScore}',
                                      style: const TextStyle(
                                        fontFamily: 'kbo',
                                        color: BLACK,
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 6.0,
                                      ),
                                      child: Text(
                                        ':',
                                        style: TextStyle(
                                          color: BLACK,
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      '${activeGame.homeScore}',
                                      style: const TextStyle(
                                        fontFamily: 'kbo',
                                        color: BLACK,
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: RED_DANGER_TEXT_50,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    activeGame.inning ?? 'LIVE',
                                    style: const TextStyle(
                                      color: WHITE,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ] else ...[
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text(
                                      'VS',
                                      style: TextStyle(
                                        fontFamily: 'kbo',
                                        color: BLACK,
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      isLive
                                          ? '${activeGame.inning ?? "LIVE"}\n${activeGame.stadium}'
                                          : '${DateFormat('MM.dd E HH:mm', 'ko').format(activeGame.dateTimeKst)}\n${activeGame.stadium}',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: BLACK.withValues(alpha: 0.7),
                                        fontSize: 11,
                                        height: 1.3,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),

                        // 홈팀 (Home)
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (homeTeam != null &&
                                  homeTeam.logoPath.isNotEmpty)
                                Image.asset(
                                  homeTeam.logoPath,
                                  height: 102,
                                  fit: BoxFit.contain,
                                )
                              else
                                const SizedBox(height: 42),
                              const SizedBox(height: 6),
                              Text(
                                activeGame.homeTeam,
                                style: const TextStyle(
                                  fontFamily: 'kbo',
                                  color: BLACK,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
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
    return Consumer<TeamProvider>(
      builder: (context, teamProvider, child) {
        final teamColor = teamProvider.selectedTeam?.color;
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(Icons.people_sharp, color: teamColor),
            SizedBox(width: 2),
            Text(
              title,
              style: GoogleFonts.gothicA1(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: GRAYSCALE_LABEL_900,
                letterSpacing: -0.5,
              ),
            ),
            if (onSeeAll != null)
              IconButton(
                onPressed: onSeeAll,
                icon: const Icon(
                  Icons.arrow_forward_ios_outlined,
                  color: GRAYSCALE_LABEL_500,
                  size: 18,
                ),
              ),
          ],
        );
      },
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Transform.translate(
                  offset: Offset(-10, 0),
                  child: TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => MeetupPage()),
                      );
                    },
                    child: Text(
                      '같이 보면 더 즐거운 직관',
                      style: GoogleFonts.gothicA1(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: GRAYSCALE_LABEL_900,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => MeetupPage()),
                    );
                  },
                  icon: Icon(
                    Icons.arrow_forward_ios_outlined,
                    size: 18,
                    color: GRAYSCALE_LABEL_500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (recruitingMeetups.isEmpty)
              _buildEmptyCard('현재 모집 중인 직관 모임이 없습니다')
            else
              SizedBox(
                height: 180,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
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
        return Container(
          width: double.infinity,
          height: 310,
          decoration: BoxDecoration(
            color: WHITE,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildSectionHeader('야구 팬들의 이야기'),
                    GestureDetector(
                      onTap: () => widget.onTabTab(1),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '더보기',
                            style: TextStyle(
                              color: GRAYSCALE_LABEL_500,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          SizedBox(width: 2),
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 11,
                            color: GRAYSCALE_LABEL_500,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (recentPosts.isEmpty)
                  _buildEmptyCard('최근 게시물이 존재하지 않습니다')
                else
                  SizedBox(
                    height: 250,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: recentPosts.length,
                      itemBuilder: (context, index) =>
                          _buildFeedHighlightCard(context, recentPosts[index]),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFeedHighlightCard(BuildContext context, PostModel post) {
    return Consumer<ProfileProvider>(
      builder: (context, profileProvider, _) {
        // 유저 정보 구독
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
            width: 260,
            margin: const EdgeInsets.only(right: 12, bottom: 4),
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
            decoration: BoxDecoration(
              color: WHITE,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hasMedia) ...[
                  // const Spacer(),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      width: double.infinity,
                      height: 150,
                      child: isVideo
                          ? Stack(
                              fit: StackFit.expand,
                              children: [
                                IgnorePointer(
                                  child: NetworkVideoPlayer(
                                    videoUrl: post.mediaUrls.first,
                                    width: double.infinity,
                                    height: 130,
                                    fit: BoxFit.cover,
                                    autoPlay: true,
                                    muted: true,
                                    showControls: false,
                                  ),
                                ),
                                Positioned(
                                  right: 8,
                                  top: 8,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(
                                        alpha: 0.6,
                                      ),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: const Icon(
                                      Icons.videocam_rounded,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : Image.network(
                              post.mediaUrls.first,
                              width: double.infinity,
                              height: 130,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Container(
                                    color: GRAYSCALE_LABEL_200,
                                    alignment: Alignment.center,
                                    child: const Icon(
                                      Icons.broken_image,
                                      color: GRAYSCALE_LABEL_400,
                                    ),
                                  ),
                            ),
                    ),
                  ),
                ],
                SizedBox(height: 5),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: BACKGROUND_COLOR,
                      foregroundImage: authorProfileUrl != null
                          ? NetworkImage(authorProfileUrl)
                          : null,
                      child: const Icon(Icons.person, size: 14),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          authorName,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 2),
                        Text(
                          DateFormat('M.d HH:mm').format(post.createdAt),
                          style: const TextStyle(
                            fontSize: 11,
                            color: GRAYSCALE_LABEL_400,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  post.text,
                  style: const TextStyle(fontSize: 11, height: 1.4),
                  maxLines: hasMedia ? 2 : 6,
                  overflow: TextOverflow.ellipsis,
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

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MeetupDetailPage(meetup: meetup),
        ),
      ),
      child: Container(
        width: 185,

        margin: const EdgeInsets.only(right: 12, bottom: 0),
        decoration: BoxDecoration(
          color: BACKGROUND_COLOR,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            // 베이스 부드러운 그림자
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
            // 선택 팀 컬러를 이용한 은은한 글로우 효과 (더 자연스러움)
            BoxShadow(
              color: selectedTeam.color.withOpacity(0.15),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
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
                      colors: [
                        selectedTeam.color,
                        selectedTeam.color.withOpacity(0.4),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ),

              // 배경 로고 (희미한 워터마크)
              Positioned(
                right: -18,
                bottom: -10,
                child: Opacity(
                  opacity: 0.07,
                  child: homeTeam?.logoPath != null
                      ? Image.asset(homeTeam!.logoPath, width: 100, height: 100)
                      : const SizedBox.shrink(),
                ),
              ),

              // 본문
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 12, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 팀 매치업 로고 (원정 vs 홈)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // 원정팀
                        Column(
                          children: [
                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: awayTeam?.logoPath != null
                                  ? Padding(
                                      padding: const EdgeInsets.all(4),
                                      child: Image.asset(
                                        awayTeam!.logoPath,
                                        fit: BoxFit.contain,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.sports_baseball,
                                      color: Colors.white54,
                                      size: 16,
                                    ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'VS',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            fontStyle: FontStyle.italic,
                            color: Colors.black.withOpacity(0.3),
                          ),
                        ),
                        const SizedBox(width: 6),
                        // 홈팀
                        Column(
                          children: [
                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: homeTeam?.logoPath != null
                                  ? Padding(
                                      padding: const EdgeInsets.all(4),
                                      child: Image.asset(
                                        homeTeam!.logoPath,
                                        fit: BoxFit.contain,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.sports_baseball,
                                      color: Colors.white54,
                                      size: 16,
                                    ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        // 모집중 배지
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: selectedTeam.color.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: selectedTeam.color.withOpacity(0.5),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            '모집중',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: selectedTeam.color,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // 날짜
                    if (gameDate != null)
                      Text(
                        '${DateFormat('M.d (E)', 'ko').format(gameDate)}  ${meetup.gameTime}',
                        style: TextStyle(
                          fontSize: 10,
                          color: selectedTeam.color.withOpacity(0.9),
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                        ),
                      ),
                    const SizedBox(height: 4),

                    // 제목
                    Text(
                      meetup.title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),

                    // 응원팀 정보
                    if (meetup.myTeam.isNotEmpty)
                      Builder(
                        builder: (context) {
                          final cheerTeam = teamProvider.findTeamByName(
                            meetup.myTeam,
                          );
                          return Row(
                            children: [
                              Icon(
                                Icons.favorite,
                                size: 10,
                                color: Colors.redAccent.withOpacity(0.8),
                              ),
                              const SizedBox(width: 4),
                              if (cheerTeam?.logoPath != null)
                                Image.asset(
                                  cheerTeam!.logoPath,
                                  width: 14,
                                  height: 14,
                                ),
                              const SizedBox(width: 3),
                              Expanded(
                                child: Text(
                                  '${meetup.myTeam} 팬 모집',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.black.withOpacity(0.5),
                                    fontWeight: FontWeight.w500,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    const SizedBox(height: 8),

                    // 인원 바
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: Colors.black.withOpacity(0.1),
                                width: 0.8,
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: fillRatio,

                                backgroundColor: Colors.white.withOpacity(0.1),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  selectedTeam.color,
                                ),
                                minHeight: 4,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$currentCount/$maxCount',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.black.withOpacity(0.75),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // 경기장
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 10,
                          color: Colors.black.withOpacity(0.4),
                        ),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            meetup.stadium,
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.black.withOpacity(0.4),
                            ),
                            overflow: TextOverflow.ellipsis,
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
      ),
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
          if (ip.isLoading) {
            final selectedColor = tp.selectedTeam?.color ?? BUTTON;
            return Center(
              child: CircularProgressIndicator(color: selectedColor),
            );
          }
          final items = ip.records;
          if (items.isEmpty) {
            return Center(
              child: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const IntutionRecordUploadPage(),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: const [
                    Text(
                      '아직 직관 기록이 없네요. 첫 직관을 남겨볼까요?',
                      style: TextStyle(color: GRAYSCALE_LABEL_600),
                    ),
                    SizedBox(height: 10),
                    Text('직관기록 추가 하기 +', style: TextStyle(color: Colors.black)),
                  ],
                ),
              ),
            );
          }
          int wins = 0;
          int losses = 0;
          int draws = 0;
          int? _prseScore(dynamic v) => v is int ? v : int.tryParse('$v');
          for (final d in items) {
            final int? my = _prseScore(d['myScore']);
            final int? opp = _prseScore(d['opponentScore']);
            if (my != null && opp != null) {
              if (my > opp)
                wins++;
              else if (my < opp)
                losses++;
              else
                draws++;
            }
          }

          final int totalGames = items.length;
          final double winRate = totalGames > 0 ? (wins / totalGames) * 100 : 0;
          final teamColor = tp.selectedTeam?.color ?? Colors.blueAccent;

          return Container(
            width: double.infinity,
            height: 180,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: WHITE,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: teamColor,
                        ),
                        child: Icon(
                          CupertinoIcons.ticket_fill,
                          color: WHITE,
                          size: 16,
                        ),
                      ),
                      SizedBox(width: 5),
                      Transform.translate(
                        offset: Offset(-10, 0),
                        child: TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => IntutionTabBar(),
                              ),
                            );
                          },
                          child: Text(
                            '나의 직관 기록',
                            style: GoogleFonts.gothicA1(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: GRAYSCALE_LABEL_900,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ),
                      ),
                      Spacer(),
                      Text(
                        '더보기',
                        style: TextStyle(
                          color: GRAYSCALE_LABEL_500,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          // Navigator.push(
                          //   context,
                          //   MaterialPageRoute(
                          //     builder: (context) => IntutionTabBar(),
                          //   ),
                          // );
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  AllUsersIntutionRecordPage(),
                            ),
                          );
                        },
                        icon: Icon(
                          Icons.arrow_forward_ios_outlined,
                          color: GRAYSCALE_LABEL_500,
                          size: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => IntutionTabBar(),
                        ),
                      );
                    },
                    child: Row(
                      children: [
                        // 왼쪽: 총 경기 & 승리
                        Icon(Icons.calendar_month_outlined),
                        SizedBox(width: 8),
                        _buildMiniStat('총 경기', '$totalGames', teamColor),
                        const SizedBox(width: 25),
                        Container(
                          width: 1,
                          height: 55,
                          color: const Color(0xFFE5E7EB),
                        ),
                        const SizedBox(width: 25),
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: 60,
                              height: 60,
                              child: CircularProgressIndicator(
                                value: winRate / 100,
                                strokeWidth: 12,
                                backgroundColor: teamColor.withOpacity(0.1),
                                color: teamColor,
                                strokeCap: StrokeCap.round,
                              ),
                            ),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${winRate.toStringAsFixed(0)}%',
                                  style: GoogleFonts.outfit(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: GRAYSCALE_LABEL_900,
                                  ),
                                ),
                                const Text(
                                  '승률',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: GRAYSCALE_LABEL_500,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(width: 25),
                        Container(
                          width: 1,
                          height: 55,
                          color: const Color(0xFFE5E7EB),
                        ),
                        const SizedBox(width: 25),
                        _buildMiniStat('승리', '$wins', Colors.blueAccent),
                        const SizedBox(width: 25),
                        Container(
                          width: 1,
                          height: 55,
                          color: const Color(0xFFE5E7EB),
                        ),
                        const SizedBox(width: 25),
                        // 중앙: 승률 게이지

                        // 오른쪽: 패배 & 무승부
                        Row(
                          children: [
                            _buildMiniStat('패배', '$losses', Colors.redAccent),
                            const SizedBox(height: 24),
                            // _buildMiniStat(
                            //   '무승부',
                            //   '$draws',
                            //   GRAYSCALE_LABEL_400,
                            // ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    height: 30,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: GRAYSCALE_LABEL_100,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 5.0),
                      child: Row(
                        children: [
                          Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: GRAYSCALE_LABEL_500,
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: Icon(
                              Icons.rocket_launch_rounded,
                              color: WHITE,
                              size: 12,
                            ),
                          ),
                          SizedBox(width: 10),
                          Text(
                            '이번 시즌 직관 기록을 확인해보세요!',
                            style: TextStyle(
                              fontSize: 11,
                              color: GRAYSCALE_LABEL_700,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          SizedBox(width: 90),
                          IconButton(
                            onPressed: () {},
                            icon: Icon(
                              Icons.arrow_forward_ios_outlined,
                              size: 12,
                              color: GRAYSCALE_LABEL_500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
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
