import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/model/market_post_model.dart';
import 'package:lockerroom/page/afterMarket/after_market_detail_page.dart';
import 'package:lockerroom/page/alert/diallog.dart';
import 'package:lockerroom/provider/market_feed_provider.dart';
import 'package:lockerroom/provider/team_provider.dart';
import 'package:provider/provider.dart';
import 'package:toastification/toastification.dart';

class MyMarketPage extends StatelessWidget {
  const MyMarketPage({super.key});

  @override
  Widget build(BuildContext context) {
    final marketFeedProvider = Provider.of<MarketFeedProvider>(
      context,
      listen: false,
    );
    final tp = Provider.of<TeamProvider>(context, listen: false);
    final teamColor = tp.selectedTeam?.color;
    return Scaffold(
      backgroundColor: BACKGROUND_COLOR,
      body: StreamBuilder<List<MarketPostModel>>(
        stream: marketFeedProvider.listenMyMarketPosts(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            debugPrint('market 스트림에러 : ${snapshot.error}');
            return Center(child: Text('에러 발생'));
          }
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator(color: teamColor));
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
              return MyMarketPostWidget(
                marketPost: posts[index],
                marketFeed: marketFeedProvider,
              );
            },
          );
        },
      ),
    );
  }
}

class MyMarketPostWidget extends StatelessWidget {
  final MarketPostModel marketPost;
  final MarketFeedProvider marketFeed;
  final VoidCallback? onTap;
  const MyMarketPostWidget({
    super.key,
    required this.marketPost,
    required this.marketFeed,
    this.onTap,
  });

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
    final isOwner = currentUserId != null && marketPost.userId == currentUserId;

    return GestureDetector(
      onTap: () {
        // 조회수 증가
        context.read<MarketFeedProvider>().viewPost(marketPost.postId);
        onTap?.call();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AfterMarketDetailPage(
              marketPost: marketPost,
              postId: marketPost.postId,
            ),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.only(
          top: 10,
          left: 10,
          right: 10,
          bottom: 15,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: WHITE,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: GRAYSCALE_LABEL_200),
          ),
          padding: const EdgeInsets.all(10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 100,
                  height: 100,
                  child: marketPost.imageUrls.isNotEmpty
                      ? Image.network(
                          marketPost.imageUrls[0],
                          fit: BoxFit.cover,
                        )
                      : Container(
                          color: Colors.grey[300],
                          child: const Icon(Icons.image_not_supported),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          marketPost.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        PopupMenuTheme(
                          data: const PopupMenuThemeData(
                            color: BACKGROUND_COLOR,
                          ),
                          child: PopupMenuButton<String>(
                            padding: EdgeInsets.zero,
                            icon: const Icon(Icons.more_vert_rounded, size: 20),
                            onSelected: (value) async {
                              if (value == 'delete' && isOwner) {
                                showDialog(
                                  context: context,
                                  builder: (context) => ConfirmationDialog(
                                    title: '게시글 삭제',
                                    content: '게시글을 삭제 하시겠습니까?',
                                    onConfirm: () async {
                                      try {
                                        await marketFeed.deletePost(marketPost);
                                        toastification.show(
                                          context: context,
                                          type: ToastificationType.success,
                                          alignment: Alignment.bottomCenter,
                                          autoCloseDuration: const Duration(
                                            seconds: 2,
                                          ),
                                          title: const Text('게시물을 삭제했습니다'),
                                        );
                                      } catch (e) {
                                        print('Delete error: $e');
                                        toastification.show(
                                          context: context,
                                          type: ToastificationType.error,
                                          alignment: Alignment.bottomCenter,
                                          autoCloseDuration: const Duration(
                                            seconds: 2,
                                          ),
                                          title: const Text('삭제 중 오류가 발생했습니다'),
                                        );
                                      }
                                    },
                                  ),
                                );
                              } else if (value == 'report') {
                                toastification.show(
                                  context: context,
                                  type: ToastificationType.info,
                                  alignment: Alignment.bottomCenter,
                                  autoCloseDuration: const Duration(seconds: 2),
                                  title: const Text('신고가 접수되었습니다.'),
                                );
                              }
                            },
                            itemBuilder: (context) => [
                              if (isOwner)
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Text(
                                    '삭제',
                                    style: TextStyle(color: RED_DANGER_TEXT_50),
                                  ),
                                )
                              else
                                const PopupMenuItem(
                                  value: 'report',
                                  child: Text('신고'),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    Transform.translate(
                      offset: Offset(0, -10),
                      child: Text(
                        timeAgo(marketPost.createdAt),
                        style: TextStyle(
                          color: GRAYSCALE_LABEL_500,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (marketPost.type == '무료나눔')
                          Text(
                            '나눔',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        else
                          Text(
                            '${marketPost.price}원',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
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
}
