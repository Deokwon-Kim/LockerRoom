import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/model/post_model.dart';
import 'package:lockerroom/model/user_model.dart';
import 'package:lockerroom/provider/feed_provider.dart';
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
      ),
      backgroundColor: BACKGROUND_COLOR,
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('posts')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return const Center(
              child: CircularProgressIndicator(color: BUTTON, strokeWidth: 2),
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

// 🔹 개별 포스트 위젯
class PostWidget extends StatelessWidget {
  final PostModel post;
  final FeedProvider feedProvider;

  const PostWidget({required this.post, required this.feedProvider, super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: WHITE,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 작성자 + 프로필
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(post.userId)
                .snapshots(),
            builder: (context, userSnapshot) {
              if (!userSnapshot.hasData)
                return const ListTile(title: Text('로딩중...'));
              final user = UserModel.fromDoc(userSnapshot.data!);
              return ListTile(
                leading: CircleAvatar(
                  backgroundImage:
                      user.profileImageUrl != null &&
                          user.profileImageUrl!.isNotEmpty
                      ? NetworkImage(user.profileImageUrl!)
                      : null,
                  child:
                      user.profileImageUrl == null ||
                          user.profileImageUrl!.isEmpty
                      ? const Icon(Icons.person)
                      : null,
                ),
                title: Text(
                  user.username ?? 'Unknown',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              );
            },
          ),

          // 본문
          Padding(
            padding: const EdgeInsets.only(left: 70.0),
            child: Text(post.text),
          ),
          const SizedBox(height: 8),

          // 이미지/영상 슬라이드
          if (post.mediaUrls.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 70.0),
              child: SizedBox(
                height: 200,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: post.mediaUrls.length,
                  itemBuilder: (_, i) {
                    final url = post.mediaUrls[i];
                    return Container(
                      margin: const EdgeInsets.only(left: 8, right: 8),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: url.endsWith('.mp4')
                            ? Center(child: Text('비디오 미리보기'))
                            : Image.network(
                                url,
                                height: 200,
                                width: 150,
                                fit: BoxFit.cover,
                                loadingBuilder:
                                    (context, child, loadingProgress) {
                                      if (loadingProgress == null) return child;
                                      return const Center(
                                        child: CircularProgressIndicator(
                                          color: BUTTON,
                                        ),
                                      );
                                    },
                              ),
                      ),
                    );
                  },
                ),
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
        ],
      ),
    );
  }
}
