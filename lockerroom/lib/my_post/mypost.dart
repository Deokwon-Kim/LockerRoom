import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/model/post_model.dart';
import 'package:lockerroom/provider/feed_provider.dart';
import 'package:lockerroom/provider/profile_provider.dart';
import 'package:provider/provider.dart';

class MypostPage extends StatefulWidget {
  const MypostPage({super.key});

  @override
  State<MypostPage> createState() => _MypostPageState();
}

class _MypostPageState extends State<MypostPage> {
  late final Stream<QuerySnapshot> _myPostsStream;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      _myPostsStream = FirebaseFirestore.instance
          .collection('posts')
          .where('userId', isEqualTo: user.uid)
          .orderBy('createdAt', descending: true)
          .snapshots();
    } else {
      _myPostsStream = const Stream.empty();
    }
  }

  @override
  Widget build(BuildContext context) {
    final feedProvider = Provider.of<FeedProvider>(context, listen: false);

    return Scaffold(
      backgroundColor: BACKGROUND_COLOR,
      body: StreamBuilder<QuerySnapshot>(
        stream: _myPostsStream,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: BUTTON),
            );
          }

          final posts = snapshot.data!.docs
              .map((doc) => PostModel.fromDoc(doc))
              .toList();

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
              return MyPostWidget(
                post: posts[index],
                feedProvider: feedProvider,
              );
            },
          );
        },
      ),
    );
  }
}

class MyPostWidget extends StatelessWidget {
  final PostModel post;
  final FeedProvider feedProvider;

  const MyPostWidget({
    required this.post,
    required this.feedProvider,
    super.key,
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
    final profileProvider = context.read<ProfileProvider>();
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
      child: Card(
        color: WHITE,
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 작성자 + 프로필
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  StreamBuilder<String?>(
                    stream: profileProvider.liveloadProfileImage(post.userId),
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
                        backgroundColor: GRAYSCALE_LABEL_300,
                        backgroundImage: NetworkImage(snapshot.data!),
                      );
                    },
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.userName,
                        style: const TextStyle(
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
                  const Spacer(),
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.more_horiz),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // 본문
              Text(post.text),
              const SizedBox(height: 8),
              // 이미지/영상
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
                        padding: EdgeInsets.only(right: inSingle ? 0 : 8),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: url.endsWith('.mp4')
                              ? Container(
                                  width: inSingle ? 290 : 150,
                                  height: 200,
                                  color: Colors.black12,
                                  child: const Center(child: Text('비디오 미리보기')),
                                )
                              : Image.network(
                                  url,
                                  width: inSingle ? 290 : 150,
                                  height: 200,
                                  fit: BoxFit.cover,
                                  loadingBuilder:
                                      (context, child, loadingProgress) {
                                        if (loadingProgress == null)
                                          return child;
                                        return SizedBox(
                                          width: inSingle ? 290 : 150,
                                          height: 200,
                                          child: const Center(
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
              const SizedBox(height: 8),
              // 좋아요 + 댓글
              Row(
                children: [
                  IconButton(
                    onPressed: () => feedProvider.toggleLike(post),
                    icon: Icon(
                      currentUserId != null &&
                              post.likedBy.contains(currentUserId)
                          ? Icons.favorite
                          : Icons.favorite_border,
                      color:
                          currentUserId != null &&
                              post.likedBy.contains(currentUserId)
                          ? Colors.red
                          : null,
                    ),
                  ),
                  Transform.translate(
                    offset: const Offset(-10, 0),
                    child: Text('${post.likesCount}'),
                  ),
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(CupertinoIcons.chat_bubble),
                  ),
                  const Spacer(),
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
            ],
          ),
        ),
      ),
    );
  }
}
