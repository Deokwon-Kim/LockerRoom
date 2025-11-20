import 'package:carousel_slider/carousel_slider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/model/comment_model.dart';
import 'package:lockerroom/model/market_post_model.dart';
import 'package:lockerroom/page/afterMarket/after_market_edit_page.dart';
import 'package:lockerroom/page/alert/confirm_diallog.dart';
import 'package:lockerroom/provider/block_provider.dart';
import 'package:lockerroom/provider/comment_provider.dart';
import 'package:lockerroom/provider/market_feed_provider.dart';
import 'package:lockerroom/provider/profile_provider.dart';
import 'package:provider/provider.dart';
import 'package:toastification/toastification.dart';

class AfterMarketDetailPage extends StatefulWidget {
  final MarketPostModel marketPost;
  final CommentModel? comment;
  final String postId;
  const AfterMarketDetailPage({
    super.key,
    required this.marketPost,
    this.comment,
    required this.postId,
  });

  @override
  State<AfterMarketDetailPage> createState() => _AfterMarketDetailPageState();
}

class _AfterMarketDetailPageState extends State<AfterMarketDetailPage> {
  final TextEditingController _marketCommentController =
      TextEditingController();
  late final CommentProvider _commentProvider;
  late final MarketFeedProvider _marketFeedProvider;
  late final ProfileProvider _profileProvider;
  BlockProvider? _blockProvider;
  VoidCallback? _blockListener;
  int _currentIndex = 0;
  final ScrollController _scrollController = ScrollController();
  final FocusNode _commentFocusNode = FocusNode();
  String? _replyParentId;
  String? _replyToUserName;
  final Map<String, bool> _replyVisibility = {}; // 답글 표시/숨김 상태 관리
  bool _isInitialized = false;
  bool _isSecretComment = false; // 비밀댓글 여부
  late MarketPostModel _currentMarketPost; // 현재 게시물 상태 관리

  @override
  void initState() {
    super.initState();
    // 현재 게시물 초기화
    _currentMarketPost = widget.marketPost;

    // 입력창 포커스 시 스크롤을 맨 아래로 이동
    _commentFocusNode.addListener(() {
      if (_commentFocusNode.hasFocus) {
        Future.delayed(const Duration(milliseconds: 120), () {
          if (!_scrollController.hasClients) return;
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          );
        });
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // 한 번만 실행되도록 체크
    if (!_isInitialized) {
      // Provider 참조를 보관해 두고 사용 (dispose에서 context 조회 방지)
      _commentProvider = context.read<CommentProvider>();
      _marketFeedProvider = context.read<MarketFeedProvider>();
      _profileProvider = context.read<ProfileProvider>();
      _blockProvider = context.read<BlockProvider>();

      // build 완료 후 초기화 (notifyListeners 호출 방지)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;

        // postId별 구독 시작
        _commentProvider.subscribeMarketComments(widget.marketPost.postId);

        // 작성자 프로필 구독
        _profileProvider.subscribeUserProfile(widget.marketPost.userId);

        // 초기 동기화
        _commentProvider.setBlockedUsers(_blockProvider!.blockedUserIds);
        _commentProvider.setBlockedByUsers(_blockProvider!.blockedByUserIds);

        // 차단 목록 변경 리스너
        _blockListener = () {
          _commentProvider.setBlockedUsers(_blockProvider!.blockedUserIds);
          _commentProvider.setBlockedByUsers(_blockProvider!.blockedByUserIds);
        };
        _blockProvider!.addListener(_blockListener!);

        // 페이지 진입 시 조회수 증가
        _marketFeedProvider.viewPost(widget.postId);
      });

      _isInitialized = true;
    }
  }

