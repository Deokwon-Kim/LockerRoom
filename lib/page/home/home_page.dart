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
import 'package:lockerroom/model/team_model.dart';
import 'package:lockerroom/page/feed/feed_detail_page.dart';
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
// import 'package:lockerroom/page/schedule/schedule.dart';
import 'package:lockerroom/provider/block_provider.dart';
import 'package:lockerroom/provider/feed_provider.dart';
import 'package:lockerroom/provider/meetup_provider.dart';
// import 'package:lockerroom/provider/food_store_provider.dart';
import 'package:lockerroom/provider/notification_provider.dart';
import 'package:lockerroom/provider/profile_provider.dart';
import 'package:lockerroom/provider/team_provider.dart';
import 'package:lockerroom/provider/video_provider.dart';
import 'package:lockerroom/model/ranking_team_model.dart';
import 'package:lockerroom/provider/quiz_ranking_provider.dart';
// import 'package:lockerroom/provider/schdule_Provider.dart';
// import 'package:lockerroom/utils/quiz_season_utils.dart';
import 'package:lockerroom/provider/intution_record_list_provider.dart';
import 'package:lockerroom/page/intution_record/intution_record_upload_page.dart';
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
              style: const TextStyle(
                color: WHITE,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
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
                        style: const TextStyle(color: WHITE, fontSize: 12),
                      ),
                      child: IconButton(
                        onPressed: () => Navigator.pushNamed(context, '알림센터'),
                        icon: const Icon(CupertinoIcons.bell, color: WHITE),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          body: Stack(
            children: [
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: BACKGROUND_COLOR,
                    gradient: RadialGradient(
                      center: const Alignment(0, -0.6),
                      radius: 1.2,
                      colors: [
                        selectedTeam.color.withOpacity(0.08),
                        BACKGROUND_COLOR,
                      ],
                    ),
                  ),
                ),
              ),

              SingleChildScrollView(
                child: Column(
                  children: [
                    // _buildMyStatusBar(selectedTeam),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // _buildMatchCard(context, selectedTeam),
                          // const SizedBox(height: 24),
                          _QuizRankingDashboard(selectedTeam: selectedTeam),
                          const SizedBox(height: 12),
                          // _buildSectionHeader('나의 직관 기록 🏟'),
                          const SizedBox(height: 12),
                          _buildIntutionRecord(),
                          const SizedBox(height: 24),
                          _buildMeetupSection(context, selectedTeam),
                          const SizedBox(height: 24),
                          _buildFeedSection(context, selectedTeam),
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

  // Widget _buildMatchCard(BuildContext context, TeamModel selectedTeam) {
  //   return Consumer<ScheduleProvider>(
  //     builder: (context, scheduleProvider, child) {
  //       if (!scheduleProvider.loaded) {
  //         return Container(
  //           width: double.infinity,
  //           height: 120,
  //           decoration: BoxDecoration(
  //             color: selectedTeam.color.withOpacity(0.3),
  //             borderRadius: BorderRadius.circular(18),
  //           ),
  //           child: const Center(child: CircularProgressIndicator(color: WHITE)),
  //         );
  //       }
  //       final schedules = scheduleProvider.allSchedules;
  //       final teamName = selectedTeam.symplename;
  //       final now = DateTime.now();
  //       final relatedGames = schedules.where((s) {
  //         final isMyTeam = s.homeTeam == teamName || s.awayTeam == teamName;
  //         if (!isMyTeam) return false;
  //         if (s.status == 'FINAL' || s.status == 'PPD') return false;
  //         return s.status == 'LIVE' || s.dateTimeKst.isAfter(now);
  //       }).toList();
  //       relatedGames.sort((a, b) {
  //         if (a.status == 'LIVE' && b.status != 'LIVE') return -1;
  //         if (a.status != 'LIVE' && b.status == 'LIVE') return 1;
  //         return a.dateTimeKst.compareTo(b.dateTimeKst);
  //       });
  //       final activeGame = relatedGames.isNotEmpty ? relatedGames.first : null;
  //       final isLive = activeGame?.status == 'LIVE';

  //       return GestureDetector(
  //         onTap: () => Navigator.push(
  //           context,
  //           MaterialPageRoute(
  //             builder: (context) => SchedulePage(teamModel: widget.teamModel),
  //           ),
  //         ),
  //         child: Container(
  //           width: double.infinity,
  //           height: 130,
  //           decoration: BoxDecoration(
  //             gradient: LinearGradient(
  //               colors: [
  //                 selectedTeam.color,
  //                 selectedTeam.color.withOpacity(0.8),
  //               ],
  //               begin: Alignment.topLeft,
  //               end: Alignment.bottomRight,
  //             ),
  //             borderRadius: BorderRadius.circular(18),
  //             boxShadow: [
  //               BoxShadow(
  //                 color: selectedTeam.color.withOpacity(0.3),
  //                 blurRadius: 15,
  //                 offset: const Offset(0, 8),
  //               ),
  //             ],
  //           ),
  //           child: Stack(
  //             children: [
  //               Positioned(
  //                 right: -10,
  //                 bottom: -10,
  //                 child: Opacity(
  //                   opacity: 0.15,
  //                   child: Image.asset(selectedTeam.logoPath, height: 110),
  //                 ),
  //               ),
  //               Padding(
  //                 padding: const EdgeInsets.symmetric(
  //                   horizontal: 20.0,
  //                   vertical: 16.0,
  //                 ),
  //                 child: Row(
  //                   children: [
  //                     Expanded(
  //                       child: Column(
  //                         mainAxisAlignment: MainAxisAlignment.center,
  //                         crossAxisAlignment: CrossAxisAlignment.start,
  //                         children: [
  //                           Container(
  //                             padding: const EdgeInsets.symmetric(
  //                               horizontal: 8,
  //                               vertical: 4,
  //                             ),
  //                             decoration: BoxDecoration(
  //                               color: isLive
  //                                   ? RED_DANGER_TEXT_50
  //                                   : Colors.white24,
  //                               borderRadius: BorderRadius.circular(6),
  //                             ),
  //                             child: Text(
  //                               isLive ? 'LIVE' : 'UPCOMING MATCH',
  //                               style: const TextStyle(
  //                                 color: WHITE,
  //                                 fontSize: 11,
  //                                 fontWeight: FontWeight.bold,
  //                               ),
  //                             ),
  //                           ),
  //                           const SizedBox(height: 10),
  //                           if (isLive)
  //                             Row(
  //                               children: [
  //                                 Text(
  //                                   '${activeGame!.awayTeam} ${activeGame.awayScore}',
  //                                   style: const TextStyle(
  //                                     fontFamily: 'kbo',
  //                                     color: WHITE,
  //                                     fontSize: 22,
  //                                     fontWeight: FontWeight.bold,
  //                                   ),
  //                                 ),
  //                                 const Padding(
  //                                   padding: EdgeInsets.symmetric(
  //                                     horizontal: 10.0,
  //                                   ),
  //                                   child: Text(
  //                                     ':',
  //                                     style: TextStyle(
  //                                       color: WHITE,
  //                                       fontSize: 22,
  //                                       fontWeight: FontWeight.bold,
  //                                     ),
  //                                   ),
  //                                 ),
  //                                 Text(
  //                                   '${activeGame.homeScore} ${activeGame.homeTeam}',
  //                                   style: const TextStyle(
  //                                     fontFamily: 'kbo',
  //                                     color: WHITE,
  //                                     fontSize: 22,
  //                                     fontWeight: FontWeight.bold,
  //                                   ),
  //                                 ),
  //                               ],
  //                             )
  //                           else
  //                             Text(
  //                               activeGame != null
  //                                   ? '${activeGame.homeTeam} vs ${activeGame.awayTeam}'
  //                                   : 'No matches scheduled',
  //                               style: const TextStyle(
  //                                 fontFamily: 'kbo',
  //                                 color: WHITE,
  //                                 fontSize: 22,
  //                                 fontWeight: FontWeight.bold,
  //                               ),
  //                             ),
  //                           if (activeGame != null)
  //                             Text(
  //                               isLive
  //                                   ? '${activeGame.inning} | ${activeGame.stadium}'
  //                                   : '${DateFormat('MM.dd E HH:mm', 'ko').format(activeGame.dateTimeKst)}  ${activeGame.stadium}',
  //                               style: TextStyle(
  //                                 color: WHITE.withOpacity(0.9),
  //                                 fontSize: 12,
  //                                 fontWeight: FontWeight.w500,
  //                               ),
  //                             ),
  //                         ],
  //                       ),
  //                     ),
  //                     const Icon(
  //                       Icons.arrow_forward_ios,
  //                       color: WHITE,
  //                       size: 20,
  //                     ),
  //                   ],
  //                 ),
  //               ),
  //             ],
  //           ),
  //         ),
  //       );
  //     },
  //   );
  // }

  Widget _buildSectionHeader(String title, {VoidCallback? onSeeAll}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: GoogleFonts.gothicA1(
            fontSize: 16,
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
        final posts = feedProvider.posts;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('실시간 야구 커뮤니티'),
            const SizedBox(height: 12),
            if (posts.isEmpty)
              _buildEmptyCard('최근 게시물이 존재하지 않습니다')
            else ...[
              _buildFeedHighlightCard(context, posts.first),
              const SizedBox(height: 16),
              _buildSecondaryButton(
                label: '커뮤니티 전체 소식 보기',
                onPressed: () => widget.onTabTab(1),
              ),
            ],
          ],
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

        return GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => FeedDetailPage(post: post)),
          ),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                    Text(
                      authorName,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      DateFormat('M.d HH:mm').format(post.createdAt),
                      style: TextStyle(
                        fontSize: 11,
                        color: GRAYSCALE_LABEL_400,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  post.text,
                  style: const TextStyle(fontSize: 14, height: 1.5),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (post.mediaUrls.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      post.mediaUrls.first,
                      width: double.infinity,
                      height: 180,
                      fit: BoxFit.cover,
                    ),
                  ),
                ],
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
                  IconButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => IntutionTabBar(),
                        ),
                      );
                    },
                    icon: Icon(
                      Icons.arrow_forward_ios_outlined,
                      color: GRAYSCALE_LABEL_500,
                      size: 18,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => IntutionTabBar()),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 30,
                  ),
                  decoration: BoxDecoration(
                    color: WHITE,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: teamColor.withOpacity(0.08),
                        blurRadius: 40,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // 왼쪽: 총 경기 & 승리
                      Column(
                        children: [
                          _buildMiniStat('총 경기', '$totalGames', teamColor),
                          const SizedBox(height: 24),
                          _buildMiniStat('승리', '$wins', Colors.blueAccent),
                        ],
                      ),
                      // 중앙: 승률 게이지
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 110,
                            height: 110,
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
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800,
                                  color: GRAYSCALE_LABEL_900,
                                ),
                              ),
                              const Text(
                                '승률',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: GRAYSCALE_LABEL_500,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      // 오른쪽: 패배 & 무승부
                      Column(
                        children: [
                          _buildMiniStat('패배', '$losses', Colors.redAccent),
                          const SizedBox(height: 24),
                          _buildMiniStat('무승부', '$draws', GRAYSCALE_LABEL_400),
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
    );
  }

  Widget _buildMiniStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: GRAYSCALE_LABEL_500,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
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

class _QuizRankingDashboard extends StatefulWidget {
  final TeamModel selectedTeam;
  const _QuizRankingDashboard({required this.selectedTeam});

  @override
  State<_QuizRankingDashboard> createState() => _QuizRankingDashboardState();
}

class _QuizRankingDashboardState extends State<_QuizRankingDashboard> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startAutoSlide();
  }

  void _startAutoSlide() {
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_pageController.hasClients) {
        int nextPage = (_currentPage + 1) % 2;
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
    const goldColor = Color(0xFFE9C46A);
    return Consumer2<QuizRankingProvider, TeamProvider>(
      builder: (context, rankProvider, teamProvider, _) {
        final currentUserId = FirebaseAuth.instance.currentUser?.uid;
        final myTeam = teamProvider.selectedTeam;

        final top3Individuals = rankProvider.rankings.take(3).toList();
        final myIndividualRanking = currentUserId != null
            ? rankProvider.getMyRanking(currentUserId)
            : null;
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
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              children: [
                // 배경 그라데이션
                Positioned.fill(
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF1A1A1A), Color(0xFF2C2C2C)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
                ),
                // 배경 트로피 이미지
                Positioned.fill(
                  child: Center(
                    child: Opacity(
                      opacity: 0.15,
                      child: Image.asset(
                        'assets/images/quiz/quiz_trophy_champion2.png',
                        height: 280, // 전체 대시보드 내에서 적절한 크기로 조정
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
                // 콘텐츠
                Column(
                  children: [
                    // 상단 퀴즈 배너 영역
                    GestureDetector(
                      onTap: () =>
                          Navigator.of(context, rootNavigator: true).push(
                            MaterialPageRoute(
                              builder: (context) => QuizTabBar(initialIndex: 0),
                            ),
                          ),
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: goldColor,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'BEST FAN CHALLENGE',
                                      style: TextStyle(
                                        color: Color(0xFF1A1A1A),
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  const Text(
                                    '야구 덕력 테스트! 퀴즈 풀기',
                                    style: TextStyle(
                                      fontFamily: 'kbo',
                                      color: WHITE,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.play_circle_filled_rounded,
                              color: goldColor,
                              size: 32,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const Divider(height: 1, color: Colors.white10),

                    // 하단 랭킹 영역
                    SizedBox(
                      height: 180,
                      child:
                          rankProvider.isLoading &&
                              rankProvider.rankings.isEmpty
                          ? const Center(
                              child: CircularProgressIndicator(
                                color: goldColor,
                              ),
                            )
                          : PageView(
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
                                  myLabel: '내 개인 순위',
                                  isDark: true,
                                ),
                                _buildRankingPage(
                                  title: '팀 순위 TOP 3',
                                  top3: top3Teams.map((e) {
                                    final team = teamProvider.findTeamByName(
                                      e.teamName,
                                    );
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
                                  isDark: true,
                                ),
                              ],
                            ),
                    ),

                    // 인디케이터
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
                                  ? goldColor
                                  : Colors.white24,
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
    bool isDark = false,
  }) {
    return GestureDetector(
      onTap: () => Navigator.of(
        context,
        rootNavigator: true,
      ).push(MaterialPageRoute(builder: (_) => QuizTabBar(initialIndex: 3))),
      child: Container(
        color: Colors.transparent,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white70 : GRAYSCALE_LABEL_900,
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  size: 16,
                  color: isDark ? Colors.white38 : GRAYSCALE_LABEL_400,
                ),
              ],
            ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (top3.length > 1)
                  _buildTop3Item(top3[1], 2, isDark: isDark)
                else
                  const SizedBox(width: 60),
                if (top3.isNotEmpty)
                  _buildTop3Item(top3[0], 1, isDark: isDark)
                else
                  const SizedBox(width: 70),
                if (top3.length > 2)
                  _buildTop3Item(top3[2], 3, isDark: isDark)
                else
                  const SizedBox(width: 60),
              ],
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withOpacity(0.05)
                    : const Color(0xFFF8F9FA),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    myLabel,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white54 : GRAYSCALE_LABEL_500,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        myRank,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : GRAYSCALE_LABEL_900,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        myScore,
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.white38 : GRAYSCALE_LABEL_400,
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
  }

  Widget _buildTop3Item(
    _RankingItemData data,
    int rank, {
    bool isDark = false,
  }) {
    double avatarSize = rank == 1 ? 44 : 38;
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
                          : Icon(
                              Icons.person,
                              size: 20,
                              color: isDark
                                  ? Colors.white24
                                  : GRAYSCALE_LABEL_300,
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
                  fontSize: 7,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A1A),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: 60,
          child: Text(
            data.name,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : GRAYSCALE_LABEL_800,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ),
        Text(
          '${data.score}점',
          style: TextStyle(
            fontSize: 9,
            color: isDark ? Colors.white38 : GRAYSCALE_LABEL_500,
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
