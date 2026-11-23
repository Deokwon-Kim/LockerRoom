import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/model/user_model.dart';
import 'package:lockerroom/page/my_post/mypost.dart';
import 'package:lockerroom/page/alert/confirm_diallog.dart';
import 'package:lockerroom/page/follow/follow_list_page.dart';
import 'package:lockerroom/provider/feed_provider.dart';
import 'package:lockerroom/provider/follow_provider.dart';
import 'package:lockerroom/provider/profile_provider.dart';
import 'package:lockerroom/provider/team_provider.dart';
import 'package:lockerroom/provider/user_provider.dart';
import 'package:lockerroom/page/myPage/quiz_trophy_page.dart';
import 'package:provider/provider.dart';
import 'package:toastification/toastification.dart';

class Mypage extends StatefulWidget {
  final String userId;
  final UserModel? user;
  const Mypage({super.key, required this.userId, this.user});

  @override
  State<Mypage> createState() => _MypageState();
}

class _MypageState extends State<Mypage> {
  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // 프로필 이미지 로드
      Future.microtask(() async {
        if (!mounted) return;
        await context.read<ProfileProvider>().loadProfileImage(user.uid);
        if (!mounted) return;
        await context.read<TeamProvider>().loadTeam(user.uid);
        if (!mounted) return;
        await context.read<UserProvider>().loadNickname();
      });
    }
  }

  void _showProfileImageOptions(
    BuildContext context,
    ProfileProvider profileProvider,
    User? user,
  ) {
    showModalBottomSheet(
      isScrollControlled: true,
      backgroundColor: GRAYSCALE_LABEL_50,
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        // Consumer를 사용하여 실시간으로 profileProvider 상태를 반영
        return Consumer<ProfileProvider>(
          builder: (context, provider, child) {
            return Container(
              padding: EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '프로필 사진 편집',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 20),
                  ListTile(
                    leading: Icon(Icons.photo_library, color: BUTTON),
                    title: Text('사진 선택'),
                    onTap: () async {
                      Navigator.pop(context);
                      try {
                        await provider.pickImage();
                        if (user != null && provider.image != null) {
                          await provider.uploadImage(user.uid);
                          toastification.show(
                            context: context,
                            type: ToastificationType.success,
                            alignment: Alignment.bottomCenter,
                            autoCloseDuration: const Duration(seconds: 2),
                            title: Text('프로필 사진을 업로드했습니다'),
                          );
                        }
                      } catch (e) {
                        toastification.show(
                          context: context,
                          type: ToastificationType.error,
                          alignment: Alignment.bottomCenter,
                          autoCloseDuration: const Duration(seconds: 2),
                          title: Text('업로드 실패: $e'),
                        );
                      }
                    },
                  ),
                  // 실시간으로 imageUrl 상태를 확인
                  if (provider.imageUrl != null &&
                      provider.imageUrl!.isNotEmpty)
                    ListTile(
                      leading: Icon(Icons.delete, color: Colors.red),
                      title: Text('사진 삭제'),
                      onTap: () async {
                        Navigator.pop(context);
                        // 삭제 확인 대화상자
                        showDialog(
                          context: context,
                          builder: (BuildContext dialogContext) {
                            return ConfirmationDialog(
                              title: '프로필 사진 삭제',
                              content: '프로필 사진을 삭제하시겠습니까?',
                              cancelText: '취소',
                              confirmText: '삭제',
                              confirmColor: Colors.red,
                              onConfirm: () async {
                                try {
                                  await provider.deleteProfileImage(user!.uid);
                                  toastification.show(
                                    context: context,
                                    type: ToastificationType.success,
                                    alignment: Alignment.bottomCenter,
                                    autoCloseDuration: const Duration(
                                      seconds: 2,
                                    ),
                                    title: Text('프로필 사진을 삭제했습니다'),
                                  );
                                } catch (e) {
                                  toastification.show(
                                    context: context,
                                    type: ToastificationType.error,
                                    alignment: Alignment.bottomCenter,
                                    autoCloseDuration: const Duration(
                                      seconds: 2,
                                    ),
                                    title: Text('삭제 실패: $e'),
                                  );
                                }
                              },
                            );
                          },
                        );
                      },
                    ),
                  ListTile(
                    leading: Icon(Icons.cancel, color: GRAYSCALE_LABEL_500),
                    title: Text('취소'),
                    onTap: () => Navigator.pop(context),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final profileProvider = Provider.of<ProfileProvider>(context);
    final userProvider = Provider.of<UserProvider>(context);
    final userName =
        userProvider.nickname ?? userProvider.currentUser?.displayName ?? '사용자';
    final selectedTeam = Provider.of<TeamProvider>(context).selectedTeam;
    final teamColor = selectedTeam?.color ?? BUTTON;
    final user = FirebaseAuth.instance.currentUser;
    final fp = context.watch<FollowProvider>();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: BACKGROUND_COLOR,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: BACKGROUND_COLOR,
          scrolledUnderElevation: 0,
          centerTitle: false,
          title: Row(
            children: [
              const Text(
                '내 정보',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: GRAYSCALE_LABEL_950,
                  letterSpacing: -0.4,
                ),
              ),
              if (selectedTeam != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: teamColor,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: teamColor.withValues(alpha: 0.25),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    selectedTeam.name,
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
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: InkWell(
                  onTap: () {
                    Navigator.pushNamed(context, '환경설정');
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: WHITE,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: GRAYSCALE_LABEL_200.withValues(alpha: 0.8),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: BLACK.withValues(alpha: 0.03),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(Icons.menu_rounded, color: teamColor, size: 20),
                  ),
                ),
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            // 프로필 히어로 라운지 카드
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
                        // 프로필 아바타 + 편집 뱃지
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: teamColor.withValues(alpha: 0.3),
                                  width: 2.2,
                                ),
                              ),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  CircleAvatar(
                                    backgroundColor: GRAYSCALE_LABEL_100,
                                    radius: 38,
                                    backgroundImage:
                                        profileProvider.image != null
                                        ? FileImage(profileProvider.image!)
                                        : (profileProvider.imageUrl != null
                                              ? NetworkImage(
                                                  profileProvider.imageUrl!,
                                                )
                                              : null),
                                    child:
                                        (profileProvider.image == null &&
                                            profileProvider.imageUrl == null)
                                        ? const Icon(
                                            Icons.person_rounded,
                                            size: 36,
                                            color: GRAYSCALE_LABEL_400,
                                          )
                                        : null,
                                  ),
                                  if (profileProvider.isUploading)
                                    Container(
                                      width: 76,
                                      height: 76,
                                      decoration: BoxDecoration(
                                        color: Colors.black.withAlpha(153),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          SizedBox(
                                            width: 24,
                                            height: 24,
                                            child: CircularProgressIndicator(
                                              value: profileProvider
                                                  .uploadProgress,
                                              color: teamColor,
                                              strokeWidth: 2.5,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${(profileProvider.uploadProgress * 100).toInt()}%',
                                            style: const TextStyle(
                                              color: WHITE,
                                              fontSize: 10,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: GestureDetector(
                                onTap: profileProvider.isUploading
                                    ? null
                                    : () => _showProfileImageOptions(
                                        context,
                                        profileProvider,
                                        user,
                                      ),
                                child: Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: profileProvider.isUploading
                                        ? GRAYSCALE_LABEL_400
                                        : GRAYSCALE_LABEL_950,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: WHITE, width: 2),
                                    boxShadow: [
                                      BoxShadow(
                                        color: BLACK.withValues(alpha: 0.15),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.edit_rounded,
                                    size: 14,
                                    color: WHITE,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 16),
                        // 닉네임, 이름, 퀵 액션 버튼
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      userName,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                        color: GRAYSCALE_LABEL_950,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 7,
                                      vertical: 2.5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: teamColor.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      selectedTeam != null
                                          ? '${selectedTeam.name} 직관러'
                                          : 'KBO 직관러',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        color: teamColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Consumer<UserProvider>(
                                builder: (context, userProvider, child) {
                                  final realName =
                                      userProvider.name ??
                                      widget.user?.name ??
                                      '';
                                  final stadiumName =
                                      selectedTeam?.stadium ?? '더베이스 라운지';
                                  return Text(
                                    realName.isNotEmpty
                                        ? '$realName · $stadiumName'
                                        : stadiumName,
                                    style: const TextStyle(
                                      color: GRAYSCALE_LABEL_500,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  );
                                },
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  InkWell(
                                    onTap: profileProvider.isUploading
                                        ? null
                                        : () => _showProfileImageOptions(
                                            context,
                                            profileProvider,
                                            user,
                                          ),
                                    borderRadius: BorderRadius.circular(10),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 11,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: BACKGROUND_COLOR,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: GRAYSCALE_LABEL_200,
                                        ),
                                      ),
                                      child: const Text(
                                        '프로필 사진 변경',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: GRAYSCALE_LABEL_800,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  InkWell(
                                    onTap: () {
                                      Navigator.pushNamed(context, '환경설정');
                                    },
                                    borderRadius: BorderRadius.circular(10),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 11,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: teamColor,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Text(
                                        '환경설정',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          color: WHITE,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
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
                            child: StreamBuilder<int>(
                              stream: context
                                  .read<FeedProvider>()
                                  .listenUserPostCount(widget.userId),
                              builder: (context, snapshot) {
                                final count = snapshot.data ?? 0;
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
                              stream: fp.getFollowersCountStream(widget.userId),
                              builder: (context, snapshot) {
                                final count = snapshot.data ?? 0;
                                return GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => FollowListPage(
                                          userId: widget.userId,
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
                              stream: fp.getFollowCountStream(widget.userId),
                              builder: (context, snapshot) {
                                final count = snapshot.data ?? 0;
                                return GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => FollowListPage(
                                          userId: widget.userId,
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
                    color: teamColor,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: teamColor.withValues(alpha: 0.25),
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
                    Tab(text: '내 게시글'),
                    Tab(text: '트로피'),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 8),

            // 탭 컨텐츠 뷰
            Expanded(
              child: TabBarView(
                children: [
                  const MypostPage(),
                  QuizTrophyPage(userId: widget.userId),
                ],
              ),
            ),
          ],
        ),
      ),
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
}