  @override
  void dispose() {
    _commentProvider.cancelSubscription(widget.marketPost.postId);
    if (_blockProvider != null && _blockListener != null) {
      _blockProvider!.removeListener(_blockListener!);
    }
    _marketCommentController.dispose();
    _commentFocusNode.dispose();
    _scrollController.dispose();
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

  Stream<MarketPostModel> getPostStream(String postId) {
    return FirebaseFirestore.instance
        .collection('market_posts')
        .doc(postId)
        .snapshots()
        .map((doc) => MarketPostModel.fromDoc(doc));
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final marketFeedProvider = Provider.of<MarketFeedProvider>(
      context,
      listen: true,
    );
    final isOwner =
        currentUserId != null && _currentMarketPost.userId == currentUserId;

    // MarketFeedProvider에서 최신 게시물 가져오기
    final latestMarketPost =
        marketFeedProvider.getMarketPostById(_currentMarketPost.postId) ??
        _currentMarketPost;
    if (latestMarketPost != _currentMarketPost) {
      // 최신 게시물로 업데이트
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _currentMarketPost = latestMarketPost;
          });
        }
      });
    }

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: BACKGROUND_COLOR,
      appBar: AppBar(
        backgroundColor: BACKGROUND_COLOR,
        scrolledUnderElevation: 0,
        title: Text(
          _currentMarketPost.title,
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          StreamBuilder<MarketPostModel>(
            stream: getPostStream(widget.postId),
            builder: (context, snapshot) {
              final post = snapshot.data ?? widget.marketPost;
              final isLiked =
                  FirebaseAuth.instance.currentUser?.uid != null &&
                  post.likedBy.contains(FirebaseAuth.instance.currentUser!.uid);
              return IconButton(
                onPressed: () => _marketFeedProvider.toggleLike(post),
                icon: Icon(isLiked ? Icons.favorite : Icons.favorite_border),
                color: isLiked ? Colors.red : null,
              );
            },
          ),

          IconButton(
            onPressed: () {
              _showPostOptionBottomSheet(context, _marketFeedProvider, isOwner);
            },
            icon: Icon(Icons.more_horiz),
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          child: Column(
            children: [
              Stack(
                children: [
                  CarouselSlider.builder(
                    itemCount: _currentMarketPost.imageUrls.length,
                    itemBuilder: (context, index, realIndex) {
                      final url = _currentMarketPost.imageUrls[index];
                      return Image.network(url, fit: BoxFit.cover, width: 1000);
                    },
                    options: CarouselOptions(
                      height: 350,
                      viewportFraction: 1.0,
                      enlargeCenterPage: false,
                      autoPlay: false,
                      enableInfiniteScroll:
                          _currentMarketPost.imageUrls.length > 1, // 무한 스크롤 막기
                      scrollPhysics: _currentMarketPost.imageUrls.length > 1
                          ? const PageScrollPhysics() // 이미지가 여러개일때만 스와이프 허용
                          : const NeverScrollableScrollPhysics(), // 이미지 하나일땐 스와이프 막음
                      onPageChanged: (index, reason) {
                        setState(() {
                          _currentIndex = index;
                        });
                      },
                    ),
                  ),
                  if (_currentMarketPost.imageUrls.length > 1)
                    Padding(
                      padding: const EdgeInsets.only(top: 315.0, right: 10.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withAlpha(150),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${_currentIndex + 1} / ${_currentMarketPost.imageUrls.length}',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 10.0, left: 10.0),
                    child: Row(
                      children: [
                        Consumer<ProfileProvider>(
                          builder: (context, profileProvider, child) {
                            final url = profileProvider
                                .userProfiles[_currentMarketPost.userId];
                            return CircleAvatar(
                              radius: 23,
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
                        Consumer<ProfileProvider>(
                          builder: (context, profileProvider, child) {
                            // build 중 구독을 피하기 위해 postFrameCallback 사용
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              profileProvider.subscribeUserProfile(
                                _currentMarketPost.userId,
                              );
                            });
                            final nickname =
                                profileProvider.userNicknames[_currentMarketPost
                                    .userId] ??
                                _currentMarketPost.userNickName;
                            return Text(
                              nickname,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              _currentMarketPost.title,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Spacer(),
                            StreamBuilder(
                              stream: getPostStream(widget.postId),
                              builder: (context, snapshot) {
                                if (!snapshot.hasData)
                                  return CircularProgressIndicator(
                                    color: BUTTON,
                                  );

                                final post = snapshot.data!;
                                return Text(
                                  '조회수: ${post.viewCount}',
                                  style: TextStyle(color: GRAYSCALE_LABEL_500),
                                );
                              },
                            ),
                            SizedBox(width: 5),
                            StreamBuilder(
                              stream: getPostStream(widget.postId),
                              builder: (context, snapshot) {
                                if (!snapshot.hasData)
                                  return CircularProgressIndicator(
                                    color: BUTTON,
                                  );
                                final post = snapshot.data!;
                                return Text(
                                  '찜: ${post.likesCount}',
                                  style: TextStyle(color: GRAYSCALE_LABEL_500),
                                );
                              },
                            ),
                            SizedBox(width: 5),
                            Consumer<CommentProvider>(
                              builder: (context, commentProvider, child) {
                                final comment = commentProvider
                                    .getMarketComments(
                                      widget.marketPost.postId,
                                    );
                                return Text(
                                  '댓글: ${comment.length}',
                                  style: TextStyle(color: GRAYSCALE_LABEL_500),
                                );
                              },
                            ),
                          ],
                        ),
                        Text(
                          timeAgo(_currentMarketPost.createdAt),
                          style: TextStyle(
                            color: GRAYSCALE_LABEL_500,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: 5),
                        Text(
                          '${_currentMarketPost.price}원',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 5),
                        Text(
                          '${_currentMarketPost.description}',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 15,
                          ),
                        ),
                        SizedBox(height: 10),
                        Row(
                          children: [
                            Text(
                              '거래 희망 유형 :',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: GRAYSCALE_LABEL_500,
                              ),
                            ),
                            SizedBox(width: 10),
                            Text(
                              _currentMarketPost.type,
                              style: TextStyle(
                                color: GRAYSCALE_LABEL_500,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 10),
                        Consumer<CommentProvider>(
                          builder: (context, commentProvider, child) {
                            final comments = commentProvider.getMarketComments(
                              _currentMarketPost.postId,
                            );
                            if (comments.isEmpty) {
                              return Center(child: Text('댓글이 없습니다.'));
                            }

                            // 댓글과 답글을 구분
                            final parentComments = comments
                                .where((c) => c.reComments.isEmpty)
                                .toList();
                            final replyComments = comments
                                .where((c) => c.reComments.isNotEmpty)
                                .toList();

                            return ListView.builder(
                              shrinkWrap: true,
                              physics: NeverScrollableScrollPhysics(),
                              itemCount: parentComments.length,
                              itemBuilder: (context, index) {
                                final parentComment = parentComments[index];
                                final replies = replyComments
                                    .where(
                                      (r) => r.reComments == parentComment.id,
                                    )
                                    .toList();

                                return _buildCommentWithReplies(
                                  parentComment,
                                  replies,
                                  commentProvider,
                                  currentUserId,
                                );
                              },
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: AnimatedPadding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        child: SafeArea(
          child: Container(
            decoration: BoxDecoration(
              color: WHITE,
              border: Border(
                top: BorderSide(color: GRAYSCALE_LABEL_300, width: 1),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 비밀댓글 체크박스
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _isSecretComment = !_isSecretComment;
                    });
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                    child: Row(
                      children: [
                        Icon(
                          _isSecretComment
                              ? Icons.check_box
                              : Icons.check_box_outline_blank,
                          color: _isSecretComment
                              ? BUTTON
                              : GRAYSCALE_LABEL_500,
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Text(
                          '비밀댓글',
                          style: TextStyle(
                            fontSize: 13,
                            color: _isSecretComment
                                ? BUTTON
                                : GRAYSCALE_LABEL_700,
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(
                          Icons.lock_outline,
                          size: 14,
                          color: _isSecretComment
                              ? BUTTON
                              : GRAYSCALE_LABEL_500,
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 15.0,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          focusNode: _commentFocusNode,
                          controller: _marketCommentController,
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
                            labelText: _replyParentId == null
                                ? '댓글을 입력해주세요'
                                : (_replyToUserName != null
                                      ? '${_replyToUserName}님에게 답글'
                                      : '답글을 입력하세요'),
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
                          final text = _marketCommentController.text.trim();
                          if (text.isEmpty) return;
                          final user = FirebaseAuth.instance.currentUser!;
                          final marketComment = CommentModel(
                            id: '', // Firestore에서 자동생성
                            postId: _currentMarketPost.postId,
                            userId: user.uid,
                            userName: user.displayName ?? '익명',
                            text: text,
                            reComments: _replyParentId ?? '',
                            createdAt: DateTime.now(),
                            likesCount: 0,
                            isSecret: _isSecretComment,
                          );
                          await context
                              .read<CommentProvider>()
                              .addMarketCommentAndNotify(
                                marketPostId: _currentMarketPost.postId,
                                marketComment: marketComment,
                                currentUserId: user.uid,
                                marketPostOwnerId: _currentMarketPost.userId,
                                parentMarketCommentOwnerId:
                                    _replyParentId == null
                                    ? null
                                    : _replyParentId,
                              );

                          if (!mounted) return;
                          _marketCommentController.clear();
                          setState(() {
                            _replyParentId = null;
                            _replyToUserName = null;
                            _isSecretComment = false; // 비밀댓글 상태 초기화
                          });
                          // 전송 후에도 맨 아래로 스크롤
                          Future.delayed(const Duration(milliseconds: 80), () {
                            if (!_scrollController.hasClients) return;
                            _scrollController.animateTo(
                              _scrollController.position.maxScrollExtent,
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeOut,
                            );
                          });
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
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 비밀댓글 텍스트 표시 처리
  Widget _buildCommentText(
    CommentModel comment,
    String? currentUserId,
    String postOwnerId,
  ) {
    // 비밀댓글이 아니면 그냥 표시
    if (!comment.isSecret) {
      return Text(
        comment.text,
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w400),
      );
    }

    // 비밀댓글인 경우: 작성자, 게시물 작성자만 볼 수 있음
    final canView =
        currentUserId != null &&
        (currentUserId == comment.userId || currentUserId == postOwnerId);

    if (canView) {
      return Text(
        comment.text,
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w400),
      );
    } else {
      // 권한이 없는 경우 아무것도 표시하지 않음 (사용자 정보 영역에서 이미 표시함)
      return SizedBox.shrink();
    }
  }

  Widget _buildCommentWithReplies(
    CommentModel parentComment,
    List<CommentModel> replies,
    CommentProvider commentProvider,
    String? currentUserId,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 부모 댓글
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // 비밀댓글 권한 체크
                if (parentComment.isSecret &&
                    currentUserId != null &&
                    currentUserId != parentComment.userId &&
                    currentUserId != _currentMarketPost.userId) ...[
                  // 권한이 없는 경우: 비밀댓글입니다 표시
                  Row(
                    children: [
                      Icon(Icons.lock, size: 16, color: GRAYSCALE_LABEL_500),
                      SizedBox(width: 6),
                      Text(
                        '비밀댓글입니다',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: GRAYSCALE_LABEL_500,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  // 권한이 있는 경우: 프로필 정보 표시
                  Consumer<ProfileProvider>(
                    builder: (context, profileProvider, child) {
                      // build 중 구독을 피하기 위해 postFrameCallback 사용
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        profileProvider.subscribeUserProfile(
                          parentComment.userId,
                        );
                      });
                      final url =
                          profileProvider.userProfiles[parentComment.userId];
                      return CircleAvatar(
                        radius: 15,
                        backgroundImage: url != null ? NetworkImage(url) : null,
                        backgroundColor: GRAYSCALE_LABEL_300,
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
                  Consumer<ProfileProvider>(
                    builder: (context, profileProvider, child) {
                      // build 중 구독을 피하기 위해 postFrameCallback 사용
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        profileProvider.subscribeUserProfile(
                          parentComment.userId,
                        );
                      });
                      final nickname =
                          profileProvider.userNicknames[parentComment.userId] ??
                          parentComment.userName;
                      return Row(
                        children: [
                          Text(
                            nickname,
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          if (parentComment.isSecret) ...[
                            SizedBox(width: 4),
                            Icon(
                              Icons.lock,
                              size: 14,
                              color: GRAYSCALE_LABEL_600,
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                ],
                Spacer(),
                // 비밀댓글이고 권한이 없으면 좋아요/메뉴 버튼 숨김
                if (!(parentComment.isSecret &&
                    currentUserId != null &&
                    currentUserId != parentComment.userId &&
                    currentUserId != _currentMarketPost.userId)) ...[
                  Consumer<CommentProvider>(
                    builder: (context, commentProvider, _) {
                      final updatedComment = commentProvider
                          .getMarketComments(_currentMarketPost.postId)
                          .firstWhere(
                            (comment) => comment.id == parentComment.id,
                            orElse: () => parentComment,
                          );
                      final bool isLiked =
                          currentUserId != null &&
                          updatedComment.likedBy.contains(currentUserId);

                      return Row(
                        children: [
                          IconButton(
                            onPressed: currentUserId != null
                                ? () => commentProvider.commentLikeAndNotify(
                                    commentId: parentComment.id,
                                    comment: updatedComment,
                                    currentUserId: currentUserId,
                                    commentOwnerId: parentComment.userId,
                                  )
                                : null,
                            icon: Icon(
                              isLiked ? Icons.favorite : Icons.favorite_border,
                              color: isLiked ? Colors.red : null,
                              size: 20,
                            ),
                          ),
                          Text('${updatedComment.likesCount}'),
                        ],
                      );
                    },
                  ),
                  SizedBox(width: 5),
                  if (currentUserId != null)
                    PopupMenuTheme(
                      data: PopupMenuThemeData(color: BACKGROUND_COLOR),
                      child: PopupMenuButton<String>(
                        icon: Icon(Icons.more_horiz),
                        onSelected: (value) async {
                          if (value == 'delete') {
                            showDialog(
                              context: context,
                              builder: (context) => ConfirmationDialog(
                                title: '댓글 삭제',
                                content: '댓글을 삭제 하시겠습니까?',
                                onConfirm: () async {
                                  await commentProvider.deleteMarketComment(
                                    parentComment,
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
                            _showMarketCommentReportDialog(
                              context,
                              parentComment,
                              commentProvider,
                              currentUserId,
                            );
                          } else if (value == 'block') {
                            final uid = FirebaseAuth.instance.currentUser?.uid;
                            if (uid == null) return;
                            _showBlockConfirmDialog(
                              context,
                              widget.comment!.userName,
                              widget.comment!.userId,
                              currentUserId,
                            );
                          }
                        },
                        itemBuilder: (context) {
                          final isOwner = parentComment.userId == currentUserId;
                          if (isOwner) {
                            return [
                              PopupMenuItem(
                                value: 'delete',
                                child: Text(
                                  '삭제하기',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ),
                            ];
                          } else {
                            return [
                              PopupMenuItem(
                                value: 'report',
                                child: Text(
                                  '신고하기',
                                  style: TextStyle(color: Colors.black),
                                ),
                              ),
                              PopupMenuItem(
                                value: 'block',
                                child: Text(
                                  '사용자 차단',
                                  style: TextStyle(color: RED_DANGER_TEXT_50),
                                ),
                              ),
                            ];
                          }
                        },
                      ),
                    ),
                ],
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(left: 40.0),
              child: Transform.translate(
                offset: Offset(0, -10),
                child: _buildCommentText(
                  parentComment,
                  currentUserId,
                  _currentMarketPost.userId,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 0.0),
              child: Transform.translate(
                offset: Offset(0, -5),
                child: Column(
                  children: [
                    // 비밀댓글이고 권한이 없으면 답글달기 버튼 숨김
                    if (!(parentComment.isSecret &&
                        currentUserId != null &&
                        currentUserId != parentComment.userId &&
                        currentUserId != _currentMarketPost.userId))
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _replyParentId = parentComment.id;
                            _replyToUserName = parentComment.userName;
                          });
                          _commentFocusNode.requestFocus();
                        },
                        child: Text(
                          '답글달기',
                          style: TextStyle(
                            fontSize: 14,
                            color: GRAYSCALE_LABEL_500,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    if (replies.isNotEmpty) ...[
                      SizedBox(width: 10),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _replyVisibility[parentComment.id] =
                                !(_replyVisibility[parentComment.id] ?? true);
                          });
                        },
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              (_replyVisibility[parentComment.id] ?? true)
                                  ? Icons.keyboard_arrow_down
                                  : Icons.keyboard_arrow_right,
                              size: 16,
                              color: GRAYSCALE_LABEL_500,
                            ),
                            SizedBox(width: 4),
                            Text(
                              (_replyVisibility[parentComment.id] ?? true)
                                  ? '답글 숨기기'
                                  : '답글${replies.length}개 보기',
                              style: TextStyle(
                                fontSize: 14,
                                color: GRAYSCALE_LABEL_500,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
        // 답글들
        if (replies.isNotEmpty && (_replyVisibility[parentComment.id] ?? true))
          AnimatedContainer(
            duration: Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            margin: EdgeInsets.only(left: 20, top: 10),
            child: Column(
              children: replies
                  .map(
                    (reply) =>
                        _buildReply(reply, commentProvider, currentUserId),
                  )
                  .toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildReply(
    CommentModel reply,
    CommentProvider commentProvider,
    String? currentUserId,
  ) {
    return Padding(
      padding: const EdgeInsets.only(left: 10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // 비밀댓글 권한 체크
              if (reply.isSecret &&
                  currentUserId != null &&
                  currentUserId != reply.userId &&
                  currentUserId != _currentMarketPost.userId) ...[
                // 권한이 없는 경우: 비밀댓글입니다 표시
                Row(
                  children: [
                    Icon(Icons.lock, size: 14, color: GRAYSCALE_LABEL_500),
                    SizedBox(width: 6),
                    Text(
                      '비밀댓글입니다',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: GRAYSCALE_LABEL_500,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ] else ...[
                // 권한이 있는 경우: 프로필 정보 표시
                Consumer<ProfileProvider>(
                  builder: (context, profileProvider, child) {
                    // build 중 구독을 피하기 위해 postFrameCallback 사용
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      profileProvider.subscribeUserProfile(reply.userId);
                    });
                    final url = profileProvider.userProfiles[reply.userId];
                    return CircleAvatar(
                      radius: 12,
                      backgroundImage: url != null ? NetworkImage(url) : null,
                      backgroundColor: GRAYSCALE_LABEL_300,
                      child: url == null
                          ? const Icon(
                              Icons.person,
                              color: Colors.black,
                              size: 16,
                            )
                          : null,
                    );
                  },
                ),
                SizedBox(width: 8),
                Consumer<ProfileProvider>(
                  builder: (context, profileProvider, child) {
                    // build 중 구독을 피하기 위해 postFrameCallback 사용
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      profileProvider.subscribeUserProfile(reply.userId);
                    });
                    final nickname =
                        profileProvider.userNicknames[reply.userId] ??
                        reply.userName;
                    return Row(
                      children: [
                        Text(
                          nickname,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        if (reply.isSecret) ...[
                          SizedBox(width: 4),
                          Icon(
                            Icons.lock,
                            size: 12,
                            color: GRAYSCALE_LABEL_600,
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ],
              Spacer(),
              // 비밀댓글이고 권한이 없으면 좋아요/메뉴 버튼 숨김
              if (!(reply.isSecret &&
                  currentUserId != null &&
                  currentUserId != reply.userId &&
                  currentUserId != _currentMarketPost.userId)) ...[
                Consumer<CommentProvider>(
                  builder: (context, commentProvider, _) {
                    final updatedReply = commentProvider
                        .getMarketComments(_currentMarketPost.postId)
                        .firstWhere(
                          (comment) => comment.id == reply.id,
                          orElse: () => reply,
                        );
                    final bool isLiked =
                        currentUserId != null &&
                        updatedReply.likedBy.contains(currentUserId);

                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          onPressed: currentUserId != null
                              ? () => commentProvider.commentLikeAndNotify(
                                  commentId: reply.id,
                                  comment: updatedReply,
                                  currentUserId: currentUserId,
                                  commentOwnerId: reply.userId,
                                )
                              : null,
                          icon: Icon(
                            isLiked ? Icons.favorite : Icons.favorite_border,
                            color: isLiked ? Colors.red : null,
                            size: 16,
                          ),
                        ),
                        Text(
                          '${updatedReply.likesCount}',
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    );
                  },
                ),
                SizedBox(width: 5),
                if (currentUserId != null && reply.userId == currentUserId)
                  PopupMenuTheme(
                    data: PopupMenuThemeData(color: BACKGROUND_COLOR),
                    child: PopupMenuButton<String>(
                      icon: Icon(Icons.more_horiz, size: 16),
                      onSelected: (value) async {
                        showDialog(
                          context: context,
                          builder: (context) => ConfirmationDialog(
                            title: '답글 삭제',
                            content: '답글을 삭제 하시겠습니까?',
                            onConfirm: () async {
                              await commentProvider.deleteMarketComment(reply);
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
                            style: TextStyle(color: Colors.red, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 32.0),
            child: Transform.translate(
              offset: Offset(0, -8),
              child: _buildCommentText(
                reply,
                currentUserId,
                _currentMarketPost.userId,
              ),
            ),
          ),
          SizedBox(height: 8),
        ],
      ),
    );
  }

  // 댓글 신고 다이얼로그
  void _showMarketCommentReportDialog(
    BuildContext context,
    CommentModel comment,
    CommentProvider commentProvider,
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
            child: Text('취소', style: TextStyle(color: BLACK)),
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

                await commentProvider.reportMarketComment(
                  comment: comment,
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

  void _showPostOptionBottomSheet(
    BuildContext context,
    MarketFeedProvider mfp,
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
                  onTap: () async {
                    Navigator.pop(context); // 바텀시트 닫기
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            AfterMarketEditPage(marketPost: _currentMarketPost),
                      ),
                    );
                    // 편집 페이지에서 돌아온 후 최신 게시물 정보 가져오기
                    if (mounted) {
                      final updatedMarketPost = _marketFeedProvider
                          .getMarketPostById(_currentMarketPost.postId);
                      if (updatedMarketPost != null) {
                        setState(() {
                          _currentMarketPost = updatedMarketPost;
                        });
                      }
                    }
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
                    final pageContext = context; // 페이지 context 저장
                    Navigator.pop(context); // 바텀시트 닫기
                    showDialog(
                      context: pageContext,
                      builder: (dialogContext) => ConfirmationDialog(
                        title: '삭제 확인',
                        content: '게시물을 삭제 하시겠습니까?',
                        onConfirm: () async {
                          // 다이얼로그 닫기
                          Navigator.pop(dialogContext);

                          // 게시물 삭제
                          await mfp.deletePost(_currentMarketPost);

                          // mounted 체크
                          if (!mounted) return;

                          // 토스트 메시지 표시 (페이지 닫기 전)
                          try {
                            toastification.show(
                              context: pageContext,
                              type: ToastificationType.success,
                              alignment: Alignment.bottomCenter,
                              autoCloseDuration: Duration(seconds: 2),
                              title: Text('게시물을 삭제했습니다'),
                            );
                          } catch (e) {
                            // context가 유효하지 않은 경우 무시
                            print('토스트 표시 실패: $e');
                          }

                          // Detail 페이지 닫기 (리스트로 돌아가기)
                          // 약간의 딜레이를 주어 토스트가 표시된 후 페이지 닫기
                          Future.delayed(Duration(milliseconds: 50), () {
                            try {
                              if (mounted) {
                                Navigator.pop(pageContext);
                              }
                            } catch (e) {
                              // 이미 닫힌 경우 무시
                              print('페이지 닫기 실패: $e');
                            }
                          });
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
                    _showMarketFeedReportDialog(
                      context,
                      _currentMarketPost,
                      mfp,
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
                      _currentMarketPost.userNickName,
                      _currentMarketPost.userId,
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

  void _showMarketFeedReportDialog(
    BuildContext context,
    MarketPostModel marketPost,
    MarketFeedProvider marketFeedProvider,
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

                            await marketFeedProvider.reportMarketPost(
                              marketPost: marketPost,
                              reporterUserId: user.uid,
                              reporterUserNickName: user.displayName ?? '익명',
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

  // 사용자 차단 다이얼로그
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
                            toastification.show(
                              context: bottomSheetContext,
                              type: ToastificationType.error,
                              alignment: Alignment.bottomCenter,
                              autoCloseDuration: Duration(seconds: 2),
                              title: Text('차단 중 오류가 발생했습니다'),
                            );
                          });
                          if (!mounted) return;
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
