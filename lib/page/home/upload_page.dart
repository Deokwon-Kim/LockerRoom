import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/rendering.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/provider/profile_provider.dart';
import 'package:lockerroom/provider/team_provider.dart';
import 'package:lockerroom/provider/upload_provider.dart';
import 'package:lockerroom/provider/user_provider.dart';
import 'package:provider/provider.dart';

class UploadPage extends StatefulWidget {
  final VoidCallback? onUploaded;
  const UploadPage({super.key, this.onUploaded});

  @override
  State<UploadPage> createState() => _UploadPageState();
}

class _UploadPageState extends State<UploadPage> {
  late final TextEditingController _captionController;
  bool _requestedProfileLoad = false;

  @override
  void initState() {
    super.initState();
    _captionController = TextEditingController();
  }

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uploadProvider = context.watch<UploadProvider>();
    final hasCaption = _captionController.text.trim().isNotEmpty;
    final hasMedia =
        uploadProvider.images.isNotEmpty ||
        uploadProvider.video != null ||
        uploadProvider.camera != null;
    final canUpload = hasCaption && hasMedia && !uploadProvider.isUploading;
    final userProvider = context.read<UserProvider>();
    final userName =
        userProvider.nickname ?? userProvider.currentUser?.displayName ?? '사용자';
    final teamProvider = context.read<TeamProvider>();
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

