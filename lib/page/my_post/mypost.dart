import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/model/post_model.dart';
import 'package:lockerroom/page/alert/confirm_diallog.dart';
import 'package:lockerroom/provider/feed_provider.dart';
import 'package:lockerroom/provider/profile_provider.dart';
import 'package:lockerroom/utils/media_utils.dart';
import 'package:lockerroom/widgets/network_video_player.dart';
import 'package:provider/provider.dart';
import 'package:toastification/toastification.dart';

class MypostPage extends StatelessWidget {
  const MypostPage({super.key});

  @override
  Widget build(BuildContext context) {
    final feedProvider = Provider.of<FeedProvider>(context, listen: false);

    return Scaffold(
      backgroundColor: BACKGROUND_COLOR,
      body: StreamBuilder<List<PostModel>>(
        stream: feedProvider.listenMyPosts(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('에러 발생'));
          }
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: BUTTON),
            );
          }

          final posts = snapshot.data!;

          if (posts.isEmpty) {
            return Center(
              child: Text(
                '게시물이 없습니다',
                style: TextStyle(
                  fontSize: 16,
                  color: GRAYSCALE_LABEL_500,
                  fontWeight: FontWeight.bold,
                ),
              ),
            );
          }

          return ListView.builder(
            itemCount: posts.length,
            itemBuilder: (context, index) {
              return MyPostWidget(
                post: posts[index],
                feedProvider: feedProvider,
              );
            },
          );
        },
      ),
    );
  }
}

class MyPostWidget extends StatelessWidget {
  final PostModel post;
  final FeedProvider feedProvider;

  const MyPostWidget({
    required this.post,
    required this.feedProvider,
    super.key,
  });

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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
      child: Card(
        color: WHITE,
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 작성자 + 프로필
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Consumer<ProfileProvider>(
                    builder: (context, profileProvider, child) {
                      profileProvider.subscribeUserProfile(post.userId);

                      final url = profileProvider.userProfiles[post.userId];
                      return CircleAvatar(
                        radius: 25,
                        backgroundImage: url != null ? NetworkImage(url) : null,
                        backgroundColor: GRAYSCALE_LABEL_300,
                        child: url == null
                            ? const Icon(
                                Icons.person,
                                color: Colors.black,
                                size: 25,
                              )
                            : null,
                      );
                    },
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.userNickName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        timeAgo(post.createdAt),
                        style: TextStyle(
                          color: GRAYSCALE_LABEL_500,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  currentUserId != null && post.userId == currentUserId
                      ? PopupMenuTheme(
                          data: PopupMenuThemeData(color: BACKGROUND_COLOR),
                          child: PopupMenuButton<String>(
                            icon: const Icon(Icons.more_horiz),
                            onSelected: (value) async {
                              if (value == 'delete') {
                                // 삭제 확인 다이얼로그 추가
                                showDialog(
                                  context: context,
                                  builder: (context) => ConfirmationDialog(
                                    title: '삭제 확인',
                                    content: '게시글을 삭제 하시겠습니까?',
                                    onConfirm: () async {
                                      await feedProvider.deletePost(post);
                                      toastification.show(
                                        context: context,
                                        type: ToastificationType.success,
                                        alignment: Alignment.bottomCenter,
                                        autoCloseDuration: Duration(seconds: 2),
                                        title: Text('게시물을 삭제했습니다'),
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
                                  style: TextStyle(color: RED_DANGER_TEXT_50),
                                ),
                              ),
                            ],
                          ),
                        )
                      : SizedBox.shrink(),
                ],
              ),
              const SizedBox(height: 8),
              // 본문
              Text(post.text),
              const SizedBox(height: 8),
              // 이미지/영상 슬라이드
              if (post.mediaUrls.isNotEmpty)
                LayoutBuilder(
                  builder: (context, constraints) {
                    final bool inSingle = post.mediaUrls.length == 1;
                    final double availableWidth = constraints.maxWidth;
                    // 리스트 높이와 각 아이템 너비를 화면/가용 폭 기준으로 계산
                    final double listHeight = (availableWidth * 0.55).clamp(
                      160.0,
                      320.0,
                    );
                    final double itemWidth = inSingle
                        ? availableWidth
                        : (availableWidth * 0.48).clamp(140.0, availableWidth);

                    return SizedBox(
                      height: listHeight,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: post.mediaUrls.length,
                        itemBuilder: (_, i) {
                          final url = post.mediaUrls[i];
                          final isVideo = MediaUtils.isVideoFromPost(post, i);
                          return Padding(
                            padding: EdgeInsets.only(
                              left: 0,
                              right: inSingle ? 0 : 8,
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
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
                                          (context, child, loadingProgress) {
                                            if (loadingProgress == null) {
                                              return child;
                                            }
                                            return SizedBox(
                                              height: listHeight,
                                              width: itemWidth,
                                              child: const Center(
                                                child:
                                                    CircularProgressIndicator(
                                                      color: BUTTON,
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
              const SizedBox(height: 8),
              // 좋아요 + 댓글
              Row(
                children: [
                  IconButton(
                    onPressed: () => feedProvider.toggleLikeAndNotify(
                      currentUserId: currentUserId!,
                      post: post,
                      postId: post.id,
                      postOwnerId: post.userId,
                    ),
                    icon: Icon(
                      currentUserId != null &&
                              post.likedBy.contains(currentUserId)
                          ? Icons.favorite
                          : Icons.favorite_border,
                      color:
                          currentUserId != null &&
                              post.likedBy.contains(currentUserId)
                          ? Colors.red
                          : null,
                    ),
                  ),
                  Transform.translate(
                    offset: const Offset(-10, 0),
                    child: Text('${post.likesCount}'),
                  ),
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(CupertinoIcons.chat_bubble),
                  ),
                  const Spacer(),
                  Text(
                    '${post.mediaUrls.length}개의 이미지',
                    style: TextStyle(
                      color: GRAYSCALE_LABEL_500,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
