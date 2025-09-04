import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:lockerroom/bottom_tab_bar/bottom_tab_bar.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/model/comment_model.dart';
import 'package:lockerroom/model/post_model.dart';
import 'package:lockerroom/page/alert/diallog.dart';
import 'package:lockerroom/provider/comment_provider.dart';
import 'package:lockerroom/provider/feed_provider.dart';
import 'package:lockerroom/provider/profile_provider.dart';
import 'package:lockerroom/utils/media_utils.dart';
import 'package:lockerroom/widgets/network_video_player.dart';
import 'package:provider/provider.dart';
import 'package:toastification/toastification.dart';

class FeedDetailPage extends StatefulWidget {
  final PostModel post;
  final CommentModel? comment;
  const FeedDetailPage({super.key, required this.post, this.comment});

  @override
  State<FeedDetailPage> createState() => _FeedDetailPageState();
}

class _FeedDetailPageState extends State<FeedDetailPage> {
  final TextEditingController _commentsController = TextEditingController();
  late final CommentProvider _commentProvider;

  @override
  void initState() {
    super.initState();
    // Provider 참조를 보관해 두고 사용 (dispose에서 context 조회 방지)
    _commentProvider = context.read<CommentProvider>();
    // postId별 구독 시작
    _commentProvider.subscribeComments(widget.post.id);
    // 작성자 프로필은 빌드 외부에서 1회만 구독
    context.read<ProfileProvider>().subscribeUserProfile(widget.post.userId);
  }

  @override
  void dispose() {
    _commentProvider.cancelSubscription(widget.post.id);
    _commentsController.dispose();
    super.dispose();
  }

