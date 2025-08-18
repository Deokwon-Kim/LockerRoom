import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fade_shimmer/fade_shimmer.dart';
import 'package:flutter/material.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/model/post_model.dart';
import 'package:lockerroom/provider/feed_provider.dart';
import 'package:lockerroom/provider/profile_provider.dart';
import 'package:provider/provider.dart';

class FeedPage extends StatefulWidget {
  final PostModel? post; // nullable로 변경
  const FeedPage({this.post, super.key});

  @override
  State<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage> {
  @override
  Widget build(BuildContext context) {
    final feedProvider = Provider.of<FeedProvider>(context, listen: false);
    // 단일 포스트 모드
    if (widget.post != null) {
      return Scaffold(
        appBar: AppBar(
          title: Image.asset('assets/images/applogo/app_logo.png', height: 100),
          centerTitle: true,
          backgroundColor: BACKGROUND_COLOR,
        ),
        backgroundColor: BACKGROUND_COLOR,
        body: PostWidget(post: widget.post!, feedProvider: feedProvider),
      );
    }

    // 전체 피드 모드
    return Scaffold(
      appBar: AppBar(
        title: Padding(
          padding: const EdgeInsets.only(top: 10.0),
          child: Image.asset('assets/images/applogo/app_logo.png', height: 100),
        ),
        centerTitle: true,
        backgroundColor: BACKGROUND_COLOR,
        scrolledUnderElevation: 0,
      ),
      backgroundColor: BACKGROUND_COLOR,
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('posts')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return FadeShimmer(
              width: 150,
              height: 8,
              radius: 4,
              fadeTheme: FadeTheme.light,
            );

          final posts = snapshot.data!.docs
              .map((doc) => PostModel.fromDoc(doc))
              .toList();

          if (posts.isEmpty) {
            return Center(
              child: Text(
                '게시물이 없습니다.',
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
              return PostWidget(post: posts[index], feedProvider: feedProvider);
            },
          );
        },
      ),
    );
  }
}

// 개별 포스트 위젯
class PostWidget extends StatelessWidget {
  final PostModel post;
  final FeedProvider feedProvider;

  const PostWidget({required this.post, required this.feedProvider, super.key});

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
    return Padding(
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
                  StreamBuilder<String?>(
                    stream: context
                        .read<ProfileProvider>()
                        .liveloadProfileImage(post.userId),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return CircleAvatar(
                          radius: 20,
                          backgroundColor: GRAYSCALE_LABEL_300,
                        );
                      }
                      if (!snapshot.hasData || snapshot.data == null) {
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(30),
                          child: const Icon(Icons.person, size: 20),
                        );
                      }
                      return CircleAvatar(
                        radius: 20,
                        backgroundImage: NetworkImage(snapshot.data!),
                      );
                    },
                  ),
                  SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.userName,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        timeAgo(post.createdAt),
                        style: TextStyle(
                          color: GRAYSCALE_LABEL_500,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  Spacer(),
                  IconButton(onPressed: () {}, icon: Icon(Icons.more_horiz)),
                ],
              ),
              const SizedBox(height: 8),
              // 본문
              Text(post.text),
              const SizedBox(height: 8),

              // 이미지/영상 슬라이드
              if (post.mediaUrls.isNotEmpty)
                SizedBox(
                  height: 200,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: post.mediaUrls.length,
                    itemBuilder: (_, i) {
                      final url = post.mediaUrls[i];
                      final inSingle = post.mediaUrls.length == 1;

                      return Padding(
                        padding: EdgeInsets.only(
                          left: inSingle ? 0 : 0,
                          right: inSingle ? 0 : 8,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: url.endsWith('.mp4')
                              ? Container(
                                  width: inSingle
                                      ? 290
                                      : 150, // 단일: 화면 전체, 여러장: 150
                                  height: 200,
                                  color: Colors.black12,
                                  child: Center(child: Text('비디오 미리보기')),
                                )
                              : Image.network(
                                  url,
                                  height: 200,
                                  width: inSingle
                                      ? 290
                                      : 150, // 단일: 화면 전체, 여러장: 150
                                  fit: inSingle
                                      ? BoxFit.cover
                                      : BoxFit.cover, // 단일은 contain, 여러장 cover
                                  loadingBuilder:
                                      (context, child, loadingProgress) {
                                        if (loadingProgress == null)
                                          return child;
                                        return const Center(
                                          child: Padding(
                                            padding: EdgeInsets.only(right: 8),
                                            child: CircularProgressIndicator(
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
                ),
              // 좋아요 버튼
              Row(
                children: [
                  IconButton(
                    onPressed: () => feedProvider.toggleLike(post),
                    icon: Icon(Icons.favorite_border),
                  ),
                  Text('${post.likesCount}'),
                ],
              ),
              Text(
                '${post.mediaUrls.length}개의 이미지',
                style: TextStyle(
                  color: GRAYSCALE_LABEL_500,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
