import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_link_previewer/flutter_link_previewer.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/model/post_model.dart';
import 'package:lockerroom/page/alert/confirm_diallog.dart';
import 'package:lockerroom/page/feed/feed_edit_page.dart';
import 'package:lockerroom/provider/comment_provider.dart';
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
  String? extractUrl(String text) {
    final urlPattern = RegExp(r'(https?://[^\s,]+)', caseSensitive: false);
    final match = urlPattern.firstMatch(text);
    return match?.group(0);
  }

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
                      Consumer<ProfileProvider>(
                        builder: (context, profileProvider, child) {
                          profileProvider.subscribeUserProfile(post.userId);
                          final nickName =
                              profileProvider.userNicknames[post.userId] ??
                              post.userNickName;
                          return Text(
                            nickName,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          );
                        },
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

                  IconButton(
                    onPressed: () {
                      _showPostOptionBottomSheet(context, post, feedProvider);
                    },
                    icon: Icon(Icons.more_horiz),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // 본문
              Text(post.text),
              const SizedBox(height: 8),
              if (extractUrl(post.text) != null) ...[
                SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    color: WHITE,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.2),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LinkPreview(
                        enableAnimation: true,
                        text: extractUrl(post.text)!,
                        onLinkPreviewDataFetched: (data) {
                          print('Preview data fetched: ${data.title}');
                        },
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(color: WHITE),
                        child: Row(
                          children: [
                            Icon(Icons.link, size: 16, color: Colors.blue),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                extractUrl(post.text)!,
                                style: TextStyle(
                                  color: Colors.blue,
                                  fontSize: 13,
                                ),
                                maxLines: 1,
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
                  Consumer<CommentProvider>(
                    builder: (context, commentProvider, child) {
                      final comment = commentProvider.getComments(post.id);
                      return Transform.translate(
                        offset: Offset(-5, 0),
                        child: Text('${comment.length}'),
                      );
                    },
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

  void _showPostOptionBottomSheet(
    BuildContext context,
    PostModel post,
    FeedProvider feedProvider,
  ) {
    showModalBottomSheet(
      isScrollControlled: true,
      context: context,
      backgroundColor: GRAYSCALE_LABEL_50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        height: 200,
        child: Padding(
          padding: EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 상단 바
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: GRAYSCALE_LABEL_400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(height: 20),

              GestureDetector(
                onTap: () {
                  Navigator.pop(context); // 바텀시트 닫기
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => FeedEditPage(post: post),
                    ),
                  );
                },
                child: Container(
                  padding: EdgeInsets.all(10),
                  width: double.infinity,
                  height: 50,
                  decoration: BoxDecoration(
                    color: WHITE,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '게시물 수정',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Icon(Icons.edit_outlined, color: BLACK),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 10),
              GestureDetector(
                onTap: () {
                  Navigator.pop(context); // 바텀시트 닫기
                  showDialog(
                    context: context,
                    builder: (context) => ConfirmationDialog(
                      title: '삭제 확인',
                      content: '게시물을 삭제 하시겠습니까?',
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
                },
                child: Container(
                  padding: EdgeInsets.all(10),
                  width: double.infinity,
                  height: 50,
                  decoration: BoxDecoration(
                    color: WHITE,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '게시물 삭제',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: RED_DANGER_TEXT_50,
                        ),
                      ),
                      Icon(
                        CupertinoIcons.delete_solid,
                        color: RED_DANGER_TEXT_50,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