  String timeAgo(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inSeconds < 60) {
      return '${difference.inSeconds}s 전';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}분 전';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}시간 전';
    } else {
      return '${difference.inDays}일 전';
    }
  }

  @override
  Widget build(BuildContext context) {
    final feedProvider = Provider.of<FeedProvider>(context, listen: false);
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    // Ensure provider is in the tree; actual values are read via Consumers below.
    Provider.of<CommentProvider>(context, listen: false);

    return Scaffold(
      backgroundColor: BACKGROUND_COLOR,
      appBar: AppBar(
        backgroundColor: BACKGROUND_COLOR,
        title: Padding(
          padding: const EdgeInsets.only(top: 10.0),
          child: Image.asset('assets/images/applogo/app_logo.png', height: 100),
        ),
        centerTitle: true,
        scrolledUnderElevation: 0,
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.deferToChild,
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.only(
              left: 15.0,
              right: 15.0,
              bottom: 15.0,
            ),
            child: Card(
              color: WHITE,
              child: Padding(
                padding: const EdgeInsets.all(15.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 작성자 + 프로필
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Consumer<ProfileProvider>(
                          builder: (context, profileProvider, child) {
                            final url = profileProvider
                                .userProfiles[widget.post.userId];
                            return CircleAvatar(
                              radius: 25,
                              backgroundImage: url != null
                                  ? NetworkImage(url)
                                  : null,
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
                        SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
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
                                  icon: const Icon(Icons.more_horiz),
                                  onSelected: (value) async {
                                    if (value == 'delete') {
                                      // 삭제 확인 다이얼로그 추가
                                      showDialog(
                                        context: context,
                                        builder: (context) =>
                                            ConfirmationDialog(
                                              title: '삭제 확인',
                                              content: '게시글을 삭제 하시겠습니까?',
                                              onConfirm: () async {
                                                await feedProvider.deletePost(
                                                  widget.post,
                                                );

                                                // 바로 네비게이션 (토스트 제거)
                                                Navigator.pushAndRemoveUntil(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) =>
                                                        const BottomTabBar(
                                                          initialIndex: 1,
                                                        ),
                                                  ),
                                                  (route) => false,
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
                    const SizedBox(height: 8),
                    // 본문
                    Text(widget.post.text),
                    const SizedBox(height: 8),

                    // 이미지/ 영상 슬라이드
                    if (widget.post.mediaUrls.isNotEmpty)
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final bool inSingle =
                              widget.post.mediaUrls.length == 1;
                          final double availableWidth = constraints.maxWidth;
                          // 리스트 높이와 각 아이템 너비를 화면/가용 폭 기준으로 계산
                          final double listHeight = (availableWidth * 0.55)
                              .clamp(160.0, 320.0);
                          final double itemWidth = inSingle
                              ? availableWidth
                              : (availableWidth * 0.48).clamp(
                                  140.0,
                                  availableWidth,
                                );

                          return SizedBox(
                            height: listHeight,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: widget.post.mediaUrls.length,
                              itemBuilder: (_, i) {
                                final url = widget.post.mediaUrls[i];
                                final isVideo = MediaUtils.isVideoFromPost(
                                  widget.post,
                                  i,
                                );
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
                                                (
                                                  context,
                                                  child,
                                                  loadingProgress,
                                                ) {
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
                    // 좋아요, 댓글버튼 (실시간 반영)
                    StreamBuilder<DocumentSnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('posts')
                          .doc(widget.post.id)
                          .snapshots(),
                      builder: (context, snap) {
                        final currentUserId =
                            FirebaseAuth.instance.currentUser?.uid;
                        // 스냅샷 데이터가 준비되지 않은 경우 기존 값 사용
                        List<String> likedBy = widget.post.likedBy;
                        int likesCount = widget.post.likesCount;
                        if (snap.hasData && snap.data!.exists) {
                          final data =
                              snap.data!.data() as Map<String, dynamic>;
                          likedBy = List<String>.from(
                            data['likedBy'] ?? const [],
                          );
                          likesCount = (data['likesCount'] ?? 0) as int;
                        }
                        final bool isLiked =
                            currentUserId != null &&
                            likedBy.contains(currentUserId);

                        return Row(
                          children: [
                            IconButton(
                              onPressed: () =>
                                  feedProvider.toggleLike(widget.post),
                              icon: Icon(
                                isLiked
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                                color: isLiked ? Colors.red : null,
                              ),
                            ),
                            Transform.translate(
                              offset: Offset(-10, 0),
                              child: Text('$likesCount'),
                            ),
                            Row(
                              children: [
                                IconButton(
                                  onPressed: () {},
                                  icon: Icon(CupertinoIcons.chat_bubble),
                                ),
                                Consumer<CommentProvider>(
                                  builder: (context, cp, _) {
                                    final count = cp
                                        .getComments(widget.post.id)
                                        .length;
                                    return Transform.translate(
                                      offset: Offset(-5, 0),
                                      child: Text('$count'),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ],
                        );
                      },
                    ),
                    Builder(
                      builder: (context) {
                        int videoCount = 0;
                        int imageCount = 0;

                        for (int i = 0; i < widget.post.mediaUrls.length; i++) {
                          if (MediaUtils.isVideoFromPost(widget.post, i)) {
                            videoCount++;
                          } else {
                            imageCount++;
                          }
                        }

                        String mediaText;
                        if (videoCount > 0 && imageCount > 0) {
                          mediaText = '이미지 $imageCount개, 동영상 $videoCount개';
                        } else if (videoCount > 0) {
                          mediaText = '$videoCount개의 동영상';
                        } else {
                          mediaText = '$imageCount개의 이미지';
                        }

                        return Text(
                          mediaText,
                          style: TextStyle(
                            color: GRAYSCALE_LABEL_500,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        );
                      },
                    ),
                    SizedBox(height: 10),
                    Consumer<CommentProvider>(
                      builder: (context, cp, _) {
                        final count = cp.getComments(widget.post.id).length;
                        return Text(
                          '$count개의 댓글',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        );
                      },
                    ),
                    SizedBox(height: 10),
                    Consumer<CommentProvider>(
                      builder: (context, commentProvider, child) {
                        final comments = commentProvider.getComments(
                          widget.post.id,
                        );
                        if (comments.isEmpty) {
                          return Center(child: Text('댓글이 없습니다.'));
                        }

                        return ListView.builder(
                          shrinkWrap: true,
                          physics: NeverScrollableScrollPhysics(),

                          itemCount: comments.length,
                          itemBuilder: (context, index) {
                            final c = comments[index];
                            final liked =
                                currentUserId != null &&
                                (c.likesCount! > 0); // 단순 표시
                            return Container(
                              decoration: BoxDecoration(
                                border: BorderDirectional(
                                  bottom: BorderSide(
                                    color: GRAYSCALE_LABEL_300,
                                    width: 1,
                                  ),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Consumer<ProfileProvider>(
                                        builder:
                                            (context, profileProvider, child) {
                                              profileProvider
                                                  .subscribeUserProfile(
                                                    c.userId,
                                                  );

                                              final url = profileProvider
                                                  .userProfiles[c.userId];
                                              return CircleAvatar(
                                                radius: 15,
                                                backgroundImage: url != null
                                                    ? NetworkImage(url)
                                                    : null,
                                                backgroundColor:
                                                    GRAYSCALE_LABEL_300,
                                                child: url == null
                                                    ? const Icon(
                                                        Icons.person,
                                                        color: Colors.black,
                                                        size: 20,
                                                      )
                                                    : null,
                                              );
                                            },
                                      ),
                                      SizedBox(width: 10),
                                      Text(
                                        c.userName,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      SizedBox(width: 20),
                                      IconButton(
                                        onPressed: currentUserId != null
                                            ? () => commentProvider.toggleLike(
                                                c,
                                                currentUserId,
                                              )
                                            : null,
                                        icon: Icon(
                                          liked
                                              ? Icons.favorite
                                              : Icons.favorite_border,
                                          color: liked ? Colors.red : null,
                                          size: 20,
                                        ),
                                      ),
                                      Text('${c.likesCount}'),
                                      SizedBox(width: 5),
                                      if (currentUserId != null &&
                                          c.userId == currentUserId)
                                        PopupMenuTheme(
                                          data: PopupMenuThemeData(
                                            color: BACKGROUND_COLOR,
                                          ),
                                          child: PopupMenuButton<String>(
                                            icon: Icon(Icons.more_horiz),
                                            onSelected: (value) async {
                                              showDialog(
                                                context: context,
                                                builder: (context) =>
                                                    ConfirmationDialog(
                                                      title: '댓글 삭제',
                                                      content: '댓글을 삭제 하시겠습니까?',
                                                      onConfirm: () async {
                                                        await commentProvider
                                                            .deleteComment(c);
                                                        if (!mounted) return;
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
                                                    color: Colors.red,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.only(left: 40.0),
                                    child: Transform.translate(
                                      offset: Offset(0, -10),
                                      child: Text(
                                        c.text,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w400,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    ),
                    SizedBox(height: 230),
                    Row(
                      children: [
                        // Consumer<ProfileProvider>(
                        //   builder: (context, profileProvider, child) {
                        //     profileProvider.subscribeUserProfile(post.userId);

                        //     final url = profileProvider.userProfiles[post.userId];
                        //     return CircleAvatar(
                        //       radius: 15,
                        //       backgroundImage: url != null
                        //           ? NetworkImage(url)
                        //           : null,
                        //       backgroundColor: GRAYSCALE_LABEL_300,
                        //       child: url == null
                        //           ? const Icon(
                        //               Icons.person,
                        //               color: Colors.black,
                        //               size: 20,
                        //             )
                        //           : null,
                        //     );
                        //   },
                        // ),
                        Expanded(
                          child: TextFormField(
                            controller: _commentsController,
                            cursorColor: BUTTON,
                            cursorHeight: 18,
                            minLines: 1,
                            maxLines: 3,
                            keyboardType: TextInputType.multiline,
                            textInputAction: TextInputAction.newline,
                            enableIMEPersonalizedLearning: true,
                            style: TextStyle(decoration: TextDecoration.none),
                            decoration: InputDecoration(
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 10,
                              ),

                              labelText: '댓글을 입력해주세요',
                              labelStyle: TextStyle(
                                color: Colors.grey,
                                fontSize: 13,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: GRAYSCALE_LABEL_400,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: GRAYSCALE_LABEL_400,
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 10),
                        GestureDetector(
                          onTap: () async {
                            final text = _commentsController.text.trim();
                            if (text.isEmpty) return;
                            final user = FirebaseAuth.instance.currentUser!;
                            final comment = CommentModel(
                              id: '', // Firestore에서 자동생성
                              postId: widget.post.id,
                              userId: user.uid,
                              userName: user.displayName ?? '익명',
                              text: text,
                              createdAt: DateTime.now(),
                              likesCount: 0,
                            );
                            await context.read<CommentProvider>().addComment(
                              widget.post.id,
                              comment,
                            );
                            if (!mounted) return;
                            _commentsController.clear();
                          },
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              vertical: 8,
                              horizontal: 8,
                            ),
                            decoration: BoxDecoration(
                              color: BUTTON,
                              borderRadius: BorderRadius.circular(50),
                            ),
                            child: Icon(Icons.send, color: WHITE),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
