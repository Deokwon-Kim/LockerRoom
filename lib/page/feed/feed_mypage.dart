import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/model/post_model.dart';
import 'package:lockerroom/model/team_model.dart';
import 'package:lockerroom/page/alert/diallog.dart';
import 'package:lockerroom/page/feed/feed_detail_page.dart';
import 'package:lockerroom/provider/feed_provider.dart';
import 'package:lockerroom/provider/follow_provider.dart';
import 'package:lockerroom/provider/profile_provider.dart';
import 'package:lockerroom/provider/team_provider.dart';
import 'package:lockerroom/utils/media_utils.dart';
import 'package:lockerroom/widgets/network_video_player.dart';
import 'package:provider/provider.dart';
import 'package:toastification/toastification.dart';

class FeedMypage extends StatefulWidget {
  final PostModel post;
  final String targetUserId;
  const FeedMypage({super.key, required this.post, required this.targetUserId});

  @override
  State<FeedMypage> createState() => _FeedMypageState();
}

class _FeedMypageState extends State<FeedMypage> {
  String timeAgo(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inSeconds < 60) return '${diff.inSeconds}s 전';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    return '${diff.inDays}일 전';
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final feedProvider = Provider.of<FeedProvider>(context, listen: false);
    final fp = context.watch<FollowProvider>();
    final tp = context.watch<TeamProvider>();
    final teamColor = tp.selectedTeam?.color;
    return Scaffold(
      backgroundColor: BACKGROUND_COLOR,
      appBar: AppBar(
        backgroundColor: BACKGROUND_COLOR,
        scrolledUnderElevation: 0,
        title: Transform.translate(
          offset: Offset(-20, 0),
          child: Row(
            children: [
              Text(
                widget.post.userName,
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(width: 5),
              StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(widget.targetUserId)
                    .snapshots(),
                builder: (context, snap) {
                  if (!snap.hasData) return const SizedBox.shrink();
                  final data = snap.data!.data();
                  final teamName = data?['team'] as String?;
                  if (teamName == null || teamName.isEmpty)
                    return const SizedBox.shrink();

                  final teams = context.read<TeamProvider>().getTeam('team');
                  TeamModel? teamModel;
                  try {
                    teamModel = teams.firstWhere(
                      (t) => t.name == teamName || t.symplename == teamName,
                    );
                  } catch (_) {}

                  return Transform.translate(
                    offset: Offset(0, 5),
                    child: Text(
                      teamName,
                      style: TextStyle(
                        fontSize: 12,
                        color: teamModel?.color,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        centerTitle: false,
        actions: [
          if (currentUserId != widget.targetUserId)
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: GestureDetector(
                onTap: () => fp.toggleFollow(widget.targetUserId),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 5, vertical: 5),
                  decoration: BoxDecoration(
                    color: fp.isFollowing ? BACKGROUND_COLOR : teamColor,
                    border: Border.all(color: Colors.black),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    fp.isFollowing ? '팔로잉' : '팔로우',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: fp.isFollowing ? Colors.black : Colors.white,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Consumer<ProfileProvider>(
                  builder: (context, pt, child) {
                    final profileUrl = pt.userProfiles[widget.post.userId];
                    return CircleAvatar(
                      radius: 35,
                      backgroundImage: profileUrl != null
                          ? NetworkImage(profileUrl)
                          : null,
                      backgroundColor: GRAYSCALE_LABEL_300,
                      child: profileUrl == null
                          ? const Icon(
                              Icons.person,
                              color: Colors.black,
                              size: 25,
                            )
                          : null,
                    );
                  },
                ),
                SizedBox(width: 20),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.post.userName,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 10),
                    Row(
                      children: [
                        StreamBuilder<List<PostModel>>(
                          stream: context.read<FeedProvider>().listenUserPosts(
                            widget.post.userId,
                          ),
                          builder: (context, snapshot) {
                            final count = (snapshot.data ?? const []).length;
                            return Column(
                              children: [Text('$count'), Text('게시물')],
                            );
                          },
                        ),

                        SizedBox(width: 50),
                        StreamBuilder<int>(
                          stream: fp.getFollowersCountStream(
                            widget.targetUserId,
                          ),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) {
                              final color =
                                  context
                                      .read<TeamProvider>()
                                      .selectedTeam
                                      ?.color ??
                                  BUTTON;
                              return CircularProgressIndicator(color: color);
                            }
                            return Column(
                              children: [Text('${snapshot.data}'), Text("팔로워")],
                            );
                          },
                        ),
                        SizedBox(width: 50),
                        StreamBuilder<int>(
                          stream: fp.getFollowCountStream(widget.targetUserId),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) {
                              final color =
                                  context
                                      .read<TeamProvider>()
                                      .selectedTeam
                                      ?.color ??
                                  BUTTON;
                              return CircularProgressIndicator(color: color);
                            }
                            return Column(
                              children: [Text('${snapshot.data}'), Text('팔로잉')],
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: 30),
            Expanded(
              child: StreamBuilder<List<PostModel>>(
                stream: context.read<FeedProvider>().listenUserPosts(
                  widget.post.userId,
                ),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    final color =
                        context.read<TeamProvider>().selectedTeam?.color ??
                        BUTTON;
                    return Center(
                      child: CircularProgressIndicator(color: color),
                    );
                  }
                  final posts = snapshot.data!;
                  if (posts.isEmpty) {
                    return const Center(child: Text('작성한 게시물이 없습니다'));
                  }
                  return ListView.builder(
                    itemCount: posts.length,
                    itemBuilder: (_, i) {
                      final p = posts[i];
                      return GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => FeedDetailPage(post: p),
                            ),
                          );
                        },
                        child: Card(
                          color: WHITE,
                          child: Padding(
                            padding: EdgeInsets.all(15),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Consumer<ProfileProvider>(
                                      builder: (context, pd, child) {
                                        pd.subscribeUserProfile(
                                          widget.post.userId,
                                        );

                                        final profileUrl =
                                            pd.userProfiles[widget.post.userId];
                                        return CircleAvatar(
                                          radius: 25,
                                          backgroundImage: profileUrl != null
                                              ? NetworkImage(profileUrl)
                                              : null,
                                          backgroundColor: GRAYSCALE_LABEL_300,
                                          child: profileUrl == null
                                              ? const Icon(
                                                  Icons.person,
                                                  color: Colors.black,
                                                  size: 25,
                                                )
                                              : null,
                                        );
                                      },
                                    ),
                                    SizedBox(width: 10),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          widget.post.userName,
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        Text(
                                          timeAgo(widget.post.createdAt),
                                          style: TextStyle(
                                            color: GRAYSCALE_LABEL_500,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Spacer(),
                                    currentUserId != null &&
                                            widget.post.userId == currentUserId
                                        ? PopupMenuTheme(
                                            data: PopupMenuThemeData(
                                              color: BACKGROUND_COLOR,
                                            ),
                                            child: PopupMenuButton<String>(
                                              icon: Icon(Icons.more_horiz),
                                              onSelected: (value) async {
                                                if (value == 'delete') {
                                                  // 삭제확인 다이얼로그
                                                  showDialog(
                                                    context: context,
                                                    builder: (context) =>
                                                        ConfirmationDialog(
                                                          title: '삭제 확인',
                                                          content:
                                                              '게시글을 삭제 하시겠습니까?',
                                                          onConfirm: () async {
                                                            await feedProvider
                                                                .deletePost(
                                                                  widget.post,
                                                                );
                                                            toastification.show(
                                                              context: context,
                                                              type:
                                                                  ToastificationType
                                                                      .success,
                                                              alignment: Alignment
                                                                  .bottomCenter,
                                                              autoCloseDuration:
                                                                  Duration(
                                                                    seconds: 2,
                                                                  ),
                                                              title: Text(
                                                                '게시물을 삭제했습니다',
                                                              ),
                                                            );
                                                          },
                                                        ),
                                                  );
                                                }
                                              },
                                              itemBuilder: (context) => const [
                                                PopupMenuItem(
                                                  value: 'delete',
                                                  child: Text(
                                                    '삭제하기',
                                                    style: TextStyle(
                                                      color: RED_DANGER_TEXT_50,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          )
                                        : SizedBox.shrink(),
                                  ],
                                ),
                                SizedBox(height: 8),
                                // 본문
                                Text(p.text),
                                SizedBox(height: 8),
                                // 이미지/영상 슬라이드
                                if (p.mediaUrls.isNotEmpty)
                                  LayoutBuilder(
                                    builder: (context, constraints) {
                                      final bool inSingle =
                                          widget.post.mediaUrls.length == 1;
                                      final double avilableWidth =
                                          constraints.maxWidth;
                                      // 리스트 높이와 각 아이템 너비를 화면/가용 폭 기준으로 계산
                                      final double listHeight =
                                          (avilableWidth * 0.55).clamp(
                                            160,
                                            320,
                                          );
                                      final double itemWidth = inSingle
                                          ? avilableWidth
                                          : (avilableWidth * 0.48).clamp(
                                              140,
                                              avilableWidth,
                                            );

                                      return SizedBox(
                                        height: listHeight,
                                        child: ListView.builder(
                                          scrollDirection: Axis.horizontal,
                                          itemCount: p.mediaUrls.length,
                                          itemBuilder: (_, i) {
                                            final url = p.mediaUrls[i];
                                            final isVideo =
                                                MediaUtils.isVideoFromPost(
                                                  widget.post,
                                                  i,
                                                );
                                            return Padding(
                                              padding: EdgeInsets.only(
                                                left: 0,
                                                right: inSingle ? 0 : 8,
                                              ),
                                              child: ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                child: isVideo
                                                    ? NetworkVideoPlayer(
                                                        videoUrl: url,
                                                        width: itemWidth,
                                                        height: listHeight,
                                                        fit: BoxFit.cover,
                                                        autoPlay: true,
                                                        muted: true,
                                                        showControls: false,
                                                      )
                                                    : Image.network(
                                                        url,
                                                        height: listHeight,
                                                        width: itemWidth,
                                                        fit: BoxFit.cover,
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
                                                              final color =
                                                                  context
                                                                      .read<
                                                                        TeamProvider
                                                                      >()
                                                                      .selectedTeam
                                                                      ?.color ??
                                                                  BUTTON;
                                                              return SizedBox(
                                                                height:
                                                                    listHeight,
                                                                width:
                                                                    itemWidth,
                                                                child: Center(
                                                                  child:
                                                                      CircularProgressIndicator(
                                                                        color:
                                                                            color,
                                                                      ),
                                                                ),
                                                              );
                                                            },
                                                      ),
                                              ),
                                            );
                                          },
                                        ),
                                      );
                                    },
                                  ),
                                SizedBox(height: 8),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
