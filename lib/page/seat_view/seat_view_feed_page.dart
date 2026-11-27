import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/model/comment_model.dart';
import 'package:lockerroom/model/seat_view_model.dart';
import 'package:lockerroom/page/alert/confirm_diallog.dart';
import 'package:lockerroom/page/seat_view/seat_view_detail_page.dart';
import 'package:lockerroom/page/seat_view/seat_view_upload_page.dart';
import 'package:lockerroom/provider/comment_provider.dart';
import 'package:lockerroom/provider/profile_provider.dart';
import 'package:lockerroom/provider/seat_view_provider.dart';
import 'package:lockerroom/provider/team_provider.dart';
import 'package:lockerroom/provider/user_provider.dart';
import 'package:lockerroom/widgets/ilu_share_card.dart';
import 'package:provider/provider.dart';
import 'package:toastification/toastification.dart';

class SeatViewFeedPage extends StatefulWidget {
  final String? initialStadium;

  const SeatViewFeedPage({super.key, this.initialStadium});

  @override
  State<SeatViewFeedPage> createState() => _SeatViewFeedPageState();
}

class _SeatViewFeedPageState extends State<SeatViewFeedPage> {
  String _selectedStadium = '전체 구장';
  String _selectedZone = '전체';
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _stadiumScrollController = ScrollController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    if (widget.initialStadium != null && widget.initialStadium!.isNotEmpty) {
      _selectedStadium = SeatViewModel.normalizeStadium(widget.initialStadium!);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<SeatViewProvider>().subscribe();
      _scrollToSelectedStadium();
    });
  }

  void _scrollToSelectedStadium() {
    if (!_stadiumScrollController.hasClients) return;
    final stadiumFilters = ['전체 구장', ...kSeatViewStadiums];
    final index = stadiumFilters.indexOf(_selectedStadium);
    if (index <= 0) return;
    final screenWidth = MediaQuery.of(context).size.width;
    const itemExtent = 56.0 + 10.0;
    final targetOffset = (16.0 + index * itemExtent + 28.0 - screenWidth / 2)
        .clamp(0.0, _stadiumScrollController.position.maxScrollExtent);
    _stadiumScrollController.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _stadiumScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final teamColor =
        context.watch<TeamProvider>().selectedTeam?.color ?? BUTTON;
    final stadiumFilters = ['전체 구장', ...kSeatViewStadiums];

    return Scaffold(
      backgroundColor: context.bgColor,
      appBar: AppBar(
        backgroundColor: context.bgColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              '👀 구장별 좌석 시야',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: context.textPrimary,
              ),
            ),
            Text(
              _selectedStadium,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: context.textMuted,
              ),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SeatViewUploadPage(
                    initialStadium: _selectedStadium == '전체 구장'
                        ? null
                        : _selectedStadium,
                  ),
                ),
              );
            },
            icon: Icon(Icons.add_a_photo_outlined, size: 18, color: teamColor),
            label: Text(
              '시야 올리기',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: teamColor,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. 구장 선택 원형 사진 바
          SizedBox(
            height: 80,
            child: ListView.separated(
              controller: _stadiumScrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: stadiumFilters.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final st = stadiumFilters[index];
                final selected = st == _selectedStadium;
                final photoAsset = kStadiumPhotoAssets[st];
                final shortLabel = kStadiumShortNames[st] ?? st;

                return GestureDetector(
                  onTap: () => setState(() => _selectedStadium = st),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(30),
                          border: selected
                              ? Border.all(color: teamColor, width: 2.5)
                              : null,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(
                            selected ? 30 : 28,
                          ),
                          child: st == '전체 구장'
                              ? Container(
                                  color: selected
                                      ? teamColor
                                      : context.cardColor,
                                  alignment: Alignment.center,
                                  child: Text(
                                    '전체',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: selected
                                          ? WHITE
                                          : context.textPrimary,
                                    ),
                                  ),
                                )
                              : photoAsset != null
                              ? Opacity(
                                  opacity: selected ? 1.0 : 0.72,
                                  child: Image.asset(
                                    photoAsset,
                                    fit: BoxFit.cover,
                                    width: 52,
                                    height: 52,
                                  ),
                                )
                              : Container(
                                  color: selected
                                      ? context
                                            .readableColor(teamColor)
                                            .withValues(alpha: 0.16)
                                      : context.cardColor,
                                  alignment: Alignment.center,
                                  child: Text(
                                    shortLabel,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: selected
                                          ? context.readableColor(teamColor)
                                          : context.textPrimary,
                                    ),
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        shortLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: selected
                              ? FontWeight.w800
                              : FontWeight.w500,
                          color: selected
                              ? context.readableColor(teamColor)
                              : context.textSecondary,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),

          // 2. 블럭·좌석 검색바
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              cursorColor: context.readableColor(teamColor),
              style: TextStyle(fontSize: 14, color: context.textPrimary),
              onChanged: (val) => setState(() => _query = val.trim()),
              decoration: InputDecoration(
                hintText: '블럭 번호·좌석명으로 검색 (예: 306, 네이비)',
                hintStyle: TextStyle(
                  fontSize: 13,
                  color: context.textMuted,
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  size: 20,
                  color: context.textMuted,
                ),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                        icon: Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: context.textMuted,
                        ),
                      )
                    : null,
                filled: true,
                fillColor: context.cardColor,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 11,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: context.borderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                    color: context.readableColor(teamColor),
                    width: 1.4,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // 3. 구역 필터 칩
          SizedBox(
            height: 34,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: kSeatViewZones.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final z = kSeatViewZones[index];
                final selected = z == _selectedZone;
                return GestureDetector(
                  onTap: () => setState(() => _selectedZone = z),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: selected ? ACCENT_CORAL : context.cardColor,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: selected ? ACCENT_CORAL : context.borderColor,
                      ),
                    ),
                    child: Text(
                      z,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: selected ? WHITE : context.textSecondary,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),

          // 4. 게시글 피드 리스트
          Expanded(
            child: Consumer<SeatViewProvider>(
              builder: (context, sp, _) {
                if (sp.isLoading && sp.posts.isEmpty) {
                  return Center(
                    child: CircularProgressIndicator(color: teamColor),
                  );
                }

                final filtered = sp.posts.where((p) {
                  final matchStadium =
                      _selectedStadium == '전체 구장' ||
                      p.stadium == _selectedStadium;
                  final matchZone =
                      _selectedZone == '전체' || p.zone == _selectedZone;
                  final q = _query.toLowerCase();
                  final matchQuery =
                      q.isEmpty ||
                      p.seatText.toLowerCase().contains(q) ||
                      p.blockNumber.toLowerCase().contains(q) ||
                      p.review.toLowerCase().contains(q) ||
                      p.stadium.toLowerCase().contains(q);
                  return matchStadium && matchZone && matchQuery;
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.photo_camera_outlined,
                            size: 42,
                            color: GRAYSCALE_LABEL_400,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            '아직 등록된 좌석 시야 글이 없어요',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: GRAYSCALE_LABEL_800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            '직관 갔던 자리의 첫 시야를 공유해 보세요!',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: GRAYSCALE_LABEL_500,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => SeatViewUploadPage(
                                    initialStadium: _selectedStadium == '전체 구장'
                                        ? null
                                        : _selectedStadium,
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.add_rounded, size: 18),
                            label: const Text('첫 시야 올리기'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: BUTTON,
                              foregroundColor: WHITE,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    return _SeatViewPostCard(post: filtered[index]);
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

class _SeatViewPostCard extends StatefulWidget {
  final SeatViewModel post;

  const _SeatViewPostCard({required this.post});

  @override
  State<_SeatViewPostCard> createState() => _SeatViewPostCardState();
}

class _SeatViewPostCardState extends State<_SeatViewPostCard> {
  int _imageIndex = 0;

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return '방금 전';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    if (diff.inDays < 7) return '${diff.inDays}일 전';
    return '${dt.month}/${dt.day}';
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final isOwner = uid != null && uid == post.userId;
    final isLiked = uid != null && post.likedBy.contains(uid);

    return Container(
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. 작성자 + 구장/구역 헤더
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 10),
            child: Row(
              children: [
                Expanded(
                  child: Consumer<ProfileProvider>(
                    builder: (context, profileProvider, _) {
                      profileProvider.subscribeUserProfile(post.userId);
                      final avatarUrl =
                          profileProvider.userProfiles[post.userId] ??
                          post.userProfileImage;
                      final nickName =
                          profileProvider.userNicknames[post.userId] ??
                          post.userNickName;
                      return Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: context.surfaceAltColor,
                            backgroundImage:
                                avatarUrl != null && avatarUrl.isNotEmpty
                                ? CachedNetworkImageProvider(avatarUrl)
                                : null,
                            child: avatarUrl == null || avatarUrl.isEmpty
                                ? Icon(
                                    Icons.person_rounded,
                                    size: 18,
                                    color: context.textMuted,
                                  )
                                : null,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  nickName,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: context.textPrimary,
                                  ),
                                ),
                                Text(
                                  '${post.stadium} · ${_timeAgo(post.createdAt)}${post.updatedAt != null ? ' · 수정됨' : ''}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: context.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: ACCENT_CORAL.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    post.zone,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: ACCENT_CORAL,
                    ),
                  ),
                ),
                if (isOwner)
                  PopupMenuButton<String>(
                    padding: EdgeInsets.zero,
                    icon: const Icon(
                      Icons.more_horiz_rounded,
                      size: 20,
                      color: GRAYSCALE_LABEL_500,
                    ),
                    color: WHITE,
                    onSelected: (value) async {
                      if (value == 'edit') {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                SeatViewUploadPage(editingPost: post),
                          ),
                        );
                      } else if (value == 'delete') {
                        await showDialog<void>(
                          context: context,
                          builder: (_) => ConfirmationDialog(
                            title: '좌석 시야 삭제',
                            content: '이 좌석 시야 게시글을 삭제하시겠습니까?',
                            cancelText: '취소',
                            confirmText: '삭제',
                            onConfirm: () {
                              context.read<SeatViewProvider>().deletePost(
                                post.id,
                              );
                            },
                          ),
                        );
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('수정하기')),
                      PopupMenuItem(
                        value: 'delete',
                        child: Text(
                          '삭제하기',
                          style: TextStyle(color: RED_DANGER_TEXT_50),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),

          // 2. 좌석 정보 배지
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: context.surfaceAltColor,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: context.borderColor),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.event_seat_rounded,
                    size: 14,
                    color: context.readableColor(BUTTON),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      post.seatText,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: context.readableColor(BUTTON),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),

          // 3. 실제 시야 사진 캐러셀 (원본 비율 기반 + 높이 상한으로 글까지 한눈에 표시)
          if (post.imageUrls.isNotEmpty)
            SeatViewPhotoCarousel(
              imageUrls: post.imageUrls,
              initialIndex: _imageIndex,
              minAspectRatio: 0.95,
              maxHeight: 300,
              badgeText: '탭하여 상세·확대',
              onPageChanged: (i) => setState(() => _imageIndex = i),
              onImageTap: (i) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        SeatViewDetailPage(post: post, initialImageIndex: i),
                  ),
                );
              },
            ),

          // 4. 태그 + 후기 + 도움돼요
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (post.tags.isNotEmpty) ...[
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: post.tags
                        .map(
                          (tag) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: context.surfaceAltColor,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '#$tag',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: context.textSecondary,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 8),
                ],
                if (post.review.isNotEmpty) ...[
                  Text(
                    post.review,
                    style: TextStyle(
                      fontSize: 13.5,
                      color: context.textPrimary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                Row(
                  children: [
                    GestureDetector(
                      onTap: () =>
                          context.read<SeatViewProvider>().toggleLike(post),
                      child: Row(
                        children: [
                          Icon(
                            isLiked
                                ? CupertinoIcons.heart_fill
                                : CupertinoIcons.heart,
                            size: 18,
                            color: isLiked ? HEART_FILL : context.textMuted,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            '도움돼요 ${post.likeCount}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color:
                                  isLiked ? HEART_FILL : context.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    GestureDetector(
                      onTap: () => _showCommentSheet(context, post),
                      child: Row(
                        children: [
                          Icon(
                            CupertinoIcons.chat_bubble,
                            size: 17,
                            color: context.textMuted,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            '댓글 ${post.commentsCount}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: GRAYSCALE_LABEL_600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => _sharePost(context, post),
                      child: const Row(
                        children: [
                          Icon(
                            CupertinoIcons.share,
                            size: 16,
                            color: GRAYSCALE_LABEL_600,
                          ),
                          SizedBox(width: 4),
                          Text(
                            '공유',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: GRAYSCALE_LABEL_600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _sharePost(BuildContext context, SeatViewModel post) {
    showIluWatermarkShareSheet(
      context: context,
      watermarkSubtitle: '${post.stadium} · ${post.seatText}',
      shareText: '${post.stadium} ${post.seatText} 직관 시야 공유! ⚾\n#ILU #직관시야',
      shareContent: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (post.imageUrls.isNotEmpty)
            CachedNetworkImage(
              imageUrl: post.imageUrls.first,
              height: 220,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          Padding(
            padding: const EdgeInsets.all(14),
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
                        color: ACCENT_CORAL.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        post.zone,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: ACCENT_CORAL,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        post.stadium,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: GRAYSCALE_LABEL_600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  post.seatText,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: GRAYSCALE_LABEL_950,
                  ),
                ),
                if (post.review.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    post.review,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: GRAYSCALE_LABEL_700,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showCommentSheet(BuildContext context, SeatViewModel post) {
    final commentProvider = context.read<CommentProvider>();
    commentProvider.subscribeSeatViewComments(post.id);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: WHITE,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => _SeatViewCommentSheet(post: post),
    ).whenComplete(() {
      commentProvider.cancelSeatViewSubscription(post.id);
    });
  }
}

class _SeatViewCommentSheet extends StatefulWidget {
  final SeatViewModel post;
  const _SeatViewCommentSheet({required this.post});

  @override
  State<_SeatViewCommentSheet> createState() => _SeatViewCommentSheetState();
}

class _SeatViewCommentSheetState extends State<_SeatViewCommentSheet> {
  final TextEditingController _controller = TextEditingController();
  String? _replyParentId;
  String? _replyToUserName;
  String? _replyToUserId;
  bool _replyIsToReply = false;
  bool _isSending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submitComment() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isSending) return;
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    setState(() => _isSending = true);
    try {
      final up = context.read<UserProvider>();
      final finalText =
          (_replyIsToReply &&
              _replyToUserName != null &&
              !text.startsWith('@$_replyToUserName'))
          ? '@$_replyToUserName $text'
          : text;
      final comment = CommentModel(
        id: '',
        postId: widget.post.id,
        userId: currentUser.uid,
        userName: up.nickname ?? currentUser.displayName ?? '야구팬',
        text: finalText,
        reComments: _replyParentId ?? '',
        createdAt: DateTime.now(),
      );
      await context.read<CommentProvider>().addSeatViewCommentAndNotify(
        postId: widget.post.id,
        comment: comment,
        currentUserId: currentUser.uid,
        postOwnerId: widget.post.userId,
        parentCommentOwnerId: _replyToUserId,
      );
      if (!mounted) return;
      _controller.clear();
      setState(() {
        _replyParentId = null;
        _replyToUserName = null;
        _replyToUserId = null;
        _replyIsToReply = false;
      });
    } catch (_) {
      if (!mounted) return;
      toastification.show(
        context: context,
        type: ToastificationType.error,
        autoCloseDuration: const Duration(seconds: 2),
        title: const Text('댓글 등록에 실패했습니다'),
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    final allComments = context.watch<CommentProvider>().getSeatViewComments(
      widget.post.id,
    );
    final parents = allComments.where((c) => c.reComments.isEmpty).toList();
    final Map<String, List<CommentModel>> repliesMap = {};
    for (final c in allComments.where((c) => c.reComments.isNotEmpty)) {
      repliesMap.putIfAbsent(c.reComments, () => []).add(c);
    }

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.65,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: GRAYSCALE_LABEL_200,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '댓글 ${allComments.length}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: GRAYSCALE_LABEL_950,
                      ),
                    ),
                  ),
                  Text(
                    widget.post.seatText,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: GRAYSCALE_LABEL_500,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: GRAYSCALE_LABEL_100),
            Expanded(
              child: allComments.isEmpty
                  ? const Center(
                      child: Text(
                        '첫 댓글을 남겨보세요!',
                        style: TextStyle(
                          fontSize: 13.5,
                          color: GRAYSCALE_LABEL_500,
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      itemCount: parents.length,
                      itemBuilder: (_, idx) {
                        final parent = parents[idx];
                        final replies = repliesMap[parent.id] ?? const [];
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildCommentTile(
                              parent,
                              currentUid: currentUid,
                              isReply: false,
                            ),
                            ...replies.map(
                              (r) => Padding(
                                padding: const EdgeInsets.only(left: 24),
                                child: _buildCommentTile(
                                  r,
                                  currentUid: currentUid,
                                  isReply: true,
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
            ),
            if (_replyToUserName != null)
              Container(
                width: double.infinity,
                color: BACKGROUND_COLOR,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                child: Row(
                  children: [
                    Text(
                      '$_replyToUserName님에게 답글 작성 중',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: BUTTON,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => setState(() {
                        _replyParentId = null;
                        _replyToUserName = null;
                        _replyToUserId = null;
                        _replyIsToReply = false;
                      }),
                      child: const Icon(
                        Icons.close_rounded,
                        size: 16,
                        color: GRAYSCALE_LABEL_500,
                      ),
                    ),
                  ],
                ),
              ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        cursorColor: BUTTON,
                        decoration: InputDecoration(
                          hintText: '좌석 시야에 대한 댓글을 입력하세요',
                          filled: true,
                          fillColor: BACKGROUND_COLOR,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _isSending ? null : _submitComment,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: BUTTON,
                        foregroundColor: WHITE,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                      ),
                      child: const Text(
                        '등록',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentTile(
    CommentModel c, {
    required String? currentUid,
    required bool isReply,
  }) {
    final canDelete =
        currentUid != null &&
        (c.userId == currentUid || widget.post.userId == currentUid);
    return Container(
      margin: EdgeInsets.symmetric(vertical: isReply ? 4 : 6),
      padding: isReply
          ? const EdgeInsets.fromLTRB(10, 8, 10, 8)
          : EdgeInsets.zero,
      decoration: isReply
          ? BoxDecoration(
              color: BACKGROUND_COLOR,
              borderRadius: BorderRadius.circular(10),
              border: const Border(
                left: BorderSide(color: GRAYSCALE_LABEL_300, width: 2.5),
              ),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (isReply) ...[
                const Icon(
                  Icons.subdirectory_arrow_right_rounded,
                  size: 15,
                  color: GRAYSCALE_LABEL_400,
                ),
                const SizedBox(width: 4),
              ],
              Text(
                c.userName,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: GRAYSCALE_LABEL_950,
                ),
              ),
              if (c.userId == widget.post.userId) ...[
                const SizedBox(width: 5),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: BUTTON.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    '작성자',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: BUTTON,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              GestureDetector(
                onTap: () => setState(() {
                  _replyParentId = isReply ? c.reComments : c.id;
                  _replyToUserName = c.userName;
                  _replyToUserId = c.userId;
                  _replyIsToReply = isReply;
                }),
                child: const Text(
                  '답글',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: GRAYSCALE_LABEL_500,
                  ),
                ),
              ),
              if (canDelete) ...[
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: () =>
                      context.read<CommentProvider>().deleteSeatViewComment(
                        postId: widget.post.id,
                        commentId: c.id,
                      ),
                  child: const Text(
                    '삭제',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: RED_DANGER_TEXT_50,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 3),
          _buildMentionText(c.text, BUTTON),
        ],
      ),
    );
  }

  Widget _buildMentionText(String text, Color mentionColor) {
    final match = RegExp(r'^(@\S+)\s+(.*)$', dotAll: true).firstMatch(text);
    if (match == null) {
      return Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          color: GRAYSCALE_LABEL_800,
          height: 1.4,
        ),
      );
    }
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '${match.group(1)} ',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: mentionColor,
              height: 1.4,
            ),
          ),
          TextSpan(
            text: match.group(2),
            style: const TextStyle(
              fontSize: 13,
              color: GRAYSCALE_LABEL_800,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
