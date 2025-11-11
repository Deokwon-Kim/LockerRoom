import 'package:flutter/material.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/page/feed/feed_search_page.dart';
import 'package:lockerroom/provider/feed_provider.dart';
import 'package:provider/provider.dart';

class LikedPostsPage extends StatefulWidget {
  const LikedPostsPage({super.key});

  @override
  State<LikedPostsPage> createState() => _LikedPostsPageState();
}

class _LikedPostsPageState extends State<LikedPostsPage> {
  late final FeedProvider _feedProvider;
  @override
  void initState() {
    super.initState();
    _feedProvider = context.read<FeedProvider>();
    // 구독시작
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _feedProvider.subscribeLikedPosts();
    });
  }

  @override
  void dispose() {
    // 페이지를 나갈때 구독취소
    _feedProvider.cancelLikedPostsSubscription();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BACKGROUND_COLOR,
      appBar: AppBar(
        backgroundColor: BACKGROUND_COLOR,
        title: Text(
          '좋아요한 게시물',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        scrolledUnderElevation: 0,
      ),
      body: Consumer<FeedProvider>(
        builder: (context, feedProvider, child) {
          final likedPosts = feedProvider.likedPosts;

          if (likedPosts.isEmpty) {
            return Center(child: Text('좋아요한 게시물이 없습니다.'));
          }

          return ListView.builder(
            itemCount: likedPosts.length,
            itemBuilder: (context, index) {
              return PostWidget(
                post: likedPosts[index],
                feedProvider: feedProvider,
              );
            },
          );
        },
      ),
    );
  }
}
