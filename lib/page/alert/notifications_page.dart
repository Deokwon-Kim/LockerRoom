import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/model/market_post_model.dart';
import 'package:lockerroom/model/post_model.dart';
import 'package:lockerroom/page/afterMarket/after_market_detail_page.dart';
import 'package:lockerroom/page/feed/feed_detail_page.dart';
import 'package:lockerroom/page/myPage/user_detail_page.dart';
import 'package:lockerroom/provider/notification_provider.dart';
import 'package:provider/provider.dart';
import 'package:lockerroom/provider/team_provider.dart';
import 'package:toastification/toastification.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  @override
  void initState() {
    super.initState();
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<NotificationProvider>().listen(userId);
        // 페이지 진입시 모든 알림을 읽음 처리
        context.read<NotificationProvider>().markAllAsRead(userId);
      });
    }
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _formatRelative(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inSeconds < 60) {
      return '방금 전';
    }
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}분 전';
    }
    if (diff.inHours < 24) {
      return '${diff.inHours}시간 전';
    }
    return '${diff.inDays}일 전';
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NotificationProvider>();
    final selectedColor =
        context.watch<TeamProvider>().selectedTeam?.color ?? BUTTON;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '알림',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
        backgroundColor: BACKGROUND_COLOR,
        foregroundColor: BLACK,
        scrolledUnderElevation: 0,
      ),
      backgroundColor: BACKGROUND_COLOR,
      body: provider.isLoading
          ? Center(child: CircularProgressIndicator(color: selectedColor))
          : provider.notifications.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.notifications_none,
                    color: GRAYSCALE_LABEL_400,
                    size: 40,
                  ),
                  SizedBox(height: 8),
                  Text(
                    '새 알림이 없습니다',
                    style: TextStyle(color: GRAYSCALE_LABEL_500, fontSize: 14),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    itemCount: provider.notifications.length,
                    itemBuilder: (context, index) {
                      final n = provider.notifications[index];
                      final createdAt = n.createdAt ?? DateTime.now();
                      final bool showHeader = index == 0
                          ? true
                          : !_isSameDay(
                              createdAt,
                              (provider.notifications[index - 1].createdAt ??
                                  DateTime.now()),
                            );
                      return FutureBuilder<
                        DocumentSnapshot<Map<String, dynamic>>
                      >(
                        future: FirebaseFirestore.instance
                            .collection('users')
                            .doc(n.fromUserId)
                            .get(),
                        builder: (context, snap) {
                          final isFollow = n.type == 'follow';
                          final isFeedLike = n.type == 'feedLike';
                          final commentLike = n.type == 'commentLike';
                          final isComment = n.type == 'comment';
                          final isMarketComment = n.type == 'marketComment';
                          final isReport = n.type == 'report';
                          final isCommentReport =
                              n.type == 'coment_report' ||
                              n.type == 'comment_report';
                          final isMarketCommentReport =
                              n.type == 'market_comment_report';
                          final isMarketPostReport =
                              n.type == 'market_post_report';

                          // users 컬렉션에서 사용자 정보 가져오기
                          final data = snap.data?.data() ?? {};
                          final fetchedName = (data['userNickName'] as String?)
                              ?.trim();
                          final name =
                              (n.userNickName.isNotEmpty
                                      ? n.userNickName
                                      : (fetchedName ?? '알 수 없음'))
                                  .trim();
                          final imageUrl =
                              (data['profileImage'] as String?) ?? '';

                          final tile = GestureDetector(
                            onTap: () async {
                              // 알림 타입에 따라 다른 페이지로 이동
                              if (n.postId != null) {
                                if (isFeedLike || isComment) {
                                  // 일반 피드 게시물로 이동
                                  try {
                                    final postDoc = await FirebaseFirestore
                                        .instance
                                        .collection('posts')
                                        .doc(n.postId)
                                        .get();

                                    if (postDoc.exists) {
                                      final post = PostModel.fromDoc(postDoc);
                                      if (!context.mounted) return;
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              FeedDetailPage(post: post),
                                        ),
                                      );
                                    } else {
                                      // 게시물이 삭제된 경우
                                      if (!context.mounted) return;
                                      toastification.show(
                                        context: context,
                                        type: ToastificationType.error,
                                        alignment: Alignment.bottomCenter,
                                        autoCloseDuration: Duration(seconds: 2),
                                        title: Text('게시물을 찾을 수 없습니다'),
                                      );
                                    }
                                  } catch (e) {
                                    if (!context.mounted) return;
                                    toastification.show(
                                      context: context,
                                      type: ToastificationType.error,
                                      alignment: Alignment.bottomCenter,
                                      autoCloseDuration: Duration(seconds: 2),
                                      title: Text('오류가 발생했습니다'),
                                    );
                                  }
                                } else if (isMarketComment) {
                                  // 마켓 게시물로 이동
                                  try {
                                    final marketPostDoc =
                                        await FirebaseFirestore.instance
                                            .collection('market_posts')
                                            .doc(n.postId)
                                            .get();

                                    if (marketPostDoc.exists) {
                                      final marketPost =
                                          MarketPostModel.fromDoc(
                                            marketPostDoc,
                                          );
                                      if (!context.mounted) return;
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              AfterMarketDetailPage(
                                                marketPost: marketPost,
                                                postId: n.postId!,
                                              ),
                                        ),
                                      );
                                    } else {
                                      // 마켓 게시물이 삭제 된 경우
                                      if (!context.mounted) return;
                                      toastification.show(
                                        context: context,
                                        type: ToastificationType.error,
                                        alignment: Alignment.bottomCenter,
                                        autoCloseDuration: Duration(seconds: 2),
                                        title: Text('게시물을 찾을 수 없습니다'),
                                      );
                                    }
                                  } catch (e) {
                                    if (!context.mounted) return;
                                    toastification.show(
                                      context: context,
                                      type: ToastificationType.error,
                                      alignment: Alignment.bottomCenter,
                                      autoCloseDuration: Duration(seconds: 2),
                                      title: Text('오류가 발생했습니다'),
                                    );
                                  }
                                }
                              } else if (commentLike && n.commentId != null) {
                                // 댓글 좋아요의 경우 - 해당 댓글이 있는 게시물로 이동
                                try {
                                  final commentDoc = await FirebaseFirestore
                                      .instance
                                      .collection('comments')
                                      .doc(n.commentId)
                                      .get();

                                  if (commentDoc.exists) {
                                    final commentPostId =
                                        commentDoc.data()?['postId'] as String?;
                                    if (commentPostId != null) {
                                      final postDoc = await FirebaseFirestore
                                          .instance
                                          .collection('posts')
                                          .doc(commentPostId)
                                          .get();

                                      if (postDoc.exists) {
                                        final post = PostModel.fromDoc(postDoc);
                                        if (!context.mounted) return;
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                FeedDetailPage(post: post),
                                          ),
                                        );
                                      }
                                    }
                                  } else {
                                    if (!context.mounted) return;
                                    toastification.show(
                                      context: context,
                                      type: ToastificationType.error,
                                      alignment: Alignment.bottomCenter,
                                      autoCloseDuration: Duration(seconds: 2),
                                      title: Text('댓글을 찾을 수 없습니다'),
                                    );
                                  }
                                } catch (e) {
                                  if (!context.mounted) return;
                                  toastification.show(
                                    context: context,
                                    type: ToastificationType.error,
                                    alignment: Alignment.bottomCenter,
                                    autoCloseDuration: Duration(seconds: 2),
                                    title: Text('오류가 발생했습니다'),
                                  );
                                }
                              }
                            },
                            child: Padding(
                              padding: const EdgeInsets.only(left: 10.0),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 20,
                                    backgroundColor: GRAYSCALE_LABEL_300,
                                    backgroundImage: imageUrl.isNotEmpty
                                        ? CachedNetworkImageProvider(imageUrl)
                                        : null,
                                    child: imageUrl.isEmpty
                                        ? const Icon(
                                            Icons.person,
                                            color: GRAYSCALE_LABEL_500,
                                            size: 20,
                                          )
                                        : null,
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => UserDetailPage(
                                            userId: n.fromUserId,
                                          ),
                                        ),
                                      );
                                    },
                                    child: Text(
                                      name,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: BLACK,
                                      ),
                                    ),
                                  ),
                                  if (isFollow) ...[
                                    Transform.translate(
                                      offset: Offset(-10, 0),
                                      child: Text(
                                        '님이 회원님을 팔로우하기 시작했습니다.',
                                        style: TextStyle(fontSize: 14),
                                      ),
                                    ),
                                  ] else if (isFeedLike) ...[
                                    Transform.translate(
                                      offset: Offset(-10, 0),
                                      child: Text(
                                        '님이 회원님의 게시물을 좋아합니다.',
                                        style: TextStyle(fontSize: 14),
                                      ),
                                    ),
                                  ] else if (isComment) ...[
                                    Transform.translate(
                                      offset: Offset(-10, 0),
                                      child: Text(
                                        '님이 회원님의 게시글에 댓글을 남겼습니다.',
                                        style: TextStyle(fontSize: 14),
                                      ),
                                    ),
                                  ] else if (commentLike) ...[
                                    Transform.translate(
                                      offset: Offset(-10, 0),
                                      child: Text(
                                        '님이 회원님의 댓글을 좋아합니다.',
                                        style: TextStyle(fontSize: 14),
                                      ),
                                    ),
                                  ] else if (isMarketComment) ...[
                                    Transform.translate(
                                      offset: Offset(-10, 0),
                                      child: Text(
                                        '님이 회원님의 게시글의 댓글을 남겼습니다.',
                                        style: TextStyle(fontSize: 14),
                                      ),
                                    ),
                                  ] else if (isMarketPostReport) ...[
                                    Transform.translate(
                                      offset: Offset(-10, 0),
                                      child: Text(
                                        '마켓 게시글 신고발생 🚨',
                                        style: TextStyle(fontSize: 14),
                                      ),
                                    ),
                                  ] else if (isReport) ...[
                                    Transform.translate(
                                      offset: Offset(-10, 0),
                                      child: Text(
                                        '게시글 신고발생 🚨',
                                        style: TextStyle(fontSize: 14),
                                      ),
                                    ),
                                  ] else if (isMarketCommentReport) ...[
                                    Transform.translate(
                                      offset: Offset(-10, 0),
                                      child: Text(
                                        '마켓 댓글 신고발생 🚨',
                                        style: TextStyle(fontSize: 14),
                                      ),
                                    ),
                                  ] else if (isCommentReport) ...[
                                    Transform.translate(
                                      offset: Offset(-10, 0),
                                      child: Text(
                                        '피드 댓글 신고발생 🚨',
                                        style: TextStyle(fontSize: 14),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );

                          final slidableTile = Slidable(
                            key: ValueKey(index),
                            endActionPane: ActionPane(
                              motion: ScrollMotion(),
                              children: [
                                SlidableAction(
                                  onPressed: (context) async {
                                    try {
                                      await provider.deleteNotification(n.id);
                                      if (!mounted) return;
                                      toastification.show(
                                        context: context,
                                        type: ToastificationType.success,
                                        alignment: Alignment.bottomCenter,
                                        autoCloseDuration: Duration(seconds: 2),
                                        title: Text('알림이 삭제되었습니다'),
                                      );
                                    } catch (e) {
                                      if (!mounted) return;
                                      toastification.show(
                                        context: context,
                                        type: ToastificationType.error,
                                        alignment: Alignment.bottomCenter,
                                        autoCloseDuration: Duration(seconds: 2),
                                        title: Text('알림 삭제에 실패했습니다'),
                                      );
                                    }
                                  },
                                  backgroundColor: RED_DANGER_TEXT_50,
                                  icon: Icons.delete,
                                  foregroundColor: WHITE,
                                ),
                              ],
                            ),
                            child: tile,
                          );

                          if (showHeader) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  child: Text(
                                    _formatRelative(createdAt),
                                    style: TextStyle(
                                      fontSize: 17,
                                      color: BLACK,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                slidableTile,
                              ],
                            );
                          }
                          return slidableTile;
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
