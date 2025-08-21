import 'dart:io';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
        context.read<ProfileProvider>().loadProfileImage(authUser.uid);
      });
    }

    final themeColor = teamProvider.selectedTeam?.color ?? BUTTON;
    final hasCaption = _captionController.text.trim().isNotEmpty;
    final hasMedia = uploadProvider.mediaFiles.isNotEmpty;
    final canUpload = hasCaption && hasMedia && !uploadProvider.isUploading;
    uploadProvider.mediaFiles.isNotEmpty && !uploadProvider.isUploading;

    return Scaffold(
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
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 헤더: 프로필 + 이름
              Row(
                children: [
                  if (authUser != null)
                    StreamBuilder<String?>(
                      stream: context
                          .read<ProfileProvider>()
                          .liveloadProfileImage(authUser.uid),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const SizedBox(
                            width: 40,
                            height: 40,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: BUTTON,
                            ),
                          );
                        }
                        final url = snapshot.data;
                        return CircleAvatar(
                          radius: 25,
                          backgroundImage: url != null
                              ? NetworkImage(url)
                              : null,
                          backgroundColor: GRAYSCALE_LABEL_300,
                          child: url == null
                              ? const Icon(Icons.person, color: BLACK, size: 25)
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
              const SizedBox(height: 12),

              // 캡션 입력 박스
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: GRAYSCALE_LABEL_200),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
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

              const SizedBox(height: 12),

              // 미디어 미리보기 그리드/가로 스크롤
              if (uploadProvider.mediaFiles.isNotEmpty)
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: GRAYSCALE_LABEL_200),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: SizedBox(
                    height: 110,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: uploadProvider.mediaFiles.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final file = uploadProvider.mediaFiles[index];
                        return Stack(
                          clipBehavior: Clip.none,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.file(
                                File(file.path),
                                width: 110,
                                height: 110,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              top: -6,
                              right: -6,
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () {
                                    uploadProvider.removeMediaAt(index);
                                  },
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: Colors.black.withAlpha(160),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.close,
                                      color: WHITE,
                                      size: 13,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),

              if (uploadProvider.mediaFiles.isNotEmpty)
                const SizedBox(height: 8),

              // 미디어 선택 버튼
              OutlinedButton.icon(
                onPressed: uploadProvider.isUploading
                    ? null
                    : uploadProvider.pickMultipleMedia,
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: const Text(
                  '미디어 선택',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: BUTTON,
                  side: const BorderSide(color: BUTTON),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),

              const Spacer(),

              // 업로드 버튼
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: canUpload
                      ? () async {
                          final ok = await uploadProvider.uploadPost(
                            _captionController.text,
                          );
                          if (ok) {
                            _captionController.clear();
                            widget.onUploaded?.call();
                          }
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
            ],
          ),
        ),
      ),
    );
  }
}
