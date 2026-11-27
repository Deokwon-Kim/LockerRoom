import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/model/comment_model.dart';
import 'package:lockerroom/model/seat_view_model.dart';
import 'package:lockerroom/page/feed/fullscreen_image_viewer.dart';
import 'package:lockerroom/provider/comment_provider.dart';
import 'package:lockerroom/provider/profile_provider.dart';
import 'package:lockerroom/provider/seat_view_provider.dart';
import 'package:lockerroom/provider/user_provider.dart';
import 'package:provider/provider.dart';
import 'package:toastification/toastification.dart';

/// 좌석 시야 상세페이지 (원본 비율 뷰어 + 핀치 줌 확대 + 후기 + 인라인 댓글)
class SeatViewDetailPage extends StatefulWidget {
  final SeatViewModel post;
  final int initialImageIndex;

  const SeatViewDetailPage({
    super.key,
    required this.post,
    this.initialImageIndex = 0,
  });

  @override
  State<SeatViewDetailPage> createState() => _SeatViewDetailPageState();
}

class _SeatViewDetailPageState extends State<SeatViewDetailPage> {
  late int _imageIndex;
  late final CommentProvider _commentProvider;
  final TextEditingController _commentController = TextEditingController();
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _imageIndex = widget.initialImageIndex;
    _commentProvider = context.read<CommentProvider>();
    _commentProvider.subscribeSeatViewComments(widget.post.id);
  }

  @override
  void dispose() {
    _commentProvider.cancelSeatViewSubscription(widget.post.id);
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submitComment(SeatViewModel post) async {
    final text = _commentController.text.trim();
    if (text.isEmpty || _isSending) return;
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    setState(() => _isSending = true);
    try {
      final up = context.read<UserProvider>();
      final comment = CommentModel(
        id: '',
        postId: post.id,
        userId: currentUser.uid,
        userName: up.nickname ?? currentUser.displayName ?? '야구팬',
        text: text,
        reComments: '',
        createdAt: DateTime.now(),
      );
      await _commentProvider.addSeatViewCommentAndNotify(
        postId: post.id,
        comment: comment,
        currentUserId: currentUser.uid,
        postOwnerId: post.userId,
      );
      if (!mounted) return;
      _commentController.clear();
      FocusScope.of(context).unfocus();
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

  String _formatDate(DateTime dt) {
    return '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    final seatViewProvider = context.watch<SeatViewProvider>();
    final post =
        seatViewProvider.posts
            .where((p) => p.id == widget.post.id)
            .fold<SeatViewModel?>(null, (_, p) => p) ??
        widget.post;
    final isLiked = currentUid != null && post.likedBy.contains(currentUid);
    final comments = context.watch<CommentProvider>().getSeatViewComments(
      post.id,
    );

    return Scaffold(
      backgroundColor: context.bgColor,
      appBar: AppBar(
        backgroundColor: context.cardColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          '좌석 시야 상세',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: context.textPrimary,
          ),
        ),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text(
                kStadiumShortNames[post.stadium] ?? post.stadium,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: BUTTON,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              children: [
                if (post.imageUrls.isNotEmpty)
                  SeatViewPhotoCarousel(
                    imageUrls: post.imageUrls,
                    initialIndex: _imageIndex,
                    minAspectRatio: 0.75,
                    maxHeight: 400,
                    badgeText: '탭하여 확대',
                    onPageChanged: (i) => setState(() => _imageIndex = i),
                    onImageTap: (i) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => FullscreenImageViewer(
                            imageUrls: post.imageUrls,
                            initialIndex: i,
                          ),
                        ),
                      );
                    },
                  ),
                Container(
                  color: context.cardColor,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Consumer<ProfileProvider>(
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
                                radius: 17,
                                backgroundColor: context.surfaceAltColor,
                                backgroundImage:
                                    (avatarUrl != null && avatarUrl.isNotEmpty)
                                    ? CachedNetworkImageProvider(avatarUrl)
                                    : null,
                                child: (avatarUrl == null || avatarUrl.isEmpty)
                                    ? Icon(
                                        Icons.person,
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
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        color: context.textPrimary,
                                      ),
                                    ),
                                    Text(
                                      '${post.stadium} · ${_formatDate(post.createdAt)}',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: context.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 9,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: ACCENT_CORAL.withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  post.zone,
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
                                    color: ACCENT_CORAL,
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 11,
                          vertical: 7,
                        ),
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
                              size: 15,
                              color: context.readableColor(BUTTON),
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                post.seatText,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: context.readableColor(BUTTON),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (post.tags.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: post.tags.map((tag) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: context.surfaceAltColor,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '#$tag',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: context.textSecondary,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                      if (post.review.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          post.review,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.55,
                            color: context.textPrimary,
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      Divider(height: 1, color: context.dividerColor),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () => seatViewProvider.toggleLike(post),
                            child: Row(
                              children: [
                                Icon(
                                  isLiked
                                      ? CupertinoIcons.heart_fill
                                      : CupertinoIcons.heart,
                                  size: 19,
                                  color: isLiked
                                      ? HEART_FILL
                                      : context.textMuted,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '도움돼요 ${post.likeCount}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: isLiked
                                        ? HEART_FILL
                                        : context.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 18),
                          Row(
                            children: [
                              Icon(
                                CupertinoIcons.chat_bubble,
                                size: 18,
                                color: context.textMuted,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '댓글 ${comments.length}',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: context.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  color: context.cardColor,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '댓글 ${comments.length}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: context.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (comments.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Center(
                            child: Text(
                              '이 좌석 시야에 대해 첫 댓글을 남겨보세요!',
                              style: TextStyle(
                                fontSize: 13,
                                color: context.textMuted,
                              ),
                            ),
                          ),
                        )
                      else
                        ...comments.map((c) {
                          final isCommentOwner =
                              currentUid != null && c.userId == currentUid;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: context.surfaceAltColor,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        c.userName,
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w800,
                                          color: context.textPrimary,
                                        ),
                                      ),
                                    ),
                                    if (isCommentOwner)
                                      GestureDetector(
                                        onTap: () => _commentProvider
                                            .deleteSeatViewComment(
                                              postId: post.id,
                                              commentId: c.id,
                                            ),
                                        child: Text(
                                          '삭제',
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            color: context.textMuted,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  c.text,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: context.textPrimary,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 8, 10, 8),
              decoration: BoxDecoration(
                color: context.cardColor,
                border: Border(top: BorderSide(color: context.borderColor)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      minLines: 1,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: '좌석 시야에 대해 질문하거나 댓글을 남겨보세요',
                        hintStyle: const TextStyle(
                          fontSize: 13,
                          color: GRAYSCALE_LABEL_400,
                        ),
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
                  const SizedBox(width: 6),
                  IconButton(
                    onPressed: _isSending ? null : () => _submitComment(post),
                    icon: _isSending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(
                            Icons.send_rounded,
                            color: BUTTON,
                            size: 22,
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 이미지 실제 종횡비에 맞춰 컨테이너 높이를 자동 조절해 세로 사진도 좌우 여백 없이 꽉 채우는 캐러셀
class SeatViewPhotoCarousel extends StatefulWidget {
  final List<String> imageUrls;
  final int initialIndex;
  final double minAspectRatio;
  final double maxAspectRatio;
  final double? maxHeight;
  final String badgeText;
  final ValueChanged<int>? onPageChanged;
  final ValueChanged<int>? onImageTap;

  const SeatViewPhotoCarousel({
    super.key,
    required this.imageUrls,
    this.initialIndex = 0,
    this.minAspectRatio = 0.72,
    this.maxAspectRatio = 1.65,
    this.maxHeight,
    this.badgeText = '탭하여 확대',
    this.onPageChanged,
    this.onImageTap,
  });

  @override
  State<SeatViewPhotoCarousel> createState() => _SeatViewPhotoCarouselState();
}

class _SeatViewPhotoCarouselState extends State<SeatViewPhotoCarousel> {
  late final PageController _pageController;
  late int _currentIndex;
  final Map<String, double> _aspectRatios = {};
  final Map<String, (ImageStream, ImageStreamListener)> _listeners = {};

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(
      0,
      widget.imageUrls.isEmpty ? 0 : widget.imageUrls.length - 1,
    );
    _pageController = PageController(initialPage: _currentIndex);
    _resolveImages();
  }

  @override
  void didUpdateWidget(covariant SeatViewPhotoCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrls != widget.imageUrls) {
      _resolveImages();
    }
  }

  void _resolveImages() {
    for (final url in widget.imageUrls) {
      if (url.isEmpty ||
          _aspectRatios.containsKey(url) ||
          _listeners.containsKey(url)) {
        continue;
      }
      final stream = CachedNetworkImageProvider(
        url,
      ).resolve(ImageConfiguration.empty);
      late final ImageStreamListener listener;
      listener = ImageStreamListener(
        (info, _) {
          final w = info.image.width.toDouble();
          final h = info.image.height.toDouble();
          if (w > 0 && h > 0 && mounted) {
            setState(() {
              _aspectRatios[url] = w / h;
            });
          }
          stream.removeListener(listener);
          _listeners.remove(url);
        },
        onError: (_, _) {
          stream.removeListener(listener);
          _listeners.remove(url);
        },
      );
      _listeners[url] = (stream, listener);
      stream.addListener(listener);
    }
  }

  @override
  void dispose() {
    for (final entry in _listeners.values) {
      entry.$1.removeListener(entry.$2);
    }
    _listeners.clear();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.imageUrls.isEmpty) return const SizedBox.shrink();
    final safeIdx = _currentIndex.clamp(0, widget.imageUrls.length - 1);
    final currentUrl = widget.imageUrls[safeIdx];
    final rawRatio = _aspectRatios[currentUrl] ?? 0.85;
    final clampedRatio = rawRatio.clamp(
      widget.minAspectRatio,
      widget.maxAspectRatio,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth;
        final double targetRatio = (widget.maxHeight != null && maxW > 0)
            ? clampedRatio.clamp(
                maxW / widget.maxHeight!,
                widget.maxAspectRatio,
              )
            : clampedRatio;
        return AnimatedSize(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          child: AspectRatio(
            aspectRatio: targetRatio,
            child: Stack(
              children: [
                PageView.builder(
                  controller: _pageController,
                  itemCount: widget.imageUrls.length,
                  onPageChanged: (i) {
                    setState(() => _currentIndex = i);
                    widget.onPageChanged?.call(i);
                  },
                  itemBuilder: (context, i) {
                    return GestureDetector(
                      onTap: () => widget.onImageTap?.call(i),
                      child: CachedNetworkImage(
                        imageUrl: widget.imageUrls[i],
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                        placeholder: (_, _) =>
                            Container(color: GRAYSCALE_LABEL_100),
                        errorWidget: (_, _, _) => Container(
                          color: GRAYSCALE_LABEL_100,
                          child: const Icon(
                            Icons.broken_image_outlined,
                            color: GRAYSCALE_LABEL_400,
                          ),
                        ),
                      ),
                    );
                  },
                ),
                if (widget.imageUrls.length > 1)
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
                        '${safeIdx + 1}/${widget.imageUrls.length}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: WHITE,
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  right: 10,
                  bottom: 10,
                  child: IgnorePointer(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.68),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.zoom_in_rounded,
                            size: 13,
                            color: WHITE,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            widget.badgeText,
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: WHITE,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
