import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/model/post_model.dart';
import 'package:lockerroom/page/alert/confirm_diallog.dart';
import 'package:lockerroom/page/feed/feed_detail_page.dart';
import 'package:lockerroom/page/feed/feed_edit_page.dart';
import 'package:lockerroom/page/feed/feed_mypage.dart';
import 'package:lockerroom/page/feed/feed_search_page.dart';
import 'package:lockerroom/page/feed/fullscreen_video_player.dart';
import 'package:lockerroom/provider/comment_provider.dart';
import 'package:lockerroom/provider/feed_provider.dart';
import 'package:lockerroom/provider/profile_provider.dart';
import 'package:lockerroom/provider/block_provider.dart';
import 'package:lockerroom/utils/media_utils.dart';
import 'package:lockerroom/widgets/network_video_player.dart';
import 'package:provider/provider.dart';
import 'package:toastification/toastification.dart';
import 'package:lockerroom/provider/team_provider.dart';
import 'package:lockerroom/page/feed/fullscreen_image_viewer.dart';

class FeedPage extends StatefulWidget {
  final PostModel? post; // nullable로 변경
  const FeedPage({this.post, super.key});

  @override
  State<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage> {
  late FeedProvider _feedProvider;
  BlockProvider? _blockProvider;
  VoidCallback? _blockListener;

  @override
  void initState() {
    super.initState();
    // initState에서 context.read() 사용 (안전함)
    _feedProvider = context.read<FeedProvider>();
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    _feedProvider.postStream(userId);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _blockProvider = context.read<BlockProvider>();
      // 초기 동기화
      _feedProvider.setBlockedUsers(_blockProvider!.blockedUserIds);
      _feedProvider.setBlockedByUsers(_blockProvider!.blockedByUserIds);
      // 차단 목록 변경 리스너
      _blockListener = () {
        _feedProvider.setBlockedUsers(_blockProvider!.blockedUserIds);
        _feedProvider.setBlockedByUsers(_blockProvider!.blockedByUserIds);
      };
      _blockProvider!.addListener(_blockListener!);
    });
  }

  @override
  void dispose() {
    // dispose에서는 저장된 참조를 직접 사용 (context.read() 사용 금지!)
    _feedProvider.cancelSubscription();
    if (_blockProvider != null && _blockListener != null) {
      _blockProvider!.removeListener(_blockListener!);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF5F5F5),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Image.asset('assets/images/applogo/app_logo.png', height: 100),
        centerTitle: true,
        scrolledUnderElevation: 0,
        backgroundColor: Color(0xFFF5F5F5),
        actions: [
          IconButton(
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => FeedSearchPage()),
              );
              if (!mounted) return;
              context.read<FeedProvider>().setQuery('');
            },
            icon: Icon(Icons.search, color: BUTTON),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Consumer2<FeedProvider, ProfileProvider>(
              builder: (context, feedProvider, profileProvider, child) {
                final allPosts = feedProvider.filteredPosts;

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
  BlockProvider? _blockProvider;
  VoidCallback? _blockListener;
  PageController? _pageController;
  int _currentPageIndex = 0;

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

    // PageController 초기화 (이미지가 여러 개인 경우)
    if (widget.post.mediaUrls.length > 1) {
      _pageController = PageController();
    }

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
    _pageController?.dispose();
    _commentProvider.cancelSubscription(widget.post.id);
    if (_blockProvider != null && _blockListener != null) {
      _blockProvider!.removeListener(_blockListener!);
    }

    super.dispose();
  }

  String? extractUrl(String text) {
    final urlPattern = RegExp(r'(https?://[^\s,]+)', caseSensitive: false);

    final match = urlPattern.firstMatch(text);
    return match?.group(0);
  }

  // extractUrl 함수 아래에 추가
  String? convertToDesktopUrl(String? url) {
    if (url == null || url.isEmpty) return null;

    // 모바일 URL을 PC 버전으로 변경
    String desktopUrl = url.replaceFirst(
      'm.sports.naver.com',
      'sports.naver.com',
    );

    // 한글이나 특수문자 포함 시 인코딩
    desktopUrl = Uri.encodeFull(desktopUrl);

    return desktopUrl;
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Card(
          color: WHITE,
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 미디어 없을 때 프로필 정보
              if (widget.post.mediaUrls.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(15),
                  child: Row(
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
                              radius: 20,
                              backgroundImage: url != null
                                  ? NetworkImage(url)
                                  : null,
                              backgroundColor: GRAYSCALE_LABEL_300,
                              child: url == null
                                  ? const Icon(
                                      Icons.person,
                                      color: Colors.grey,
                                      size: 20,
                                    )
                                  : null,
                            ),
                          );
                        },
                      ),
                      SizedBox(width: 10),
                      Consumer<ProfileProvider>(
                        builder: (context, profileProvider, child) {
                          profileProvider.subscribeUserProfile(
                            widget.post.userId,
                          );
                          final nickName =
                              profileProvider.userNicknames[widget
                                  .post
                                  .userId] ??
                              widget.post.userNickName;

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
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  nickName,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  timeAgo(widget.post.createdAt),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: GRAYSCALE_LABEL_400,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      Spacer(),
                      IconButton(
                        onPressed: () {
                          _showPostOptionBottomSheet(
                            context,
                            widget.post,
                            isOwner,
                          );
                        },
                        icon: Icon(Icons.more_horiz),
                      ),
                    ],
                  ),
                ),
              // 이미지 + 오버레이
              if (widget.post.mediaUrls.isNotEmpty)
                Stack(
                  children: [
                    // 이미지
                    ClipRRect(
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                      child: AspectRatio(
                        aspectRatio: 1.0,
                        child: widget.post.mediaUrls.length == 1
                            ? _buildSingleMedia(
                                widget.post.mediaUrls[0],
                                0,
                                selectedColor,
                              )
                            : PageView.builder(
                                controller: _pageController,
                                itemCount: widget.post.mediaUrls.length,
                                onPageChanged: (index) {
                                  setState(() {
                                    _currentPageIndex = index;
                                  });
                                },
                                itemBuilder: (context, index) {
                                  return _buildSingleMedia(
                                    widget.post.mediaUrls[index],
                                    index,
                                    selectedColor,
                                  );
                                },
                              ),
                      ),
                    ),
                    // 이미지 개수 표시 (오른쪽 상단)
                    if (widget.post.mediaUrls.length > 1)
                      Positioned(
                        top: 15,
                        right: 60,
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            '${_currentPageIndex + 1}/${widget.post.mediaUrls.length}',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    // 페이지 인디케이터 (하단 중앙)
                    if (widget.post.mediaUrls.length > 1)
                      Positioned(
                        bottom: 15,
                        left: 0,
                        right: 0,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            widget.post.mediaUrls.length,
                            (index) => Container(
                              margin: EdgeInsets.symmetric(horizontal: 3),
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _currentPageIndex == index
                                    ? BUTTON
                                    : Colors.white.withOpacity(0.4),
                              ),
                            ),
                          ),
                        ),
                      ),
                    // 프로필 오버레이 (왼쪽상단)
                    Positioned(
                      top: 15,
                      left: 15,
                      child: Consumer<ProfileProvider>(
                        builder: (context, profileProvider, child) {
                          profileProvider.subscribeUserProfile(
                            widget.post.userId,
                          );
                          final url =
                              profileProvider.userProfiles[widget.post.userId];
                          final nickName =
                              profileProvider.userNicknames[widget
                                  .post
                                  .userId] ??
                              widget.post.userNickName;

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
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 20,
                                  backgroundImage: url != null
                                      ? NetworkImage(url)
                                      : null,
                                  backgroundColor: Colors.white,
                                  child: url == null
                                      ? const Icon(
                                          Icons.person,
                                          color: Colors.grey,
                                          size: 20,
                                        )
                                      : null,
                                ),
                                SizedBox(width: 8),
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black54,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    nickName,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    // 더보기 버튼 (오른쪽 상단)
                    Positioned(
                      top: 15,
                      right: 15,
                      child: GestureDetector(
                        onTap: () {
                          _showPostOptionBottomSheet(
                            context,
                            widget.post,
                            isOwner,
                          );
                        },
                        child: Container(
                          padding: EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.more_horiz,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),

                    // 좋아요 댓글 버튼 (왼쪽 하단)
                  ],
                ),
              // 텍스트 내용 (이미지 아래)
              Padding(
                padding: const EdgeInsets.all(15),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.post.text.isNotEmpty) ...[
                      Text(
                        widget.post.text,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          height: 1.4,
                        ),
                      ),
                      SizedBox(height: 8),
                    ],
                    Row(
                      children: [
                        // 좋아요 버튼
                        GestureDetector(
                          onTap: () => widget.feedProvider.toggleLikeAndNotify(
                            postId: widget.post.id,
                            post: widget.post,
                            currentUserId: currentUserId!,
                            postOwnerId: widget.post.userId,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                widget.post.likedBy.contains(currentUserId)
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                                color:
                                    widget.post.likedBy.contains(currentUserId)
                                    ? Colors.red
                                    : GRAYSCALE_LABEL_500,
                                size: 20,
                              ),
                              SizedBox(width: 4),
                              Text(
                                '${widget.post.likesCount}',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: 16),
                        // 댓글 버튼
                        Consumer<CommentProvider>(
                          builder: (context, commentProvider, child) {
                            final comments = commentProvider.getComments(
                              widget.post.id,
                            );
                            return Row(
                              children: [
                                Icon(
                                  CupertinoIcons.chat_bubble,
                                  color: GRAYSCALE_LABEL_500,
                                  size: 20,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  '${comments.length}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: GRAYSCALE_LABEL_500,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                        if (widget.post.mediaUrls.isNotEmpty) ...[
                          Spacer(),
                          Text(
                            timeAgo(widget.post.createdAt),
                            style: TextStyle(
                              fontSize: 12,
                              color: GRAYSCALE_LABEL_400,
                            ),
                          ),
                        ],
                      ],
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

  // 단일 미디어 빌드 헬퍼 함수
  Widget _buildSingleMedia(String url, int index, Color progressColor) {
    final isVideo = MediaUtils.isVideoFromPost(widget.post, index);

    if (isVideo) {
      return GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => FullscreenVideoPlayer(videoUrl: url),
            ),
          );
        },
        child: NetworkVideoPlayer(
          videoUrl: url,
          width: double.infinity,
          height: double.infinity,
          fit: BoxFit.cover,
          autoPlay: true,
          muted: true,
          showControls: false,
        ),
      );
    } else {
      return GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => FullscreenImageViewer(
                imageUrls: widget.post.mediaUrls,
                initialIndex: index,
              ),
            ),
          );
        },
        child: Image.network(
          url,
          width: double.infinity,
          height: double.infinity,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Center(
              child: CircularProgressIndicator(color: progressColor),
            );
          },
        ),
      );
    }
  }

  void _showPostOptionBottomSheet(
    BuildContext context,
    PostModel post,
    bool isOwner,
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
              if (isOwner) ...[
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
                          await widget.feedProvider.deletePost(widget.post);
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
              ] else ...[
                GestureDetector(
                  onTap: () {
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
                    Navigator.pop(context); // 바텀시트 닫기
                    _showFeedReportDialog(
                      context,
                      post,
                      widget.feedProvider,
                      reporter.uid,
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
                          '게시물 신고',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: RED_DANGER_TEXT_50,
                          ),
                        ),
                        Icon(Icons.report_outlined, color: RED_DANGER_TEXT_50),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 10),
                GestureDetector(
                  onTap: () {
                    final uid = FirebaseAuth.instance.currentUser?.uid;
                    if (uid == null) return;
                    Navigator.pop(context); // 바텀시트 닫기
                    _showBlockConfirmDialog(
                      context,
                      widget.post.userNickName,
                      widget.post.userId,
                      uid,
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
                          '사용자 차단',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: RED_DANGER_TEXT_50,
                          ),
                        ),
                        Icon(
                          Icons.person_off_outlined,
                          color: RED_DANGER_TEXT_50,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
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

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: BACKGROUND_COLOR,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 상단 바
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: GRAYSCALE_LABEL_400,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                SizedBox(height: 20),
                Text(
                  '게시물 신고',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 16),
                Text(
                  '신고 사유를 선택해주세요',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 12),
                ...reportReasons.map((reason) {
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
                SizedBox(height: 20),
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
                          final description = reportController.text.trim();
                          final reason =
                              selectedReason +
                              (description.isNotEmpty ? '\n$description' : '');

                          try {
                            final user = FirebaseAuth.instance.currentUser;
                            if (user == null) {
                              Navigator.pop(context);
                              toastification.show(
                                context: context,
                                type: ToastificationType.error,
                                alignment: Alignment.bottomCenter,
                                autoCloseDuration: Duration(seconds: 2),
                                title: Text('로그인이 필요합니다'),
                              );
                              return;
                            }

                            await feedProvider.reportPostAndNotify(
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
                        child: Container(
                          padding: EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: RED_DANGER_TEXT_50,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Text(
                              '신고하기',
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
                SizedBox(height: 20),
              ],
            ),
          ),
        ),
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
                icon: Icons.notifications_off,
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
                        final bottomSheetContext = context;
                        try {
                          await context.read<BlockProvider>().blockUser(
                            currentUserId: currentUserId,
                            targetUserId: userId,
                          );
                          Future.delayed(Duration.zero, () {
                            Navigator.pop(bottomSheetContext);
                            toastification.show(
                              context: bottomSheetContext,
                              type: ToastificationType.success,
                              alignment: Alignment.bottomCenter,
                              autoCloseDuration: Duration(seconds: 2),
                              title: Text('${userNickName}님을 차단했습니다'),
                            );
                          });
                          if (!mounted) return;
                        } catch (e) {
                          Future.delayed(Duration.zero, () {
                            Navigator.pop(bottomSheetContext);
                          });
                          if (!mounted) return;
                          toastification.show(
                            context: bottomSheetContext,
                            type: ToastificationType.error,
                            alignment: Alignment.bottomCenter,
                            autoCloseDuration: Duration(seconds: 2),
                            title: Text('차단 중 오류가 발생했습니다'),
                          );
                        }
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
