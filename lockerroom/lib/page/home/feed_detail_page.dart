import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/model/post_model.dart';
import 'package:lockerroom/page/alert/diallog.dart';
import 'package:lockerroom/provider/feed_provider.dart';
import 'package:lockerroom/provider/profile_provider.dart';
import 'package:provider/provider.dart';
import 'package:toastification/toastification.dart';

class FeedDetailPage extends StatelessWidget {
  final PostModel post;
  const FeedDetailPage({super.key, required this.post});

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
    final feedProvider = Provider.of<FeedProvider>(context, listen: false);
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final TextEditingController _commentsController = TextEditingController();
    return Scaffold(
      backgroundColor: BACKGROUND_COLOR,
      appBar: AppBar(
        backgroundColor: BACKGROUND_COLOR,
        title: Padding(
          padding: const EdgeInsets.only(top: 10.0),
          child: Image.asset('assets/images/applogo/app_logo.png', height: 100),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.only(left: 15.0, right: 15.0, bottom: 15.0),
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
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return CircleAvatar(
                            radius: 20,
                            backgroundColor: GRAYSCALE_LABEL_300,
                          );
                        }
                        if (!snapshot.hasData || snapshot.data == null) {
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(30),
                            child: const Icon(Icons.person, size: 30),
                          );
                        }
                        return CircleAvatar(
                          radius: 20,
                          backgroundColor: GRAYSCALE_LABEL_300,
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
                    currentUserId != null && post.userId == currentUserId
                        ? PopupMenuTheme(
                            data: PopupMenuThemeData(color: BACKGROUND_COLOR),
                            child: PopupMenuButton<String>(
                              icon: const Icon(Icons.more_horiz),
                              onSelected: (value) async {
                                if (value == 'delete') {
                                  // 삭제 확인 다이얼로그 추가
                                  showDialog(
                                    context: context,
                                    builder: (context) => ConfirmationDialog(
                                      title: '삭제 확인',
                                      content: '게시글을 삭제 하시겠습니까?',
                                      onConfirm: () async {
                                        await feedProvider.deletePost(post.id);
                                        toastification.show(
                                          context: context,
                                          type: ToastificationType.success,
                                          alignment: Alignment.bottomCenter,
                                          autoCloseDuration: Duration(
                                            seconds: 2,
                                          ),
                                          title: Text('게시물을 삭제했습니다.'),
                                        );
                                      },
                                    ),
                                  );
                                }
                              },
                              itemBuilder: (context) => const [
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Text(
                                    '삭제하기',
                                    style: TextStyle(color: RED_DANGER_TEXT_50),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : SizedBox.shrink(),
                  ],
                ),
                const SizedBox(height: 8),
                // 본문
                Text(post.text),
                const SizedBox(height: 8),

                // 이미지/ 영상 슬라이드
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
                                    width: inSingle ? 290 : 150,
                                    height: 200,
                                    color: Colors.black12,
                                    child: Center(child: Text('비디오 미리보기')),
                                  )
                                : Image.network(
                                    url,
                                    height: 200,
                                    width: inSingle ? 290 : 150,
                                    fit: inSingle ? BoxFit.cover : BoxFit.cover,
                                    loadingBuilder:
                                        (context, child, loadingProgress) {
                                          if (loadingProgress == null)
                                            return child;
                                          return SizedBox(
                                            height: 200,
                                            width: inSingle ? 290 : 150,
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
                // 좋아요, 댓글버튼
                Row(
                  children: [
                    IconButton(
                      onPressed: () => feedProvider.toggleLike(post),
                      icon: Icon(
                        (FirebaseAuth.instance.currentUser?.uid != null &&
                                post.likedBy.contains(
                                  FirebaseAuth.instance.currentUser!.uid,
                                ))
                            ? Icons.favorite
                            : Icons.favorite_border,
                        color:
                            (FirebaseAuth.instance.currentUser?.uid != null &&
                                post.likedBy.contains(
                                  FirebaseAuth.instance.currentUser!.uid,
                                ))
                            ? Colors.red
                            : null,
                      ),
                    ),
                    Transform.translate(
                      offset: Offset(-10, 0),
                      child: Text('${post.likesCount}'),
                    ),
                    IconButton(
                      onPressed: () {},
                      icon: Icon(CupertinoIcons.chat_bubble),
                    ),
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
                Spacer(),
                Row(
                  children: [
                    StreamBuilder<String?>(
                      stream: context
                          .read<ProfileProvider>()
                          .liveloadProfileImage(post.userId),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return CircleAvatar(
                            radius: 20,
                            backgroundColor: GRAYSCALE_LABEL_300,
                          );
                        }
                        if (!snapshot.hasData || snapshot.data == null) {
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(30),
                            child: const Icon(Icons.person, size: 30),
                          );
                        }
                        return CircleAvatar(
                          radius: 20,
                          backgroundColor: GRAYSCALE_LABEL_300,
                          backgroundImage: NetworkImage(snapshot.data!),
                        );
                      },
                    ),
                    SizedBox(width: 10),
                    SizedBox(
                      width: 240,
                      height: 35,
                      child: TextFormField(
                        controller: _commentsController,
                        cursorColor: BUTTON,
                        cursorHeight: 15,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: '댓글을 입력해주세요',
                          labelStyle: TextStyle(
                            color: Colors.grey,
                            fontSize: 13,
                          ),
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
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
