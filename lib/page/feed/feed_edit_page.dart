import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_link_previewer/flutter_link_previewer.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/model/post_model.dart';
import 'package:lockerroom/page/feed/fullscreen_image_viewer.dart';
import 'package:lockerroom/page/feed/fullscreen_video_player.dart';
import 'package:lockerroom/provider/feed_edit_provider.dart';
import 'package:lockerroom/provider/feed_provider.dart';
import 'package:lockerroom/provider/profile_provider.dart';
import 'package:lockerroom/provider/team_provider.dart';
import 'package:lockerroom/widgets/feed_hashtag_editor.dart';
import 'package:lockerroom/widgets/network_video_player.dart';
import 'package:provider/provider.dart';
import 'package:toastification/toastification.dart';

class FeedEditPage extends StatefulWidget {
  final PostModel post;
  const FeedEditPage({super.key, required this.post});

  @override
  State<FeedEditPage> createState() => _FeedEditPageState();
}

class _FeedEditPageState extends State<FeedEditPage> {
  static const int _maxTextLength = 500;
  late final TextEditingController _captionEditController;
  final ImagePicker _picker = ImagePicker();
  late List<String> _hashtags;
  bool _hasMediaChange = false;

  @override
  void initState() {
    super.initState();
    _captionEditController = TextEditingController(text: widget.post.text);
    _hashtags = List<String>.from(widget.post.hashtags);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<FeedEditProvider>().initializeEdit(widget.post);
      context.read<ProfileProvider>().subscribeUserProfile(widget.post.userId);
    });
  }

  @override
  void dispose() {
    _captionEditController.dispose();
    super.dispose();
  }

  String? _extractUrl(String text) {
    final urlPattern = RegExp(r'(https?://[^\s,]+)', caseSensitive: false);
    return urlPattern.firstMatch(text)?.group(0);
  }

  bool get _hasChanges {
    final textChanged = _captionEditController.text != widget.post.text;
    final tagsChanged =
        _hashtags.join(',') != widget.post.hashtags.join(',');
    return textChanged || tagsChanged || _hasMediaChange;
  }

  Future<void> _handleClose() async {
    if (!_hasChanges) {
      Navigator.pop(context);
      return;
    }
    final shouldDiscard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ctx.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          '수정 취소',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: ctx.textPrimary,
          ),
        ),
        content: Text(
          '변경된 내용이 저장되지 않습니다. 수정을 취소할까요?',
          style: TextStyle(fontSize: 13.5, color: ctx.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('계속 수정', style: TextStyle(color: ctx.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              '나가기',
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
    if (shouldDiscard == true && mounted) {
      Navigator.pop(context);
    }
  }

  Future<void> _pickImages(FeedEditProvider provider) async {
    if (provider.items.length >= FeedEditProvider.maxMediaCount) {
      _showLimitToast();
      return;
    }
    final picked = await _picker.pickMultiImage(imageQuality: 88);
    if (picked.isEmpty) return;
    provider.addImages(picked.map((x) => File(x.path)).toList());
    setState(() => _hasMediaChange = true);
  }

  Future<void> _pickVideo(FeedEditProvider provider) async {
    if (provider.items.length >= FeedEditProvider.maxMediaCount) {
      _showLimitToast();
      return;
    }
    final picked = await _picker.pickVideo(source: ImageSource.gallery);
    if (picked == null) return;
    provider.addVideo(File(picked.path));
    setState(() => _hasMediaChange = true);
  }

  void _showLimitToast() {
    toastification.show(
      context: context,
      type: ToastificationType.info,
      alignment: Alignment.bottomCenter,
      autoCloseDuration: const Duration(seconds: 2),
      title: const Text('미디어는 최대 5개까지 첨부할 수 있습니다.'),
    );
  }

  Future<void> _savePost(
    FeedEditProvider feedEditProvider,
    FeedProvider feedProvider,
  ) async {
    final trimmedText = _captionEditController.text.trim();
    if (trimmedText.isEmpty && feedEditProvider.items.isEmpty) {
      toastification.show(
        context: context,
        type: ToastificationType.warning,
        alignment: Alignment.bottomCenter,
        autoCloseDuration: const Duration(seconds: 2),
        title: const Text('내용 또는 미디어를 입력해 주세요.'),
      );
      return;
    }

    FocusScope.of(context).unfocus();
    feedEditProvider.setUploading(true);

    final mergedTags = PostModel.mergeHashtags(
      _captionEditController.text,
      _hashtags,
    );

    final finalMediaUrls = await feedEditProvider.updatePost(
      postId: widget.post.id,
      userId: widget.post.userId,
      newText: _captionEditController.text,
      hashtags: mergedTags,
    );

    feedEditProvider.setUploading(false);
    if (!mounted) return;

    if (finalMediaUrls != null) {
      final updatedPost = widget.post.copyWith(
        text: _captionEditController.text,
        hashtags: mergedTags,
        mediaUrls: finalMediaUrls,
        updatedAt: DateTime.now(),
      );
      feedProvider.updateLocalPost(updatedPost);
      Navigator.pop(context);
      toastification.show(
        context: context,
        type: ToastificationType.success,
        style: ToastificationStyle.flat,
        alignment: Alignment.bottomCenter,
        autoCloseDuration: const Duration(seconds: 2),
        title: const Text('게시물 수정이 완료되었습니다.'),
      );
    } else {
      toastification.show(
        context: context,
        type: ToastificationType.error,
        alignment: Alignment.bottomCenter,
        autoCloseDuration: const Duration(seconds: 2),
        title: const Text('게시물 수정에 실패했습니다.'),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final teamColor = context.read<TeamProvider>().selectedTeam?.color ?? BUTTON;
    final accentColor = context.readableColor(teamColor);
    final pillTextColor =
        ThemeData.estimateBrightnessForColor(accentColor) == Brightness.dark
        ? WHITE
        : Colors.black;
    final previewUrl = _extractUrl(_captionEditController.text);

    return PopScope(
      canPop: !_hasChanges,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleClose();
      },
      child: Scaffold(
        backgroundColor: context.bgColor,
        appBar: AppBar(
          backgroundColor: context.bgColor,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            onPressed: _handleClose,
            icon: Icon(Icons.close_rounded, color: context.textPrimary),
          ),
          title: Text(
            '게시물 수정',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: context.textPrimary,
            ),
          ),
          centerTitle: true,
          actions: [
            Consumer2<FeedEditProvider, FeedProvider>(
              builder: (context, feedEditProvider, feedProvider, _) {
                final canSave =
                    !feedEditProvider.isUploading &&
                    (_captionEditController.text.trim().isNotEmpty ||
                        feedEditProvider.items.isNotEmpty);
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Center(
                    child: ElevatedButton(
                      onPressed: canSave
                          ? () => _savePost(feedEditProvider, feedProvider)
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentColor,
                        foregroundColor: pillTextColor,
                        disabledBackgroundColor: context.surfaceAltColor,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: feedEditProvider.isUploading
                          ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: pillTextColor,
                              ),
                            )
                          : const Text(
                              '저장',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () => FocusScope.of(context).unfocus(),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: [
                    // 1. 작성자 프로필 (실시간 닉네임 동기화)
                    Consumer<ProfileProvider>(
                      builder: (context, profileProvider, _) {
                        final avatarUrl =
                            profileProvider.userProfiles[widget.post.userId];
                        final liveNickname =
                            profileProvider.userNicknames[widget.post.userId] ??
                            widget.post.userNickName;
                        return Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: GRAYSCALE_LABEL_300,
                              backgroundImage:
                                  (avatarUrl != null && avatarUrl.isNotEmpty)
                                  ? NetworkImage(avatarUrl)
                                  : null,
                              child: (avatarUrl == null || avatarUrl.isEmpty)
                                  ? const Icon(
                                      Icons.person,
                                      color: WHITE,
                                      size: 20,
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              liveNickname,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: context.textPrimary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: accentColor.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '수정 중',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: accentColor,
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 12),

                    // 2. 본문 에디터 카드 (고대비 텍스트)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: context.cardColor,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: context.borderColor),
                      ),
                      child: Column(
                        children: [
                          TextField(
                            controller: _captionEditController,
                            cursorColor: accentColor,
                            maxLength: _maxTextLength,
                            maxLines: null,
                            minLines: 4,
                            style: TextStyle(
                              fontSize: 15,
                              height: 1.55,
                              fontWeight: FontWeight.w500,
                              color: context.isDarkMode
                                  ? WHITE
                                  : context.textPrimary,
                            ),
                            onChanged: (_) => setState(() {}),
                            decoration: InputDecoration(
                              hintText: '내용을 입력하세요',
                              hintStyle: TextStyle(color: context.textMuted),
                              border: InputBorder.none,
                              counterText: '',
                            ),
                          ),
                          Divider(height: 16, color: context.borderColor),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'URL 입력 시 링크 미리보기 표시',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: context.textMuted,
                                ),
                              ),
                              Text(
                                '${_captionEditController.text.length} / $_maxTextLength',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: context.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // 3. 해시태그 편집기
                    FeedHashtagEditor(
                      tags: _hashtags,
                      accentColor: accentColor,
                      onAdd: (tag) {
                        if (_hashtags.contains(tag) ||
                            _hashtags.length >= 10) {
                          return;
                        }
                        setState(() => _hashtags.add(tag));
                      },
                      onRemove: (tag) {
                        setState(() => _hashtags.remove(tag));
                      },
                      onToggleQuickTag: (tag) {
                        setState(() {
                          if (_hashtags.contains(tag)) {
                            _hashtags.remove(tag);
                          } else if (_hashtags.length < 10) {
                            _hashtags.add(tag);
                          }
                        });
                      },
                    ),

                    if (previewUrl != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        decoration: BoxDecoration(
                          color: context.cardColor,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: context.borderColor),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            LinkPreview(
                              enableAnimation: true,
                              text: previewUrl,
                              onLinkPreviewDataFetched: (_) {},
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              color: context.surfaceAltColor,
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.link,
                                    size: 16,
                                    color: Colors.blue,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      previewUrl,
                                      style: const TextStyle(
                                        color: Colors.blue,
                                        fontSize: 13,
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

                    const SizedBox(height: 14),

                    // 4. 통합 미디어 편집기 (추가 · 삭제 · 순서 이동)
                    Consumer<FeedEditProvider>(
                      builder: (context, provider, _) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '첨부 미디어',
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w800,
                                    color: context.textPrimary,
                                  ),
                                ),
                                Text(
                                  '${provider.items.length} / ${FeedEditProvider.maxMediaCount}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: context.textMuted,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              height: 184,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount:
                                    provider.items.length +
                                    (provider.items.length <
                                            FeedEditProvider.maxMediaCount
                                        ? 1
                                        : 0),
                                separatorBuilder: (_, _) =>
                                    const SizedBox(width: 10),
                                itemBuilder: (context, index) {
                                  if (index == provider.items.length) {
                                    return GestureDetector(
                                      onTap: () => _pickImages(provider),
                                      child: Container(
                                        width: 124,
                                        decoration: BoxDecoration(
                                          color: context.cardColor,
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          border: Border.all(
                                            color: context.borderColor,
                                          ),
                                        ),
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.add_photo_alternate_outlined,
                                              size: 28,
                                              color: accentColor,
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              '사진 추가',
                                              style: TextStyle(
                                                fontSize: 12.5,
                                                fontWeight: FontWeight.w700,
                                                color: context.textSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }

                                  final item = provider.items[index];
                                  return _EditableMediaCard(
                                    item: item,
                                    isRepresentative: index == 0,
                                    canMoveLeft: index > 0,
                                    canMoveRight:
                                        index < provider.items.length - 1,
                                    accentColor: accentColor,
                                    pillTextColor: pillTextColor,
                                    onTap: () {
                                      if (item.isVideo && item.isRemote) {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                FullscreenVideoPlayer(
                                              videoUrl: item.remoteUrl!,
                                            ),
                                          ),
                                        );
                                      } else if (!item.isVideo &&
                                          item.isRemote) {
                                        final remoteImgs = provider.items
                                            .where(
                                              (e) => e.isRemote && !e.isVideo,
                                            )
                                            .map((e) => e.remoteUrl!)
                                            .toList();
                                        final imgIdx = remoteImgs.indexOf(
                                          item.remoteUrl!,
                                        );
                                        if (imgIdx >= 0) {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  FullscreenImageViewer(
                                                imageUrls: remoteImgs,
                                                initialIndex: imgIdx,
                                              ),
                                            ),
                                          );
                                        }
                                      }
                                    },
                                    onMoveLeft: () {
                                      provider.moveMedia(index, index - 1);
                                      setState(() => _hasMediaChange = true);
                                    },
                                    onMoveRight: () {
                                      provider.moveMedia(index, index + 1);
                                      setState(() => _hasMediaChange = true);
                                    },
                                    onRemove: () {
                                      provider.removeMedia(index);
                                      setState(() => _hasMediaChange = true);
                                    },
                                  );
                                },
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),

            // 5. 하단 고정 미디어 툴바
            Consumer<FeedEditProvider>(
              builder: (context, provider, _) {
                return Container(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 22),
                  decoration: BoxDecoration(
                    color: context.cardColor,
                    border: Border(top: BorderSide(color: context.borderColor)),
                  ),
                  child: Row(
                    children: [
                      _ToolbarChip(
                        icon: Icons.photo_library_outlined,
                        label: '사진 추가',
                        onTap: () => _pickImages(provider),
                      ),
                      const SizedBox(width: 8),
                      _ToolbarChip(
                        icon: Icons.videocam_outlined,
                        label: '동영상 추가',
                        onTap: () => _pickVideo(provider),
                      ),
                      const Spacer(),
                      Text(
                        '${provider.items.length}/${FeedEditProvider.maxMediaCount}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: context.textMuted,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _EditableMediaCard extends StatelessWidget {
  final EditableMediaItem item;
  final bool isRepresentative;
  final bool canMoveLeft;
  final bool canMoveRight;
  final Color accentColor;
  final Color pillTextColor;
  final VoidCallback onTap;
  final VoidCallback onMoveLeft;
  final VoidCallback onMoveRight;
  final VoidCallback onRemove;

  const _EditableMediaCard({
    required this.item,
    required this.isRepresentative,
    required this.canMoveLeft,
    required this.canMoveRight,
    required this.accentColor,
    required this.pillTextColor,
    required this.onTap,
    required this.onMoveLeft,
    required this.onMoveRight,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    Widget preview;
    if (item.isVideo) {
      if (item.isRemote) {
        preview = NetworkVideoPlayer(
          videoUrl: item.remoteUrl!,
          width: 152,
          height: 184,
          fit: BoxFit.cover,
          autoPlay: false,
          showControls: false,
        );
      } else {
        preview = Container(
          color: Colors.black87,
          child: const Center(
            child: Icon(Icons.videocam_rounded, color: WHITE, size: 36),
          ),
        );
      }
    } else if (item.isRemote) {
      preview = Image.network(item.remoteUrl!, fit: BoxFit.cover);
    } else {
      preview = Image.file(item.localFile!, fit: BoxFit.cover);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: 152,
        height: 184,
        child: Stack(
          fit: StackFit.expand,
          children: [
            GestureDetector(onTap: onTap, child: preview),
            if (isRepresentative)
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: accentColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '대표',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: pillTextColor,
                    ),
                  ),
                ),
              ),
            Positioned(
              top: 6,
              right: 6,
              child: GestureDetector(
                onTap: onRemove,
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.65),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: WHITE, size: 15),
                ),
              ),
            ),
            Positioned(
              left: 6,
              right: 6,
              bottom: 6,
              child: Row(
                children: [
                  Expanded(
                    child: _MoveBtn(
                      icon: Icons.chevron_left,
                      enabled: canMoveLeft,
                      onTap: onMoveLeft,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: _MoveBtn(
                      icon: Icons.chevron_right,
                      enabled: canMoveRight,
                      onTap: onMoveRight,
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
}

class _MoveBtn extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  const _MoveBtn({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        height: 26,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: enabled ? 0.62 : 0.25),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color: enabled ? WHITE : Colors.white38,
          size: 18,
        ),
      ),
    );
  }
}

class _ToolbarChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ToolbarChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: context.surfaceAltColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.borderColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 17, color: context.textPrimary),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: context.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
