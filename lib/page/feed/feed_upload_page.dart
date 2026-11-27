import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter_link_previewer/flutter_link_previewer.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/model/meetup_model.dart';
import 'package:lockerroom/model/post_model.dart';
import 'package:lockerroom/widgets/feed_hashtag_editor.dart';
import 'package:lockerroom/provider/meetup_provider.dart';
import 'package:lockerroom/provider/profile_provider.dart';
import 'package:lockerroom/provider/team_provider.dart';
import 'package:lockerroom/provider/upload_provider.dart';
import 'package:lockerroom/provider/user_provider.dart';
import 'package:provider/provider.dart';
import 'package:toastification/toastification.dart';

class FeedUploadPage extends StatefulWidget {
  final VoidCallback? onUploaded;
  const FeedUploadPage({super.key, this.onUploaded});

  @override
  State<FeedUploadPage> createState() => _UploadPageState();
}

class _UploadPageState extends State<FeedUploadPage> {
  late final TextEditingController _captionController;
  bool _requestedProfileLoad = false;
  final List<String> _hashtags = [];
  bool _showMediaPickerCard = false;

  @override
  void initState() {
    super.initState();
    _captionController = TextEditingController();

    // 초기 캡션 확인 (퀴즈 결과 등에서 전달된 경우)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final uploadProvider = context.read<UploadProvider>();
      final initialCaption = uploadProvider.consumeInitialCaption();
      if (initialCaption != null) {
        setState(() {
          _captionController.text = initialCaption;
        });
      }
    });
  }

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  String? extractUrl(String text) {
    final urlPattern = RegExp(r'(https?://[^\s,]+)', caseSensitive: false);
    final match = urlPattern.firstMatch(text);
    return match?.group(0);
  }

  void _handleUpload({
    required UploadProvider uploadProvider,
    required String userNickName,
    required String? name,
  }) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    FocusScope.of(context).unfocus();

    final hasImage =
        uploadProvider.images.isNotEmpty || uploadProvider.camera != null;
    final hasVideo = uploadProvider.video != null;
    final captionText = _captionController.text;
    final mergedTags = PostModel.mergeHashtags(captionText, _hashtags);

    uploadProvider.startBackgroundPost(
      userId: currentUser.uid,
      userNickName: userNickName,
      name: name ?? '',
      text: captionText,
      hashtags: mergedTags,
      onCompleted: () {
        FirebaseAnalytics.instance.logEvent(
          name: 'feed_upload',
          parameters: {
            'has_image': hasImage ? 1 : 0,
            'has_video': hasVideo ? 1 : 0,
          },
        );
      },
    );

    _captionController.clear();
    _hashtags.clear();
    widget.onUploaded?.call();
  }

  Future<void> _pickVideoDirectly(
    BuildContext context,
    UploadProvider uploadProvider,
    Color themeColor,
  ) async {
    if (uploadProvider.isUploading) return;
    try {
      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => AlertDialog(
            backgroundColor: dialogContext.cardColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: themeColor),
                const SizedBox(height: 18),
                Text(
                  '동영상 처리 중...',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: dialogContext.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        );
      }

      await uploadProvider.pickVideoFast(context);

      if (context.mounted) {
        Navigator.pop(context); // 로딩 다이얼로그 닫기
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // 로딩 다이얼로그 닫기
        toastification.show(
          context: context,
          type: ToastificationType.error,
          alignment: Alignment.bottomCenter,
          autoCloseDuration: const Duration(seconds: 4),
          title: Text(e.toString().replaceAll('Exception:', '')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final uploadProvider = context.watch<UploadProvider>();
    final hasCaption = _captionController.text.trim().isNotEmpty;
    final hasLink = extractUrl(_captionController.text) != null;
    final totalMediaCount =
        uploadProvider.images.length +
        (uploadProvider.video != null ? 1 : 0) +
        (uploadProvider.camera != null ? 1 : 0);
    final hasMedia = totalMediaCount > 0;
    final canUpload = hasCaption && !uploadProvider.isUploading;
    final userProvider = context.watch<UserProvider>();
    final userNickName =
        userProvider.nickname ??
        userProvider.currentUser?.displayName ??
        FirebaseAuth.instance.currentUser?.displayName ??
        '';
    final name = userProvider.name;
    final teamProvider = context.watch<TeamProvider>();
    final selectedTeam = teamProvider.selectedTeam;
    final profileProvider = context.watch<ProfileProvider>();
    final authUser = FirebaseAuth.instance.currentUser;

    // 프로필 이미지가 없고, 아직 요청하지 않았고, 로그인되어 있으면 로드
    if (authUser != null &&
        profileProvider.imageUrl == null &&
        !_requestedProfileLoad) {
      _requestedProfileLoad = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.read<ProfileProvider>().loadProfileImage(authUser.uid);
      });
    }

    final themeColor = selectedTeam?.color ?? BUTTON;
    final charCount = _captionController.text.length;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: context.bgColor,
      appBar: AppBar(
        title: Text(
          '새 게시물 작성',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: context.textPrimary,
            letterSpacing: -0.3,
          ),
        ),
        centerTitle: false,
        backgroundColor: context.bgColor,
        scrolledUnderElevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: GestureDetector(
                onTap: canUpload
                    ? () => _handleUpload(
                        uploadProvider: uploadProvider,
                        userNickName: userNickName,
                        name: name,
                      )
                    : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: canUpload ? themeColor : GRAYSCALE_LABEL_200,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: canUpload
                        ? [
                            BoxShadow(
                              color: themeColor.withValues(alpha: 0.25),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    '게시하기',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: canUpload ? WHITE : GRAYSCALE_LABEL_500,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            behavior: HitTestBehavior.translucent,
            child: SafeArea(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  16,
                  8,
                  16,
                  MediaQuery.of(context).viewInsets.bottom + 24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 메인 작성 라운지 카드
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: context.cardColor,
                        borderRadius: BorderRadius.circular(24),
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
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // 작성자 헤더 + 글자 수 카운터
                          Row(
                            children: [
                              if (authUser != null)
                                Consumer<ProfileProvider>(
                                  builder: (context, profileProvider, child) {
                                    profileProvider.subscribeMyProfileImage(
                                      authUser.uid,
                                    );
                                    final url = profileProvider.myProfileImage;
                                    return Container(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: themeColor.withValues(
                                            alpha: 0.25,
                                          ),
                                          width: 1.5,
                                        ),
                                      ),
                                      child: CircleAvatar(
                                        backgroundColor: GRAYSCALE_LABEL_100,
                                        radius: 21,
                                        backgroundImage: url != null
                                            ? NetworkImage(url)
                                            : null,
                                        child: url == null
                                            ? const Icon(
                                                Icons.person_rounded,
                                                color: GRAYSCALE_LABEL_500,
                                                size: 22,
                                              )
                                            : null,
                                      ),
                                    );
                                  },
                                )
                              else
                                const CircleAvatar(
                                  radius: 21,
                                  backgroundColor: GRAYSCALE_LABEL_100,
                                  child: Icon(
                                    Icons.person_rounded,
                                    color: GRAYSCALE_LABEL_500,
                                    size: 22,
                                  ),
                                ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            userNickName.isNotEmpty
                                                ? userNickName
                                                : 'ILU 팬',
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w800,
                                              color: context.textPrimary,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (selectedTeam != null) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: context
                                                  .readableColor(themeColor)
                                                  .withValues(alpha: 0.16),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              selectedTeam.name,
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w800,
                                                color: context.readableColor(
                                                  themeColor,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '전체 공개 · ILU 피드',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
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
                                  color: context.surfaceAltColor,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: context.borderColor,
                                  ),
                                ),
                                child: Text(
                                  '$charCount / 500',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: charCount > 450
                                        ? RED_DANGER_TEXT_50
                                        : context.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // 소프트 라운드 캡션 입력 박스
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: context.surfaceAltColor,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: context.borderColor),
                            ),
                            child: TextField(
                              controller: _captionController,
                              cursorColor: themeColor,
                              maxLines: null,
                              minLines: 5,
                              maxLength: 500,
                              onChanged: (_) => setState(() {}),
                              style: TextStyle(
                                fontSize: 15,
                                height: 1.5,
                                color: context.isDarkMode
                                    ? WHITE
                                    : context.textPrimary,
                              ),
                              decoration: InputDecoration(
                                hintText: '오늘 직관 분위기나 야구 이야기를 자유롭게 남겨보세요! (필수)',
                                hintStyle: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: context.textMuted,
                                ),
                                border: InputBorder.none,
                                counterText: '',
                                isDense: true,
                              ),
                            ),
                          ),

                          const SizedBox(height: 12),
                          FeedHashtagEditor(
                            tags: _hashtags,
                            accentColor: context.readableColor(themeColor),
                            onAdd: (tag) {
                              if (_hashtags.contains(tag)) return;
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

                          // 직관 모임 첨부 배너 (티켓 스타일 + 해제 가능)
                          if (uploadProvider.meetupId != null) ...[
                            const SizedBox(height: 12),
                            FutureBuilder<MeetupModel?>(
                              future: context
                                  .read<MeetupProvider>()
                                  .getMeetupById(uploadProvider.meetupId!),
                              builder: (context, snapshot) {
                                final meetup = snapshot.data;
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: themeColor.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: themeColor.withValues(alpha: 0.25),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 36,
                                        height: 36,
                                        decoration: BoxDecoration(
                                          color: WHITE,
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.groups_rounded,
                                          color: themeColor,
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              meetup?.title ??
                                                  '직관 모임 정보가 함께 공유됩니다',
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w800,
                                                color: themeColor,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            if (meetup != null) ...[
                                              const SizedBox(height: 2),
                                              Text(
                                                '${meetup.awayTeam} vs ${meetup.homeTeam} · ${meetup.stadium}',
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: GRAYSCALE_LABEL_600,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      InkWell(
                                        onTap: () =>
                                            uploadProvider.setMeetupId(null),
                                        borderRadius: BorderRadius.circular(12),
                                        child: Padding(
                                          padding: const EdgeInsets.all(4),
                                          child: Icon(
                                            Icons.close_rounded,
                                            size: 18,
                                            color: themeColor,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ],

                          // URL 링크 프리뷰
                          if (extractUrl(_captionController.text) != null) ...[
                            const SizedBox(height: 12),
                            Container(
                              decoration: BoxDecoration(
                                color: BACKGROUND_COLOR,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: GRAYSCALE_LABEL_200.withValues(
                                    alpha: 0.8,
                                  ),
                                ),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  LinkPreview(
                                    enableAnimation: true,
                                    text: extractUrl(_captionController.text)!,
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
                                        Icon(
                                          Icons.link_rounded,
                                          size: 16,
                                          color: themeColor,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            extractUrl(
                                              _captionController.text,
                                            )!,
                                            style: TextStyle(
                                              color: themeColor,
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

                          // 가로 스크롤 미디어 프리뷰 스트립
                          if (hasMedia) ...[
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      '첨부된 미디어',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        color: context.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 7,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: themeColor.withValues(
                                          alpha: 0.12,
                                        ),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        '$totalMediaCount',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          color: context.readableColor(
                                            themeColor,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  '가로로 스크롤하여 확인',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: context.textMuted,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              height: 104,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: totalMediaCount + 1,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(width: 10),
                                itemBuilder: (context, index) {
                                  if (index == totalMediaCount) {
                                    final accent = context.readableColor(
                                      themeColor,
                                    );
                                    return GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _showMediaPickerCard =
                                              !_showMediaPickerCard;
                                        });
                                      },
                                      child: Container(
                                        width: 104,
                                        height: 104,
                                        decoration: BoxDecoration(
                                          color: _showMediaPickerCard
                                              ? accent.withValues(alpha: 0.12)
                                              : context.surfaceAltColor,
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          border: Border.all(
                                            color: _showMediaPickerCard
                                                ? accent
                                                : context.borderColor,
                                            width: 1.2,
                                          ),
                                        ),
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              _showMediaPickerCard
                                                  ? Icons
                                                        .keyboard_arrow_up_rounded
                                                  : Icons.add_rounded,
                                              color: _showMediaPickerCard
                                                  ? accent
                                                  : context.textSecondary,
                                              size: 26,
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              _showMediaPickerCard
                                                  ? '접기'
                                                  : '추가하기',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                color: _showMediaPickerCard
                                                    ? accent
                                                    : context.textSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }
                                  if (index < uploadProvider.images.length) {
                                    return SizedBox(
                                      width: 104,
                                      height: 104,
                                      child: _buildMediaItem(
                                        uploadProvider.images[index],
                                        isVideo: false,
                                        provider: uploadProvider,
                                      ),
                                    );
                                  } else if (index <
                                      uploadProvider.images.length +
                                          (uploadProvider.video != null
                                              ? 1
                                              : 0)) {
                                    return SizedBox(
                                      width: 104,
                                      height: 104,
                                      child: _buildMediaItem(
                                        uploadProvider.video!,
                                        isVideo: true,
                                        provider: uploadProvider,
                                        thumbnail:
                                            uploadProvider.videoThumbnail,
                                      ),
                                    );
                                  } else {
                                    return SizedBox(
                                      width: 104,
                                      height: 104,
                                      child: _buildMediaItem(
                                        uploadProvider.camera!,
                                        isVideo: false,
                                        provider: uploadProvider,
                                        isCamera: true,
                                      ),
                                    );
                                  }
                                },
                              ),
                            ),
                            if (uploadProvider.video != null &&
                                (uploadProvider.isPreProcessingVideo ||
                                    uploadProvider
                                        .videoPreprocessLabel
                                        .isNotEmpty)) ...[
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: BACKGROUND_COLOR,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: GRAYSCALE_LABEL_200.withValues(
                                      alpha: 0.7,
                                    ),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(
                                              uploadProvider
                                                      .isPreProcessingVideo
                                                  ? Icons.bolt_rounded
                                                  : Icons.check_circle_rounded,
                                              size: 14,
                                              color: themeColor,
                                            ),
                                            const SizedBox(width: 5),
                                            Text(
                                              uploadProvider
                                                  .videoPreprocessLabel,
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                color: themeColor,
                                              ),
                                            ),
                                          ],
                                        ),
                                        Text(
                                          '${uploadProvider.videoPreprocessProgress}%',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                            color: GRAYSCALE_LABEL_700,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: LinearProgressIndicator(
                                        value:
                                            uploadProvider
                                                .videoPreprocessProgress /
                                            100,
                                        minHeight: 4,
                                        backgroundColor: GRAYSCALE_LABEL_200,
                                        color: themeColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ],
                      ),
                    ),

                    // 원탭 미디어 추가 툴바 카드 (첨부 전 기본 노출, 첨부 후엔 '추가하기' 클릭 시 노출)
                    if (!hasLink && (!hasMedia || _showMediaPickerCard)) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: context.cardColor,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: context.borderColor),
                          boxShadow: [
                            BoxShadow(
                              color: BLACK.withValues(alpha: 0.03),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '미디어 추가 (선택사항)',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: context.textPrimary,
                                  ),
                                ),
                                if (hasMedia)
                                  GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _showMediaPickerCard = false;
                                      });
                                    },
                                    child: Text(
                                      '접기',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: context.textMuted,
                                      ),
                                    ),
                                  )
                                else
                                  Text(
                                    '1탭으로 바로 추가',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: context.textMuted,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildQuickMediaButton(
                                    icon: Icons.camera_alt_rounded,
                                    label: '카메라 촬영',
                                    themeColor: themeColor,
                                    onTap: () async {
                                      if (uploadProvider.isUploading) return;
                                      await uploadProvider.pickCamera();
                                      if (mounted) {
                                        setState(() {
                                          _showMediaPickerCard = false;
                                        });
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _buildQuickMediaButton(
                                    icon: Icons.photo_library_rounded,
                                    label: '사진 앨범',
                                    themeColor: themeColor,
                                    onTap: () async {
                                      if (uploadProvider.isUploading) return;
                                      await uploadProvider.pickImages();
                                      if (mounted) {
                                        setState(() {
                                          _showMediaPickerCard = false;
                                        });
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _buildQuickMediaButton(
                                    icon: Icons.movie_creation_rounded,
                                    label: '동영상',
                                    themeColor: themeColor,
                                    onTap: () async {
                                      await _pickVideoDirectly(
                                        context,
                                        uploadProvider,
                                        themeColor,
                                      );
                                      if (mounted) {
                                        setState(() {
                                          _showMediaPickerCard = false;
                                        });
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],

                    // 직관모임 첨부 버튼 (피드의 '직관모임 🤝' 필터와 연동)
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: () => _showMeetupPickerBottomSheet(
                        context,
                        uploadProvider,
                        themeColor,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: context.cardColor,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: uploadProvider.meetupId != null
                                ? themeColor.withValues(alpha: 0.5)
                                : context.borderColor,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: BLACK.withValues(alpha: 0.03),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: context
                                    .readableColor(themeColor)
                                    .withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.groups_rounded,
                                color: context.readableColor(themeColor),
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    uploadProvider.meetupId != null
                                        ? '첨부된 직관모임 변경하기'
                                        : '내 직관모임 첨부하기 (선택)',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: context.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '모임을 첨부하면 피드의 직관모임 탭에도 함께 노출돼요',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: context.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.chevron_right_rounded,
                              color: context.textMuted,
                              size: 22,
                            ),
                          ],
                        ),
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

  void _showMeetupPickerBottomSheet(
    BuildContext context,
    UploadProvider uploadProvider,
    Color themeColor,
  ) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: context.bgColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          initialChildSize: 0.55,
          minChildSize: 0.35,
          maxChildSize: 0.85,
          expand: false,
          builder: (_, scrollController) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: sheetContext.borderColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '참여 중인 직관모임 선택',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: sheetContext.textPrimary,
                        ),
                      ),
                      if (uploadProvider.meetupId != null)
                        TextButton(
                          onPressed: () {
                            uploadProvider.setMeetupId(null);
                            Navigator.pop(sheetContext);
                          },
                          child: const Text(
                            '첨부 해제',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: RED_DANGER_TEXT_50,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: StreamBuilder<List<MeetupModel>>(
                      stream: context
                          .read<MeetupProvider>()
                          .getJoinedMeetupStream(currentUser.uid),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return Center(
                            child: CircularProgressIndicator(color: themeColor),
                          );
                        }
                        final meetups = snapshot.data!;
                        if (meetups.isEmpty) {
                          return Center(
                            child: Text(
                              '참여 중인 직관모임이 없습니다.\n직관모임 탭에서 모임을 만들거나 참여해 보세요!',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                color: context.textMuted,
                                fontWeight: FontWeight.w600,
                                height: 1.5,
                              ),
                            ),
                          );
                        }
                        return ListView.separated(
                          controller: scrollController,
                          itemCount: meetups.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
                          itemBuilder: (_, index) {
                            final m = meetups[index];
                            final isSelected = uploadProvider.meetupId == m.id;
                            return InkWell(
                              onTap: () {
                                uploadProvider.setMeetupId(m.id);
                                Navigator.pop(sheetContext);
                              },
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: sheetContext.cardColor,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isSelected
                                        ? themeColor
                                        : sheetContext.borderColor,
                                    width: isSelected ? 1.6 : 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: themeColor.withValues(
                                          alpha: 0.14,
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(
                                        Icons.groups_rounded,
                                        color: sheetContext.readableColor(
                                          themeColor,
                                        ),
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            m.title,
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w800,
                                              color: sheetContext.textPrimary,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            '${m.awayTeam} vs ${m.homeTeam} · ${m.stadium} (${m.gameDate})',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: sheetContext.textSecondary,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (isSelected)
                                      Icon(
                                        Icons.check_circle_rounded,
                                        color: themeColor,
                                        size: 22,
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildQuickMediaButton({
    required IconData icon,
    required String label,
    required Color themeColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: context.surfaceAltColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.borderColor),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color:
                  (context.isDarkMode && themeColor.computeLuminance() < 0.22)
                  ? ACCENT_CORAL
                  : themeColor,
              size: 22,
            ),
            const SizedBox(height: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: context.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaItem(
    File file, {
    required bool isVideo,
    Uint8List? thumbnail,
    required UploadProvider provider,
    bool isCamera = false,
  }) {
    Widget mediaContent;

    if (isVideo) {
      if (thumbnail != null && thumbnail.isNotEmpty) {
        mediaContent = Image.memory(
          thumbnail,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              color: Colors.grey[300],
              child: Center(
                child: Icon(Icons.videocam, color: Colors.white, size: 20),
              ),
            );
          },
        );
      } else {
        mediaContent = Container(
          color: Colors.grey[300],
          width: double.infinity,
          height: double.infinity,
          child: Center(
            child: Icon(Icons.videocam, color: Colors.white, size: 20),
          ),
        );
      }
    } else {
      mediaContent = Image.file(
        file,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      );
    }

    return Stack(
      children: [
        ClipRRect(borderRadius: BorderRadius.circular(16), child: mediaContent),
        Positioned(
          bottom: 6,
          left: 6,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isVideo) ...[
                  const Icon(Icons.play_arrow_rounded, color: WHITE, size: 12),
                  const SizedBox(width: 2),
                ],
                Text(
                  isVideo ? 'VIDEO' : (isCamera ? 'CAM' : 'PHOTO'),
                  style: const TextStyle(
                    color: WHITE,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          top: 6,
          right: 6,
          child: InkWell(
            onTap: () {
              if (isVideo) {
                provider.setVideo(null);
              } else if (isCamera) {
                provider.setCamera(null);
              } else {
                final updated = List<File>.from(provider.images)..remove(file);
                provider.setImages(updated);
              }
            },
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.65),
                shape: BoxShape.circle,
              ),
              padding: const EdgeInsets.all(5),
              child: const Icon(Icons.close_rounded, color: WHITE, size: 13),
            ),
          ),
        ),
      ],
    );
  }
}
