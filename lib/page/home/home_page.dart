import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lockerroom/const/color.dart';
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
import 'package:lockerroom/page/intution_record/intution_record_list_page.dart';
import 'package:lockerroom/page/intution_record/intution_record_upload_page.dart';
import 'package:lockerroom/page/schedule/schedule.dart';
import 'package:lockerroom/provider/block_provider.dart';
import 'package:lockerroom/provider/feed_provider.dart';
import 'package:lockerroom/provider/food_store_provider.dart';
import 'package:lockerroom/provider/intution_record_list_provider.dart';
import 'package:lockerroom/provider/notification_provider.dart';
import 'package:lockerroom/provider/profile_provider.dart';
import 'package:lockerroom/provider/team_provider.dart';
import 'package:lockerroom/provider/video_provider.dart';
import 'package:lockerroom/services/schedule_service.dart';
import 'package:lockerroom/utils/media_utils.dart';
import 'package:lockerroom/widgets/network_video_player.dart';
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<FeedProvider>().listenRecentPosts();

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
                      showBadge: ntp.notifications.isNotEmpty,
                      badgeStyle: const badges.BadgeStyle(
                        badgeColor: RED_DANGER_TEXT_50,
                        padding: EdgeInsets.all(5),
                      ),
                      badgeContent: Text(
                        '${ntp.notifications.length}',
                        style: TextStyle(color: WHITE, fontSize: 15),
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
              // IconButton(
              //   onPressed: () {
              //     Navigator.pushNamed(context, 'notifications');
              //   },
              //   icon: Icon(CupertinoIcons.bell, color: WHITE),
              // ),
            ],
          ),
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.only(left: 15.0, right: 15.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  SchedulePage(teamModel: widget.teamModel),
                            ),
                          );
                        },
                        child: Text(
                          '전체일정 보기 >',
                          style: TextStyle(color: GRAYSCALE_LABEL_500),
                        ),
                      ),
                    ],
                  ),
                  FutureBuilder(
                    future: ScheduleService().loadSchedules(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Container(
                          width: double.infinity,
                          height: 200,
                          decoration: BoxDecoration(
                            color: selectedTeam.color,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Center(
                            child: CircularProgressIndicator(color: WHITE),
                          ),
                        );
                      }

                      final schedules = snapshot.data ?? [];
                      final teamName = selectedTeam.symplename;
                      final now = DateTime.now();

                      // 선택 한 팀의 미래 경기만 필터링 하고 정렬
                      final futureGames =
                          schedules
                              .where(
                                (s) =>
                                    (s.homeTeam == teamName ||
                                        s.awayTeam == teamName) &&
                                    s.dateTimeKst.isAfter(now),
                              )
                              .toList()
                            ..sort(
                              (a, b) => a.dateTimeKst.compareTo(b.dateTimeKst),
                            );

                      final nextGame = futureGames.isNotEmpty
                          ? futureGames.first
                          : null;

                      return Stack(
                        children: [
                          Container(
                            width: double.infinity,
                            height: 200,
                            decoration: BoxDecoration(
                              color: selectedTeam.color,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Image.asset(selectedTeam.logoPath),
                          ),
                          Container(
                            width: double.infinity,
                            height: 200,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: Colors.black.withAlpha(120),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(
                              top: 130.0,
                              left: 15,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '주요 경기 일정',
                                  style: TextStyle(
                                    color: WHITE,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (nextGame != null)
                                  Row(
                                    children: [
                                      Text(
                                        '다음경기:',
                                        style: TextStyle(
                                          color: WHITE,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      SizedBox(width: 5),
                                      Text(
                                        '${nextGame.homeTeam} vs ${nextGame.awayTeam}',
                                        style: TextStyle(
                                          color: WHITE,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                if (nextGame == null)
                                  Row(
                                    children: [
                                      Text(
                                        '예정된 경기가 없습니다',
                                        style: TextStyle(color: WHITE),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '최신게시물',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton(
                        onPressed: () => widget.onTabTab(1),
                        child: Text(
                          '모든 게시물 보기 >',
                          style: TextStyle(color: GRAYSCALE_LABEL_500),
                        ),
                      ),
                    ],
                  ),

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
                        listHeight = 246.0; // 미디어 있음
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
                                                  profileProvider
                                                      .subscribeUserProfile(
                                                        post.userId,
                                                      );
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '나의 직관기록',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => IntutionRecordListPage(),
                            ),
                          );
                        },
                        child: Text(
                          '직관기록 더보기 >',
                          style: TextStyle(
                            color: GRAYSCALE_LABEL_500,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  ChangeNotifierProvider(
                    create: (_) =>
                        IntutionRecordListProvider()
                          ..subscribe(autoSetYear: false),
                    child: Consumer2<IntutionRecordListProvider, TeamProvider>(
                      builder: (context, ip, tp, child) {
                        if (ip.isLoading) {
                          final selectedColor =
                              tp.selectedTeam?.color ?? BUTTON;
                          return Center(
                            child: CircularProgressIndicator(
                              color: selectedColor,
                            ),
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
                                    builder: (context) =>
                                        IntutionRecordUploadPage(),
                                  ),
                                );
                              },
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Text(
                                    '아직 직관 기록이 없네요. 첫 직관을 남겨볼까요?',
                                    style: TextStyle(
                                      color: GRAYSCALE_LABEL_600,
                                    ),
                                  ),
                                  SizedBox(height: 10),
                                  Text(
                                    '직관기록 추가 하기 +',
                                    style: TextStyle(color: Colors.black),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }
                        int wins = 0;
                        int losses = 0;
                        int draws = 0;
                        int? _prseScore(dynamic v) =>
                            v is int ? v : int.tryParse('$v');
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
                        // 승률 계산
                        final int totalGames = items.length;
                        final double winRate = totalGames > 0
                            ? (wins / totalGames) * 100
                            : 0;

                        return Column(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: WHITE,
                                borderRadius: BorderRadius.circular(28),
                                boxShadow: [
                                  BoxShadow(
                                    offset: Offset(2, 3),
                                    color: BLACK.withOpacity(0.1),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),

                              child: Padding(
                                padding: const EdgeInsets.all(10.0),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Column(
                                      children: [
                                        Icon(Icons.stadium_outlined),
                                        SizedBox(height: 5),
                                        Text(
                                          '총 경기',
                                          style: TextStyle(
                                            color: GRAYSCALE_LABEL_500,
                                            fontSize: 12,
                                          ),
                                        ),
                                        SizedBox(height: 5),
                                        Text(
                                          '${items.length}',
                                          style: GoogleFonts.robotoMono(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(width: 20),
                                    Container(
                                      width: 0.6,
                                      height: 80,
                                      color: GRAYSCALE_LABEL_300,
                                    ),
                                    SizedBox(width: 20),
                                    Column(
                                      children: [
                                        Icon(
                                          Icons.emoji_events_outlined,
                                          color: Colors.blueAccent,
                                        ),
                                        SizedBox(height: 5),
                                        Text(
                                          '승',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: GRAYSCALE_LABEL_500,
                                          ),
                                        ),
                                        SizedBox(height: 5),
                                        Text(
                                          '$wins',
                                          style: GoogleFonts.robotoMono(
                                            color: Colors.blueAccent,
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(width: 20),
                                    Container(
                                      width: 0.6,
                                      height: 80,
                                      color: GRAYSCALE_LABEL_300,
                                    ),
                                    SizedBox(width: 20),

                                    Column(
                                      children: [
                                        Icon(
                                          Icons.sentiment_dissatisfied_rounded,
                                          color: Colors.redAccent,
                                        ),
                                        SizedBox(height: 5),
                                        Text(
                                          '패',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: GRAYSCALE_LABEL_500,
                                          ),
                                        ),
                                        SizedBox(height: 5),
                                        Text(
                                          '$losses',
                                          style: GoogleFonts.robotoMono(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.redAccent,
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(width: 20),
                                    Container(
                                      width: 0.6,
                                      height: 80,
                                      color: GRAYSCALE_LABEL_300,
                                    ),
                                    SizedBox(width: 20),
                                    Column(
                                      children: [
                                        Transform.translate(
                                          offset: Offset(0, -10),
                                          child: Icon(Icons.minimize_outlined),
                                        ),
                                        SizedBox(height: 5),
                                        Text(
                                          '무',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: GRAYSCALE_LABEL_500,
                                          ),
                                        ),
                                        SizedBox(height: 5),
                                        Text(
                                          '$draws',
                                          style: GoogleFonts.robotoMono(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(width: 20),
                                    Container(
                                      width: 0.6,
                                      height: 80,
                                      color: GRAYSCALE_LABEL_300,
                                    ),
                                    SizedBox(width: 10),
                                    Column(
                                      children: [
                                        Icon(Icons.percent_outlined),
                                        SizedBox(height: 5),
                                        Text(
                                          '승률',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: GRAYSCALE_LABEL_500,
                                          ),
                                        ),
                                        SizedBox(height: 5),
                                        Text(
                                          winRate.toStringAsFixed(1),
                                          style: GoogleFonts.robotoMono(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${selectedTeam.stadium} 푸드존',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
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
                        child: Text(
                          '푸드존 정보 더보기 >',
                          style: TextStyle(
                            color: GRAYSCALE_LABEL_500,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Consumer<FoodStoreProvider>(
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // 가게 이미지
                                      if (store.storePhoto != null)
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          child: Image.asset(
                                            store.storePhoto!,
                                            height: 100,
                                            width: double.infinity,
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                      if (store.storePhoto == null)
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
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
                  ),
                  SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        selectedTeam.youtubeName,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => FullscreenVideoPlayer(
                                videoUrl: selectedTeam.youtubeUrl,
                              ),
                            ),
                          );
                        },
                        child: Text(
                          '더보기 >',
                          style: TextStyle(
                            color: GRAYSCALE_LABEL_500,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
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
}
