import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/model/seat_view_model.dart';
import 'package:lockerroom/page/seat_view/seat_view_upload_page.dart';
import 'package:lockerroom/provider/seat_view_provider.dart';
import 'package:lockerroom/provider/team_provider.dart';
import 'package:provider/provider.dart';

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
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final teamColor =
        context.watch<TeamProvider>().selectedTeam?.color ?? BUTTON;
    final stadiumFilters = ['전체 구장', ...kSeatViewStadiums];

    return Scaffold(
      backgroundColor: BACKGROUND_COLOR,
      appBar: AppBar(
        backgroundColor: BACKGROUND_COLOR,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              '👀 구장별 좌석 시야',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: GRAYSCALE_LABEL_950,
              ),
            ),
            Text(
              _selectedStadium,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: GRAYSCALE_LABEL_500,
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
                                  color: selected ? teamColor : WHITE,
                                  alignment: Alignment.center,
                                  child: Text(
                                    '전체',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: selected
                                          ? WHITE
                                          : GRAYSCALE_LABEL_700,
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
                                      ? teamColor.withValues(alpha: 0.14)
                                      : WHITE,
                                  alignment: Alignment.center,
                                  child: Text(
                                    shortLabel,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: selected
                                          ? teamColor
                                          : GRAYSCALE_LABEL_700,
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
                          color: selected ? teamColor : GRAYSCALE_LABEL_600,
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
              cursorColor: BUTTON,
              onChanged: (val) => setState(() => _query = val.trim()),
              decoration: InputDecoration(
                hintText: '블럭 번호·좌석명으로 검색 (예: 306, 네이비)',
                hintStyle: const TextStyle(
                  fontSize: 13,
                  color: GRAYSCALE_LABEL_400,
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  size: 20,
                  color: GRAYSCALE_LABEL_500,
                ),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                        icon: const Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: GRAYSCALE_LABEL_500,
                        ),
                      )
                    : null,
                filled: true,
                fillColor: WHITE,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 11,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: GRAYSCALE_LABEL_200),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: teamColor, width: 1.4),
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
                      color: selected ? ACCENT_CORAL : WHITE,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: selected ? ACCENT_CORAL : GRAYSCALE_LABEL_200,
                      ),
                    ),
                    child: Text(
                      z,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: selected ? WHITE : GRAYSCALE_LABEL_700,
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
        color: WHITE,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: GRAYSCALE_LABEL_200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. 작성자 + 구장/구역 헤더
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 10),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: GRAYSCALE_LABEL_100,
                  backgroundImage:
                      post.userProfileImage != null &&
                          post.userProfileImage!.isNotEmpty
                      ? CachedNetworkImageProvider(post.userProfileImage!)
                      : null,
                  child:
                      post.userProfileImage == null ||
                          post.userProfileImage!.isEmpty
                      ? const Icon(
                          Icons.person_rounded,
                          size: 18,
                          color: GRAYSCALE_LABEL_500,
                        )
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.userNickName,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: GRAYSCALE_LABEL_950,
                        ),
                      ),
                      Text(
                        '${post.stadium} · ${_timeAgo(post.createdAt)}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: GRAYSCALE_LABEL_500,
                        ),
                      ),
                    ],
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
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: () =>
                        context.read<SeatViewProvider>().deletePost(post.id),
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      size: 18,
                      color: GRAYSCALE_LABEL_400,
                    ),
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
                color: BACKGROUND_COLOR,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: GRAYSCALE_LABEL_200),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.event_seat_rounded, size: 14, color: BUTTON),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      post.seatText,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: BUTTON,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),

          // 3. 실제 시야 사진 캐러셀
          if (post.imageUrls.isNotEmpty)
            Stack(
              children: [
                SizedBox(
                  height: 220,
                  child: PageView.builder(
                    itemCount: post.imageUrls.length,
                    onPageChanged: (i) => setState(() => _imageIndex = i),
                    itemBuilder: (context, i) {
                      return CachedNetworkImage(
                        imageUrl: post.imageUrls[i],
                        fit: BoxFit.cover,
                        width: double.infinity,
                        placeholder: (_, _) =>
                            Container(color: GRAYSCALE_LABEL_100),
                        errorWidget: (_, _, _) => Container(
                          color: GRAYSCALE_LABEL_100,
                          child: const Icon(
                            Icons.broken_image_outlined,
                            color: GRAYSCALE_LABEL_400,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                if (post.imageUrls.length > 1)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_imageIndex + 1}/${post.imageUrls.length}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: WHITE,
                        ),
                      ),
                    ),
                  ),
              ],
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
                              color: BACKGROUND_COLOR,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '#$tag',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: GRAYSCALE_LABEL_700,
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
                    style: const TextStyle(
                      fontSize: 13.5,
                      color: GRAYSCALE_LABEL_900,
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
                            color: isLiked ? HEART_FILL : GRAYSCALE_LABEL_500,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            '도움돼요 ${post.likeCount}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isLiked ? HEART_FILL : GRAYSCALE_LABEL_600,
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
}
