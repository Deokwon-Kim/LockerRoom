import 'package:flutter/material.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/model/post_model.dart';
import 'package:lockerroom/provider/feed_provider.dart';
import 'package:provider/provider.dart';

class FeedPage extends StatelessWidget {
  const FeedPage({super.key});

  @override
  Widget build(BuildContext context) {
    final feedProvider = context.read<FeedProvider>();

    return Scaffold(
      backgroundColor: BACKGROUND_COLOR,
      body: StreamBuilder<List<PostModel>>(
        stream: feedProvider.postsStream,
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return const Center(
              child: CircularProgressIndicator(color: BUTTON, strokeWidth: 2),
            );
          final posts = snapshot.data!;
          return ListView.builder(
            itemCount: posts.length,
            itemBuilder: (_, index) {
              return PostCard(post: posts[index]);
            },
          );
        },
      ),
    );
  }
}

class PostCard extends StatefulWidget {
  final PostModel post;
  const PostCard({super.key, required this.post});

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  int _currentPage = 0;

  @override
  Widget build(BuildContext context) {
    final feedProvider = context.read<FeedProvider>();

    return Padding(
      padding: const EdgeInsets.all(10.0),
      child: Card(
        color: WHITE,
        margin: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 작성자 + 시간
              Row(
                children: [
                  CircleAvatar(
                    radius: 25,
                    backgroundColor: GRAYSCALE_LABEL_300,
                  ),
                ],
              ),
              Text(
                widget.post.userId,
                style: TextStyle(fontWeight: FontWeight.bold, color: BLACK),
              ),
              Text(widget.post.text),
              SizedBox(height: 8),
              // 이미지 / 영상 슬라이드
              if (widget.post.mediaUrls.isNotEmpty)
                SizedBox(
                  height: 200,
                  child: Stack(
                    alignment: Alignment.bottomCenter,
                    children: [
                      ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: widget.post.mediaUrls.length,

                        itemBuilder: (_, i) {
                          final url = widget.post.mediaUrls[i];
                          return url.endsWith('.mp4')
                              ? Center(child: Text('비디오 미리보기'))
                              : Container(
                                  margin: EdgeInsets.only(right: 8),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      url,
                                      loadingBuilder:
                                          (context, child, loadingProgress) {
                                            if (loadingProgress == null)
                                              return child; // 로딩 완료
                                            return Center(
                                              child: CircularProgressIndicator(
                                                color: BUTTON,
                                                value:
                                                    loadingProgress
                                                            .expectedTotalBytes !=
                                                        null
                                                    ? loadingProgress
                                                              .cumulativeBytesLoaded /
                                                          loadingProgress
                                                              .expectedTotalBytes!
                                                    : null,
                                              ),
                                            );
                                          },
                                      height: 200,
                                      width: 150,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                );
                        },
                      ),
                    ],
                  ),
                ),
              Row(
                children: [
                  IconButton(
                    onPressed: () => feedProvider.toggleLike(widget.post),
                    icon: Icon(Icons.favorite_border),
                  ),
                  Text('${widget.post.likesCount}'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
