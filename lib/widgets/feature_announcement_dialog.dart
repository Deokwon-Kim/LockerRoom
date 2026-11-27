import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/model/feature_announcement_model.dart';
import 'package:lockerroom/provider/team_provider.dart';
import 'package:lockerroom/services/feature_announcement_service.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

class FeatureAnnouncementDialog extends StatefulWidget {
  final FeatureAnnouncementModel announcement;
  final String currentVersion;
  final void Function(String ctaTarget)? onNavigate;

  const FeatureAnnouncementDialog({
    super.key,
    required this.announcement,
    this.currentVersion = '',
    this.onNavigate,
  });

  static Future<void> show(
    BuildContext context, {
    required FeatureAnnouncementModel announcement,
    String? currentVersion,
    void Function(String ctaTarget)? onNavigate,
  }) async {
    var resolvedVersion = currentVersion ?? '';
    if (resolvedVersion.isEmpty) {
      try {
        resolvedVersion = (await PackageInfo.fromPlatform()).version;
      } catch (_) {}
    }
    if (!context.mounted) return;
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => FeatureAnnouncementDialog(
        announcement: announcement,
        currentVersion: resolvedVersion,
        onNavigate: onNavigate,
      ),
    );
  }

  @override
  State<FeatureAnnouncementDialog> createState() =>
      _FeatureAnnouncementDialogState();
}

class _FeatureAnnouncementDialogState extends State<FeatureAnnouncementDialog> {
  final PageController _pageController = PageController();
  int _featureIndex = 0;
  int _mediaIndex = 0;
  bool _dontShowAgain = false;

  FeatureAnnouncementItem get _currentFeature =>
      widget.announcement.features[_featureIndex];

  List<FeatureMediaItem> get _mediaItems => _currentFeature.mediaItems;

  bool get _isOutdated =>
      widget.announcement.needsAppUpdate(widget.currentVersion);

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _selectFeature(int index) {
    if (index == _featureIndex) return;
    setState(() {
      _featureIndex = index;
      _mediaIndex = 0;
    });
    if (_pageController.hasClients) {
      _pageController.jumpToPage(0);
    }
  }

  void _goNext() {
    if (_mediaIndex < _mediaItems.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    } else if (_featureIndex < widget.announcement.features.length - 1) {
      _selectFeature(_featureIndex + 1);
    }
  }

  void _goPrev() {
    if (_mediaIndex > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    } else if (_featureIndex > 0) {
      _selectFeature(_featureIndex - 1);
    }
  }

  Future<void> _close({String? ctaTarget}) async {
    if (_dontShowAgain) {
      final key = FeatureAnnouncementService.dismissKeyFor(
        widget.announcement,
        isOutdated: _isOutdated,
      );
      await FeatureAnnouncementService().dismissAnnouncement(key);
    }
    if (!mounted) return;
    Navigator.of(context).pop();
    if (ctaTarget != null && ctaTarget.isNotEmpty) {
      widget.onNavigate?.call(ctaTarget);
    }
  }

