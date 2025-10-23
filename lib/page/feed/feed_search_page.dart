import 'package:contained_tab_bar_view/contained_tab_bar_view.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/model/post_model.dart';
import 'package:lockerroom/page/alert/confirm_diallog.dart';
import 'package:lockerroom/page/feed/feed_detail_page.dart';
import 'package:lockerroom/page/feed/feed_mypage.dart';
import 'package:lockerroom/page/feed/fullscreen_image_viewer.dart';
import 'package:lockerroom/page/feed/fullscreen_video_player.dart';
import 'package:lockerroom/page/myPage/user_detail_page.dart';
import 'package:lockerroom/provider/comment_provider.dart';
import 'package:lockerroom/provider/feed_provider.dart';
import 'package:lockerroom/provider/profile_provider.dart';
import 'package:lockerroom/provider/block_provider.dart';
import 'package:lockerroom/provider/team_provider.dart';
import 'package:lockerroom/utils/media_utils.dart';
import 'package:lockerroom/widgets/network_video_player.dart';
import 'package:provider/provider.dart';
import 'package:toastification/toastification.dart';

class FeedSearchPage extends StatefulWidget {
  const FeedSearchPage({super.key});

  @override
  State<FeedSearchPage> createState() => _FeedSearchPageState();
}

class _FeedSearchPageState extends State<FeedSearchPage> {
  late FeedProvider _feedProvider;
  BlockProvider? _blockProvider;
  VoidCallback? _blockListener;

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser!.uid;
    _feedProvider = context.read<FeedProvider>();

    _feedProvider.postStream(uid);
    _feedProvider.loadAllUsers();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _blockProvider = context.read<BlockProvider>();
      // 초기 동기화
      _feedProvider.setBlockedUsers(_blockProvider!.blockedUserIds);
      _feedProvider.setBlockedByUsers(_blockProvider!.blockedByUserIds);
      // 차단 목록 변경 리스너
      _blockListener = () {
        if (mounted) {
          _feedProvider.setBlockedUsers(_blockProvider!.blockedUserIds);
          _feedProvider.setBlockedByUsers(_blockProvider!.blockedByUserIds);
        }
      };
      _blockProvider!.addListener(_blockListener!);

