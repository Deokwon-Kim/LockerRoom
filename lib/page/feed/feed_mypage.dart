import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_link_previewer/flutter_link_previewer.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/model/post_model.dart';
import 'package:lockerroom/model/team_model.dart';
import 'package:lockerroom/page/alert/confirm_diallog.dart';
import 'package:lockerroom/page/feed/feed_detail_page.dart';
import 'package:lockerroom/page/feed/feed_edit_page.dart';
import 'package:lockerroom/page/follow/follow_list_page.dart';
import 'package:lockerroom/provider/block_provider.dart';
import 'package:lockerroom/provider/feed_provider.dart';
import 'package:lockerroom/provider/follow_provider.dart';
import 'package:lockerroom/provider/profile_provider.dart';
import 'package:lockerroom/provider/team_provider.dart';
import 'package:lockerroom/utils/media_utils.dart';
import 'package:lockerroom/widgets/network_video_player.dart';
import 'package:provider/provider.dart';
import 'package:toastification/toastification.dart';

class FeedMypage extends StatefulWidget {
  final PostModel post;
  final String targetUserId;
  const FeedMypage({super.key, required this.post, required this.targetUserId});

  @override
  State<FeedMypage> createState() => _FeedMypageState();
}

class _FeedMypageState extends State<FeedMypage> {
  String timeAgo(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inSeconds < 60) return '${diff.inSeconds}s 전';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    return '${diff.inDays}일 전';
  }

  @override
  void initState() {
    super.initState();
    // 대상 유저의 팔로우 상태를 초기 로딩하여 UI가 이전 화면의 상태에 의존하지 않도록 함
    Future.microtask(
      () => context.read<FollowProvider>().loadFollowingStatus(
        widget.targetUserId,
      ),
    );
  }

  String? extractUrl(String text) {
    final urlPattern = RegExp(r'(https?://[^\s,]+)', caseSensitive: false);
    final match = urlPattern.firstMatch(text);
    return match?.group(0);
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final feedProvider = Provider.of<FeedProvider>(context, listen: false);
    final fp = context.watch<FollowProvider>();
    final tp = context.watch<TeamProvider>();
    final teamColor = tp.selectedTeam?.color;
    final isOwner =
        currentUserId != null && widget.post.userId == currentUserId;
    return Scaffold(
      backgroundColor: BACKGROUND_COLOR,
      appBar: AppBar(
        backgroundColor: BACKGROUND_COLOR,
        scrolledUnderElevation: 0,
        title: Transform.translate(
          offset: Offset(-20, 0),
          child: Row(
            children: [
              Consumer<ProfileProvider>(
                builder: (context, profileProvider, child) {
                  profileProvider.subscribeUserProfile(widget.post.userId);
                  final nickname =
                      profileProvider.userNicknames[widget.post.userId] ??
                      widget.post.userNickName;
                  return Text(
                    nickname,
                    style: TextStyle(fontWeight: FontWeight.bold),
                  );
                },
              ),

              SizedBox(width: 5),
              StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(widget.targetUserId)
                    .snapshots(),
                builder: (context, snap) {
                  if (!snap.hasData) return const SizedBox.shrink();
                  final data = snap.data!.data();
                  final teamName = data?['team'] as String?;
                  if (teamName == null || teamName.isEmpty)
                    return const SizedBox.shrink();

                  final teams = context.read<TeamProvider>().getTeam('team');
                  TeamModel? teamModel;
                  try {
                    teamModel = teams.firstWhere(
                      (t) => t.name == teamName || t.symplename == teamName,
                    );
                  } catch (_) {}

                  return Transform.translate(
                    offset: Offset(0, 5),
                    child: Text(
                      teamName,
                      style: TextStyle(
                        fontSize: 12,
                        color: teamModel?.color,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        centerTitle: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: 5, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Consumer<ProfileProvider>(
                        builder: (context, pt, child) {
                          final profileUrl =
                              pt.userProfiles[widget.post.userId];
                          return CircleAvatar(
                            radius: 35,
                            backgroundImage: profileUrl != null
                                ? NetworkImage(profileUrl)
                                : null,
                            backgroundColor: GRAYSCALE_LABEL_300,
                            child: profileUrl == null
                                ? const Icon(
                                    Icons.person,
                                    color: Colors.black,
                                    size: 25,
                                  )
                                : null,
                          );
                        },
                      ),
                      SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.post.userName,
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            SizedBox(height: 8),
                            Row(
                              children: [
                                StreamBuilder<List<PostModel>>(
                                  stream: context
                                      .read<FeedProvider>()
                                      .listenUserPosts(widget.post.userId),
                                  builder: (context, snapshot) {
                                    final count =
                                        (snapshot.data ?? const []).length;
                                    return Column(
                                      children: [
                                        Text(
                                          '$count',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        Text(
                                          '게시물',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                                SizedBox(width: 50),
                                StreamBuilder<int>(
                                  stream: fp.getFollowersCountStream(
                                    widget.targetUserId,
                                  ),
                                  builder: (context, snapshot) {
                                    if (!snapshot.hasData) {
                                      final color =
                                          context
                                              .read<TeamProvider>()
                                              .selectedTeam
                                              ?.color ??
                                          BUTTON;
                                      return Center(
                                        child: SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            color: color,
                                            strokeWidth: 2,
                                          ),
                                        ),
                                      );
                                    }
                                    return GestureDetector(
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                FollowListPage(
                                                  userId: widget.targetUserId,
                                                  initialIndex: 0,
                                                ),
                                          ),
                                        );
                                      },
                                      child: Column(
                                        children: [
                                          Text(
                                            '${snapshot.data}',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          Text(
                                            "팔로워",
                                            style: TextStyle(
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                                SizedBox(width: 50),
                                StreamBuilder<int>(
                                  stream: fp.getFollowCountStream(
                                    widget.targetUserId,
                                  ),
                                  builder: (context, snapshot) {
                                    if (!snapshot.hasData) {
                                      final color =
                                          context
                                              .read<TeamProvider>()
                                              .selectedTeam
                                              ?.color ??
                                          BUTTON;
                                      return Center(
                                        child: SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            color: color,
                                            strokeWidth: 2,
                                          ),
                                        ),
                                      );
                                    }
                                    return GestureDetector(
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                FollowListPage(
                                                  userId: widget.targetUserId,
                                                  initialIndex: 1,
                                                ),
                                          ),
                                        );
                                      },
                                      child: Column(
                                        children: [
                                          Text(
                                            '${snapshot.data}',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          Text(
                                            '팔로잉',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: 10),
            if (widget.post.userId != FirebaseAuth.instance.currentUser?.uid)
              if (currentUserId != null)
                StreamBuilder<bool>(
                  stream: context.read<BlockProvider>().getBlockedByStream(
                    currentUserId,
                    widget.targetUserId,
                  ),
                  builder: (context, snapshot) {
                    final isBlockedByTarget = snapshot.data ?? false;
                    return isBlockedByTarget
                        ? Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: GRAYSCALE_LABEL_100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '이 사용자가 회원님을 차단했습니다',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: GRAYSCALE_LABEL_600,
                              ),
                            ),
                          )
                        : Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    fp.toggleFollow(widget.post.userId);
                                  },
                                  child: Container(
                                    padding: EdgeInsets.symmetric(vertical: 8),
                                    decoration: BoxDecoration(
                                      color:
                                          fp.isFollowingUser(widget.post.userId)
                                          ? GRAYSCALE_LABEL_300
                                          : teamColor,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Center(
                                      child: Text(
                                        fp.isFollowingUser(widget.post.userId)
                                            ? '팔로잉'
                                            : '팔로우',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color:
                                              fp.isFollowingUser(
                                                widget.post.userId,
                                              )
                                              ? Colors.black
                                              : Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(width: 10),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    showMenu<String>(
                                      context: context,
                                      position: RelativeRect.fromLTRB(
                                        300,
                                        250,
                                        50,
                                        0,
                                      ),
                                      color: BACKGROUND_COLOR,
                                      items: [
                                        PopupMenuItem(
                                          value: 'block',
                                          child: Text(
                                            '사용자 차단',
                                            style: TextStyle(
                                              color: RED_DANGER_TEXT_50,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ).then((value) {
                                      if (value == 'block') {
                                        final uid = FirebaseAuth
                                            .instance
                                            .currentUser
                                            ?.uid;
                                        if (uid == null) return;
                                        final profileProvider = context
                                            .read<ProfileProvider>();
                                        final nickname =
                                            profileProvider.userNicknames[widget
                                                .post
                                                .userId] ??
                                            widget.post.userNickName;
                                        _showBlockConfirmDialog(
                                          context,
                                          nickname,
                                          widget.post.userId,
                                          uid,
                                        );
                                      }
                                    });
                                  },
                                  child: Container(
                                    padding: EdgeInsets.symmetric(vertical: 8),
                                    decoration: BoxDecoration(
                                      color: GRAYSCALE_LABEL_300,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Center(
                                      child: Text(
                                        '더보기',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                  },
                ),

            SizedBox(height: 30),
            Expanded(
              child: StreamBuilder<List<PostModel>>(
                stream: context.read<FeedProvider>().listenUserPosts(
                  widget.post.userId,
                ),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    final color =
                        context.read<TeamProvider>().selectedTeam?.color ??
                        BUTTON;
                    return Center(
                      child: CircularProgressIndicator(color: color),
                    );
                  }
                  final posts = snapshot.data!;
                  if (posts.isEmpty) {
                    return const Center(child: Text('작성한 게시물이 없습니다'));
                  }
                  return ListView.builder(
                    itemCount: posts.length,
                    itemBuilder: (_, i) {
                      final p = posts[i];
                      return GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => FeedDetailPage(post: p),
                            ),
                          );
                        },
                        child: Card(
                          color: WHITE,
                          child: Padding(
                            padding: EdgeInsets.all(15),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Consumer<ProfileProvider>(
                                      builder: (context, pd, child) {
                                        pd.subscribeUserProfile(
                                          widget.post.userId,
                                        );

                                        final profileUrl =
                                            pd.userProfiles[widget.post.userId];
                                        return CircleAvatar(
                                          radius: 25,
                                          backgroundImage: profileUrl != null
                                              ? NetworkImage(profileUrl)
                                              : null,
                                          backgroundColor: GRAYSCALE_LABEL_300,
                                          child: profileUrl == null
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
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
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
                                                      widget.post.userId,
                                                    );
                                                final nickname =
                                                    profileProvider
                                                        .userNicknames[widget
                                                        .post
                                                        .userId] ??
                                                    widget.post.userNickName;
                                                return Text(
                                                  nickname,
                                                  style: TextStyle(
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                );
                                              },
                                        ),
                                        Text(
                                          timeAgo(widget.post.createdAt),
                                          style: TextStyle(
                                            color: GRAYSCALE_LABEL_500,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Spacer(),
                                    IconButton(
                                      onPressed: () {
                                        _showPostOptionBottomSheet(
                                          context,
                                          p,
                                          feedProvider,
                                          isOwner,
                                        );
                                      },
                                      icon: Icon(Icons.more_horiz),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 8),
                                // 본문
                                Text(p.text),
                                SizedBox(height: 8),
                                if (extractUrl(widget.post.text) != null) ...[
                                  SizedBox(height: 10),
                                  Container(
                                    decoration: BoxDecoration(
                                      color: WHITE,
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.grey.withOpacity(0.2),
                                          blurRadius: 8,
                                          offset: Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        LinkPreview(
                                          enableAnimation: true,
                                          text: extractUrl(widget.post.text)!,
                                          onLinkPreviewDataFetched: (data) {
                                            print(
                                              'Preview data fetched: ${data.title}',
                                            );
                                          },
                                        ),
                                        Container(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 8,
                                          ),
                                          decoration: BoxDecoration(
                                            color: WHITE,
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.link,
                                                size: 16,
                                                color: Colors.blue,
                                              ),
                                              SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  extractUrl(widget.post.text)!,
                                                  style: TextStyle(
                                                    color: Colors.blue,
                                                    fontSize: 13,
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                // 이미지/영상 슬라이드
                                if (p.mediaUrls.isNotEmpty)
                                  LayoutBuilder(
                                    builder: (context, constraints) {
                                      final bool inSingle =
                                          p.mediaUrls.length == 1;
                                      final double avilableWidth =
                                          constraints.maxWidth;
                                      // 리스트 높이와 각 아이템 너비를 화면/가용 폭 기준으로 계산
                                      final double listHeight =
                                          (avilableWidth * 0.55).clamp(
                                            160,
                                            320,
                                          );
                                      final double itemWidth = inSingle
                                          ? avilableWidth
                                          : (avilableWidth * 0.48).clamp(
                                              140,
                                              avilableWidth,
                                            );

                                      return SizedBox(
                                        height: listHeight,
                                        child: ListView.builder(
                                          scrollDirection: Axis.horizontal,
                                          itemCount: p.mediaUrls.length,
                                          itemBuilder: (_, i) {
                                            final url = p.mediaUrls[i];
                                            final isVideo =
                                                MediaUtils.isVideoFromPost(
                                                  p,
                                                  i,
                                                );
                                            return Padding(
                                              padding: EdgeInsets.only(
                                                left: 0,
                                                right: inSingle ? 0 : 8,
                                              ),
                                              child: ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                child: isVideo
                                                    ? NetworkVideoPlayer(
                                                        videoUrl: url,
                                                        width: itemWidth,
                                                        height: listHeight,
                                                        fit: BoxFit.cover,
                                                        autoPlay: true,
                                                        muted: true,
                                                        showControls: false,
                                                      )
                                                    : Image.network(
                                                        url,
                                                        height: listHeight,
                                                        width: itemWidth,
                                                        fit: BoxFit.cover,
                                                        loadingBuilder:
                                                            (
                                                              context,
                                                              child,
                                                              loadingProgress,
                                                            ) {
                                                              if (loadingProgress ==
                                                                  null) {
                                                                return child;
                                                              }
                                                              final color =
                                                                  context
                                                                      .read<
                                                                        TeamProvider
                                                                      >()
                                                                      .selectedTeam
                                                                      ?.color ??
                                                                  BUTTON;
                                                              return SizedBox(
                                                                height:
                                                                    listHeight,
                                                                width:
                                                                    itemWidth,
                                                                child: Center(
                                                                  child:
                                                                      CircularProgressIndicator(
                                                                        color:
                                                                            color,
                                                                      ),
                                                                ),
                                                              );
                                                            },
                                                      ),
                                              ),
                                            );
                                          },
                                        ),
                                      );
                                    },
                                  ),
                                SizedBox(height: 8),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPostOptionBottomSheet(
    BuildContext context,
    PostModel post,
    FeedProvider feedProvider,
    bool isOwner,
  ) {
    showModalBottomSheet(
      isScrollControlled: true,
      context: context,
      backgroundColor: GRAYSCALE_LABEL_50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        height: 200,
        child: Padding(
          padding: EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 상단 바
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: GRAYSCALE_LABEL_400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(height: 20),
              if (isOwner) ...[
                GestureDetector(
                  onTap: () {
                    Navigator.pop(context); // 바텀시트 닫기
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => FeedEditPage(post: post),
                      ),
                    );
                  },
                  child: Container(
                    padding: EdgeInsets.all(10),
                    width: double.infinity,
                    height: 50,
                    decoration: BoxDecoration(
                      color: WHITE,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '게시물 수정',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Icon(Icons.edit_outlined, color: BLACK),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 10),
                GestureDetector(
                  onTap: () {
                    Navigator.pop(context); // 바텀시트 닫기
                    showDialog(
                      context: context,
                      builder: (context) => ConfirmationDialog(
                        title: '삭제 확인',
                        content: '게시물을 삭제 하시겠습니까?',
                        onConfirm: () async {
                          await feedProvider.deletePost(widget.post);
                          toastification.show(
                            context: context,
                            type: ToastificationType.success,
                            alignment: Alignment.bottomCenter,
                            autoCloseDuration: Duration(seconds: 2),
                            title: Text('게시물을 삭제했습니다'),
                          );
                        },
                      ),
                    );
                  },
                  child: Container(
                    padding: EdgeInsets.all(10),
                    width: double.infinity,
                    height: 50,
                    decoration: BoxDecoration(
                      color: WHITE,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '게시물 삭제',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: RED_DANGER_TEXT_50,
                          ),
                        ),
                        Icon(
                          CupertinoIcons.delete_solid,
                          color: RED_DANGER_TEXT_50,
                        ),
                      ],
                    ),
                  ),
                ),
              ] else ...[
                GestureDetector(
                  onTap: () {
                    final reporter = FirebaseAuth.instance.currentUser;
                    if (reporter == null) {
                      toastification.show(
                        context: context,
                        type: ToastificationType.error,
                        alignment: Alignment.bottomCenter,
                        autoCloseDuration: Duration(seconds: 2),
                        title: Text('로그인이 필요합니다'),
                      );
                      return;
                    }
                    Navigator.pop(context); // 바텀시트 닫기
                    _showFeedReportDialog(
                      context,
                      post,
                      feedProvider,
                      reporter.uid,
                    );
                  },
                  child: Container(
                    padding: EdgeInsets.all(10),
                    width: double.infinity,
                    height: 50,
                    decoration: BoxDecoration(
                      color: WHITE,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '게시물 신고',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: RED_DANGER_TEXT_50,
                          ),
                        ),
                        Icon(Icons.report_outlined, color: RED_DANGER_TEXT_50),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 10),
                GestureDetector(
                  onTap: () {
                    final uid = FirebaseAuth.instance.currentUser?.uid;
                    if (uid == null) return;
                    final profileProvider = context.read<ProfileProvider>();
                    final nickname =
                        profileProvider.userNicknames[widget.post.userId] ??
                        widget.post.userNickName;
                    Navigator.pop(context); // 바텀시트 닫기
                    _showBlockConfirmDialog(
                      context,
                      nickname,
                      widget.post.userId,
                      uid,
                    );
                  },
                  child: Container(
                    padding: EdgeInsets.all(10),
                    width: double.infinity,
                    height: 50,
                    decoration: BoxDecoration(
                      color: WHITE,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '사용자 차단',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: RED_DANGER_TEXT_50,
                          ),
                        ),
                        Icon(
                          Icons.person_off_outlined,
                          color: RED_DANGER_TEXT_50,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showFeedReportDialog(
    BuildContext context,
    PostModel post,
    FeedProvider feedProvider,
    String currentUserId,
  ) {
    final TextEditingController reportController = TextEditingController();
    final List<String> reportReasons = [
      '스팸 및 광고',
      '부적절한 콘텐츠',
      '혐오 표현',
      '욕설 및 음란물',
      '개인정보 침해',
      '기타',
    ];
    String selectedReason = reportReasons[0];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: BACKGROUND_COLOR,
        title: Text('댓글 신고'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '신고 사유를 선택해주세요',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 12),
              StatefulBuilder(
                builder: (context, setState) {
                  return Column(
                    children: reportReasons.map((reason) {
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            selectedReason = reason;
                          });
                        },
                        child: Container(
                          margin: EdgeInsets.symmetric(vertical: 4),
                          padding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: selectedReason == reason
                                  ? BUTTON
                                  : GRAYSCALE_LABEL_400,
                              width: selectedReason == reason ? 2 : 1,
                            ),
                            borderRadius: BorderRadius.circular(8),
                            color: selectedReason == reason
                                ? BUTTON.withOpacity(0.1)
                                : Colors.transparent,
                          ),
                          child: Row(
                            children: [
                              Expanded(child: Text(reason)),
                              if (selectedReason == reason)
                                Icon(Icons.check, color: BUTTON),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
              SizedBox(height: 16),
              Text(
                '추가 설명 (선택사항)',
                style: TextStyle(fontSize: 12, color: GRAYSCALE_LABEL_500),
              ),
              SizedBox(height: 8),
              TextField(
                controller: reportController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: '자세한 내용을 입력해주세요',
                  hintStyle: TextStyle(color: GRAYSCALE_LABEL_400),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: GRAYSCALE_LABEL_400),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: BUTTON),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('취소', style: TextStyle(color: Colors.black)),
          ),
          TextButton(
            onPressed: () async {
              final description = reportController.text.trim();
              final reason =
                  selectedReason +
                  (description.isNotEmpty ? '\n$description' : '');

              try {
                final user = FirebaseAuth.instance.currentUser;
                if (user == null) {
                  if (!mounted) return;
                  toastification.show(
                    context: context,
                    type: ToastificationType.error,
                    alignment: Alignment.bottomCenter,
                    autoCloseDuration: Duration(seconds: 2),
                    title: Text('로그인이 필요합니다'),
                  );

                  return;
                }

                await feedProvider.reportPost(
                  post: post,
                  reporterUserId: user.uid,
                  reporterUserName: user.displayName ?? '익명',
                  reason: reason,
                );

                if (!mounted) return;
                Navigator.pop(context);
                toastification.show(
                  context: context,
                  type: ToastificationType.success,
                  alignment: Alignment.bottomCenter,
                  autoCloseDuration: Duration(seconds: 2),
                  title: Text('신고가 접수되었습니다'),
                );
              } catch (e) {
                if (!mounted) return;
                Navigator.pop(context);
                toastification.show(
                  context: context,
                  type: ToastificationType.error,
                  alignment: Alignment.bottomCenter,
                  autoCloseDuration: Duration(seconds: 2),
                  title: Text('신고 중 오류가 발생했습니다'),
                );
              }
            },
            child: Text('신고하기', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showBlockConfirmDialog(
    BuildContext context,
    String userNickName,
    String userId,
    String currentUserId,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: BACKGROUND_COLOR,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: 8),
              // 상단 바
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: GRAYSCALE_LABEL_400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(height: 24),

              // 제목
              Text(
                '${userNickName}님을\n차단하시겠어요?',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 16),

              // 설명 텍스트
              Text(
                '이 사람이 만든 다른 계정과 앞으로 만드는 모든 계정이 함께 차단됩니다. 언제든지 차단을 해제할 수 있습니다.',
                style: TextStyle(
                  fontSize: 13,
                  color: GRAYSCALE_LABEL_600,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 20),

              // 차단 효과 설명
              _buildBlockEffectItem(
                icon: Icons.search_off,
                title: '게시물 및 프로필 숨김',
                description: '해당 사용자는 회원님의 프로필과 게시물을 찾을 수 없습니다.',
              ),
              SizedBox(height: 16),

              _buildBlockEffectItem(
                icon: Icons.comment,
                title: '상호작용 차단',
                description: '해당 사용자가 남긴 댓글은 회원님에게 보이지 않습니다.',
              ),
              SizedBox(height: 16),

              _buildBlockEffectItem(
                icon: Icons.mail,
                title: '메시지 차단',
                description: '해당 사용자는 직접 메시지를 보낼 수 없습니다.',
              ),
              SizedBox(height: 16),

              _buildBlockEffectItem(
                icon: Icons.notifications_off,
                title: '상대방에게 알림 없음',
                description: '상대방에게 회원님이 차단했다는 사실을 알리지 않습니다.',
              ),
              SizedBox(height: 28),

              // 버튼
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          border: Border.all(color: GRAYSCALE_LABEL_300),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text(
                            '취소',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: GRAYSCALE_LABEL_900,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        await context.read<BlockProvider>().blockUser(
                          currentUserId: currentUserId,
                          targetUserId: userId,
                        );
                        if (!mounted) return;
                        Navigator.pop(context);
                        Navigator.pop(context);
                        toastification.show(
                          context: context,
                          type: ToastificationType.success,
                          alignment: Alignment.bottomCenter,
                          autoCloseDuration: Duration(seconds: 2),
                          title: Text('${userNickName}님을 차단했습니다'),
                        );
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: RED_DANGER_TEXT_50,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text(
                            '차단',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: WHITE,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBlockEffectItem({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 24, color: GRAYSCALE_LABEL_600),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: GRAYSCALE_LABEL_900,
                ),
              ),
              SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  fontSize: 12,
                  color: GRAYSCALE_LABEL_600,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