  Future<void> _openStoreForUpdate() async {
    const iosUrl =
        'https://apps.apple.com/us/app/%EB%8D%94%EB%B2%A0%EC%9D%B4%EC%8A%A4-%EC%95%BC%EA%B5%AC-%ED%8C%AC%EB%93%A4%EC%9D%98-%EC%9D%BC%EC%83%81%EC%9D%B4-%EB%AA%A8%EC%9D%B4%EB%8A%94-%EA%B3%B3/id6752247698';
    const androidUrl =
        'https://play.google.com/store/apps/details?id=com.codegrove.thebase';
    final uri = Uri.parse(Platform.isIOS ? iosUrl : androidUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final teamColor =
        context.read<TeamProvider>().selectedTeam?.color ?? BUTTON;
    final accentColor = context.readableColor(teamColor);
    final selectedTextColor =
        ThemeData.estimateBrightnessForColor(accentColor) == Brightness.dark
        ? WHITE
        : Colors.black;

    if (_isOutdated ||
        widget.announcement.features.every((f) => f.mediaItems.isEmpty)) {
      return _buildOutdatedUpdateDialog(
        context: context,
        accentColor: accentColor,
        selectedTextColor: selectedTextColor,
      );
    }

    final features = widget.announcement.features;
    final currentMedia = _mediaItems.isNotEmpty
        ? _mediaItems[_mediaIndex.clamp(0, _mediaItems.length - 1)]
        : null;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        decoration: BoxDecoration(
          color: context.cardColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: context.borderColor),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Header
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 12, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: accentColor.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            widget.announcement.badge,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: accentColor,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          widget.announcement.title,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: context.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => _close(),
                    style: IconButton.styleFrom(
                      backgroundColor: context.surfaceAltColor,
                      minimumSize: const Size(32, 32),
                      padding: EdgeInsets.zero,
                    ),
                    icon: Icon(
                      Icons.close,
                      size: 18,
                      color: context.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

            // 2. Multi-Feature Tabs (hidden when only 1 feature)
            if (features.length > 1)
              SizedBox(
                height: 36,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  itemCount: features.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 6),
                  itemBuilder: (context, idx) {
                    final item = features[idx];
                    final isSelected = idx == _featureIndex;
                    return GestureDetector(
                      onTap: () => _selectFeature(idx),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? accentColor
                              : context.surfaceAltColor,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Center(
                          child: Text(
                            '${item.tabLabel} (${item.mediaItems.length})',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isSelected
                                  ? selectedTextColor
                                  : context.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

            if (features.length > 1) const SizedBox(height: 12),

            // 3. Media Carousel (Image + Video horizontal swipe)
            AspectRatio(
              aspectRatio: 1,
              child: Stack(
                children: [
                  Container(
                    color: Colors.black,
                    child: PageView.builder(
                      key: ValueKey(
                        'feature_${_featureIndex}_${_currentFeature.id}',
                      ),
                      controller: _pageController,
                      itemCount: _mediaItems.length,
                      onPageChanged: (idx) => setState(() => _mediaIndex = idx),
                      itemBuilder: (context, idx) {
                        final media = _mediaItems[idx];
                        if (media.isVideo) {
                          return _AnnouncementVideoSlide(
                            url: media.url,
                            isActive: idx == _mediaIndex,
                            accentColor: accentColor,
                          );
                        }
                        return CachedNetworkImage(
                          imageUrl: media.url,
                          fit: BoxFit.contain,
                          placeholder: (_, _) => Center(
                            child: CircularProgressIndicator(
                              color: accentColor,
                            ),
                          ),
                          errorWidget: (_, _, _) => const Center(
                            child: Icon(
                              Icons.broken_image_outlined,
                              color: Colors.white54,
                              size: 40,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  // Top-left media type badge
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            (currentMedia?.isVideo ?? false)
                                ? Icons.videocam_rounded
                                : Icons.photo_rounded,
                            size: 13,
                            color: WHITE,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            (currentMedia?.isVideo ?? false) ? '동영상' : '사진',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: WHITE,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Top-right counter badge
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${_mediaIndex + 1} / ${_mediaItems.length}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: WHITE,
                        ),
                      ),
                    ),
                  ),
                  if (_mediaItems.length > 1 || features.length > 1) ...[
                    Positioned(
                      left: 8,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: _CarouselArrowButton(
                          icon: Icons.chevron_left,
                          onTap: _goPrev,
                        ),
                      ),
                    ),
                    Positioned(
                      right: 8,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: _CarouselArrowButton(
                          icon: Icons.chevron_right,
                          onTap: _goNext,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // 4. Feature Subtitle, Caption & Dots
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
              child: Column(
                children: [
                  if (_currentFeature.title.isNotEmpty &&
                      _currentFeature.title != widget.announcement.title) ...[
                    _buildKeepAllCenteredText(
                      _currentFeature.title,
                      TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        height: 1.4,
                        color: context.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                  ],
                  if (currentMedia != null && currentMedia.caption.isNotEmpty)
                    _buildKeepAllCenteredText(
                      currentMedia.caption,
                      TextStyle(
                        fontSize: 12.5,
                        height: 1.45,
                        color: context.textSecondary,
                      ),
                    ),
                  if (_mediaItems.length > 1) ...[
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(_mediaItems.length, (i) {
                        final active = i == _mediaIndex;
                        return GestureDetector(
                          onTap: () => _pageController.animateToPage(
                            i,
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOut,
                          ),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            width: active ? 18 : 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: active ? accentColor : context.borderColor,
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        );
                      }),
                    ),
                  ],
                ],
              ),
            ),

            // 5. Footer Actions
            Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 16, 14),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: context.borderColor)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () =>
                        setState(() => _dontShowAgain = !_dontShowAgain),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 4,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: Checkbox(
                              value: _dontShowAgain,
                              activeColor: accentColor,
                              onChanged: (v) =>
                                  setState(() => _dontShowAgain = v ?? false),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '다시 보지 않기',
                            style: TextStyle(
                              fontSize: 12,
                              color: context.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () =>
                        _close(ctaTarget: _currentFeature.ctaTarget),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
                      foregroundColor: selectedTextColor,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      _currentFeature.ctaLabel.isNotEmpty
                          ? _currentFeature.ctaLabel
                          : '확인',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 한글 어절(공백) 단위로만 줄바꿈하고 명시적 줄바꿈(\n)을 그대로 유지
  Widget _buildKeepAllCenteredText(String text, TextStyle style) {
    final lines = text.split('\n');
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: lines.map((line) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) {
          return const SizedBox(height: 6);
        }
        final words = trimmed.split(RegExp(r'\s+'));
        return Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 4,
            runSpacing: 2,
            children: words
                .map((word) => Text(word, style: style))
                .toList(),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildOutdatedUpdateDialog({
    required BuildContext context,
    required Color accentColor,
    required Color selectedTextColor,
  }) {
    final targetVer = widget.announcement.targetVersion;
    final updateMsg = widget.announcement.updateMessage.isNotEmpty
        ? widget.announcement.updateMessage
        : '새로운 기능과 안정성 개선이 포함된 v$targetVer이 출시되었어요.\n스토어에서 업데이트 후 바로 이용해 보세요!';
    final warnColor = context.isDarkMode
        ? const Color(0xFFFBBF24)
        : const Color(0xFFD97706);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 380),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: context.cardColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: context.borderColor),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: warnColor.withValues(
                      alpha: context.isDarkMode ? 0.18 : 0.12,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'UPDATE AVAILABLE',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: warnColor,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => _close(),
                  style: IconButton.styleFrom(
                    backgroundColor: context.surfaceAltColor,
                    minimumSize: const Size(30, 30),
                    padding: EdgeInsets.zero,
                  ),
                  icon: Icon(
                    Icons.close,
                    size: 17,
                    color: context.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '최신 버전으로\n업데이트해 주세요!',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w900,
                height: 1.32,
                color: context.textPrimary,
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: context.surfaceAltColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: context.borderColor),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '현재 내 버전',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: context.textMuted,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'v${widget.currentVersion}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: context.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  Icon(
                    Icons.arrow_forward_rounded,
                    color: context.textMuted,
                    size: 20,
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '최신 버전',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: context.textMuted,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'v$targetVer',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: accentColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              updateMsg,
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: context.textSecondary,
              ),
            ),
            if (widget.announcement.features.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: context.surfaceAltColor,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: widget.announcement.features.take(3).map((f) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: accentColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              f.title.isNotEmpty ? f.title : f.tabLabel,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: context.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                await _openStoreForUpdate();
                if (mounted) _close();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor,
                foregroundColor: selectedTextColor,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                '스토어에서 업데이트하기',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => setState(() => _dontShowAgain = !_dontShowAgain),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 4,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: Checkbox(
                            value: _dontShowAgain,
                            activeColor: accentColor,
                            onChanged: (v) =>
                                setState(() => _dontShowAgain = v ?? false),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '다시 보지 않기',
                          style: TextStyle(
                            fontSize: 12,
                            color: context.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => _close(),
                  child: Text(
                    '나중에 할게요',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: context.textMuted,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CarouselArrowButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CarouselArrowButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.45),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: WHITE, size: 20),
      ),
    );
  }
}

class _AnnouncementVideoSlide extends StatefulWidget {
  final String url;
  final bool isActive;
  final Color accentColor;

  const _AnnouncementVideoSlide({
    required this.url,
    required this.isActive,
    required this.accentColor,
  });

  @override
  State<_AnnouncementVideoSlide> createState() =>
      _AnnouncementVideoSlideState();
}

class _AnnouncementVideoSlideState extends State<_AnnouncementVideoSlide> {
  late VideoPlayerController _controller;
  bool _initialized = false;
  bool _hasError = false;
  bool _isMuted = true;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..setLooping(true)
      ..setVolume(0.0);

    _controller
        .initialize()
        .then((_) {
          if (!mounted) return;
          setState(() => _initialized = true);
          if (widget.isActive) {
            _controller.play();
          }
        })
        .catchError((_) {
          if (!mounted) return;
          setState(() => _hasError = true);
        });
  }

  @override
  void didUpdateWidget(covariant _AnnouncementVideoSlide oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_initialized && oldWidget.isActive != widget.isActive) {
      if (widget.isActive) {
        _controller.play();
      } else {
        _controller.pause();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _togglePlay() {
    if (!_initialized) return;
    setState(() {
      if (_controller.value.isPlaying) {
        _controller.pause();
      } else {
        _controller.play();
      }
    });
  }

  void _toggleMute() {
    if (!_initialized) return;
    setState(() {
      _isMuted = !_isMuted;
      _controller.setVolume(_isMuted ? 0.0 : 1.0);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return const Center(
        child: Icon(Icons.videocam_off, color: Colors.white54, size: 40),
      );
    }
    if (!_initialized) {
      return Center(
        child: CircularProgressIndicator(color: widget.accentColor),
      );
    }

    final isPlaying = _controller.value.isPlaying;
    return GestureDetector(
      onTap: _togglePlay,
      child: Stack(
        alignment: Alignment.center,
        children: [
          FittedBox(
            fit: BoxFit.contain,
            child: SizedBox(
              width: _controller.value.size.width,
              height: _controller.value.size.height,
              child: VideoPlayer(_controller),
            ),
          ),
          if (!isPlaying)
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.play_arrow, color: WHITE, size: 32),
            ),
          Positioned(
            bottom: 10,
            right: 10,
            child: GestureDetector(
              onTap: _toggleMute,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.62),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isMuted ? Icons.volume_off : Icons.volume_up,
                      color: WHITE,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _isMuted ? '음소거' : '소리 켜짐',
                      style: const TextStyle(
                        color: WHITE,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
