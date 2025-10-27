import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:contained_tab_bar_view/contained_tab_bar_view.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/model/post_model.dart';
import 'package:lockerroom/model/team_model.dart';
import 'package:lockerroom/page/my_post/user_market_post_page.dart';
import 'package:lockerroom/page/my_post/user_post_page.dart';
import 'package:lockerroom/page/follow/follow_list_page.dart';
import 'package:lockerroom/provider/block_provider.dart';
import 'package:lockerroom/provider/feed_provider.dart';
import 'package:lockerroom/provider/follow_provider.dart';
import 'package:provider/provider.dart';
import 'package:lockerroom/provider/team_provider.dart';
import 'package:toastification/toastification.dart';

class UserDetailPage extends StatefulWidget {
  final String userId;
  const UserDetailPage({super.key, required this.userId});

  @override
  State<UserDetailPage> createState() => _UserDetailPageState();
}

class _UserDetailPageState extends State<UserDetailPage> {
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
    Future.microtask(
      () => context.read<FollowProvider>().loadFollowingStatus(widget.userId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fp = context.watch<FollowProvider>();
    final tp = context.watch<TeamProvider>();
    final teamColor = tp.selectedTeam?.color;
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    if (currentUserId == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('로그인이 필요합니다')),
      );
    }

    // 현재 사용자가 이 프로필의 소유자에게 차단당했는지 확인
    return StreamBuilder<bool>(
      stream: context.read<BlockProvider>().getBlockedByStream(
        currentUserId,
        widget.userId,
      ),
      builder: (context, blockedSnapshot) {
        // 차단당했으면 접근 불가 화면 표시
        if (blockedSnapshot.data == true) {
          return Scaffold(
            backgroundColor: BACKGROUND_COLOR,
            appBar: AppBar(
              backgroundColor: BACKGROUND_COLOR,
              title: const Text('프로필'),
            ),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.block,
                      size: 64,
                      color: GRAYSCALE_LABEL_400,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      '이 프로필에 접근할 수 없습니다',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '사용자가 회원님을 차단했습니다',
                      style: TextStyle(
                        fontSize: 14,
                        color: GRAYSCALE_LABEL_600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(widget.userId)
              .snapshots(),
          builder: (context, snap) {
            if (!snap.hasData) {
              final color =
                  context.read<TeamProvider>().selectedTeam?.color ?? BUTTON;
              return Center(child: CircularProgressIndicator(color: color));
            }
            final data = snap.data!.data() ?? {};
            final nickName = (data['username'] as String?) ?? '';
            final userName = (data['name'] as String?) ?? '';
            final teamName = data['team'] as String?;
            if (teamName == null || teamName.isEmpty)
              return const SizedBox.shrink();

            final teams = context.read<TeamProvider>().getTeam('team');
            TeamModel? teamModel;
            try {
              teamModel = teams.firstWhere(
                (t) => t.name == teamName || t.symplename == teamName,
              );
            } catch (_) {}
            final imageUrl = (data['profileImage'] as String?) ?? '';

            return Scaffold(
              backgroundColor: BACKGROUND_COLOR,
              appBar: AppBar(
                backgroundColor: BACKGROUND_COLOR,
                title: Row(
                  children: [
                    Transform.translate(
                      offset: Offset(-15, 0),
                      child: Text(
                        nickName,
                        style: TextStyle(
                          fontSize: 25,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    SizedBox(width: 5),
                    Transform.translate(
                      offset: Offset(-15, 5),
                      child: Text(
                        teamName,
                        style: TextStyle(
                          color: teamModel?.color,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              body: Padding(
                padding: const EdgeInsets.all(15.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: GRAYSCALE_LABEL_300,
                              radius: 40,
                              backgroundImage: imageUrl.isNotEmpty
                                  ? NetworkImage(imageUrl)
                                  : null,
                              child: imageUrl.isEmpty
                                  ? const Icon(
                                      Icons.person,
                                      color: Colors.black,
                                    )
                                  : null,
                            ),
                            SizedBox(width: 20),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    userName,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  SizedBox(height: 5),
                                  Row(
                                    children: [
                                      StreamBuilder<List<PostModel>>(
                                        stream: context
                                            .read<FeedProvider>()
                                            .listenUserPosts(widget.userId),
                                        builder: (context, snapshot) {
                                          final count =
                                              (snapshot.data ?? const [])
                                                  .length;
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
                                          widget.userId,
                                        ),
                                        builder: (context, snpshot) {
                                          if (!snpshot.hasData) {
                                            final teamColor =
                                                context
                                                    .read<TeamProvider>()
                                                    .selectedTeam
                                                    ?.color ??
                                                BUTTON;
                                            return Center(
                                              child: SizedBox(
                                                width: 20,
                                                height: 20,
                                                child:
                                                    CircularProgressIndicator(
                                                      color: teamColor,
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
                                                        userId: widget.userId,
                                                        initialIndex: 0,
                                                      ),
                                                ),
                                              );
                                            },
                                            child: Column(
                                              children: [
                                                Text(
                                                  '${snpshot.data}',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                                Text(
                                                  '팔로워',
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
                                          widget.userId,
                                        ),
                                        builder: (context, snpshot) {
                                          if (!snpshot.hasData) {
                                            final teamColor =
                                                context
                                                    .read<TeamProvider>()
                                                    .selectedTeam
                                                    ?.color ??
                                                BUTTON;
                                            return Center(
                                              child: SizedBox(
                                                width: 20,
                                                height: 20,
                                                child:
                                                    CircularProgressIndicator(
                                                      color: teamColor,
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
                                                        userId: widget.userId,
                                                        initialIndex: 1,
                                                      ),
                                                ),
                                              );
                                            },
                                            child: Column(
                                              children: [
                                                Text(
                                                  '${snpshot.data}',
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
                    SizedBox(height: 10),
                    if (widget.userId != FirebaseAuth.instance.currentUser?.uid)
                      StreamBuilder<bool>(
                        stream: context
                            .read<BlockProvider>()
                            .getBlockedByStream(
                              FirebaseAuth.instance.currentUser?.uid ?? '',
                              widget.userId,
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
                                          fp.toggleFollow(widget.userId);
                                        },
                                        child: Container(
                                          padding: EdgeInsets.symmetric(
                                            vertical: 8,
                                          ),
                                          decoration: BoxDecoration(
                                            color:
                                                fp.isFollowingUser(
                                                  widget.userId,
                                                )
                                                ? GRAYSCALE_LABEL_300
                                                : teamColor,
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: Center(
                                            child: Text(
                                              fp.isFollowingUser(widget.userId)
                                                  ? '팔로잉'
                                                  : '팔로우',
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                                color:
                                                    fp.isFollowingUser(
                                                      widget.userId,
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
                                              _showBlockConfirmDialog(
                                                context,
                                                nickName,
                                                widget.userId,
                                                uid,
                                              );
                                            }
                                          });
                                        },
                                        child: Container(
                                          padding: EdgeInsets.symmetric(
                                            vertical: 8,
                                          ),
                                          decoration: BoxDecoration(
                                            color: GRAYSCALE_LABEL_300,
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
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

                    SizedBox(height: 10),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: BACKGROUND_COLOR,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: ContainedTabBarView(
                          tabs: [
                            Text('게시글', style: TextStyle(color: BLACK)),
                            Text('마켓', style: TextStyle(color: BLACK)),
                          ],
                          tabBarProperties: TabBarProperties(
                            indicatorColor: teamColor,
                            indicatorSize: TabBarIndicatorSize.tab,
                            indicatorWeight: 3.0,
                            unselectedLabelColor: GRAYSCALE_LABEL_500,
                          ),
                          views: [
                            UserPostPage(userId: widget.userId),
                            UserMarketPostPage(userId: widget.userId),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
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
