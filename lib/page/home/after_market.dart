import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/model/market_post_model.dart';
import 'package:lockerroom/page/alert/diallog.dart';
import 'package:lockerroom/page/home/after_market_upload_page.dart';
import 'package:lockerroom/provider/market_feed_provider.dart';
import 'package:provider/provider.dart';
import 'package:toastification/toastification.dart';

class AfterMarket extends StatefulWidget {
  final MarketPostModel? marketPost;
  const AfterMarket({super.key, this.marketPost});

  @override
  State<AfterMarket> createState() => _AfterMarketState();
}

class _AfterMarketState extends State<AfterMarket> {
  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final marketFeedProvider = context.read<MarketFeedProvider>();

    marketFeedProvider.marketPostStream(uid);
  }

  bool _isSerching = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BACKGROUND_COLOR,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: BACKGROUND_COLOR,
        title: Text(
          '더베이스 마켓',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: () {
              setState(() {
                if (_isSerching) {
                  // 검색 종료 시 검색어 초기화
                  Provider.of<MarketFeedProvider>(
                    context,
                    listen: false,
                  ).setQuery('');
                }
                _isSerching = !_isSerching;
              });
            },
            icon: Icon(Icons.search),
          ),
        ],
        scrolledUnderElevation: 0,
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_isSerching)
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
                      onChanged: (value) => Provider.of<MarketFeedProvider>(
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
                  child: Consumer<MarketFeedProvider>(
                    builder: (context, marketFeed, child) {
                      final allMakretPosts = marketFeed.marketPostsStream;
                      if (marketFeed.isLoading) {
                        return Center(
                          child: CircularProgressIndicator(color: BUTTON),
                        );
                      }
                      if (allMakretPosts.isEmpty) {
                        return Center(
                          child: Text(
                            '게시물이 없습니다',
                            style: TextStyle(color: GRAYSCALE_LABEL_500),
                          ),
                        );
                      }
                      return ListView.builder(
                        itemCount: allMakretPosts.length,
                        itemBuilder: (context, index) => MarketPostWidget(
                          marketPost: allMakretPosts[index],
                          merketFeed: marketFeed,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AfterMarketUploadPage(),
                          ),
                        );
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 15,
                          vertical: 15,
                        ),
                        decoration: BoxDecoration(
                          color: BUTTON,
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Icon(Icons.add, color: WHITE),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class MarketPostWidget extends StatefulWidget {
  final MarketPostModel marketPost;
  final MarketFeedProvider merketFeed;

  const MarketPostWidget({
    required this.marketPost,
    required this.merketFeed,
    super.key,
  });

  @override
  State<MarketPostWidget> createState() => _MarketPostsWidgetState();
}

class _MarketPostsWidgetState extends State<MarketPostWidget> {
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
    final isOwner =
        currentUserId != null && widget.marketPost.userId == currentUserId;

    print('MarketPostWidget Debug - currentUserId: $currentUserId');
    print('MarketPostWidget Debug - post.userId: ${widget.marketPost.userId}');
    print('MarketPostWidget Debug - isOwner: $isOwner');

    return GestureDetector(
      onTap: () {},
      child: Padding(
        padding: const EdgeInsets.only(left: 5, right: 5, bottom: 15),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: widget.marketPost.imageUrls.isNotEmpty
                      ? Image.network(widget.marketPost.imageUrls[0])
                      : Container(
                          width: 100,
                          height: 100,
                          color: Colors.grey[300],
                          child: Icon(Icons.image_not_supported),
                        ),
                ),
                SizedBox(width: 20),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.marketPost.title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      timeAgo(widget.marketPost.createdAt),
                      style: TextStyle(
                        color: GRAYSCALE_LABEL_500,
                        fontSize: 13,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      '${widget.marketPost.price}원',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Spacer(),
                if (isOwner)
                  PopupMenuTheme(
                    data: PopupMenuThemeData(color: BACKGROUND_COLOR),
                    child: PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert_rounded),
                      onSelected: (value) async {
                        if (value == 'delete') {
                          // 삭제 확인 다이얼로그
                          showDialog(
                            context: context,
                            builder: (context) => ConfirmationDialog(
                              title: '게시글 삭제',
                              content: '게시글을 삭제 하시겠습니까?',
                              onConfirm: () async {
                                try {
                                  // 삭제 실행
                                  await widget.merketFeed.deletePost(
                                    widget.marketPost,
                                  );

                                  // 성공 토스트
                                  toastification.show(
                                    context: context,
                                    type: ToastificationType.success,
                                    alignment: Alignment.bottomCenter,
                                    autoCloseDuration: Duration(seconds: 2),
                                    title: Text('게시물을 삭제했습니다'),
                                  );
                                } catch (e) {
                                  print('Delete error: $e');
                                  // 에러 토스트
                                  toastification.show(
                                    context: context,
                                    type: ToastificationType.error,
                                    alignment: Alignment.bottomCenter,
                                    autoCloseDuration: Duration(seconds: 2),
                                    title: Text('삭제 중 오류가 발생했습니다'),
                                  );
                                }
                              },
                            ),
                          );
                        }
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(
                          value: 'delete',
                          child: Text(
                            '삭제',
                            style: TextStyle(color: RED_DANGER_TEXT_50),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