      _isSearching = false;
      _searchController.clear();
      context.read<FeedProvider>().setQuery('');
      setState(() {});
    });
  }

  @override
  void dispose() {
    // dispose에서는 저장된 참조를 직접 사용 (context.read() 사용 금지!)
    if (_blockProvider != null && _blockListener != null) {
      _blockProvider!.removeListener(_blockListener!);
    }
    _searchController.dispose();
    super.dispose();
  }

  bool _isSearching = false;
  bool get isSearching => _isSearching;
  final TextEditingController _searchController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final selectedColor =
        Provider.of<TeamProvider>(context).selectedTeam?.color ?? BUTTON;
    final feedProvider = _feedProvider;
    return Scaffold(
      backgroundColor: BACKGROUND_COLOR,
      appBar: AppBar(
        backgroundColor: BACKGROUND_COLOR,
        title: Text(
          '검색',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
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
              onChanged: (value) {
                setState(() {
                  _isSearching = value.isNotEmpty;
                });
                Provider.of<FeedProvider>(
                  context,
                  listen: false,
                ).setQuery(value);
              },
              decoration: InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 10,
                ),
                labelText: '사용자 또는 게시물 검색',
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
          SizedBox(height: 10),
          Expanded(
            child: ContainedTabBarView(
              tabs: [
                Text('사용자', style: TextStyle(color: Colors.black)),
                Text('게시물', style: TextStyle(color: Colors.black)),
              ],
              tabBarProperties: TabBarProperties(
                indicatorColor: selectedColor,
                indicatorSize: TabBarIndicatorSize.tab,
                indicatorWeight: 3.0,
                unselectedLabelColor: GRAYSCALE_LABEL_500,
              ),
              views: [_userResult(feedProvider), _postResult(feedProvider)],
            ),
          ),
        ],
      ),
    );
  }

  Widget _userResult(FeedProvider feedProvider) {
    final filteredUser = feedProvider.filteredUsers;

    if (filteredUser.isEmpty) {
      return Center(child: Text('검색 결과가 없습니다'));
    }
    return ListView(
      children: filteredUser
          .map(
            (u) => ListTile(
              leading: CircleAvatar(
                radius: 20,
                backgroundColor: GRAYSCALE_LABEL_300,
                backgroundImage:
                    (u.profileImage != null && u.profileImage!.isNotEmpty)
                    ? NetworkImage(u.profileImage!)
                    : null,
                child: (u.profileImage == null || u.profileImage!.isEmpty)
                    ? const Icon(Icons.person, color: Colors.black, size: 20)
                    : null,
              ),
              title: Text(u.username),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => UserDetailPage(userId: u.uid),
                  ),
                );
              },
            ),
          )
          .toList(),
    );
  }

  Widget _postResult(FeedProvider feedProvider) {
    final allPosts = feedProvider.filteredPosts;

    if (allPosts.isEmpty) {
      return Center(child: Text('검색 결과가 없습니다'));
    }

    return ListView.builder(
      itemCount: allPosts.length,
      itemBuilder: (context, index) =>
          PostWidget(post: allPosts[index], feedProvider: feedProvider),
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
  BlockProvider? _blockProvider;
  VoidCallback? _blockListener;

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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _blockProvider = context.read<BlockProvider>();
      // 초기 동기화
      _commentProvider.setBlockedUsers(_blockProvider!.blockedUserIds);
      _commentProvider.setBlockedByUsers(_blockProvider!.blockedByUserIds);
      // 차단 목록 변경 리스너
      _blockListener = () {
        _commentProvider.setBlockedUsers(_blockProvider!.blockedUserIds);
        _commentProvider.setBlockedByUsers(_blockProvider!.blockedByUserIds);
      };
      _blockProvider!.addListener(_blockListener!);
    });
  }

  @override
  void dispose() {
    _commentProvider.cancelSubscription(widget.post.id);
    if (_blockProvider != null && _blockListener != null) {
      _blockProvider!.removeListener(_blockListener!);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final isOwner =
        currentUserId != null && widget.post.userId == currentUserId;
    final selectedColor =
        Provider.of<TeamProvider>(context).selectedTeam?.color ?? BUTTON;
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
                            widget.post.userNickName,
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

                    PopupMenuTheme(
                      data: PopupMenuThemeData(color: BACKGROUND_COLOR),
                      child: PopupMenuButton<String>(
                        icon: const Icon(Icons.more_horiz),
                        onSelected: (value) async {
                          if (value == 'delete' && isOwner) {
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
                                    autoCloseDuration: Duration(seconds: 2),
                                    title: Text('게시물을 삭제했습니다'),
                                  );
                                },
                              ),
                            );
                          } else if (value == 'report') {
                            final reporter = FirebaseAuth.instance.currentUser;
                            if (reporter == null) {
                              toastification.show(
                                context: context,
                                type: ToastificationType.error,
                                alignment: Alignment.bottomCenter,
                                autoCloseDuration: Duration(seconds: 2),
                                title: Text('로그인이 필요합니다'),
                              );
                              return;
                            }
                            _showFeedReportDialog(
                              context,
                              widget.post,
                              widget.feedProvider,
                              reporter.uid,
                            );
                          } else if (value == 'block') {
                            final uid = FirebaseAuth.instance.currentUser?.uid;
                            if (uid == null) return;
                            _showBlockConfirmDialog(
                              context,
                              widget.post.userNickName,
                              widget.post.userId,
                              uid,
                            );
                          }
                        },
                        itemBuilder: (context) => [
                          if (isOwner)
                            PopupMenuItem(
                              value: 'delete',
                              child: Text(
                                '삭제하기',
                                style: TextStyle(color: RED_DANGER_TEXT_50),
                              ),
                            )
                          else ...[
                            PopupMenuItem(
                              value: 'report',
                              child: Text(
                                '신고',
                                style: TextStyle(
                                  color: BLACK,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            PopupMenuItem(
                              value: 'block',
                              child: Text(
                                '사용자 차단',
                                style: TextStyle(
                                  color: BLACK,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
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

                      // 싱글일 때는 16:9 비율, 멀티일 때는 정사각형
                      final double aspectRatio = inSingle ? 16 / 9 : 1.0;
                      final double listHeight = (availableWidth / aspectRatio)
                          .clamp(160.0, 400.0);
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
                                    ? GestureDetector(
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  FullscreenVideoPlayer(
                                                    videoUrl: url,
                                                  ),
                                            ),
                                          );
                                        },
                                        child: NetworkVideoPlayer(
                                          videoUrl: url,
                                          width: itemWidth,
                                          height: listHeight,
                                          fit: BoxFit.contain,
                                          autoPlay: true,
                                          muted: true,
                                          showControls: false,
                                        ),
                                      )
                                    : GestureDetector(
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  FullscreenImageViewer(
                                                    imageUrls:
                                                        widget.post.mediaUrls,
                                                    initialIndex: i,
                                                  ),
                                            ),
                                          );
                                        },
                                        child: Image.network(
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
                                                  child: Center(
                                                    child:
                                                        CircularProgressIndicator(
                                                          color: selectedColor,
                                                        ),
                                                  ),
                                                );
                                              },
                                        ),
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
                      onPressed: () => widget.feedProvider.toggleLikeAndNotify(
                        postId: widget.post.id,
                        post: widget.post,
                        currentUserId: currentUserId!,
                        postOwnerId: widget.post.userId,
                      ),
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

  void _showFeedReportDialog(
    BuildContext context,
    PostModel post,
    FeedProvider feedProvider,
    String currentUserId,
  ) {
    final TextEditingController reportController = TextEditingController();
    final List<String> reportReasons = [
      '스팸 및 광고',
      '부적절한 콘텐츠',
      '혐오 표현',
      '욕설 및 음란물',
      '개인정보 침해',
      '기타',
    ];
    String selectedReason = reportReasons[0];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: BACKGROUND_COLOR,
        title: Text('댓글 신고'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '신고 사유를 선택해주세요',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 12),
              StatefulBuilder(
                builder: (context, setState) {
                  return Column(
                    children: reportReasons.map((reason) {
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            selectedReason = reason;
                          });
                        },
                        child: Container(
                          margin: EdgeInsets.symmetric(vertical: 4),
                          padding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: selectedReason == reason
                                  ? BUTTON
                                  : GRAYSCALE_LABEL_400,
                              width: selectedReason == reason ? 2 : 1,
                            ),
                            borderRadius: BorderRadius.circular(8),
                            color: selectedReason == reason
                                ? BUTTON.withOpacity(0.1)
                                : Colors.transparent,
                          ),
                          child: Row(
                            children: [
                              Expanded(child: Text(reason)),
                              if (selectedReason == reason)
                                Icon(Icons.check, color: BUTTON),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
              SizedBox(height: 16),
              Text(
                '추가 설명 (선택사항)',
                style: TextStyle(fontSize: 12, color: GRAYSCALE_LABEL_500),
              ),
              SizedBox(height: 8),
              TextField(
                controller: reportController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: '자세한 내용을 입력해주세요',
                  hintStyle: TextStyle(color: GRAYSCALE_LABEL_400),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: GRAYSCALE_LABEL_400),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: BUTTON),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('취소', style: TextStyle(color: Colors.black)),
          ),
          TextButton(
            onPressed: () async {
              final description = reportController.text.trim();
              final reason =
                  selectedReason +
                  (description.isNotEmpty ? '\n$description' : '');

              try {
                final user = FirebaseAuth.instance.currentUser;
                if (user == null) {
                  if (!mounted) return;
                  toastification.show(
                    context: context,
                    type: ToastificationType.error,
                    alignment: Alignment.bottomCenter,
                    autoCloseDuration: Duration(seconds: 2),
                    title: Text('로그인이 필요합니다'),
                  );

                  return;
                }

                await feedProvider.reportPost(
                  post: post,
                  reporterUserId: user.uid,
                  reporterUserName: user.displayName ?? '익명',
                  reason: reason,
                );

                if (!mounted) return;
                Navigator.pop(context);
                toastification.show(
                  context: context,
                  type: ToastificationType.success,
                  alignment: Alignment.bottomCenter,
                  autoCloseDuration: Duration(seconds: 2),
                  title: Text('신고가 접수되었습니다'),
                );
              } catch (e) {
                if (!mounted) return;
                Navigator.pop(context);
                toastification.show(
                  context: context,
                  type: ToastificationType.error,
                  alignment: Alignment.bottomCenter,
                  autoCloseDuration: Duration(seconds: 2),
                  title: Text('신고 중 오류가 발생했습니다'),
                );
              }
            },
            child: Text('신고하기', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showBlockConfirmDialog(
    BuildContext context,
    String userNickName,
    String userId,
    String currentUserId,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: BACKGROUND_COLOR,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: 8),
              // 상단 바
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: GRAYSCALE_LABEL_400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(height: 24),

              // 제목
              Text(
                '${userNickName}님을\n차단하시겠어요?',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 16),

              // 설명 텍스트
              Text(
                '이 사람이 만든 다른 계정과 앞으로 만드는 모든 계정이 함께 차단됩니다. 언제든지 차단을 해제할 수 있습니다.',
                style: TextStyle(
                  fontSize: 13,
                  color: GRAYSCALE_LABEL_600,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 20),

              // 차단 효과 설명
              _buildBlockEffectItem(
                icon: Icons.search_off,
                title: '게시물 및 프로필 숨김',
                description: '해당 사용자는 회원님의 프로필과 게시물을 찾을 수 없습니다.',
              ),
              SizedBox(height: 16),

              _buildBlockEffectItem(
                icon: Icons.comment,
                title: '상호작용 차단',
                description: '해당 사용자가 남긴 댓글은 회원님에게 보이지 않습니다.',
              ),
              SizedBox(height: 16),

              _buildBlockEffectItem(
                icon: Icons.mail,
                title: '메시지 차단',
                description: '해당 사용자는 직접 메시지를 보낼 수 없습니다.',
              ),
              SizedBox(height: 16),

              _buildBlockEffectItem(
                icon: Icons.notifications_none,
                title: '상대방에게 알림 없음',
                description: '상대방에게 회원님이 차단했다는 사실을 알리지 않습니다.',
              ),
              SizedBox(height: 28),

              // 버튼
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          border: Border.all(color: GRAYSCALE_LABEL_300),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text(
                            '취소',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: GRAYSCALE_LABEL_900,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        await context.read<BlockProvider>().blockUser(
                          currentUserId: currentUserId,
                          targetUserId: userId,
                        );
                        if (!mounted) return;
                        Navigator.pop(context);
                        toastification.show(
                          context: context,
                          type: ToastificationType.success,
                          alignment: Alignment.bottomCenter,
                          autoCloseDuration: Duration(seconds: 2),
                          title: Text('${userNickName}님을 차단했습니다'),
                        );
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: RED_DANGER_TEXT_50,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text(
                            '차단',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: WHITE,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBlockEffectItem({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 24, color: GRAYSCALE_LABEL_600),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: GRAYSCALE_LABEL_900,
                ),
              ),
              SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  fontSize: 12,
                  color: GRAYSCALE_LABEL_600,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
