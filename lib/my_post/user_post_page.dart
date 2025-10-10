import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/model/post_model.dart';
import 'package:lockerroom/page/alert/diallog.dart';
import 'package:lockerroom/page/feed/feed_detail_page.dart';
import 'package:lockerroom/provider/feed_provider.dart';
import 'package:lockerroom/provider/team_provider.dart';
import 'package:lockerroom/utils/media_utils.dart';
import 'package:lockerroom/widgets/network_video_player.dart';
import 'package:provider/provider.dart';
import 'package:toastification/toastification.dart';

class UserPostPage extends StatefulWidget {
  final String userId;
  final PostModel? post;
  const UserPostPage({super.key, required this.userId, this.post});

  @override
  State<UserPostPage> createState() => _UserPostPageState();
}

class _UserPostPageState extends State<UserPostPage> {
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
    final tp = context.watch<TeamProvider>();
    final teamColor = tp.selectedTeam?.color;

    final feedProvider = context.watch<FeedProvider>();
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          final color =
              context.read<TeamProvider>().selectedTeam?.color ?? BUTTON;
          return Center(child: CircularProgressIndicator(color: color));
        }
        final data = snap.data!.data() ?? {};

        final imageUrl = (data['profileImage'] as String?) ?? '';
        return Scaffold(
          backgroundColor: BACKGROUND_COLOR,
          body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('posts')
                .where('userId', isEqualTo: widget.userId)
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snap) {
              if (!snap.hasData)
                return Center(
                  child: CircularProgressIndicator(color: teamColor),
                );
              final posts = snap.data!.docs
                  .map((d) => PostModel.fromDoc(d))
                  .toList();

              if (posts.isEmpty) return Center(child: Text('게시물이 없습니다'));

              return ListView.builder(
                itemCount: posts.length,
                itemBuilder: (_, i) {
                  final p = posts[i];
                  return Padding(
                    padding: const EdgeInsets.all(10.0),
                    child: GestureDetector(
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
                                  CircleAvatar(
                                    backgroundColor: GRAYSCALE_LABEL_300,
                                    radius: 25,
                                    backgroundImage: imageUrl.isNotEmpty
                                        ? NetworkImage(imageUrl)
                                        : null,
                                    child: imageUrl.isEmpty
                                        ? const Icon(
                                            Icons.person,
                                            color: Colors.black,
                                          )
                                        : null,
                                  ),
                                  SizedBox(width: 10),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        p.userName,
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      Text(
                                        timeAgo(p.createdAt),
                                        style: TextStyle(
                                          color: GRAYSCALE_LABEL_500,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Spacer(),
                                  currentUserId != null &&
                                          p.userId == currentUserId
                                      ? PopupMenuTheme(
                                          data: PopupMenuThemeData(
                                            color: BACKGROUND_COLOR,
                                          ),
                                          child: PopupMenuButton<String>(
                                            icon: Icon(Icons.more_horiz),
                                            onSelected: (value) async {
                                              // 삭제확인 다이얼로그
                                              showDialog(
                                                context: context,
                                                builder: (context) =>
                                                    ConfirmationDialog(
                                                      title: '삭제확인',
                                                      content:
                                                          '게시글을 삭제 하시겠습니까?',
                                                      onConfirm: () async {
                                                        await feedProvider
                                                            .deletePost(p);
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
                                  builder: (context, constraint) {
                                    final bool inSingle =
                                        p.mediaUrls.length == 1;
                                    final double avilableWidth =
                                        constraint.maxWidth;
                                    final double listHeight =
                                        (avilableWidth * 0.55).clamp(160, 320);
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
                                              MediaUtils.isVideoFromPost(p, i);
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
                                                              width: itemWidth,
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
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}
