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
import 'package:lockerroom/model/team_model.dart';
import 'package:lockerroom/page/feed/feed_detail_page.dart';
import 'package:lockerroom/page/feed/fullscreen_image_viewer.dart';
import 'package:lockerroom/page/feed/fullscreen_video_player.dart';
import 'package:lockerroom/page/food_store/ballParkStore_page.dart';
import 'package:lockerroom/page/food_store/championsFieldStore_page.dart';
import 'package:lockerroom/page/food_store/giantsStroe_page.dart';
import 'package:lockerroom/page/food_store/gocheokStore_page.dart';
import 'package:lockerroom/page/food_store/jamsilStore_page.dart';
import 'package:lockerroom/page/food_store/landersfield_Store_page.dart';
import 'package:lockerroom/page/food_store/lionsParksStore_page.dart';
import 'package:lockerroom/page/food_store/ncParkStore_page.dart';
import 'package:lockerroom/page/food_store/wizParkStore_page.dart';
import 'package:lockerroom/page/intution_record/intution_record_upload_page.dart';
import 'package:lockerroom/page/meetup/meetup_detail_page.dart';
import 'package:lockerroom/page/meetup/meetup_page.dart';
import 'package:lockerroom/page/schedule/schedule.dart';
import 'package:lockerroom/provider/block_provider.dart';
import 'package:lockerroom/provider/feed_provider.dart';
import 'package:lockerroom/provider/meetup_provider.dart';
import 'package:lockerroom/provider/food_store_provider.dart';
import 'package:lockerroom/provider/intution_record_list_provider.dart';
import 'package:lockerroom/provider/notification_provider.dart';
import 'package:lockerroom/provider/profile_provider.dart';
import 'package:lockerroom/provider/team_provider.dart';
import 'package:lockerroom/provider/video_provider.dart';
import 'package:lockerroom/utils/media_utils.dart';
import 'package:lockerroom/widgets/network_video_player.dart';
import 'package:lockerroom/model/ranking_team_model.dart';
import 'package:lockerroom/provider/quiz_ranking_provider.dart';
import 'package:lockerroom/provider/schdule_Provider.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:badges/badges.dart' as badges;

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

      // BlockProvider와 동기화
      _blockProvider = context.read<BlockProvider>();
      final feedProvider = context.read<FeedProvider>();
      // 초기 동기화
      feedProvider.setBlockedUsers(_blockProvider!.blockedUserIds);
      feedProvider.setBlockedByUsers(_blockProvider!.blockedByUserIds);
      // 차단 목록 변경 리스너
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

  String? extractUrl(String text) {
    final urlPattern = RegExp(r'(https?://[^\s,]+)', caseSensitive: false);

    final match = urlPattern.firstMatch(text);
    return match?.group(0);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TeamProvider>(
      builder: (context, teamProvider, child) {
        final selectedTeam = teamProvider.selectedTeam ?? widget.teamModel;
        _maybeFetchVideos(selectedTeam);
        return Scaffold(
          backgroundColor: BACKGROUND_COLOR,
          appBar: AppBar(
            backgroundColor: selectedTeam.color,
            leading: Padding(
              padding: const EdgeInsets.only(left: 20.0),
              child: Image.asset(selectedTeam.logoPath, fit: BoxFit.contain),
            ),
            scrolledUnderElevation: 0,
            title: Text(
              selectedTeam.name,
              style: TextStyle(
                color: WHITE,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            centerTitle: true,

            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 10.0),
                child: Consumer<NotificationProvider>(
                  builder: (context, ntp, child) {
                    return badges.Badge(
                      position: badges.BadgePosition.topEnd(top: 0, end: 0),
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
                        style: TextStyle(color: WHITE, fontSize: 12),
                      ),
                      child: IconButton(
                        onPressed: () {
                          Navigator.pushNamed(context, 'notifications');
                        },
                        icon: Icon(CupertinoIcons.bell, color: WHITE),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.only(
                top: 15.0,
                left: 15.0,
                right: 15.0,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Consumer<ScheduleProvider>(
                    builder: (context, scheduleProvider, child) {
                      if (!scheduleProvider.loaded) {
                        return Container(
                          width: double.infinity,
                          height: 100,
                          decoration: BoxDecoration(
                            color: selectedTeam.color,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Center(
                            child: CircularProgressIndicator(color: WHITE),
                          ),
                        );
                      }

                      final schedules = scheduleProvider.allSchedules;
                      final teamName = selectedTeam.symplename;
                      final now = DateTime.now();

                      // 선택 한 팀의 경기 필터링
                      final relatedGames = schedules.where((s) {
                        final isMyTeam =
                            s.homeTeam == teamName || s.awayTeam == teamName;
                        if (!isMyTeam) return false;

                        // 종료(FINAL) 혹은 취소(PPD)된 경기는 제외 (바로 다음 경기 대상이 됨)
                        if (s.status == 'FINAL' || s.status == 'PPD')
                          return false;

                        // LIVE 경기면 무조건 포함
                        if (s.status == 'LIVE') return true;

                        // 그 외(SCHEDULED 등)는 미래 경기만 포함
                        return s.dateTimeKst.isAfter(now);
                      }).toList();

                      // 정렬 우선순위: LIVE > 시간순
                      relatedGames.sort((a, b) {
                        if (a.status == 'LIVE' && b.status != 'LIVE') return -1;
                        if (a.status != 'LIVE' && b.status == 'LIVE') return 1;
                        return a.dateTimeKst.compareTo(b.dateTimeKst);
                      });

                      final activeGame = relatedGames.isNotEmpty
                          ? relatedGames.first
                          : null;
                      final isLive = activeGame?.status == 'LIVE';

                      return GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                SchedulePage(teamModel: widget.teamModel),
                          ),
                        ),
                        child: Container(
                          width: double.infinity,
                          height: 100,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                selectedTeam.color,
                                selectedTeam.color.withOpacity(0.8),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: selectedTeam.color.withOpacity(0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Stack(
                            children: [
                              Positioned(
                                right: -20,
                                bottom: -20,
                                child: Opacity(
                                  opacity: 0.2,
                                  child: Image.asset(
                                    selectedTeam.logoPath,
                                    height: 120,
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20.0,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Text(
                                                isLive ? 'LIVE' : 'Next Match',
                                                style: TextStyle(
                                                  color: isLive
                                                      ? Colors.yellowAccent
                                                      : WHITE.withOpacity(0.8),
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              if (isLive &&
                                                  activeGame?.inning != null)
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                        left: 8.0,
                                                      ),
                                                  child: Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 6,
                                                          vertical: 1,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: Colors.white
                                                          .withOpacity(0.2),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            4,
                                                          ),
                                                    ),
                                                    child: Text(
                                                      activeGame!.inning!,
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 10,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          if (isLive)
                                            Row(
                                              children: [
                                                Text(
                                                  '${activeGame!.awayTeam} ${activeGame.awayScore}',
                                                  style: const TextStyle(
                                                    color: WHITE,
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                const Padding(
                                                  padding: EdgeInsets.symmetric(
                                                    horizontal: 8.0,
                                                  ),
                                                  child: Text(
                                                    ':',
                                                    style: TextStyle(
                                                      color: WHITE,
                                                      fontSize: 18,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                                Text(
                                                  '${activeGame.homeScore} ${activeGame.homeTeam}',
                                                  style: const TextStyle(
                                                    color: WHITE,
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            )
                                          else
                                            Text(
                                              activeGame != null
                                                  ? '${activeGame.homeTeam} vs ${activeGame.awayTeam}'
                                                  : 'No matches scheduled',
                                              style: const TextStyle(
                                                color: WHITE,
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          if (activeGame != null)
                                            Text(
                                              isLive
                                                  ? activeGame.stadium
                                                  : '${DateFormat('MM.dd E HH:mm', 'ko').format(activeGame.dateTimeKst)}  ${activeGame.stadium}',
                                              style: TextStyle(
                                                color: WHITE.withOpacity(0.9),
                                                fontSize: 12,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    const Icon(
                                      Icons.arrow_forward_ios,
                                      color: WHITE,
                                      size: 16,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 20),

                  // 랭킹 리포트 섹션 헤더
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => QuizTabBar(initialIndex: 0),
                        ),
                      );
                    },
                    child: Row(
                      children: [
                        Text(
                          '야구 덕력 테스트! 퀴즈 풀기',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(width: 10),
                        Icon(
                          Icons.arrow_forward_ios,
                          size: 12,
                          color: GRAYSCALE_LABEL_500,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 퀴즈 랭킹 리포트 카드
                  _HomeRankingCard(selectedTeam: selectedTeam),
                  const SizedBox(height: 10),

                  IntutionRecord(),
                  const SizedBox(height: 14),

                  Consumer<MeetupProvider>(
                    builder: (context, meetupProvider, child) {
                      final recruitingMeetups = meetupProvider.meetups
                          .where((m) => !m.isFull)
                          .take(5)
                          .toList();

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                '지금 모집 중인 직관 모임 ⚾',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Spacer(),
                              GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const MeetupPage(),
                                    ),
                                  );
                                },
                                child: Text(
                                  '전체보기',
                                  style: TextStyle(color: GRAYSCALE_LABEL_500),
                                ),
                              ),
                              SizedBox(width: 5),
                              Icon(
                                Icons.arrow_forward_ios,
                                color: GRAYSCALE_LABEL_500,
                                size: 12,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (recruitingMeetups.isEmpty)
                            Container(
                              width: double.infinity,
                              height: 190,
                              decoration: BoxDecoration(
                                color: WHITE,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: GRAYSCALE_LABEL_300.withAlpha(50),
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  '모집 중인 모임이 없습니다',
                                  style: TextStyle(
                                    color: GRAYSCALE_LABEL_500,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            )
                          else
                            SizedBox(
                              height: 190,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: recruitingMeetups.length,
                                itemBuilder: (context, index) {
                                  return _buildMeetupMiniCard(
                                    context,
                                    recruitingMeetups[index],
                                    selectedTeam,
                                  );
                                },
                              ),
                            ),
                          const SizedBox(height: 20),
                        ],
                      );
                    },
                  ),
                  GestureDetector(
                    onTap: () => widget.onTabTab(1),
                    child: Row(
                      children: [
                        Text(
                          '최신게시물',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Spacer(),
                        Text(
                          '모든 게시물 보기 ',
                          style: TextStyle(color: GRAYSCALE_LABEL_500),
                        ),
                        SizedBox(width: 5),
                        Icon(
                          Icons.arrow_forward_ios,
                          color: GRAYSCALE_LABEL_500,
                          size: 12,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 10),

                  Consumer<FeedProvider>(
                    builder: (context, feedProvider, child) {
                      final posts = feedProvider.posts;
                      if (posts.isEmpty) return Text('최근 게시물이 존재하지 않습니다');

                      // 미디어와 링크가 있는지 확인
                      final hasMediaPosts = posts.any(
                        (p) => p.mediaUrls.isNotEmpty,
                      );
                      final hasLinkPosts = posts.any(
                        (p) => extractUrl(p.text) != null,
                      );

                      // 높이 계산
                      double listHeight;
                      if (hasMediaPosts) {
                        listHeight = 248.0; // 미디어 있음
                      } else if (hasLinkPosts) {
                        listHeight = 150.0; // 링크만 있음
                      } else {
                        listHeight = 100.0; // 둘 다 없음
                      }

                      return SizedBox(
                        height: listHeight,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: posts.length,
                          itemBuilder: (context, index) {
                            final post = posts[index];

                            return Align(
                              alignment: Alignment.topCenter,
                              child: GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          FeedDetailPage(post: post),
                                    ),
                                  );
                                },
                                child: Container(
                                  width: 240,
                                  margin: const EdgeInsets.only(right: 12),
                                  child: Card(
                                    color: WHITE,
                                    child: Padding(
                                      padding: EdgeInsets.all(15.0),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          // 링크 바로가기 버튼
                                          if (extractUrl(post.text) !=
                                              null) ...[
                                            InkWell(
                                              onTap: () async {
                                                final url = extractUrl(
                                                  post.text,
                                                )!;
                                                if (await canLaunchUrl(
                                                  Uri.parse(url),
                                                )) {
                                                  await launchUrl(
                                                    Uri.parse(url),
                                                    mode: LaunchMode
                                                        .externalApplication,
                                                  );
                                                }
                                              },
                                              child: Container(
                                                padding: EdgeInsets.symmetric(
                                                  horizontal: 10,
                                                  vertical: 8,
                                                ),
                                                decoration: BoxDecoration(
                                                  gradient: LinearGradient(
                                                    colors: [
                                                      Colors.blue[50]!,
                                                      Colors.blue[100]!,
                                                    ],
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  border: Border.all(
                                                    color: Colors.blue[300]!,
                                                    width: 1,
                                                  ),
                                                ),
                                                child: Row(
                                                  children: [
                                                    Container(
                                                      padding: EdgeInsets.all(
                                                        4,
                                                      ),
                                                      decoration: BoxDecoration(
                                                        color: WHITE,
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              4,
                                                            ),
                                                      ),
                                                      child: Icon(
                                                        Icons.link,
                                                        size: 14,
                                                        color: Colors.blue[700],
                                                      ),
                                                    ),
                                                    SizedBox(width: 8),
                                                    Expanded(
                                                      child: Column(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          Text(
                                                            '링크 바로가기',
                                                            style: TextStyle(
                                                              fontSize: 12,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                              color: Colors
                                                                  .blue[900],
                                                            ),
                                                          ),
                                                          SizedBox(height: 1),
                                                          Text(
                                                            '탭하여 열기',
                                                            style: TextStyle(
                                                              fontSize: 10,
                                                              color: Colors
                                                                  .blue[700],
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    Icon(
                                                      Icons.arrow_forward_ios,
                                                      size: 12,
                                                      color: Colors.blue[700],
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            SizedBox(height: 8),
                                          ],
                                          if (post.mediaUrls.isNotEmpty)
                                            SizedBox(
                                              height: 150,
                                              child: ListView.builder(
                                                scrollDirection:
                                                    Axis.horizontal,
                                                itemCount:
                                                    post.mediaUrls.length,
                                                itemBuilder: (_, i) {
                                                  final url = post.mediaUrls[i];
                                                  final inSingle =
                                                      post.mediaUrls.length ==
                                                      1;
                                                  final isVideo =
                                                      MediaUtils.isVideoFromPost(
                                                        post,
                                                        i,
                                                      );

                                                  return Padding(
                                                    padding: EdgeInsets.only(
                                                      left: inSingle ? 0 : 0,
                                                      right: inSingle ? 0 : 8,
                                                    ),
                                                    child: ClipRRect(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            8,
                                                          ),
                                                      child: isVideo
                                                          ? GestureDetector(
                                                              onTap: () {
                                                                Navigator.push(
                                                                  context,
                                                                  MaterialPageRoute(
                                                                    builder:
                                                                        (
                                                                          context,
                                                                        ) => FullscreenVideoPlayer(
                                                                          videoUrl:
                                                                              url,
                                                                        ),
                                                                  ),
                                                                );
                                                              },
                                                              child:
                                                                  NetworkVideoPlayer(
                                                                    videoUrl:
                                                                        url,
                                                                    width:
                                                                        inSingle
                                                                        ? 200
                                                                        : 150,
                                                                    height: 150,
                                                                    fit: BoxFit
                                                                        .cover,
                                                                    autoPlay:
                                                                        true,
                                                                    muted: true,
                                                                    showControls:
                                                                        false,
                                                                  ),
                                                            )
                                                          : GestureDetector(
                                                              onTap: () {
                                                                Navigator.push(
                                                                  context,
                                                                  MaterialPageRoute(
                                                                    builder: (context) => FullscreenImageViewer(
                                                                      imageUrls:
                                                                          post.mediaUrls,
                                                                      initialIndex:
                                                                          i,
                                                                    ),
                                                                  ),
                                                                );
                                                              },
                                                              child: Image.network(
                                                                url,
                                                                height: 150,
                                                                width: inSingle
                                                                    ? 200
                                                                    : 150,
                                                                fit: inSingle
                                                                    ? BoxFit
                                                                          .cover
                                                                    : BoxFit
                                                                          .cover,
                                                                loadingBuilder:
                                                                    (
                                                                      context,
                                                                      child,
                                                                      loadingProgress,
                                                                    ) {
                                                                      if (loadingProgress ==
                                                                          null) {
                                                                        return child;
                                                                      }
                                                                      return SizedBox(
                                                                        height:
                                                                            150,
                                                                        width:
                                                                            inSingle
                                                                            ? 200
                                                                            : 150,
                                                                        child: Center(
                                                                          child: CircularProgressIndicator(
                                                                            color:
                                                                                selectedTeam.color,
                                                                          ),
                                                                        ),
                                                                      );
                                                                    },
                                                              ),
                                                            ),
                                                    ),
                                                  );
                                                },
                                              ),
                                            ),

                                          SizedBox(height: 10),
                                          Text(
                                            post.text,
                                            maxLines: 1,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w500,
                                              fontSize: 16,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          SizedBox(height: 3),
                                          Consumer<ProfileProvider>(
                                            builder:
                                                (
                                                  context,
                                                  profileProvider,
                                                  child,
                                                ) {
                                                  final nickName =
                                                      profileProvider
                                                          .userNicknames[post
                                                          .userId] ??
                                                      post.userNickName;
                                                  return Text(
                                                    nickName,
                                                    style: TextStyle(
                                                      color:
                                                          GRAYSCALE_LABEL_500,
                                                    ),
                                                  );
                                                },
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                  SizedBox(height: 20),
                  GestureDetector(
                    onTap: () {
                      final foodStorePage = _getFoodStorePage(
                        selectedTeam.stadium,
                      );
                      if (foodStorePage != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => foodStorePage,
                          ),
                        );
                      }
                    },
                    child: Row(
                      children: [
                        Text(
                          '${selectedTeam.stadium} 푸드존',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Spacer(),
                        Text(
                          '푸드존 정보 더보기 ',
                          style: TextStyle(
                            color: GRAYSCALE_LABEL_500,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(width: 5),
                        Icon(
                          Icons.arrow_forward_ios,
                          size: 12,
                          color: GRAYSCALE_LABEL_500,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 10),
                  FoodStore(selectedTeam),
                  SizedBox(height: 20),
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
                          ),
                        ),
                        SizedBox(width: 5),
                        Icon(
                          Icons.arrow_forward_ios,
                          size: 12,
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
                      if (videoProvider.videos.isEmpty) {
                        return const Center(child: Text('영상이 존재하지 않습니다.'));
                      }
                      return SizedBox(
                        height: 205,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: videoProvider.videos.length,
                          itemBuilder: (context, index) {
                            final video = videoProvider.videos[index];
                            return Container(
                              width: 240,
                              margin: const EdgeInsets.only(right: 12),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: GestureDetector(
                                  onTap: () {
                                    final youtubeUrl =
                                        'https://www.youtube.com/watch?v=${video.id}';
                                    launchUrl(
                                      Uri.parse(youtubeUrl),
                                      mode: LaunchMode.externalApplication,
                                    );
                                  },
                                  child: Image.network(
                                    video.thumbnailUrl,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                  SizedBox(height: 20),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget FoodStore(TeamModel selectedTeam) {
    return Consumer<FoodStoreProvider>(
      builder: (context, fsp, child) {
        // 선택된 팀의 경기장 이름으로 푸드존 리스트 가져오기
        final foodStores = fsp.getStore(selectedTeam.stadium);

        // 최대 5개만 표시
        final displayStores = foodStores.take(5).toList();

        if (displayStores.isEmpty) {
          return Center(child: Text('해당 경기장의 푸드존 정보가 없습니다.'));
        }

        return SizedBox(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: displayStores.length,
            itemBuilder: (context, index) {
              final store = displayStores[index];
              return Container(
                width: 150,
                margin: const EdgeInsets.only(right: 12),
                child: Card(
                  color: WHITE,
                  child: Padding(
                    padding: EdgeInsets.all(10.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 가게 이미지
                        if (store.storePhoto != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.asset(
                              store.storePhoto!,
                              height: 100,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ),
                        if (store.storePhoto == null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              width: double.infinity,
                              height: 100,
                              color: GRAYSCALE_LABEL_300,
                              child: Icon(Icons.restaurant_menu),
                            ),
                          ),

                        SizedBox(height: 8),
                        // 상호명
                        Text(
                          store.storeName,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 4),
                        // 음식 타입
                        Text(
                          store.type,
                          style: TextStyle(
                            fontSize: 12,
                            color: GRAYSCALE_LABEL_500,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          store.location,
                          style: TextStyle(
                            fontSize: 11,
                            color: GRAYSCALE_LABEL_400,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget IntutionRecord() {
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
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => IntutionRecordUploadPage(),
                    ),
                  );
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
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
          final teamColor = tp.selectedTeam?.color ?? Colors.blueAccent;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 4.0,
                  vertical: 8.0,
                ),
                child: Row(
                  children: [
                    const Text(
                      '나의 직관기록 🏟️',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
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
                      child: Row(
                        children: const [
                          Text(
                            '기록 더보기',
                            style: TextStyle(
                              color: GRAYSCALE_LABEL_500,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(width: 4),
                          Icon(
                            Icons.arrow_forward_ios,
                            size: 10,
                            color: GRAYSCALE_LABEL_500,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: WHITE,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                    BoxShadow(
                      color: teamColor.withOpacity(0.1),
                      blurRadius: 5,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 16,
                    horizontal: 8,
                  ),
                  child: Row(
                    children: [
                      _buildScoreItem(
                        '총 경기',
                        '${items.length}',
                        Icons.stadium_outlined,
                        GRAYSCALE_LABEL_600,
                      ),
                      _buildDivider(),
                      _buildScoreItem(
                        '승',
                        '$wins',
                        Icons.emoji_events_outlined,
                        Colors.blueAccent,
                      ),
                      _buildDivider(),
                      _buildScoreItem(
                        '패',
                        '$losses',
                        Icons.sentiment_dissatisfied_rounded,
                        Colors.redAccent,
                      ),
                      _buildDivider(),
                      _buildScoreItem(
                        '무',
                        '$draws',
                        Icons.remove_circle_outline_rounded,
                        GRAYSCALE_LABEL_500,
                      ),
                      _buildDivider(),
                      _buildScoreItem(
                        '승률',
                        '${winRate.toStringAsFixed(0)}%',
                        Icons.percent_rounded,
                        GRAYSCALE_LABEL_900,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildScoreItem(
    String label,
    String value,
    IconData icon,
    Color mainColor,
  ) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: mainColor.withOpacity(0.8), size: 20),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              color: GRAYSCALE_LABEL_500,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.robotoMono(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: mainColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(width: 1, height: 30, color: Colors.grey.withOpacity(0.1));
  }

  Widget? _getFoodStorePage(String stadium) {
    switch (stadium) {
      case '잠실야구장':
        return JamsilstorePage();
      case '고척스카이돔':
        return GocheokstorePage();
      case '랜더스필드':
        return LandersFieldStorePage();
      case '위즈파크':
        return WizparkstorePage();
      case '한화생명볼파크':
        return BallparkstorePage();
      case '챔피언스필드':
        return ChampionsfieldstorePage();
      case '라이온즈 파크':
        return LionsparksstorePage();
      case '창원NC파크':
        return NcparkstorePage();
      case '사직야구장':
        return GiantsstroePage();
      default:
        return null;
    }
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
        margin: const EdgeInsets.only(right: 12, bottom: 4),
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
                padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
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
}

class _HomeRankingCard extends StatefulWidget {
  final TeamModel selectedTeam;
  const _HomeRankingCard({required this.selectedTeam});

  @override
  State<_HomeRankingCard> createState() => _HomeRankingCardState();
}

class _HomeRankingCardState extends State<_HomeRankingCard> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startAutoSlide();
  }

  void _startAutoSlide() {
    _timer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (_pageController.hasClients) {
        int nextPage = (_currentPage + 1) % 2; // 페이지가 2개인 경우
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
    return Consumer2<QuizRankingProvider, TeamProvider>(
      builder: (context, rankProvider, teamProvider, _) {
        final currentUserId = FirebaseAuth.instance.currentUser?.uid;
        final myTeam = teamProvider.selectedTeam;

        // 개인 랭킹 데이터
        final top3Individuals = rankProvider.rankings.take(3).toList();
        final myIndividualRanking = currentUserId != null
            ? rankProvider.getMyRanking(currentUserId)
            : null;

        // 팀 랭킹 데이터
        final top3Teams = rankProvider.teamRankings.take(3).toList();
        RankingTeamModel? myTeamRanking;
        if (myTeam != null) {
          try {
            myTeamRanking = rankProvider.teamRankings.firstWhere(
              (t) =>
                  t.teamName == myTeam.name || t.teamName == myTeam.symplename,
            );
          } catch (_) {}
        }

        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: WHITE,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              SizedBox(
                height: 185,
                child: PageView(
                  controller: _pageController,
                  onPageChanged: (index) =>
                      setState(() => _currentPage = index),
                  children: [
                    _buildRankingPage(
                      title: '개인 순위 TOP 3',
                      top3: top3Individuals
                          .map(
                            (e) => _RankingItemData(
                              name: e.name,
                              score: e.score,
                              rank: e.rank,
                              imageUrl: e.profileUrl,
                            ),
                          )
                          .toList(),
                      myRank: myIndividualRanking != null
                          ? '${myIndividualRanking.rank}위'
                          : '순위 없음',
                      myScore: myIndividualRanking != null
                          ? '${myIndividualRanking.score}점'
                          : '-',
                      myLabel: '내 순위',
                    ),
                    _buildRankingPage(
                      title: '팀 순위 TOP 3',
                      top3: top3Teams.map((e) {
                        final team = teamProvider.findTeamByName(e.teamName);
                        return _RankingItemData(
                          name: team?.symplename ?? e.teamName,
                          score: e.totalScore,
                          rank: e.rank,
                          imagePath: team?.logoPath,
                        );
                      }).toList(),
                      myRank: myTeamRanking != null
                          ? '${myTeamRanking.rank}위'
                          : (myTeam == null ? '팀 선택 필요' : '기록 없음'),
                      myScore: myTeamRanking != null
                          ? '${myTeamRanking.totalScore}점'
                          : '-',
                      myLabel: myTeam != null
                          ? '${myTeam.symplename} 순위'
                          : '내 팀 순위',
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
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
                            ? widget.selectedTeam.color
                            : GRAYSCALE_LABEL_300,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRankingPage({
    required String title,
    required List<_RankingItemData> top3,
    required String myRank,
    required String myScore,
    required String myLabel,
  }) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => QuizTabBar(initialIndex: 3)),
      ),
      child: Container(
        color: Colors.transparent, // 터치 영역 확보
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: GRAYSCALE_LABEL_900,
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: GRAYSCALE_LABEL_400,
                ),
              ],
            ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Rank 2
                if (top3.length > 1)
                  _buildTop3Item(top3[1], 2)
                else
                  const SizedBox(width: 60),
                // Rank 1
                if (top3.isNotEmpty)
                  _buildTop3Item(top3[0], 1)
                else
                  const SizedBox(width: 70),
                // Rank 3
                if (top3.length > 2)
                  _buildTop3Item(top3[2], 3)
                else
                  const SizedBox(width: 60),
              ],
            ),
            const Spacer(),
            const Divider(height: 1, color: Color(0xFFF5F5F5)),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  myLabel,
                  style: const TextStyle(
                    fontSize: 12,
                    color: GRAYSCALE_LABEL_500,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Row(
                  children: [
                    Text(
                      myRank,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: GRAYSCALE_LABEL_900,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      myScore,
                      style: const TextStyle(
                        fontSize: 12,
                        color: GRAYSCALE_LABEL_400,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTop3Item(_RankingItemData data, int rank) {
    double avatarSize = rank == 1 ? 48 : 40;
    Color medalColor = rank == 1
        ? const Color(0xFFFFD700)
        : (rank == 2 ? const Color(0xFFC0C0C0) : const Color(0xFFCD7F32));

    return Column(
      mainAxisSize: MainAxisSize.min,
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
                    color: medalColor.withOpacity(0.2),
                    blurRadius: 4,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: ClipOval(
                child: data.imagePath != null
                    ? Image.asset(data.imagePath!, fit: BoxFit.cover)
                    : (data.imageUrl != null
                          ? Image.network(
                              data.imageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  const Icon(Icons.person, size: 20),
                            )
                          : const Icon(
                              Icons.person,
                              size: 20,
                              color: GRAYSCALE_LABEL_300,
                            )),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: medalColor,
                shape: BoxShape.circle,
              ),
              child: Text(
                '$rank',
                style: const TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                  color: WHITE,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: 70,
          child: Text(
            data.name,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: GRAYSCALE_LABEL_800,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ),
        Text(
          '${data.score}점',
          style: const TextStyle(
            fontSize: 10,
            color: GRAYSCALE_LABEL_500,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

class _RankingItemData {
  final String name;
  final int score;
  final int rank;
  final String? imageUrl;
  final String? imagePath;
  _RankingItemData({
    required this.name,
    required this.score,
    required this.rank,
    this.imageUrl,
    this.imagePath,
  });
}
