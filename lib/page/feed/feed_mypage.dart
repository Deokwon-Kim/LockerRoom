import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_link_previewer/flutter_link_previewer.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/model/attendance_model.dart';
import 'package:lockerroom/model/market_post_model.dart';
import 'package:lockerroom/model/post_model.dart';
import 'package:lockerroom/model/team_model.dart';
import 'package:lockerroom/page/afterMarket/after_market_detail_page.dart';
import 'package:lockerroom/page/alert/confirm_diallog.dart';
import 'package:lockerroom/page/feed/feed_detail_page.dart';
import 'package:lockerroom/page/feed/feed_edit_page.dart';
import 'package:lockerroom/page/follow/follow_list_page.dart';
import 'package:lockerroom/page/intution_record/intution_record_detail_page.dart';
import 'package:lockerroom/page/myPage/quiz_trophy_page.dart';
import 'package:lockerroom/provider/block_provider.dart';
import 'package:lockerroom/provider/comment_provider.dart';
import 'package:lockerroom/provider/feed_provider.dart';
import 'package:lockerroom/provider/follow_provider.dart';
import 'package:lockerroom/provider/market_feed_provider.dart';
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
    // Future.microtask(
    //   () => context.read<FollowProvider>().loadFollowingStatus(
    //     widget.post.userId,
    //   ),
    // );
  }

  String? extractUrl(String text) {
    final urlPattern = RegExp(r'(https?://[^\s,]+)', caseSensitive: false);
    final match = urlPattern.firstMatch(text);
    return match?.group(0);
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final fp = context.watch<FollowProvider>();
    final tp = context.watch<TeamProvider>();
    final myTeamColor = tp.selectedTeam?.color ?? BUTTON;
    final isOwner =
        currentUserId != null && widget.post.userId == currentUserId;

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(widget.targetUserId)
          .snapshots(),
      builder: (context, userSnap) {
        final userData = userSnap.data?.data();
        final teamName = userData?['team'] as String?;
        final realName = (userData?['name'] as String?) ?? widget.post.userName;
        final teams = tp.getTeam('team');
        TeamModel? targetTeamModel;
        if (teamName != null && teamName.isNotEmpty) {
          try {
            targetTeamModel = teams.firstWhere(
              (t) => t.name == teamName || t.symplename == teamName,
            );
          } catch (_) {}
        }
        final activeTeamColor = targetTeamModel?.color ?? myTeamColor;

        return DefaultTabController(
          length: 3,
          child: Scaffold(
            backgroundColor: BACKGROUND_COLOR,
            appBar: AppBar(
              backgroundColor: BACKGROUND_COLOR,
              scrolledUnderElevation: 0,
              centerTitle: false,
              titleSpacing: 0,
              title: Row(
                children: [
                  Flexible(
                    child: Consumer<ProfileProvider>(
                      builder: (context, profileProvider, child) {
                        profileProvider.subscribeUserProfile(
                          widget.post.userId,
                        );
                        final nickname =
                            profileProvider.userNicknames[widget.post.userId] ??
                            widget.post.userNickName;
                        return Text(
                          nickname,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: GRAYSCALE_LABEL_950,
                            letterSpacing: -0.4,
                          ),
                          overflow: TextOverflow.ellipsis,
                        );
                      },
                    ),
                  ),
                  if (teamName != null && teamName.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: activeTeamColor,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: activeTeamColor.withValues(alpha: 0.25),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        teamName,
                        style: const TextStyle(
                          fontSize: 11,
                          color: WHITE,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              // actions: [
              //   if (!isOwner && currentUserId != null)
              //     Padding(
              //       padding: const EdgeInsets.only(right: 16),
              //       child: Center(
              //         child: InkWell(
              //           onTap: () {
              //             final profileProvider = context
              //                 .read<ProfileProvider>();
              //             final nickname =
              //                 profileProvider.userNicknames[widget
              //                     .post
              //                     .userId] ??
              //                 widget.post.userNickName;
              //             _showBlockConfirmDialog(
              //               context,
              //               nickname,
              //               widget.post.userId,
              //               currentUserId,
              //             );
              //           },
              //           borderRadius: BorderRadius.circular(12),
              //           child: Container(
              //             width: 38,
              //             height: 38,
              //             decoration: BoxDecoration(
              //               color: WHITE,
              //               borderRadius: BorderRadius.circular(12),
              //               border: Border.all(
              //                 color: GRAYSCALE_LABEL_200.withValues(alpha: 0.8),
              //               ),
              //               boxShadow: [
              //                 BoxShadow(
              //                   color: BLACK.withValues(alpha: 0.03),
              //                   blurRadius: 6,
              //                   offset: const Offset(0, 2),
              //                 ),
              //               ],
              //             ),
              //             child: const Icon(
              //               Icons.more_horiz_rounded,
              //               color: GRAYSCALE_LABEL_700,
              //               size: 20,
              //             ),
              //           ),
              //         ),
              //       ),
              //     ),
              // ],
            ),
            body: Column(
              children: [
                // 프로필 히어로 라운지 카드 (내 정보 화면과 동일한 디자인)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: WHITE,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: GRAYSCALE_LABEL_200.withValues(alpha: 0.7),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: BLACK.withValues(alpha: 0.04),
                          blurRadius: 16,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // 아바타 (구단 테마 링)
                            Consumer<ProfileProvider>(
                              builder: (context, pt, child) {
                                pt.subscribeUserProfile(widget.post.userId);
                                final profileUrl =
                                    pt.userProfiles[widget.post.userId];
                                return Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: activeTeamColor.withValues(
                                        alpha: 0.3,
                                      ),
                                      width: 2.2,
                                    ),
                                  ),
                                  child: CircleAvatar(
                                    radius: 38,
                                    backgroundImage: profileUrl != null
                                        ? NetworkImage(profileUrl)
                                        : null,
                                    backgroundColor: GRAYSCALE_LABEL_100,
                                    child: profileUrl == null
                                        ? const Icon(
                                            Icons.person_rounded,
                                            color: GRAYSCALE_LABEL_400,
                                            size: 36,
                                          )
                                        : null,
                                  ),
                                );
                              },
                            ),
                            const SizedBox(width: 16),
                            // 닉네임, 구단 뱃지, 이름, 팔로우/더보기 버튼
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          realName,
                                          style: TextStyle(
                                            fontSize: 19,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 7,
                                          vertical: 2.5,
                                        ),
                                        decoration: BoxDecoration(
                                          color: activeTeamColor.withValues(
                                            alpha: 0.12,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: Text(
                                          targetTeamModel != null
                                              ? '${targetTeamModel.symplename} 직관러'
                                              : 'KBO 직관러',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            color: activeTeamColor,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    realName.isNotEmpty
                                        ? '${targetTeamModel?.stadium ?? "ILU 라운지"}'
                                        : (targetTeamModel?.stadium ??
                                              'ILU 라운지'),
                                    style: const TextStyle(
                                      color: GRAYSCALE_LABEL_500,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (!isOwner && currentUserId != null) ...[
                                    const SizedBox(height: 10),
                                    StreamBuilder<bool>(
                                      stream: context
                                          .read<BlockProvider>()
                                          .getBlockedByStream(
                                            currentUserId,
                                            widget.targetUserId,
                                          ),
                                      builder: (context, snapshot) {
                                        final isBlockedByTarget =
                                            snapshot.data ?? false;
                                        if (isBlockedByTarget) {
                                          return Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: GRAYSCALE_LABEL_100,
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            child: const Text(
                                              '이 사용자가 회원님을 차단했습니다',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                color: GRAYSCALE_LABEL_600,
                                              ),
                                            ),
                                          );
                                        }
                                        final isFollowing = fp.isFollowingUser(
                                          widget.post.userId,
                                        );
                                        return Row(
                                          children: [
                                            Expanded(
                                              child: InkWell(
                                                onTap: () {
                                                  fp.toggleFollow(
                                                    widget.post.userId,
                                                  );
                                                },
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                                child: Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        vertical: 7,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: isFollowing
                                                        ? BACKGROUND_COLOR
                                                        : activeTeamColor,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          10,
                                                        ),
                                                    border: isFollowing
                                                        ? Border.all(
                                                            color:
                                                                GRAYSCALE_LABEL_300,
                                                          )
                                                        : null,
                                                  ),
                                                  child: Center(
                                                    child: Text(
                                                      isFollowing
                                                          ? '팔로잉 ✓'
                                                          : '팔로우',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.w800,
                                                        color: isFollowing
                                                            ? GRAYSCALE_LABEL_800
                                                            : WHITE,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            InkWell(
                                              onTap: () {
                                                final profileProvider = context
                                                    .read<ProfileProvider>();
                                                final nickname =
                                                    profileProvider
                                                        .userNicknames[widget
                                                        .post
                                                        .userId] ??
                                                    widget.post.userNickName;
                                                _showBlockConfirmDialog(
                                                  context,
                                                  nickname,
                                                  widget.post.userId,
                                                  currentUserId,
                                                );
                                              },
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 7,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: BACKGROUND_COLOR,
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                  border: Border.all(
                                                    color: GRAYSCALE_LABEL_200,
                                                  ),
                                                ),
                                                child: const Text(
                                                  '차단',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w700,
                                                    color: GRAYSCALE_LABEL_700,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        );
                                      },
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // 정돈된 3열 스탯 박스 (게시물 | 팔로워 | 팔로잉)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 8,
                          ),
                          decoration: BoxDecoration(
                            color: BACKGROUND_COLOR,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: GRAYSCALE_LABEL_200.withValues(alpha: 0.7),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: StreamBuilder<List<PostModel>>(
                                  stream: context
                                      .read<FeedProvider>()
                                      .listenUserPosts(widget.post.userId),
                                  builder: (context, snapshot) {
                                    final count =
                                        (snapshot.data ?? const []).length;
                                    return _buildStatColumn(
                                      count: count,
                                      label: '게시물',
                                    );
                                  },
                                ),
                              ),
                              Container(
                                width: 1,
                                height: 28,
                                color: GRAYSCALE_LABEL_200,
                              ),
                              Expanded(
                                child: StreamBuilder<int>(
                                  stream: fp.getFollowersCountStream(
                                    widget.targetUserId,
                                  ),
                                  builder: (context, snapshot) {
                                    final count = snapshot.data ?? 0;
                                    return GestureDetector(
                                      behavior: HitTestBehavior.opaque,
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
                                      child: _buildStatColumn(
                                        count: count,
                                        label: '팔로워',
                                      ),
                                    );
                                  },
                                ),
                              ),
                              Container(
                                width: 1,
                                height: 28,
                                color: GRAYSCALE_LABEL_200,
                              ),
                              Expanded(
                                child: StreamBuilder<int>(
                                  stream: fp.getFollowCountStream(
                                    widget.targetUserId,
                                  ),
                                  builder: (context, snapshot) {
                                    final count = snapshot.data ?? 0;
                                    return GestureDetector(
                                      behavior: HitTestBehavior.opaque,
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
                                      child: _buildStatColumn(
                                        count: count,
                                        label: '팔로잉',
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // 세그먼트 캡슐 탭바 (게시글 / 트로피)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    height: 46,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: WHITE,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: GRAYSCALE_LABEL_200.withValues(alpha: 0.7),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: BLACK.withValues(alpha: 0.03),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TabBar(
                      indicator: BoxDecoration(
                        color: activeTeamColor,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: activeTeamColor.withValues(alpha: 0.25),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      indicatorSize: TabBarIndicatorSize.tab,
                      dividerColor: Colors.transparent,
                      labelColor: WHITE,
                      unselectedLabelColor: GRAYSCALE_LABEL_500,
                      labelStyle: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                      unselectedLabelStyle: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                      tabs: const [
                        Tab(text: '게시글'),
                        Tab(text: '직관기록'),
                        Tab(text: '트로피'),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                Expanded(
                  child: TabBarView(
                    children: [
                      UserPostsTab(
                        targetUserId: widget.targetUserId,
                        postUserId: widget.post.userId,
                        isOwner: isOwner,
                      ),
                      _UserAttendancesTab(
                        targetUserId: widget.targetUserId,
                        isOwner: isOwner,
                      ),
                      QuizTrophyPage(userId: widget.targetUserId),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatColumn({required int count, required String label}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$count',
          style: GoogleFonts.bebasNeue(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: GRAYSCALE_LABEL_950,
            height: 1.0,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: GRAYSCALE_LABEL_500,
          ),
        ),
      ],
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

// 사용자 게시물 탭
class UserPostsTab extends StatelessWidget {
  final String targetUserId;
  final String postUserId;
  final bool isOwner;

  const UserPostsTab({
    super.key,
    required this.targetUserId,
    required this.postUserId,
    required this.isOwner,
  });

  String timeAgo(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inSeconds < 60) return '${diff.inSeconds}s 전';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    return '${diff.inDays}일 전';
  }

  String? extractUrl(String text) {
    final urlPattern = RegExp(r'(https?://[^\s,]+)', caseSensitive: false);
    final match = urlPattern.firstMatch(text);
    return match?.group(0);
  }

  @override
  Widget build(BuildContext context) {
    final feedProvider = Provider.of<FeedProvider>(context, listen: false);
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    return StreamBuilder<List<PostModel>>(
      stream: feedProvider.listenUserPosts(postUserId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          final color =
              context.read<TeamProvider>().selectedTeam?.color ?? BUTTON;
          return Center(child: CircularProgressIndicator(color: color));
        }
        final posts = snapshot.data!;
        if (posts.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: WHITE,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: BLACK.withValues(alpha: 0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.edit_note_rounded,
                    size: 30,
                    color: GRAYSCALE_LABEL_400,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  '작성한 게시물이 없습니다',
                  style: TextStyle(
                    fontSize: 15,
                    color: GRAYSCALE_LABEL_600,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.only(top: 4, bottom: 24),
          itemCount: posts.length,
          itemBuilder: (_, i) {
            final p = posts[i];
            final isLiked =
                currentUserId != null && p.likedBy.contains(currentUserId);
            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => FeedDetailPage(post: p),
                  ),
                );
              },
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                decoration: BoxDecoration(
                  color: WHITE,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: GRAYSCALE_LABEL_200.withValues(alpha: 0.6),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: BLACK.withValues(alpha: 0.04),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Consumer<ProfileProvider>(
                            builder: (context, pd, child) {
                              pd.subscribeUserProfile(postUserId);

                              final profileUrl = pd.userProfiles[postUserId];
                              return Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: GRAYSCALE_LABEL_200,
                                    width: 1,
                                  ),
                                ),
                                child: CircleAvatar(
                                  radius: 19,
                                  backgroundImage: profileUrl != null
                                      ? NetworkImage(profileUrl)
                                      : null,
                                  backgroundColor: GRAYSCALE_LABEL_100,
                                  child: profileUrl == null
                                      ? const Icon(
                                          Icons.person_rounded,
                                          color: GRAYSCALE_LABEL_500,
                                          size: 20,
                                        )
                                      : null,
                                ),
                              );
                            },
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Consumer<ProfileProvider>(
                                  builder: (context, profileProvider, child) {
                                    profileProvider.subscribeUserProfile(
                                      postUserId,
                                    );
                                    final nickname =
                                        profileProvider
                                            .userNicknames[postUserId] ??
                                        p.userNickName;
                                    return Text(
                                      nickname,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        color: GRAYSCALE_LABEL_950,
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(height: 1),
                                Text(
                                  timeAgo(p.createdAt),
                                  style: const TextStyle(
                                    color: GRAYSCALE_LABEL_400,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            onPressed: () {
                              _showPostOptionBottomSheet(
                                context,
                                p,
                                feedProvider,
                                isOwner,
                                targetUserId,
                                postUserId,
                              );
                            },
                            icon: const Icon(
                              Icons.more_horiz_rounded,
                              color: GRAYSCALE_LABEL_500,
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                      if (p.text.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(
                          p.text,
                          style: const TextStyle(
                            fontSize: 14,
                            height: 1.45,
                            color: GRAYSCALE_LABEL_900,
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      if (extractUrl(p.text) != null) ...[
                        Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: BACKGROUND_COLOR,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: GRAYSCALE_LABEL_200.withValues(alpha: 0.8),
                            ),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              LinkPreview(
                                enableAnimation: true,
                                text: extractUrl(p.text)!,
                                onLinkPreviewDataFetched: (data) {
                                  debugPrint(
                                    'Preview data fetched: ${data.title}',
                                  );
                                },
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                color: WHITE,
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.link_rounded,
                                      size: 16,
                                      color: Colors.blue,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        extractUrl(p.text)!,
                                        style: const TextStyle(
                                          color: Colors.blue,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
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
                            final bool inSingle = p.mediaUrls.length == 1;
                            final double avilableWidth = constraints.maxWidth;
                            final double listHeight = (avilableWidth * 0.55)
                                .clamp(160.0, 320.0);
                            final double itemWidth = inSingle
                                ? avilableWidth
                                : (avilableWidth * 0.48).clamp(
                                    140.0,
                                    avilableWidth,
                                  );

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: SizedBox(
                                height: listHeight,
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: p.mediaUrls.length,
                                  itemBuilder: (_, i) {
                                    final url = p.mediaUrls[i];
                                    final isVideo = MediaUtils.isVideoFromPost(
                                      p,
                                      i,
                                    );
                                    return Padding(
                                      padding: EdgeInsets.only(
                                        right: inSingle ? 0 : 8,
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(16),
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
                                                        height: listHeight,
                                                        width: itemWidth,
                                                        child: Center(
                                                          child:
                                                              CircularProgressIndicator(
                                                                color: color,
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
                            );
                          },
                        ),
                      // 좋아요 + 댓글 캡슐 바
                      Container(
                        padding: const EdgeInsets.only(top: 10),
                        decoration: const BoxDecoration(
                          border: Border(
                            top: BorderSide(
                              color: GRAYSCALE_LABEL_100,
                              width: 1,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            InkWell(
                              onTap: currentUserId != null
                                  ? () => feedProvider.toggleLikeAndNotify(
                                      currentUserId: currentUserId,
                                      post: p,
                                      postId: p.id,
                                      postOwnerId: p.userId,
                                    )
                                  : null,
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 11,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: isLiked
                                      ? Colors.red.withValues(alpha: 0.08)
                                      : BACKGROUND_COLOR,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      isLiked
                                          ? Icons.favorite_rounded
                                          : Icons.favorite_border_rounded,
                                      size: 16,
                                      color: isLiked
                                          ? Colors.red
                                          : GRAYSCALE_LABEL_600,
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      '${p.likesCount}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: isLiked
                                            ? Colors.red
                                            : GRAYSCALE_LABEL_700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Consumer<CommentProvider>(
                              builder: (context, commentProvider, child) {
                                final comments = commentProvider.getComments(
                                  p.id,
                                );
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 11,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: BACKGROUND_COLOR,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        CupertinoIcons.chat_bubble,
                                        size: 15,
                                        color: GRAYSCALE_LABEL_600,
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        '${comments.length}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: GRAYSCALE_LABEL_700,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                            const Spacer(),
                            if (p.mediaUrls.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: BACKGROUND_COLOR,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.photo_library_outlined,
                                      size: 12,
                                      color: GRAYSCALE_LABEL_500,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${p.mediaUrls.length}',
                                      style: const TextStyle(
                                        color: GRAYSCALE_LABEL_500,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showPostOptionBottomSheet(
    BuildContext context,
    PostModel post,
    FeedProvider feedProvider,
    bool isOwner,
    String targetUserId,
    String postUserId,
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
                          await feedProvider.deletePost(post);
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
                        profileProvider.userNicknames[postUserId] ??
                        post.userNickName;
                    Navigator.pop(context); // 바텀시트 닫기
                    _showBlockConfirmDialog(context, nickname, postUserId, uid);
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
        title: Text('게시물 신고'),
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

                Navigator.pop(context);
                toastification.show(
                  context: context,
                  type: ToastificationType.success,
                  alignment: Alignment.bottomCenter,
                  autoCloseDuration: Duration(seconds: 2),
                  title: Text('신고가 접수되었습니다'),
                );
              } catch (e) {
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

// 사용자 마켓 게시물 탭
class UserMarketPostsTab extends StatelessWidget {
  final String targetUserId;
  final String postUserId;
  final bool isOwner;

  const UserMarketPostsTab({
    super.key,
    required this.targetUserId,
    required this.postUserId,
    required this.isOwner,
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
    final marketFeedProvider = Provider.of<MarketFeedProvider>(
      context,
      listen: false,
    );

    return StreamBuilder<List<MarketPostModel>>(
      stream: marketFeedProvider.listenUserMarketPosts(postUserId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          final color =
              context.read<TeamProvider>().selectedTeam?.color ?? BUTTON;
          return Center(child: CircularProgressIndicator(color: color));
        }
        final posts = snapshot.data!;
        if (posts.isEmpty) {
          return const Center(child: Text('작성한 마켓 게시물이 없습니다'));
        }
        return ListView.builder(
          itemCount: posts.length,
          itemBuilder: (_, i) {
            final marketPost = posts[i];
            return GestureDetector(
              onTap: () {
                // 조회수 증가
                marketFeedProvider.viewPost(marketPost.postId);
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
                                Expanded(
                                  child: Text(
                                    marketPost.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  onPressed: () {
                                    _showMarketPostOptionBottomSheet(
                                      context,
                                      marketPost,
                                      marketFeedProvider,
                                      isOwner,
                                      postUserId,
                                    );
                                  },
                                  icon: Icon(Icons.more_horiz),
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
          },
        );
      },
    );
  }

  void _showMarketPostOptionBottomSheet(
    BuildContext context,
    MarketPostModel marketPost,
    MarketFeedProvider marketFeedProvider,
    bool isOwner,
    String postUserId,
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
                    Navigator.pop(context);
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
                    Navigator.pop(context);
                    showDialog(
                      context: context,
                      builder: (context) => ConfirmationDialog(
                        title: '삭제 확인',
                        content: '게시물을 삭제 하시겠습니까?',
                        onConfirm: () async {
                          await marketFeedProvider.deletePost(marketPost);
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
                    Navigator.pop(context);
                    _showMarketReportDialog(
                      context,
                      marketPost,
                      marketFeedProvider,
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
                        profileProvider.userNicknames[postUserId] ??
                        marketPost.userNickName;
                    Navigator.pop(context);
                    _showMarketBlockConfirmDialog(
                      context,
                      nickname,
                      postUserId,
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

  void _showMarketReportDialog(
    BuildContext context,
    MarketPostModel marketPost,
    MarketFeedProvider marketFeedProvider,
    String currentUserId,
  ) {
    final TextEditingController reportController = TextEditingController();
    final List<String> reportReasons = [
      '스팸 및 광고',
      '부적절한 콘텐츠',
      '혐오 표현',
      '사기 의심',
      '개인정보 침해',
      '기타',
    ];
    String selectedReason = reportReasons[0];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: BACKGROUND_COLOR,
        title: Text('마켓 게시물 신고'),
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
                  (description.isNotEmpty ? '\n\$description' : '');
              try {
                final user = FirebaseAuth.instance.currentUser;
                if (user == null) {
                  toastification.show(
                    context: context,
                    type: ToastificationType.error,
                    alignment: Alignment.bottomCenter,
                    autoCloseDuration: Duration(seconds: 2),
                    title: Text('로그인이 필요합니다'),
                  );
                  return;
                }
                await marketFeedProvider.reportMarketPost(
                  marketPost: marketPost,
                  reporterUserId: user.uid,
                  reporterUserNickName: user.displayName ?? '익명',
                  reason: reason,
                );
                Navigator.pop(context);
                toastification.show(
                  context: context,
                  type: ToastificationType.success,
                  alignment: Alignment.bottomCenter,
                  autoCloseDuration: Duration(seconds: 2),
                  title: Text('신고가 접수되었습니다'),
                );
              } catch (e) {
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

  void _showMarketBlockConfirmDialog(
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
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: GRAYSCALE_LABEL_400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(height: 24),
              Text(
                '\${userNickName}님을\n차단하시겠어요?',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 16),
              Text(
                '이 사람이 만든 다른 계정과 앞으로 만드는 모든 계정이 함께 차단됩니다. 언제든지 차단을 해제할 수 있습니다.',
                style: TextStyle(
                  fontSize: 13,
                  color: GRAYSCALE_LABEL_600,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 28),
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
                        Navigator.pop(context);
                        Navigator.pop(context);
                        toastification.show(
                          context: context,
                          type: ToastificationType.success,
                          alignment: Alignment.bottomCenter,
                          autoCloseDuration: Duration(seconds: 2),
                          title: Text('\${userNickName}님을 차단했습니다'),
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
}

class _UserAttendancesTab extends StatelessWidget {
  final String targetUserId;
  final bool isOwner;

  const _UserAttendancesTab({
    required this.targetUserId,
    required this.isOwner,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(targetUserId)
          .collection('attendances')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data?.docs ?? const [];
        final records = docs
            .map((d) => AttendanceModel.fromDoc(d))
            .where((a) => isOwner || a.isPublic)
            .toList();

        if (records.isEmpty) {
          return const Center(
            child: Text(
              '공개된 직관기록이 없습니다',
              style: TextStyle(fontSize: 14, color: GRAYSCALE_LABEL_500),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          itemCount: records.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, idx) {
            final item = records[idx];
            final isWin = item.myScore > item.opponentScore;
            final isDraw = item.myScore == item.opponentScore;
            final badgeText = isWin ? 'WIN' : (isDraw ? 'DRAW' : 'LOSE');
            final badgeColor = isWin
                ? const Color(0xFF10B981)
                : (isDraw ? GRAYSCALE_LABEL_500 : RED_DANGER_TEXT_50);

            return InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => IntutionRecordDetailPage(
                      gameId: item.gameId,
                      ownerUserId: targetUserId,
                      attendanceModel: item,
                    ),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: WHITE,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: GRAYSCALE_LABEL_200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: badgeColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            badgeText,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: badgeColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${item.date} · ${item.stadium}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: GRAYSCALE_LABEL_500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (item.commentsCount > 0)
                          Row(
                            children: [
                              const Icon(
                                CupertinoIcons.chat_bubble,
                                size: 13,
                                color: GRAYSCALE_LABEL_500,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                '${item.commentsCount}',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: GRAYSCALE_LABEL_600,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${item.myTeam} ${item.myScore} : ${item.opponentScore} ${item.oppTeam ?? ''}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: GRAYSCALE_LABEL_950,
                      ),
                    ),
                    if ((item.seat ?? '').isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        '🎫 ${item.seat}',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: BUTTON,
                        ),
                      ),
                    ],
                    if ((item.memo ?? '').isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        item.memo!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          color: GRAYSCALE_LABEL_700,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
