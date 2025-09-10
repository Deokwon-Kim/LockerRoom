import 'package:carousel_slider/carousel_slider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/model/comment_model.dart';
import 'package:lockerroom/model/market_post_model.dart';
import 'package:lockerroom/page/alert/diallog.dart';
import 'package:lockerroom/provider/comment_provider.dart';
import 'package:lockerroom/provider/profile_provider.dart';
import 'package:provider/provider.dart';

class AfterMarketDetailPage extends StatefulWidget {
  final MarketPostModel marketPost;
  final CommentModel? comment;
  const AfterMarketDetailPage({
    super.key,
    required this.marketPost,
    this.comment,
  });

  @override
  State<AfterMarketDetailPage> createState() => _AfterMarketDetailPageState();
}

class _AfterMarketDetailPageState extends State<AfterMarketDetailPage> {
  final TextEditingController _marketCommentController =
      TextEditingController();
  late final CommentProvider _commentProvider;
  int _currentIndex = 0;
  final ScrollController _scrollController = ScrollController();
  final FocusNode _commentFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // Provider 참조를 보관해 두고 사용 (dispose에서 context 조회 방지)
    _commentProvider = context.read<CommentProvider>();
    // postId별 구독 시작
    _commentProvider.subscribeComments(widget.marketPost.postId);
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
    });
  }

  @override
  void dispose() {
    _commentProvider.cancelSubscription(widget.marketPost.postId);
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

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    Provider.of<CommentProvider>(context, listen: false);
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
          IconButton(
            onPressed: () {},
            icon: Icon(Icons.favorite_border_rounded),
          ),
          IconButton(onPressed: () {}, icon: Icon(Icons.more_vert_rounded)),
        ],
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          controller: _scrollController,
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
                        Text(
                          widget.marketPost.userName,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(15.0),
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
                            Text(
                              '조회수',
                              style: TextStyle(color: GRAYSCALE_LABEL_500),
                            ),
                            SizedBox(width: 5),
                            Text(
                              '10',
                              style: TextStyle(color: GRAYSCALE_LABEL_500),
                            ),
                            SizedBox(width: 5),
                            Text(
                              '찜',
                              style: TextStyle(color: GRAYSCALE_LABEL_500),
                            ),
                            SizedBox(width: 5),
                            Text(
                              '10',
                              style: TextStyle(color: GRAYSCALE_LABEL_500),
                            ),
                            SizedBox(width: 5),
                            Text(
                              '댓글',
                              style: TextStyle(color: GRAYSCALE_LABEL_500),
                            ),
                            SizedBox(width: 5),
                            Consumer<CommentProvider>(
                              builder: (context, commentProvider, child) {
                                final comment = commentProvider.getComments(
                                  widget.marketPost.postId,
                                );
                                return Text(
                                  '${comment.length}',
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
                        // if (widget.marketPost.type == '택배')
                        //   Chip(
                        //     padding: EdgeInsets.symmetric(horizontal: 15),
                        //     label: Text('택배', style: TextStyle(color: WHITE)),
                        //     shape: RoundedRectangleBorder(
                        //       borderRadius: BorderRadius.circular(30),
                        //     ),
                        //     backgroundColor: Colors.green,
                        //   )
                        // else if (widget.marketPost.type == '직거래')
                        //   Chip(
                        //     padding: EdgeInsets.symmetric(horizontal: 15),
                        //     label: const Text('직거래', style: TextStyle(color: WHITE)),
                        //     shape: RoundedRectangleBorder(
                        //       borderRadius: BorderRadius.circular(30),
                        //     ),
                        //     backgroundColor: Doosan,
                        //   )
                        // else if (widget.marketPost.type == '무료나눔')
                        //   Chip(
                        //     padding: EdgeInsets.symmetric(horizontal: 15),
                        //     label: Text('나눔', style: TextStyle(color: WHITE)),
                        //     shape: RoundedRectangleBorder(
                        //       borderRadius: BorderRadius.circular(30),
                        //     ),
                        //     backgroundColor: Samsung,
                        //   ),
                        Consumer<CommentProvider>(
                          builder: (context, commentProvider, child) {
                            final comments = commentProvider.getComments(
                              widget.marketPost.postId,
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Consumer<ProfileProvider>(
                                            builder:
                                                (
                                                  context,
                                                  profileProvider,
                                                  child,
                                                ) {
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
                                                ? () => commentProvider
                                                      .toggleLike(
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
                                                          content:
                                                              '댓글을 삭제 하시겠습니까?',
                                                          onConfirm: () async {
                                                            await commentProvider
                                                                .deleteComment(
                                                                  c,
                                                                );
                                                            if (!mounted)
                                                              return;
                                                          },
                                                        ),
                                                  );
                                                },
                                                itemBuilder: (context) =>
                                                    const [
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
                                        padding: const EdgeInsets.only(
                                          left: 40.0,
                                        ),
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
                      labelText: '댓글을 입력해주세요',
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
                    final comment = CommentModel(
                      id: '', // Firestore에서 자동생성
                      postId: widget.marketPost.postId,
                      userId: user.uid,
                      userName: user.displayName ?? '익명',
                      text: text,
                      createdAt: DateTime.now(),
                      likesCount: 0,
                    );
                    await context.read<CommentProvider>().addComment(
                      widget.marketPost.postId,
                      comment,
                    );
                    if (!mounted) return;
                    _marketCommentController.clear();
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
}
