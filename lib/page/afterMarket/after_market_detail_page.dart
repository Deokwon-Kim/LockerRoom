import 'package:carousel_slider/carousel_slider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/model/comment_model.dart';
import 'package:lockerroom/model/market_post_model.dart';
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
  BlockProvider? _blockProvider;
  VoidCallback? _blockListener;
  int _currentIndex = 0;
  final ScrollController _scrollController = ScrollController();
  final FocusNode _commentFocusNode = FocusNode();
  String? _replyParentId;
  String? _replyToUserName;
  final Map<String, bool> _replyVisibility = {}; // 답글 표시/숨김 상태 관리

  @override
  void initState() {
    super.initState();
    // Provider 참조를 보관해 두고 사용 (dispose에서 context 조회 방지)
    _commentProvider = context.read<CommentProvider>();
    // postId별 구독 시작
    _commentProvider.subscribeMarketComments(widget.marketPost.postId);
    // 작성자 프로필은 빌드 외부에서 1회만 구독
    context.read<ProfileProvider>().subscribeUserProfile(
      widget.marketPost.userId,
    );

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

      // 페이지 진입 시 조회수 증가
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<MarketFeedProvider>().viewPost(widget.postId);
      });
    });

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
    final isOwner =
        currentUserId != null && widget.marketPost.userId == currentUserId;
    final marketFeedProvider = Provider.of<MarketFeedProvider>(context);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: BACKGROUND_COLOR,
      appBar: AppBar(
        backgroundColor: BACKGROUND_COLOR,
        scrolledUnderElevation: 0,
        title: Text(
          widget.marketPost.title,
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
                onPressed: () => marketFeedProvider.toggleLike(post),
                icon: Icon(isLiked ? Icons.favorite : Icons.favorite_border),
                color: isLiked ? Colors.red : null,
              );
            },
          ),

          IconButton(
            onPressed: () {
              _showPostOptionBottomSheet(context, marketFeedProvider, isOwner);
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
                    itemCount: widget.marketPost.imageUrls.length,
                    itemBuilder: (context, index, realIndex) {
                      final url = widget.marketPost.imageUrls[index];
                      return Image.network(url, fit: BoxFit.cover, width: 1000);
                    },
                    options: CarouselOptions(
                      height: 350,
                      viewportFraction: 1.0,
                      enlargeCenterPage: false,
                      autoPlay: false,
                      enableInfiniteScroll:
                          widget.marketPost.imageUrls.length > 1, // 무한 스크롤 막기
                      scrollPhysics: widget.marketPost.imageUrls.length > 1
                          ? const PageScrollPhysics() // 이미지가 여러개일때만 스와이프 허용
                          : const NeverScrollableScrollPhysics(), // 이미지 하나일땐 스와이프 막음
                      onPageChanged: (index, reason) {
                        setState(() {
                          _currentIndex = index;
                        });
                      },
                    ),
                  ),
                  if (widget.marketPost.imageUrls.length > 1)
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
                              '${_currentIndex + 1} / ${widget.marketPost.imageUrls.length}',
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
                                .userProfiles[widget.marketPost.userId];
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
                            profileProvider.subscribeUserProfile(
                              widget.marketPost.postId,
                            );
                            final nickname =
                                profileProvider.userNicknames[widget
                                    .marketPost
                                    .postId] ??
                                widget.marketPost.userName;
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
                              widget.marketPost.title,
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
                          timeAgo(widget.marketPost.createdAt),
                          style: TextStyle(
                            color: GRAYSCALE_LABEL_500,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: 5),
                        Text(
                          '${widget.marketPost.price}원',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 5),
                        Text(
                          '${widget.marketPost.description}',
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
                              widget.marketPost.type,
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
                              widget.marketPost.postId,
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
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 0),
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
                SizedBox(width: 10),
                GestureDetector(
                  onTap: () async {
                    final text = _marketCommentController.text.trim();
                    if (text.isEmpty) return;
                    final user = FirebaseAuth.instance.currentUser!;
                    final marketComment = CommentModel(
                      id: '', // Firestore에서 자동생성
                      postId: widget.marketPost.postId,
                      userId: user.uid,
                      userName: user.displayName ?? '익명',
                      text: text,
                      reComments: _replyParentId ?? '',
                      createdAt: DateTime.now(),
                      likesCount: 0,
                    );
                    await context
                        .read<CommentProvider>()
                        .addMarketCommentAndNotify(
                          marketPostId: widget.marketPost.postId,
                          marketComment: marketComment,
                          currentUserId: user.uid,
                          marketPostOwnerId: widget.marketPost.userId,
                          parentMarketCommentOwnerId: _replyParentId == null
                              ? null
                              : _replyParentId,
                        );

                    if (!mounted) return;
                    _marketCommentController.clear();
                    setState(() {
                      _replyParentId = null;
                      _replyToUserName = null;
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
                    padding: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
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
        ),
      ),
    );
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
                Consumer<ProfileProvider>(
                  builder: (context, profileProvider, child) {
                    profileProvider.subscribeUserProfile(parentComment.userId);
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
                    profileProvider.subscribeUserProfile(parentComment.userId);
                    final nickname =
                        profileProvider.userNicknames[parentComment.userId] ??
                        parentComment.userName;
                    return Text(
                      nickname,
                      style: TextStyle(fontWeight: FontWeight.bold),
                    );
                  },
                ),
                Spacer(),
                Consumer<CommentProvider>(
                  builder: (context, commentProvider, _) {
                    final updatedComment = commentProvider
                        .getMarketComments(widget.marketPost.postId)
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
            ),
            Padding(
              padding: const EdgeInsets.only(left: 40.0),
              child: Transform.translate(
                offset: Offset(0, -10),
                child: Text(
                  parentComment.text,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w400),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 0.0),
              child: Transform.translate(
                offset: Offset(0, -5),
                child: Column(
                  children: [
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
                        child: Transform.translate(
                          offset: Offset(15, -15),
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
              Consumer<ProfileProvider>(
                builder: (context, profileProvider, child) {
                  profileProvider.subscribeUserProfile(reply.userId);
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
                  profileProvider.subscribeUserProfile(reply.userId);
                  final nickname =
                      profileProvider.userNicknames[reply.userId] ??
                      reply.userName;
                  return Text(
                    nickname,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  );
                },
              ),
              Spacer(),
              Consumer<CommentProvider>(
                builder: (context, commentProvider, _) {
                  final updatedReply = commentProvider
                      .getMarketComments(widget.marketPost.postId)
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
          ),
          Padding(
            padding: const EdgeInsets.only(left: 32.0),
            child: Transform.translate(
              offset: Offset(0, -8),
              child: Text(
                reply.text,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w400),
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
                  onTap: () {
                    Navigator.pop(context); // 바텀시트 닫기
                    // Navigator.push(
                    //   context,
                    //   MaterialPageRoute(
                    //     builder: (context) => FeedEditPage(post: post),
                    //   ),
                    // );
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
                          await mfp.deletePost(widget.marketPost);
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
                    _showMarketFeedReportDialog(
                      context,
                      widget.marketPost,
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
                      widget.marketPost.userName,
                      widget.marketPost.userId,
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

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: BACKGROUND_COLOR,
        title: Text('게시물 신고'),
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

                await marketFeedProvider.reportMarketPost(
                  marketPost: marketPost,
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
