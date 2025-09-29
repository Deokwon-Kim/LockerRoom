import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/model/post_model.dart';
import 'package:lockerroom/page/alert/diallog.dart';
import 'package:lockerroom/page/feed/feed_detail_page.dart';
import 'package:lockerroom/page/feed/feed_mypage.dart';
import 'package:lockerroom/provider/comment_provider.dart';
import 'package:lockerroom/provider/feed_provider.dart';
import 'package:lockerroom/provider/profile_provider.dart';
import 'package:lockerroom/utils/media_utils.dart';
import 'package:lockerroom/widgets/network_video_player.dart';
import 'package:provider/provider.dart';
import 'package:toastification/toastification.dart';

class FeedPage extends StatefulWidget {
  final PostModel? post; // nullable로 변경
  const FeedPage({this.post, super.key});

  @override
  State<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage> {
  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final feedProvider = context.read<FeedProvider>();

    feedProvider.postStream(uid);
  }

  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BACKGROUND_COLOR,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Image.asset('assets/images/applogo/app_logo.png', height: 100),
        centerTitle: true,
        scrolledUnderElevation: 0,
        backgroundColor: BACKGROUND_COLOR,
        actions: [
          IconButton(
            onPressed: () {
              setState(() {
                if (_isSearching) {
                  // 검색 종료 시 검색어 초기화
                  Provider.of<FeedProvider>(
                    context,
                    listen: false,
                  ).setQuery('');
                }
                _isSearching = !_isSearching;
              });
            },
            icon: Icon(
              _isSearching ? Icons.close : Icons.search,
              color: BUTTON,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_isSearching)
            Padding(
              padding: const EdgeInsets.fromLTRB(15, 10, 15, 10),
              child: TextFormField(
                controller: _searchController,
                cursorColor: BUTTON,
                cursorHeight: 18,
                minLines: 1,
                maxLines: 3,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
                enableIMEPersonalizedLearning: true,
                style: TextStyle(decoration: TextDecoration.none),
                onChanged: (value) => Provider.of<FeedProvider>(
                  context,
                  listen: false,
                ).setQuery(value),
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 10,
                  ),
                  labelText: '검색어를 입력해주세요',
                  labelStyle: TextStyle(color: Colors.grey, fontSize: 13),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: GRAYSCALE_LABEL_400),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: GRAYSCALE_LABEL_400),
                  ),
                ),
              ),
            ),
          Expanded(
            child: Consumer<FeedProvider>(
              builder: (context, feedProvider, child) {
                final allPosts = feedProvider.postsStream;
                if (feedProvider.isLoading) {
                  return Center(
                    child: CircularProgressIndicator(color: BUTTON),
                  );
                }
                if (allPosts.isEmpty) {
                  return Center(
                    child: Text(
                      '게시물이 없습니다',
                      style: TextStyle(color: GRAYSCALE_LABEL_500),
                    ),
                  );
                }
                return ListView.builder(
                  itemCount: allPosts.length,
                  itemBuilder: (context, index) => PostWidget(
                    post: allPosts[index],
                    feedProvider: feedProvider,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// 개별 포스트 위젯
class PostWidget extends StatefulWidget {
  final PostModel post;
  final FeedProvider feedProvider;

  const PostWidget({required this.post, required this.feedProvider, super.key});

  @override
  State<PostWidget> createState() => _PostWidgetState();
}

class _PostWidgetState extends State<PostWidget> {
  late final CommentProvider _commentProvider;

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
  void initState() {
    super.initState();
    _commentProvider = context.read<CommentProvider>();
    _commentProvider.subscribeComments(widget.post.id);
  }

  @override
  void dispose() {
    _commentProvider.cancelSubscription(widget.post.id);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => FeedDetailPage(post: widget.post),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.only(left: 15, right: 15, bottom: 15),
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
                        profileProvider.subscribeUserProfile(
                          widget.post.userId,
                        );

                        final url =
                            profileProvider.userProfiles[widget.post.userId];
                        return GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => FeedMypage(
                                  post: widget.post,
                                  targetUserId: widget.post.userId,
                                ),
                              ),
                            );
                          },
                          child: CircleAvatar(
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
                          ),
                        );
                      },
                    ),

                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => FeedMypage(
                                  post: widget.post,
                                  targetUserId: widget.post.userId,
                                ),
                              ),
                            );
                          },
                          child: Text(
                            widget.post.userName,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: Colors.black,
                            ),
                          ),
                        ),
                        Transform.translate(
                          offset: Offset(10, -10),
                          child: Text(
                            timeAgo(widget.post.createdAt),
                            style: TextStyle(
                              color: GRAYSCALE_LABEL_500,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Spacer(),
                    currentUserId != null && widget.post.userId == currentUserId
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
                                        await widget.feedProvider.deletePost(
                                          widget.post,
                                        );
                                        toastification.show(
                                          context: context,
                                          type: ToastificationType.success,
                                          alignment: Alignment.bottomCenter,
                                          autoCloseDuration: Duration(
                                            seconds: 2,
                                          ),
                                          title: Text('게시물을 삭제했습니다'),
                                        );
                                      },
                                    ),
                                  );
                                }
                              },
                              itemBuilder: (context) => const [
                                PopupMenuItem(
                                  value: '신고',
                                  child: Text(
                                    '신고',
                                    style: TextStyle(color: RED_DANGER_TEXT_50),
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Text(
                                    '삭제하기',
                                    style: TextStyle(
                                      color: RED_DANGER_TEXT_50,
                                      fontWeight: FontWeight.bold,
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

                // 이미지/영상 슬라이드
                if (widget.post.mediaUrls.isNotEmpty)
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final bool inSingle = widget.post.mediaUrls.length == 1;
                      final double availableWidth = constraints.maxWidth;
                      // 리스트 높이와 각 아이템 너비를 화면/가용 폭 기준으로 계산
                      final double listHeight = (availableWidth * 0.55).clamp(
                        160.0,
                        320.0,
                      );
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
                // 좋아요 버튼
                Row(
                  children: [
                    IconButton(
                      onPressed: () =>
                          widget.feedProvider.toggleLike(widget.post),
                      icon: Icon(
                        (FirebaseAuth.instance.currentUser?.uid != null &&
                                widget.post.likedBy.contains(
                                  FirebaseAuth.instance.currentUser!.uid,
                                ))
                            ? Icons.favorite
                            : Icons.favorite_border,
                        color:
                            (FirebaseAuth.instance.currentUser?.uid != null &&
                                widget.post.likedBy.contains(
                                  FirebaseAuth.instance.currentUser!.uid,
                                ))
                            ? Colors.red
                            : null,
                      ),
                    ),
                    Transform.translate(
                      offset: Offset(-10, 0),
                      child: Text('${widget.post.likesCount}'),
                    ),
                    Row(
                      children: [
                        IconButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    FeedDetailPage(post: widget.post),
                              ),
                            );
                          },
                          icon: Icon(CupertinoIcons.chat_bubble),
                        ),
                        Consumer<CommentProvider>(
                          builder: (context, commentProvider, child) {
                            final comment = commentProvider.getComments(
                              widget.post.id,
                            );
                            return Transform.translate(
                              offset: Offset(-5, 0),
                              child: Text('${comment.length}'),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
