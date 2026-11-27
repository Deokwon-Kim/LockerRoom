import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_link_previewer/flutter_link_previewer.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/model/meetup_model.dart';
import 'package:lockerroom/model/post_model.dart';
import 'package:lockerroom/widgets/attendance_feed_card.dart';
import 'package:lockerroom/widgets/feed_hashtag_editor.dart';
import 'package:lockerroom/widgets/feed_media_gallery.dart';
import 'package:lockerroom/page/alert/confirm_diallog.dart';
import 'package:lockerroom/page/feed/feed_detail_page.dart';
import 'package:lockerroom/page/feed/feed_edit_page.dart';
import 'package:lockerroom/page/feed/feed_mypage.dart';
import 'package:lockerroom/page/feed/feed_search_page.dart';
import 'package:lockerroom/page/meetup/meetup_detail_page.dart';
import 'package:lockerroom/provider/comment_provider.dart';
import 'package:lockerroom/provider/feed_provider.dart';
import 'package:lockerroom/provider/meetup_provider.dart';
import 'package:lockerroom/provider/profile_provider.dart';
import 'package:lockerroom/provider/block_provider.dart';
import 'package:lockerroom/provider/upload_provider.dart';
import 'package:provider/provider.dart';
import 'package:toastification/toastification.dart';
import 'package:lockerroom/provider/team_provider.dart';

class FeedPage extends StatefulWidget {
  final PostModel? post; // nullable로 변경
  const FeedPage({this.post, super.key});

