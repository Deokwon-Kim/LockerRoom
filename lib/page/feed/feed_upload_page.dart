import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter_link_previewer/flutter_link_previewer.dart';
import 'package:lockerroom/const/color.dart';
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

  Future<void> _handleUpload({
    required UploadProvider uploadProvider,
    required String userNickName,
    required String? name,
  }) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    FocusScope.of(context).unfocus();

    await uploadProvider.uploadAndSavePost(
      userId: currentUser.uid,
      userNickName: userNickName,
      name: name ?? '',
      text: _captionController.text,
    );

    await FirebaseAnalytics.instance.logEvent(
      name: 'feed_upload',
      parameters: {
        'has_image': uploadProvider.images.isNotEmpty ? 1 : 0,
        'has_video': uploadProvider.video != null ? 1 : 0,
      },
    );

    _captionController.clear();
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
          builder: (context) => AlertDialog(
            backgroundColor: WHITE,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: themeColor),
                const SizedBox(height: 18),
                const Text(
                  '동영상 처리 중...',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: GRAYSCALE_LABEL_900,
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
      backgroundColor: BACKGROUND_COLOR,
      appBar: AppBar(
        title: const Text(
          '새 게시물 작성',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: GRAYSCALE_LABEL_950,
            letterSpacing: -0.3,
          ),
        ),
        centerTitle: false,
        backgroundColor: BACKGROUND_COLOR,
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
                        color: WHITE,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: GRAYSCALE_LABEL_200.withValues(alpha: 0.7),
                        ),
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
                                                : '더베이스 팬',
                                            style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w800,
                                              color: GRAYSCALE_LABEL_950,
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
                                              color: themeColor.withValues(
                                                alpha: 0.12,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              selectedTeam.name,
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w800,
                                                color: themeColor,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    const Text(
                                      '전체 공개 · 더베이스 피드',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: GRAYSCALE_LABEL_500,
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
                                  color: BACKGROUND_COLOR,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: GRAYSCALE_LABEL_200.withValues(
                                      alpha: 0.8,
                                    ),
                                  ),
                                ),
                                child: Text(
                                  '$charCount / 500',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: charCount > 450
                                        ? RED_DANGER_TEXT_50
                                        : GRAYSCALE_LABEL_500,
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
                              color: BACKGROUND_COLOR,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: GRAYSCALE_LABEL_200.withValues(
                                  alpha: 0.7,
                                ),
                              ),
                            ),
                            child: TextField(
                              controller: _captionController,
                              cursorColor: themeColor,
                              maxLines: null,
                              minLines: 5,
                              maxLength: 500,
                              onChanged: (_) => setState(() {}),
                              style: const TextStyle(
                                fontSize: 15,
                                height: 1.5,
                                color: GRAYSCALE_LABEL_950,
                              ),
                              decoration: const InputDecoration(
                                hintText:
                                    '오늘 직관 분위기나 야구 이야기를 자유롭게 남겨보세요! (필수)',
                                hintStyle: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: GRAYSCALE_LABEL_400,
                                ),
                                border: InputBorder.none,
                                counterText: '',
                                isDense: true,
                              ),
                            ),
                          ),

                          // 직관 모임 첨부 배너
                          if (uploadProvider.meetupId != null) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: themeColor.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: themeColor.withValues(alpha: 0.2),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.groups_rounded,
                                    color: themeColor,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      '직관 모임 정보가 게시물에 함께 공유됩니다',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: themeColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
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
                                    const Text(
                                      '첨부된 미디어',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        color: GRAYSCALE_LABEL_900,
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
                                          color: themeColor,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const Text(
                                  '가로로 스크롤하여 확인',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: GRAYSCALE_LABEL_400,
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
                                separatorBuilder: (_, __) =>
                                    const SizedBox(width: 10),
                                itemBuilder: (context, index) {
                                  if (index == totalMediaCount) {
                                    // 마지막 + 추가 타일
                                    return GestureDetector(
                                      onTap: () => pickImageBottomSheet(
                                        context,
                                        uploadProvider,
                                      ),
                                      child: Container(
                                        width: 104,
                                        height: 104,
                                        decoration: BoxDecoration(
                                          color: BACKGROUND_COLOR,
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          border: Border.all(
                                            color: GRAYSCALE_LABEL_300,
                                            width: 1.2,
                                          ),
                                        ),
                                        child: const Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.add_rounded,
                                              color: GRAYSCALE_LABEL_500,
                                              size: 26,
                                            ),
                                            SizedBox(height: 4),
                                            Text(
                                              '미디어 추가',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                color: GRAYSCALE_LABEL_500,
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
                          ],
                        ],
                      ),
                    ),

                    // 원탭 미디어 추가 툴바 카드 (바텀시트 없이 바로 실행)
                    if (!hasLink) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: WHITE,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: GRAYSCALE_LABEL_200.withValues(alpha: 0.7),
                          ),
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
                                const Text(
                                  '원탭 미디어 추가 (선택사항)',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: GRAYSCALE_LABEL_700,
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => pickImageBottomSheet(
                                    context,
                                    uploadProvider,
                                  ),
                                  child: Text(
                                    '전체 옵션 보기',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: themeColor,
                                    ),
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
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _buildQuickMediaButton(
                                    icon: Icons.movie_creation_rounded,
                                    label: '동영상',
                                    themeColor: themeColor,
                                    onTap: () => _pickVideoDirectly(
                                      context,
                                      uploadProvider,
                                      themeColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 20),

                    // 하단 피드 업로드 완료 버튼
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: canUpload
                            ? () => _handleUpload(
                                uploadProvider: uploadProvider,
                                userNickName: userNickName,
                                name: name,
                              )
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: themeColor,
                          disabledBackgroundColor: GRAYSCALE_LABEL_300,
                          elevation: canUpload ? 2 : 0,
                          shadowColor: themeColor.withValues(alpha: 0.35),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        child: uploadProvider.isUploading
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: WHITE,
                                ),
                              )
                            : const Text(
                                '피드 업로드 완료',
                                style: TextStyle(
                                  color: WHITE,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // 업로드 오버레이 (화면 전체를 덮는 풀스크린)
          if (uploadProvider.isUploading)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.5),
                child: Center(
                  child: Container(
                    width: 230,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 26,
                    ),
                    decoration: BoxDecoration(
                      color: WHITE,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 24,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: 68,
                              height: 68,
                              child: CircularProgressIndicator(
                                value: uploadProvider.uploadProgress > 0
                                    ? uploadProvider.uploadProgress / 100
                                    : null,
                                strokeWidth: 5,
                                color: themeColor,
                                backgroundColor: GRAYSCALE_LABEL_200,
                              ),
                            ),
                            Text(
                              '${uploadProvider.uploadProgress}%',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: GRAYSCALE_LABEL_900,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Text(
                          uploadProvider.uploadStatusText.isNotEmpty
                              ? uploadProvider.uploadStatusText
                              : '게시물 업로드 중...',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: GRAYSCALE_LABEL_950,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
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
          color: BACKGROUND_COLOR,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: GRAYSCALE_LABEL_200.withValues(alpha: 0.8),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: themeColor, size: 22),
            const SizedBox(height: 5),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: GRAYSCALE_LABEL_800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<dynamic> pickImageBottomSheet(
    BuildContext context,
    UploadProvider uploadProvider,
  ) {
    return showModalBottomSheet(
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: GRAYSCALE_LABEL_50,
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: GRAYSCALE_LABEL_200,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Icon(Icons.perm_media, color: BUTTON),
                    SizedBox(width: 8),
                    Text(
                      '미디어 추가',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: BLACK,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                Container(height: 1, color: GRAYSCALE_LABEL_200),
                SizedBox(height: 8),

                ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  leading: CircleAvatar(
                    backgroundColor: BUTTON.withOpacity(0.1),
                    child: Icon(Icons.camera_alt_rounded, color: BUTTON),
                  ),
                  title: Text(
                    '사진 촬영',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text('카메라로 바로 촬영합니다.'),
                  onTap: () async {
                    if (uploadProvider.isUploading) return;
                    await uploadProvider.pickCamera();
                    if (context.mounted) Navigator.pop(context);
                  },
                ),
                ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  leading: CircleAvatar(
                    backgroundColor: BUTTON.withOpacity(0.1),
                    child: Icon(Icons.photo, color: BUTTON),
                  ),
                  title: Text(
                    '사진 선택',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text('여러 장 선택할 수 있어요.'),
                  onTap: () async {
                    if (uploadProvider.isUploading) return;
                    await uploadProvider.pickImages();
                    if (context.mounted) Navigator.pop(context);
                  },
                ),
                ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  leading: CircleAvatar(
                    backgroundColor: BUTTON.withOpacity(0.1),
                    child: Icon(Icons.movie, color: BUTTON),
                  ),
                  title: Text(
                    '동영상 선택',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text('최대 1분짜리 동영상만 업로드 가능합니다.'),
                  onTap: () async {
                    if (uploadProvider.isUploading) return;
                    try {
                      // 로딩 다이얼로그 표시
                      if (context.mounted) {
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (context) => AlertDialog(
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircularProgressIndicator(color: BUTTON),
                                SizedBox(height: 20),
                                Text(
                                  '동영상 처리 중...',
                                  style: TextStyle(fontSize: 16),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      // ⚡ wechat_assets_picker 사용 (빠름)
                      await uploadProvider.pickVideoFast(context);

                      if (context.mounted) {
                        Navigator.pop(context); // 로딩 다이얼로그 닫기
                        Navigator.pop(context); // 바텀시트(메뉴) 닫기
                      }
                    } catch (e) {
                      if (context.mounted) {
                        Navigator.pop(context); // 로딩 다이얼로그 닫기
                        Navigator.pop(context); // 바텀시트(메뉴) 닫기

                        // 바텀시트가 닫힌 후 메시지 표시

                        if (context.mounted) {
                          toastification.show(
                            context: context,
                            type: ToastificationType.error,
                            alignment: Alignment.bottomCenter,
                            autoCloseDuration: Duration(seconds: 4),
                            title: Text(
                              e.toString().replaceAll('Exception:', ''),
                            ),
                          );
                        }
                      }
                    }
                  },
                ),
                SizedBox(height: 4),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(
                      '닫기',
                      style: TextStyle(color: GRAYSCALE_LABEL_500),
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
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: mediaContent,
        ),
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
                  const Icon(
                    Icons.play_arrow_rounded,
                    color: WHITE,
                    size: 12,
                  ),
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
