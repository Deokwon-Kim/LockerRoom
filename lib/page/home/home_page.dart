import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/model/team_model.dart';
import 'package:lockerroom/page/schedule/schedule.dart';
import 'package:lockerroom/provider/feed_provider.dart';
import 'package:lockerroom/provider/team_provider.dart';
import 'package:lockerroom/provider/video_provider.dart';
import 'package:lockerroom/services/schedule_service.dart';
import 'package:lockerroom/utils/media_utils.dart';
import 'package:lockerroom/widgets/network_video_thumbnail.dart';
import 'package:provider/provider.dart';
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
              child: Image.asset(selectedTeam.symbolPath),
            ),
            scrolledUnderElevation: 0,
            title: Text(
              selectedTeam.name,
              style: TextStyle(
                color: WHITE,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),

            actions: [
              IconButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                icon: Icon(CupertinoIcons.bell, color: WHITE),
              ),
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
                                if (nextGame != null) ...[
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
                                      // Text(
                                      //   '${nextGame.dateTimeKst.month.toString().padLeft(2, '0')}/${nextGame.dateTimeKst.day.toString().padLeft(2, '0')} ${nextGame.dateTimeKst.hour.toString().padLeft(2, '0')}:${nextGame.dateTimeKst.minute.toString().padLeft(2, '0')}',
                                      //   style: TextStyle(
                                      //     color: WHITE,
                                      //     fontSize: 14,
                                      //     fontWeight: FontWeight.w400,
                                      //   ),
                                      // ),
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
                                ],
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
                      return SizedBox(
                        height: 245,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: posts.length,
                          itemBuilder: (context, index) {
                            final post = posts[index];
                            return Container(
                              width: 240,
                              margin: const EdgeInsets.only(right: 12),
                              child: Card(
                                color: WHITE,
                                child: Padding(
                                  padding: EdgeInsets.all(15.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (post.mediaUrls.isNotEmpty)
                                        SizedBox(
                                          height: 150,
                                          child: ListView.builder(
                                            scrollDirection: Axis.horizontal,
                                            itemCount: post.mediaUrls.length,
                                            itemBuilder: (_, i) {
                                              final url = post.mediaUrls[i];
                                              final inSingle =
                                                  post.mediaUrls.length == 1;
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
                                                      BorderRadius.circular(8),
                                                  child: isVideo
                                                      ? NetworkVideoThumbnail(
                                                          videoUrl: url,
                                                          width: inSingle
                                                              ? 100
                                                              : 50,
                                                          height: 150,
                                                        )
                                                      : Image.network(
                                                          url,
                                                          height: 150,
                                                          width: inSingle
                                                              ? 200
                                                              : 150,
                                                          fit: inSingle
                                                              ? BoxFit.cover
                                                              : BoxFit.cover,
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
                                                                  height: 150,
                                                                  width:
                                                                      inSingle
                                                                      ? 200
                                                                      : 150,
                                                                  child: const Center(
                                                                    child: CircularProgressIndicator(
                                                                      color:
                                                                          BUTTON,
                                                                    ),
                                                                  ),
                                                                );
                                                              },
                                                        ),
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      SizedBox(height: 10),
                                      Text(
                                        post.text,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w500,
                                          fontSize: 16,
                                        ),
                                      ),
                                      SizedBox(height: 3),
                                      Text(
                                        post.userName,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: GRAYSCALE_LABEL_400,
                                          fontWeight: FontWeight.w500,
                                        ),
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
                          launchUrl(
                            Uri.parse(selectedTeam.youtubeUrl),
                            mode: LaunchMode.externalApplication,
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
                        return const Center(
                          child: CircularProgressIndicator(color: BUTTON),
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
}