  @override
  State<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage> {
  late FeedProvider _feedProvider;
  BlockProvider? _blockProvider;
  VoidCallback? _blockListener;
  String _selectedFilter = '전체';
  final List<String> _filters = ['전체', '인기글 🔥', '직관모임 🤝', '사진/영상 📸'];

  @override
  void initState() {
    super.initState();
    // initState에서 context.read() 사용 (안전함)
    _feedProvider = context.read<FeedProvider>();
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    _feedProvider.postStream(userId);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _blockProvider = context.read<BlockProvider>();
      // 초기 동기화
      _feedProvider.setBlockedUsers(_blockProvider!.blockedUserIds);
      _feedProvider.setBlockedByUsers(_blockProvider!.blockedByUserIds);
      // 차단 목록 변경 리스너
      _blockListener = () {
        _feedProvider.setBlockedUsers(_blockProvider!.blockedUserIds);
        _feedProvider.setBlockedByUsers(_blockProvider!.blockedByUserIds);
      };
      _blockProvider!.addListener(_blockListener!);
    });
  }

  @override
  void dispose() {
    // dispose에서는 저장된 참조를 직접 사용 (context.read() 사용 금지!)
    _feedProvider.cancelSubscription();
    if (_blockProvider != null && _blockListener != null) {
      _blockProvider!.removeListener(_blockListener!);
    }
    super.dispose();
  }

  List<PostModel> _applyCategoryFilter(List<PostModel> posts) {
    switch (_selectedFilter) {
      case '인기글 🔥':
        final popular = posts.where((p) => p.likesCount > 0).toList()
          ..sort((a, b) => b.likesCount.compareTo(a.likesCount));
        return popular.isNotEmpty ? popular : posts;
      case '직관모임 🤝':
        return posts.where((p) => p.meetupId != null).toList();
      case '사진/영상 📸':
        return posts.where((p) => p.mediaUrls.isNotEmpty).toList();
      default:
        return posts;
    }
  }

  @override
  Widget build(BuildContext context) {
    final teamColor =
        context.watch<TeamProvider>().selectedTeam?.color ?? BUTTON;

    return Scaffold(
      backgroundColor: context.bgColor,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: 20,
        title: Row(
          children: [
            Image.asset(context.appLogoAsset, height: 30, fit: BoxFit.contain),
            const SizedBox(width: 8),
            Text(
              '피드',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: context.textPrimary,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
        centerTitle: false,
        scrolledUnderElevation: 0,
        backgroundColor: context.cardColor,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => FeedSearchPage()),
                );
                if (!mounted) return;
                context.read<FeedProvider>().setQuery('');
              },
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: context.bgColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  CupertinoIcons.search,
                  color: context.textPrimary,
                  size: 18,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // 상단 카테고리 필터 칩 바
          Container(
            width: double.infinity,
            color: context.cardColor,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _filters.map((filter) {
                  final isSelected = _selectedFilter == filter;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedFilter = filter),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected ? teamColor : context.bgColor,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected ? teamColor : context.borderColor,
                          ),
                        ),
                        child: Text(
                          filter,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.w600,
                            color: isSelected ? WHITE : GRAYSCALE_LABEL_600,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          Divider(height: 1, color: context.dividerColor),
          // 백그라운드 업로드 진행/실패 배너 (인스타/스레드 스타일)
          Consumer<UploadProvider>(
            builder: (context, uploadProvider, _) {
              if (!uploadProvider.isUploading && !uploadProvider.uploadFailed) {
                return const SizedBox.shrink();
              }
              return Container(
                width: double.infinity,
                color: context.cardColor,
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        if (uploadProvider.uploadFailed)
                          const Icon(
                            Icons.error_outline_rounded,
                            color: RED_DANGER_TEXT_50,
                            size: 18,
                          )
                        else if (uploadProvider.uploadProgress >= 100)
                          Icon(
                            Icons.check_circle_rounded,
                            color: teamColor,
                            size: 18,
                          )
                        else
                          SizedBox(
                            width: 15,
                            height: 15,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: teamColor,
                            ),
                          ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            uploadProvider.uploadStatusText.isNotEmpty
                                ? uploadProvider.uploadStatusText
                                : '게시물 업로드 중...',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: uploadProvider.uploadFailed
                                  ? RED_DANGER_TEXT_50
                                  : GRAYSCALE_LABEL_900,
                            ),
                          ),
                        ),
                        if (uploadProvider.uploadFailed) ...[
                          InkWell(
                            onTap: () => uploadProvider.retryLastFailedUpload(),
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              child: Text(
                                '다시 시도',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: teamColor,
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            icon: const Icon(
                              Icons.close_rounded,
                              size: 16,
                              color: GRAYSCALE_LABEL_500,
                            ),
                            onPressed: () =>
                                uploadProvider.dismissUploadError(),
                          ),
                        ] else
                          Text(
                            '${uploadProvider.uploadProgress}%',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: teamColor,
                            ),
                          ),
                      ],
                    ),
                    if (uploadProvider.isUploading) ...[
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: uploadProvider.uploadProgress / 100,
                          minHeight: 3.5,
                          backgroundColor: GRAYSCALE_LABEL_100,
                          color: teamColor,
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
          Expanded(
            child: Consumer2<FeedProvider, ProfileProvider>(
              builder: (context, feedProvider, profileProvider, child) {
                final allPosts = _applyCategoryFilter(
                  feedProvider.filteredPosts,
                );

                if (allPosts.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          CupertinoIcons.chat_bubble_2,
                          size: 42,
                          color: GRAYSCALE_LABEL_400,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          '해당 카테고리에 게시물이 없습니다',
                          style: TextStyle(
                            color: GRAYSCALE_LABEL_500,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.only(top: 12, bottom: 24),
                  itemCount: allPosts.length,
                  itemBuilder: (context, index) => PostWidget(
                    post: allPosts[index],
                    feedProvider: feedProvider,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// 개별 포스트 위젯
class PostWidget extends StatefulWidget {
  final PostModel post;
  final FeedProvider feedProvider;

  const PostWidget({required this.post, required this.feedProvider, super.key});

  @override
  State<PostWidget> createState() => _PostWidgetState();
}

class _PostWidgetState extends State<PostWidget> {
  late final CommentProvider _commentProvider;
  BlockProvider? _blockProvider;
  VoidCallback? _blockListener;

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
  void initState() {
    super.initState();

    _commentProvider = context.read<CommentProvider>();
    _commentProvider.subscribeComments(widget.post.id);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _blockProvider = context.read<BlockProvider>();
      // 초기 동기화
      _commentProvider.setBlockedUsers(_blockProvider!.blockedUserIds);
      _commentProvider.setBlockedByUsers(_blockProvider!.blockedByUserIds);
      // 차단 목록 변경 리스너
      _blockListener = () {
        _commentProvider.setBlockedUsers(_blockProvider!.blockedUserIds);
        _commentProvider.setBlockedByUsers(_blockProvider!.blockedByUserIds);
      };
      _blockProvider!.addListener(_blockListener!);
    });
  }

  @override
  void dispose() {
    _commentProvider.cancelSubscription(widget.post.id);
    if (_blockProvider != null && _blockListener != null) {
      _blockProvider!.removeListener(_blockListener!);
    }

    super.dispose();
  }

  String? extractUrl(String text) {
    final urlPattern = RegExp(r'(https?://[^\s,]+)', caseSensitive: false);

    final match = urlPattern.firstMatch(text);
    return match?.group(0);
  }

  // extractUrl 함수 아래에 추가
  String? convertToDesktopUrl(String? url) {
    if (url == null || url.isEmpty) return null;

    // 모바일 URL을 PC 버전으로 변경
    String desktopUrl = url.replaceFirst(
      'm.sports.naver.com',
      'sports.naver.com',
    );

    // 한글이나 특수문자 포함 시 인코딩
    desktopUrl = Uri.encodeFull(desktopUrl);

    return desktopUrl;
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final isOwner =
        currentUserId != null && widget.post.userId == currentUserId;
    final selectedColor =
        Provider.of<TeamProvider>(context).selectedTeam?.color ?? BUTTON;
    final isLiked =
        currentUserId != null && widget.post.likedBy.contains(currentUserId);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => FeedDetailPage(post: widget.post),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(left: 16, right: 16, bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.cardColor,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: context.borderColor),
          boxShadow: [
            BoxShadow(
              color: BLACK.withValues(alpha: 0.04),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. 작성자 헤더
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Consumer<ProfileProvider>(
                  builder: (context, profileProvider, child) {
                    profileProvider.subscribeUserProfile(widget.post.userId);
                    final url =
                        profileProvider.userProfiles[widget.post.userId];
                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => FeedMypage(
                              post: widget.post,
                              targetUserId: widget.post.userId,
                            ),
                          ),
                        );
                      },
                      child: CircleAvatar(
                        radius: 19,
                        backgroundImage: url != null ? NetworkImage(url) : null,
                        backgroundColor: GRAYSCALE_LABEL_200,
                        child: url == null
                            ? const Icon(
                                Icons.person,
                                color: GRAYSCALE_LABEL_600,
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
                            widget.post.userId,
                          );
                          final nickname =
                              profileProvider.userNicknames[widget
                                  .post
                                  .userId] ??
                              widget.post.userNickName;
                          final teamName =
                              profileProvider.userTeams[widget.post.userId];
                          final userTeam =
                              teamName != null && teamName.isNotEmpty
                              ? context.read<TeamProvider>().findTeamByName(
                                  teamName,
                                )
                              : null;

                          return Row(
                            children: [
                              Flexible(
                                child: Text(
                                  nickname,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: context.textPrimary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (teamName != null && teamName.isNotEmpty) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: (userTeam?.color ?? selectedColor)
                                        .withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    userTeam?.symplename ?? teamName,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: userTeam?.color ?? selectedColor,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 2),
                      Text(
                        timeAgo(widget.post.createdAt),
                        style: const TextStyle(
                          color: GRAYSCALE_LABEL_400,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () {
                    _showPostOptionBottomSheet(context, widget.post, isOwner);
                  },
                  child: const Padding(
                    padding: EdgeInsets.all(6.0),
                    child: Icon(
                      Icons.more_horiz,
                      color: GRAYSCALE_LABEL_500,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),

            if (widget.post.text.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                widget.post.text,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.48,
                  color: context.textPrimary,
                ),
              ),
            ],

            if (widget.post.hashtags.isNotEmpty) ...[
              const SizedBox(height: 10),
              FeedHashtagChips(
                hashtags: widget.post.hashtags,
                accentColor:
                    context.read<TeamProvider>().selectedTeam?.color ?? BUTTON,
                onTapTag: (tag) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => FeedSearchPage(initialQuery: '#$tag'),
                    ),
                  );
                },
              ),
            ],

            // 직관기록 인증 첨부 카드
            if (widget.post.attendanceSummary != null) ...[
              const SizedBox(height: 12),
              AttendanceFeedCard(summary: widget.post.attendanceSummary!),
            ],

            // 2. 직관모임 첨부 카드 (티켓 스타일)
            if (widget.post.meetupId != null) ...[
              const SizedBox(height: 12),
              FutureBuilder<MeetupModel?>(
                future: context.read<MeetupProvider>().getMeetupById(
                  widget.post.meetupId!,
                ),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Container(
                      height: 76,
                      decoration: BoxDecoration(
                        color: context.surfaceAltColor,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    );
                  }

                  if (!snapshot.hasData || snapshot.data == null) {
                    return const SizedBox.shrink();
                  }

                  final meetup = snapshot.data!;
                  final teamProvider = context.read<TeamProvider>();
                  final homeTeamColor =
                      teamProvider.findTeamByName(meetup.homeTeam)?.color ??
                      selectedColor;

                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              MeetupDetailPage(meetup: meetup),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: context.surfaceAltColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: context.borderColor),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 5,
                            height: 52,
                            decoration: BoxDecoration(
                              color: homeTeamColor,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 7,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: homeTeamColor.withValues(
                                          alpha: 0.12,
                                        ),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        '🤝 직관모임',
                                        style: TextStyle(
                                          color: homeTeamColor,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        '${meetup.gameDate} ${meetup.gameTime}',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: GRAYSCALE_LABEL_500,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  meetup.title,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: context.textPrimary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '${meetup.awayTeam} vs ${meetup.homeTeam} · ${meetup.stadium} (${meetup.participants.length}/${meetup.maxParticipants}명)',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: context.textSecondary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: context.cardColor,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: context.borderColor),
                            ),
                            child: Text(
                              '참여 ›',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: homeTeamColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],

            // 3. URL 프리뷰 표시
            if (extractUrl(widget.post.text) != null) ...[
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: context.surfaceAltColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: context.borderColor),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LinkPreview(
                      enableAnimation: true,
                      text: extractUrl(widget.post.text)!,
                      onLinkPreviewDataFetched: (_) {},
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      color: context.cardColor,
                      child: Row(
                        children: [
                          const Icon(Icons.link, size: 15, color: Colors.blue),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              extractUrl(widget.post.text)!,
                              style: const TextStyle(
                                color: Colors.blue,
                                fontSize: 12,
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

            // 4. 이미지/영상 스냅 슬라이더 (1/N 캡슐 + 하단 도트 인디케이터)
            if (widget.post.mediaUrls.isNotEmpty) ...[
              const SizedBox(height: 12),
              FeedMediaGallery(
                post: widget.post,
                accentColor: selectedColor,
                maxSingleHeight: 460,
                multiItemHeight: 260,
              ),
            ],

            const SizedBox(height: 14),

            // 5. 하단 액션 바 (알약형 좋아요 / 댓글 버튼)
            Row(
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: currentUserId == null
                      ? null
                      : () => widget.feedProvider.toggleLikeAndNotify(
                          postId: widget.post.id,
                          post: widget.post,
                          currentUserId: currentUserId,
                          postOwnerId: widget.post.userId,
                        ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isLiked
                          ? Colors.red.withValues(alpha: 0.12)
                          : context.surfaceAltColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isLiked ? Icons.favorite : Icons.favorite_border,
                          size: 16,
                          color: isLiked ? Colors.red : context.textSecondary,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          '${widget.post.likesCount}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isLiked ? Colors.red : context.textPrimary,
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
                      widget.post.id,
                    );
                    return InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                FeedDetailPage(post: widget.post),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: context.surfaceAltColor,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              CupertinoIcons.chat_bubble,
                              size: 15,
                              color: context.textSecondary,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              '${comments.length}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: context.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showPostOptionBottomSheet(
    BuildContext context,
    PostModel post,
    bool isOwner,
  ) {
    final isAdmin =
        FirebaseAuth.instance.currentUser?.email?.toLowerCase() ==
        'kdw0032@gmail.com';
    showModalBottomSheet(
      isScrollControlled: true,
      context: context,
      backgroundColor: context.bgColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
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
                      color: context.cardColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '게시물 수정',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: context.textPrimary,
                          ),
                        ),
                        Icon(Icons.edit_outlined, color: context.textPrimary),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 10),
              ],
              if (isOwner || isAdmin) ...[
                GestureDetector(
                  onTap: () {
                    Navigator.pop(context); // 바텀시트 닫기
                    showDialog(
                      context: context,
                      builder: (context) => ConfirmationDialog(
                        title: '삭제 확인',
                        content: '게시물을 삭제 하시겠습니까?',
                        onConfirm: () async {
                          await widget.feedProvider.deletePost(widget.post);
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
                      color: context.cardColor,
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
                if (!isOwner) SizedBox(height: 10),
              ],
              if (!isOwner) ...[
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
                      widget.feedProvider,
                      reporter.uid,
                    );
                  },
                  child: Container(
                    padding: EdgeInsets.all(10),
                    width: double.infinity,
                    height: 50,
                    decoration: BoxDecoration(
                      color: context.cardColor,
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
                    Navigator.pop(context); // 바텀시트 닫기
                    _showBlockConfirmDialog(
                      context,
                      widget.post.userNickName,
                      widget.post.userId,
                      uid,
                    );
                  },
                  child: Container(
                    padding: EdgeInsets.all(10),
                    width: double.infinity,
                    height: 50,
                    decoration: BoxDecoration(
                      color: context.cardColor,
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

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: BACKGROUND_COLOR,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 상단 바
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: GRAYSCALE_LABEL_400,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                SizedBox(height: 20),
                Text(
                  '게시물 신고',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 16),
                Text(
                  '신고 사유를 선택해주세요',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 12),
                ...reportReasons.map((reason) {
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
                SizedBox(height: 20),
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
                          final description = reportController.text.trim();
                          final reason =
                              selectedReason +
                              (description.isNotEmpty ? '\n$description' : '');

                          try {
                            final user = FirebaseAuth.instance.currentUser;
                            if (user == null) {
                              Navigator.pop(context);
                              toastification.show(
                                context: context,
                                type: ToastificationType.error,
                                alignment: Alignment.bottomCenter,
                                autoCloseDuration: Duration(seconds: 2),
                                title: Text('로그인이 필요합니다'),
                              );
                              return;
                            }

                            await feedProvider.reportPostAndNotify(
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
                        child: Container(
                          padding: EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: RED_DANGER_TEXT_50,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Text(
                              '신고하기',
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
                SizedBox(height: 20),
              ],
            ),
          ),
        ),
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
                        final bottomSheetContext = context;
                        try {
                          await context.read<BlockProvider>().blockUser(
                            currentUserId: currentUserId,
                            targetUserId: userId,
                          );
                          Future.delayed(Duration.zero, () {
                            Navigator.pop(bottomSheetContext);
                            toastification.show(
                              context: bottomSheetContext,
                              type: ToastificationType.success,
                              alignment: Alignment.bottomCenter,
                              autoCloseDuration: Duration(seconds: 2),
                              title: Text('${userNickName}님을 차단했습니다'),
                            );
                          });
                          if (!mounted) return;
                        } catch (e) {
                          Future.delayed(Duration.zero, () {
                            Navigator.pop(bottomSheetContext);
                          });
                          if (!mounted) return;
                          toastification.show(
                            context: bottomSheetContext,
                            type: ToastificationType.error,
                            alignment: Alignment.bottomCenter,
                            autoCloseDuration: Duration(seconds: 2),
                            title: Text('차단 중 오류가 발생했습니다'),
                          );
                        }
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
