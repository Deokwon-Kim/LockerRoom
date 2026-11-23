import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_link_previewer/flutter_link_previewer.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/model/post_model.dart';
import 'package:lockerroom/page/alert/confirm_diallog.dart';
import 'package:lockerroom/page/feed/feed_detail_page.dart';
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
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: WHITE,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: BLACK.withValues(alpha: 0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.edit_note_rounded,
                      size: 30,
                      color: GRAYSCALE_LABEL_400,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '아직 작성한 게시물이 없습니다',
                    style: TextStyle(
                      fontSize: 15,
                      color: GRAYSCALE_LABEL_600,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.only(top: 4, bottom: 24),
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
    final isLiked =
        currentUserId != null && post.likedBy.contains(currentUserId);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => FeedDetailPage(post: post)),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          color: WHITE,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: GRAYSCALE_LABEL_200.withValues(alpha: 0.6),
          ),
          boxShadow: [
            BoxShadow(
              color: BLACK.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 작성자 + 프로필
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Consumer<ProfileProvider>(
                    builder: (context, profileProvider, child) {
                      profileProvider.subscribeUserProfile(post.userId);

                      final url = profileProvider.userProfiles[post.userId];
                      return Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: GRAYSCALE_LABEL_200,
                            width: 1,
                          ),
                        ),
                        child: CircleAvatar(
                          radius: 19,
                          backgroundImage: url != null
                              ? NetworkImage(url)
                              : null,
                          backgroundColor: GRAYSCALE_LABEL_100,
                          child: url == null
                              ? const Icon(
                                  Icons.person_rounded,
                                  color: GRAYSCALE_LABEL_500,
                                  size: 20,
                                )
                              : null,
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
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
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: GRAYSCALE_LABEL_950,
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 1),
                        Text(
                          timeAgo(post.createdAt),
                          style: const TextStyle(
                            color: GRAYSCALE_LABEL_400,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: () {
                      _showPostOptionBottomSheet(context, post, feedProvider);
                    },
                    icon: const Icon(
                      Icons.more_horiz_rounded,
                      color: GRAYSCALE_LABEL_500,
                      size: 20,
                    ),
                  ),
                ],
              ),
              if (post.text.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  post.text,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.45,
                    color: GRAYSCALE_LABEL_900,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              if (extractUrl(post.text) != null) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: BACKGROUND_COLOR,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: GRAYSCALE_LABEL_200.withValues(alpha: 0.8),
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LinkPreview(
                        enableAnimation: true,
                        text: extractUrl(post.text)!,
                        onLinkPreviewDataFetched: (data) {
                          debugPrint('Preview data fetched: ${data.title}');
                        },
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        color: WHITE,
                        child: Row(
                          children: [
                            const Icon(
                              Icons.link_rounded,
                              size: 16,
                              color: Colors.blue,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                extractUrl(post.text)!,
                                style: const TextStyle(
                                  color: Colors.blue,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
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
                    final double listHeight = (availableWidth * 0.55).clamp(
                      160.0,
                      320.0,
                    );
                    final double itemWidth = inSingle
                        ? availableWidth
                        : (availableWidth * 0.48).clamp(140.0, availableWidth);

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: SizedBox(
                        height: listHeight,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: post.mediaUrls.length,
                          itemBuilder: (_, i) {
                            final url = post.mediaUrls[i];
                            final isVideo = MediaUtils.isVideoFromPost(post, i);
                            return Padding(
                              padding: EdgeInsets.only(
                                right: inSingle ? 0 : 8,
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
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
                      ),
                    );
                  },
                ),
              // 하단 좋아요 + 댓글 캡슐 바
              Container(
                padding: const EdgeInsets.only(top: 10),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: GRAYSCALE_LABEL_100,
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    InkWell(
                      onTap: currentUserId == null
                          ? null
                          : () => feedProvider.toggleLikeAndNotify(
                              currentUserId: currentUserId,
                              post: post,
                              postId: post.id,
                              postOwnerId: post.userId,
                            ),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 11,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: isLiked
                              ? Colors.red.withValues(alpha: 0.08)
                              : BACKGROUND_COLOR,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isLiked
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              size: 16,
                              color: isLiked
                                  ? Colors.red
                                  : GRAYSCALE_LABEL_600,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              '${post.likesCount}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: isLiked
                                    ? Colors.red
                                    : GRAYSCALE_LABEL_700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Consumer<CommentProvider>(
                      builder: (context, commentProvider, child) {
                        final comment = commentProvider.getComments(post.id);
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 11,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: BACKGROUND_COLOR,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                CupertinoIcons.chat_bubble,
                                size: 15,
                                color: GRAYSCALE_LABEL_600,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                '${comment.length}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: GRAYSCALE_LABEL_700,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const Spacer(),
                    if (post.mediaUrls.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: BACKGROUND_COLOR,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.photo_library_outlined,
                              size: 12,
                              color: GRAYSCALE_LABEL_500,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${post.mediaUrls.length}',
                              style: const TextStyle(
                                color: GRAYSCALE_LABEL_500,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
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
