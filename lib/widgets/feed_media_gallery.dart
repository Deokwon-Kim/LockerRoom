import 'package:flutter/material.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/model/post_model.dart';
import 'package:lockerroom/page/feed/fullscreen_image_viewer.dart';
import 'package:lockerroom/page/feed/fullscreen_video_player.dart';
import 'package:lockerroom/utils/media_utils.dart';
import 'package:lockerroom/widgets/network_video_player.dart';

/// 피드 이미지·동영상을 원본 비율에 맞춰(레터박스 여백 없이) 렌더링하는 공용 갤러리.
/// - 단일 사진: 이미지 자체 비율에 맞춰 너비·높이를 결정하며, 세로 사진도 좌우 여백 없이 둥근 모서리로 표시
/// - 다중 사진: Threads 스타일 가로 스크롤에서 각 사진 비율에 맞는 카드 너비로 나란히 표시
class FeedMediaGallery extends StatefulWidget {
  final PostModel post;
  final Color accentColor;
  final double maxSingleHeight;
  final double multiItemHeight;
  final double borderRadius;

  const FeedMediaGallery({
    super.key,
    required this.post,
    required this.accentColor,
    this.maxSingleHeight = 460,
    this.multiItemHeight = 250,
    this.borderRadius = 16,
  });

  @override
  State<FeedMediaGallery> createState() => _FeedMediaGalleryState();
}

class _FeedMediaGalleryState extends State<FeedMediaGallery> {
  static final Map<String, double> _ratioCache = {};
  final Set<String> _resolving = {};

  @override
  void initState() {
    super.initState();
    _prefetchRatios();
  }

  @override
  void didUpdateWidget(covariant FeedMediaGallery oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post.mediaUrls != widget.post.mediaUrls) {
      _prefetchRatios();
    }
  }

  void _prefetchRatios() {
    for (int i = 0; i < widget.post.mediaUrls.length; i++) {
      if (MediaUtils.isVideoFromPost(widget.post, i)) continue;
      final url = widget.post.mediaUrls[i];
      if (_ratioCache.containsKey(url) || _resolving.contains(url)) continue;

      _resolving.add(url);
      final stream = NetworkImage(url).resolve(ImageConfiguration.empty);
      late ImageStreamListener listener;
      listener = ImageStreamListener(
        (ImageInfo info, bool _) {
          final w = info.image.width.toDouble();
          final h = info.image.height.toDouble();
          if (w > 0 && h > 0) {
            _ratioCache[url] = w / h;
          }
          _resolving.remove(url);
          stream.removeListener(listener);
          if (mounted) setState(() {});
        },
        onError: (_, _) {
          _resolving.remove(url);
          stream.removeListener(listener);
        },
      );
      stream.addListener(listener);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.post.mediaUrls.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final double availableWidth = constraints.maxWidth;
        final bool isSingle = widget.post.mediaUrls.length == 1;

        if (isSingle) {
          return _buildSingleMedia(context, availableWidth);
        }
        return _buildMultiMediaStrip(context, availableWidth);
      },
    );
  }

  Widget _buildSingleMedia(BuildContext context, double availableWidth) {
    final url = widget.post.mediaUrls[0];
    final isVideo = MediaUtils.isVideoFromPost(widget.post, 0);

    if (isVideo) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: GestureDetector(
            onTap: () => _openVideo(context, url),
            child: NetworkVideoPlayer(
              videoUrl: url,
              width: availableWidth,
              height: availableWidth * 9 / 16,
              fit: BoxFit.cover,
              autoPlay: true,
              muted: true,
              showControls: false,
            ),
          ),
        ),
      );
    }

    final rawRatio = _ratioCache[url] ?? (4 / 3);
    final clampedRatio = rawRatio.clamp(0.55, 2.0);
    double targetWidth = availableWidth;
    double targetHeight = targetWidth / clampedRatio;

    if (targetHeight > widget.maxSingleHeight) {
      targetHeight = widget.maxSingleHeight;
      targetWidth = targetHeight * clampedRatio;
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: GestureDetector(
        onTap: () => _openImageViewer(context, 0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          child: Image.network(
            url,
            width: targetWidth,
            height: targetHeight,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Container(
                width: targetWidth,
                height: targetHeight.clamp(160.0, 260.0),
                color: context.surfaceAltColor,
                child: Center(
                  child: CircularProgressIndicator(color: widget.accentColor),
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              return Container(
                width: targetWidth,
                height: 200,
                color: context.surfaceAltColor,
                child: Center(
                  child: Icon(
                    Icons.broken_image_outlined,
                    color: context.textMuted,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildMultiMediaStrip(BuildContext context, double availableWidth) {
    final double itemHeight = widget.multiItemHeight.clamp(200.0, 300.0);

    return SizedBox(
      height: itemHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: widget.post.mediaUrls.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final url = widget.post.mediaUrls[index];
          final isVideo = MediaUtils.isVideoFromPost(widget.post, index);

          if (isVideo) {
            final videoWidth = (itemHeight * 1.25).clamp(
              180.0,
              availableWidth * 0.85,
            );
            return GestureDetector(
              onTap: () => _openVideo(context, url),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(widget.borderRadius - 2),
                child: NetworkVideoPlayer(
                  videoUrl: url,
                  width: videoWidth,
                  height: itemHeight,
                  fit: BoxFit.cover,
                  autoPlay: true,
                  muted: true,
                  showControls: false,
                ),
              ),
            );
          }

          final rawRatio = _ratioCache[url] ?? 0.8;
          final clampedRatio = rawRatio.clamp(0.58, 1.65);
          final double itemWidth = (itemHeight * clampedRatio).clamp(
            145.0,
            availableWidth * 0.86,
          );

          return GestureDetector(
            onTap: () => _openImageViewer(context, index),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(widget.borderRadius - 2),
              child: Image.network(
                url,
                width: itemWidth,
                height: itemHeight,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    width: itemWidth,
                    height: itemHeight,
                    color: context.surfaceAltColor,
                    child: Center(
                      child: CircularProgressIndicator(
                        color: widget.accentColor,
                      ),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: itemWidth,
                    height: itemHeight,
                    color: context.surfaceAltColor,
                    child: Center(
                      child: Icon(
                        Icons.broken_image_outlined,
                        color: context.textMuted,
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
  }

  void _openImageViewer(BuildContext context, int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FullscreenImageViewer(
          imageUrls: widget.post.mediaUrls,
          initialIndex: index,
        ),
      ),
    );
  }

  void _openVideo(BuildContext context, String url) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => FullscreenVideoPlayer(videoUrl: url)),
    );
  }
}
