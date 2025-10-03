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

class UserDetailPage extends StatefulWidget {
  final String targetUserId;
  final PostModel? post;
  const UserDetailPage({super.key, required this.targetUserId, this.post});

  @override
  State<UserDetailPage> createState() => _UserDetailPageState();
}

class _UserDetailPageState extends State<UserDetailPage> {
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
    final fp = context.watch<FollowProvider>();
    final feedProvider = context.watch<FeedProvider>();
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(widget.targetUserId)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData)
          return Center(child: CircularProgressIndicator(color: BUTTON));
        final data = snap.data!.data() ?? {};
        final name = (data['username'] as String?) ?? '';
        final teamName = data['team'] as String?;
        if (teamName == null || teamName.isEmpty)
          return const SizedBox.shrink();

        final teams = context.read<TeamProvider>().getTeam('team');
        TeamModel? teamModel;
        try {
          teamModel = teams.firstWhere(
            (t) => t.name == teamName || t.symplename == teamName,
          );
        } catch (_) {}
        final imageUrl = (data['profileImage'] as String?) ?? '';

        return Scaffold(
          backgroundColor: BACKGROUND_COLOR,
          appBar: AppBar(
            backgroundColor: BACKGROUND_COLOR,
            title: Row(
              children: [
                Transform.translate(
                  offset: Offset(-15, 0),
                  child: Text(
                    name,
                    style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
                  ),
                ),
                SizedBox(width: 5),
                Transform.translate(
                  offset: Offset(-15, 5),
                  child: Text(
                    teamName,
                    style: TextStyle(
                      color: teamModel?.color,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundImage: imageUrl.isNotEmpty
                          ? NetworkImage(imageUrl)
                          : null,
                      child: imageUrl.isEmpty ? const Icon(Icons.person) : null,
                    ),
                    SizedBox(width: 20),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 5),
                        Row(
                          children: [
                            StreamBuilder<List<PostModel>>(
                              stream: context
                                  .read<FeedProvider>()
                                  .listenUserPosts(widget.targetUserId),
                              builder: (context, snapshot) {
                                final count =
                                    (snapshot.data ?? const []).length;
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
                                if (!snapshot.hasData)
                                  return CircularProgressIndicator();
                                return Column(
                                  children: [
                                    Text('${snapshot.data}'),
                                    Text("팔로워"),
                                  ],
                                );
                              },
                            ),
                            SizedBox(width: 50),
                            StreamBuilder<int>(
                              stream: fp.getFollowCountStream(
                                widget.targetUserId,
                              ),
                              builder: (context, snapshot) {
                                if (!snapshot.hasData)
                                  return CircularProgressIndicator();
                                return Column(
                                  children: [
                                    Text('${snapshot.data}'),
                                    Text('팔로잉'),
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
                Expanded(
                  child: StreamBuilder<List<PostModel>>(
                    stream: context.read<FeedProvider>().listenUserPosts(
                      widget.targetUserId,
                    ),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(
                          child: CircularProgressIndicator(color: BUTTON),
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
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Consumer<ProfileProvider>(
                                          builder: (context, pd, child) {
                                            pd.subscribeUserProfile(
                                              widget.targetUserId,
                                            );

                                            final profileUrl =
                                                pd.userProfiles[widget
                                                    .targetUserId];
                                            return CircleAvatar(
                                              radius: 25,
                                              backgroundImage:
                                                  profileUrl != null
                                                  ? NetworkImage(profileUrl)
                                                  : null,
                                              backgroundColor:
                                                  GRAYSCALE_LABEL_300,
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
                                              name,
                                              style: TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            Text(
                                              timeAgo(widget.post!.createdAt),
                                              style: TextStyle(
                                                color: GRAYSCALE_LABEL_500,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ],
                                        ),
                                        Spacer(),
                                        currentUserId != null &&
                                                widget.targetUserId ==
                                                    currentUserId
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
                                                        builder: (context) => ConfirmationDialog(
                                                          title: '삭제 확인',
                                                          content:
                                                              '게시글을 삭제 하시겠습니까?',
                                                          onConfirm: () async {
                                                            await feedProvider
                                                                .deletePost(
                                                                  widget.post!,
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
                                                          color:
                                                              RED_DANGER_TEXT_50,
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
                                              widget.post!.mediaUrls.length ==
                                              1;
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
                                                      widget.post!,
                                                      i,
                                                    );
                                                return Padding(
                                                  padding: EdgeInsets.only(
                                                    left: 0,
                                                    right: inSingle ? 0 : 8,
                                                  ),
                                                  child: ClipRRect(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
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
                                                                  return SizedBox(
                                                                    height:
                                                                        listHeight,
                                                                    width:
                                                                        itemWidth,
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
      },
    );
  }
}