    final themeColor = teamProvider.selectedTeam?.color ?? BUTTON;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: BACKGROUND_COLOR,
      appBar: AppBar(
        title: const Text(
          '새로운 게시물',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: BACKGROUND_COLOR,
        elevation: 0,
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.translucent,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      if (authUser != null)
                        Consumer<ProfileProvider>(
                          builder: (context, profileProvider, child) {
                            profileProvider.subscribeMyProfileImage(
                              authUser.uid,
                            );
                            final url = profileProvider.myProfileImage;
                            return CircleAvatar(
                              radius: 25,
                              backgroundImage: url != null
                                  ? NetworkImage(url)
                                  : null,
                              child: url == null
                                  ? const Icon(Icons.person)
                                  : null,
                            );
                          },
                        )
                      else
                        const CircleAvatar(
                          radius: 25,
                          backgroundColor: GRAYSCALE_LABEL_300,
                          child: Icon(Icons.person, color: BLACK, size: 25),
                        ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          userName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 10),

                  // 업로드 진행 상태 표시
                  if (uploadProvider.isUploading)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: LinearProgressIndicator(
                        value: uploadProvider.uploadProgress,
                        backgroundColor: Colors.grey[300],
                        color: BUTTON,
                      ),
                    ),

                  // 캡션 입력 박스
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: GRAYSCALE_LABEL_200),
                    ),

                    child: TextField(
                      controller: _captionController,
                      cursorColor: themeColor,
                      maxLines: null,
                      minLines: 3,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        hintText: '새로운 소식이 있나요? (필수)',
                        hintStyle: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                        border: InputBorder.none,
                      ),
                    ),
                  ),

                  // 글자 수 카운터
                  Padding(
                    padding: const EdgeInsets.only(right: 24, top: 4),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        '${_captionController.text.length}/500',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // 미디어 미리보기 그리드/가로 스크롤
                  // 스크롤 없이 전부 보이게
                  if (hasMedia)
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),

                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: GRAYSCALE_LABEL_200),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        child: SizedBox(
                          height: 120, // 1줄 높이까지만 보이게 (적당히 조정 가능)
                          child: GridView.builder(
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  crossAxisSpacing: 6,
                                  mainAxisSpacing: 6,
                                ),
                            itemCount:
                                uploadProvider.images.length +
                                (uploadProvider.video != null ? 1 : 0) +
                                (uploadProvider.camera != null ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index < uploadProvider.images.length) {
                                return _buildMediaItem(
                                  uploadProvider.images[index],
                                  isVideo: false,
                                  provider: uploadProvider,
                                );
                              } else if (index <
                                  uploadProvider.images.length +
                                      (uploadProvider.video != null ? 1 : 0)) {
                                return _buildMediaItem(
                                  uploadProvider.video!,
                                  isVideo: true,
                                  provider: uploadProvider,
                                  thumbnail: uploadProvider.videoThumbnail,
                                );
                              } else {
                                return _buildMediaItem(
                                  uploadProvider.camera!,
                                  isVideo: false,
                                  provider: uploadProvider,
                                  isCamera: true,
                                );
                              }
                            },
                          ),
                        ),
                      ),
                    ),
                  // 미디어 선택 버튼
                  Transform.translate(
                    offset: Offset(5, -30),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: uploadProvider.isUploading
                              ? null
                              : uploadProvider.pickCamera,
                          icon: Icon(Icons.camera_alt_rounded),
                        ),
                        IconButton(
                          onPressed: uploadProvider.isUploading
                              ? null
                              : uploadProvider.pickImages,
                          icon: Icon(Icons.photo_library_sharp),
                        ),
                        IconButton(
                          onPressed: uploadProvider.isUploading
                              ? null
                              : uploadProvider.pickVideo,
                          icon: Icon(Icons.movie_rounded),
                        ),
                      ],
                    ),
                  ),
                  // Padding(
                  //   padding: const EdgeInsets.symmetric(
                  //     horizontal: 16.0,
                  //     vertical: 12.0,
                  //   ),
                  //   child: OutlinedButton.icon(
                  //     onPressed: uploadProvider.isUploading
                  //         ? null
                  //         : uploadProvider.pickImages,
                  //     icon: const Icon(Icons.add_photo_alternate_outlined),
                  //     label: const Text(
                  //       '사진 추가',
                  //       style: TextStyle(fontWeight: FontWeight.w500),
                  //     ),
                  //     style: OutlinedButton.styleFrom(
                  //       foregroundColor: BUTTON,
                  //       side: const BorderSide(color: BUTTON),
                  //       shape: RoundedRectangleBorder(
                  //         borderRadius: BorderRadius.circular(10),
                  //       ),
                  //       padding: const EdgeInsets.symmetric(vertical: 12),
                  //     ),
                  //   ),
                  // ),

                  // Padding(
                  //   padding: const EdgeInsets.symmetric(
                  //     horizontal: 16.0,
                  //     vertical: 12.0,
                  //   ),
                  //   child: OutlinedButton.icon(
                  //     onPressed: uploadProvider.isUploading
                  //         ? null
                  //         : () async {
                  //             await uploadProvider.pickVideo();
                  //           },
                  //     icon: const Icon(Icons.add_photo_alternate_outlined),
                  //     label: const Text(
                  //       '동영상 추가',
                  //       style: TextStyle(fontWeight: FontWeight.w500),
                  //     ),
                  //     style: OutlinedButton.styleFrom(
                  //       foregroundColor: BUTTON,
                  //       side: const BorderSide(color: BUTTON),
                  //       shape: RoundedRectangleBorder(
                  //         borderRadius: BorderRadius.circular(10),
                  //       ),
                  //       padding: const EdgeInsets.symmetric(vertical: 12),
                  //     ),
                  //   ),
                  // ),
                  const SizedBox(height: 16),

                  // 업로드 버튼
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: canUpload
                            ? () async {
                                await uploadProvider.uploadAndSavePost(
                                  userId:
                                      FirebaseAuth.instance.currentUser!.uid,
                                  userName: userName,
                                  text: _captionController.text,
                                );
                                _captionController.clear();
                                widget.onUploaded?.call();
                              }
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: themeColor,
                          disabledBackgroundColor: GRAYSCALE_LABEL_300,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
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
                                '업로드',
                                style: TextStyle(
                                  color: WHITE,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
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
        ClipRRect(borderRadius: BorderRadius.circular(10), child: mediaContent),
        if (isVideo)
          Positioned(
            bottom: 4,
            right: 4,
            child: Icon(Icons.play_circle, color: Colors.white, size: 20),
          ),
        Positioned(
          top: 4,
          right: 4,
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
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              padding: const EdgeInsets.all(4),
              child: Icon(Icons.close, color: Colors.white, size: 14),
            ),
          ),
        ),
      ],
    );

    // 헤더: 프로필 + 이름
  }
}
