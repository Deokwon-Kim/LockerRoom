import 'package:flutter/material.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/model/post_model.dart';
import 'package:lockerroom/page/feed/fullscreen_image_viewer.dart';
import 'package:lockerroom/page/feed/fullscreen_video_player.dart';
import 'package:lockerroom/provider/feedEdit_provider.dart';
import 'package:lockerroom/provider/profile_provider.dart';
import 'package:lockerroom/provider/team_provider.dart';
import 'package:lockerroom/utils/media_utils.dart';
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
  late final TextEditingController _captionEditController;

  @override
  void initState() {
    super.initState();
    // 기존 게시글 텍스트를 컨트롤러에 설정
    _captionEditController = TextEditingController(text: widget.post.text);

    // Provider 초기화 (미디어 로드)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FeedEditProvider>().initializeEdit(widget.post);
    });
  }

  @override
  void dispose() {
    _captionEditController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BACKGROUND_COLOR,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: BACKGROUND_COLOR,
        title: Text(
          '게시물 수정',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        leading: TextButton(
          onPressed: () {
            Navigator.pop(context);
          },
          child: Text(
            '취소',
            style: TextStyle(
              color: RED_DANGER_TEXT_50,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        actions: [
          Consumer2<FeedEditProvider, TeamProvider>(
            builder: (context, feedEditProvider, tp, child) {
              return TextButton(
                onPressed: feedEditProvider.isUploading
                    ? null
                    : () async {
                        final success = await feedEditProvider.updatePost(
                          postId: widget.post.id,
                          newText: _captionEditController.text,
                        );
                        if (success) {
                          Navigator.pop(context);
                          toastification.show(
                            context: context,
                            type: ToastificationType.success,
                            style: ToastificationStyle.flat,
                            alignment: Alignment.bottomCenter,
                            autoCloseDuration: Duration(seconds: 2),
                            title: Text('게시물 수정이 완료되었습니다.'),
                          );
                        }
                      },
                child: feedEditProvider.isUploading
                    ? CircularProgressIndicator(color: tp.selectedTeam?.color)
                    : Text(
                        '저장',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: BLACK,
                        ),
                      ),
              );
            },
          ),
        ],
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.deferToChild,
        onTap: () => FocusScope.of(context).unfocus(),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Card(
            color: WHITE,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Consumer<ProfileProvider>(
                        builder: (context, profileProvider, child) {
                          final url =
                              profileProvider.userProfiles[widget.post.userId];
                          return CircleAvatar(
                            radius: 25,
                            backgroundImage: url != null
                                ? NetworkImage(url)
                                : null,
                            backgroundColor: GRAYSCALE_LABEL_300,
                            child: url == null
                                ? const Icon(
                                    Icons.person,
                                    color: BLACK,
                                    size: 25,
                                  )
                                : null,
                          );
                        },
                      ),
                      SizedBox(width: 10),
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          widget.post.userNickName,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: GRAYSCALE_LABEL_200),
                    ),
                    child: TextField(
                      controller: _captionEditController,
                      cursorColor: BUTTON,
                      maxLines: null,
                      minLines: 3,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        hintText: '내용을 입력하세요',
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  SizedBox(height: 8),

                  Consumer<FeedEditProvider>(
                    builder: (context, feedEditProvider, child) {
                      return _buildMediaSection(feedEditProvider);
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMediaSection(FeedEditProvider feedEditProvider) {
    return _buildMediaItem(feedEditProvider);
  }

  Widget _buildMediaItem(FeedEditProvider feedEditProvider) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool inSingle = feedEditProvider.editableMediaUrls.length == 1;
        final double availableWidth = constraints.maxWidth;

        // 싱글일 때는 16:9 비율, 멀티일 때는 정사각형
        final double aspectRatio = inSingle ? 16 / 9 : 1.0;
        final double listHeight = (availableWidth / aspectRatio).clamp(
          160.0,
          400.0,
        );
        final double itemWidth = inSingle
            ? availableWidth
            : (availableWidth * 0.48).clamp(140.0, availableWidth);
        return SizedBox(
          height: listHeight,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: feedEditProvider.editableMediaUrls.length,
            itemBuilder: (context, index) {
              final mediaUrl = feedEditProvider.editableMediaUrls[index];
              final isVideo = MediaUtils.isVideoUrl(mediaUrl);
              return Padding(
                padding: EdgeInsets.only(left: 0, right: inSingle ? 0 : 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: isVideo
                      ? Stack(
                          children: [
                            GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => FullscreenVideoPlayer(
                                      videoUrl: mediaUrl,
                                    ),
                                  ),
                                );
                              },
                              child: NetworkVideoPlayer(
                                videoUrl: mediaUrl,
                                width: itemWidth,
                                height: listHeight,
                                fit: BoxFit.contain,
                                autoPlay: true,
                                showControls: false,
                              ),
                            ),
                            // 삭제 버튼
                            Positioned(
                              top: 8,
                              right: 8,
                              child: GestureDetector(
                                onTap: () =>
                                    feedEditProvider.removeMedia(index),
                                child: Container(
                                  padding: EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.7),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.close,
                                    color: WHITE,
                                    size: 18,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        )
                      : GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => FullscreenImageViewer(
                                  imageUrls: feedEditProvider.editableMediaUrls,
                                  initialIndex: 1,
                                ),
                              ),
                            );
                          },
                          child: Stack(
                            children: [
                              Image.network(
                                mediaUrl,
                                height: listHeight,
                                width: itemWidth,
                                fit: BoxFit.cover,
                                loadingBuilder:
                                    (context, child, loadingProgress) {
                                      if (loadingProgress == null) {
                                        return child;
                                      }
                                      return SizedBox(
                                        height: listHeight,
                                        width: itemWidth,
                                        child: Center(
                                          child: CircularProgressIndicator(
                                            color: BUTTON,
                                          ),
                                        ),
                                      );
                                    },
                              ),
                              // 삭제 버튼
                              Positioned(
                                top: 8,
                                right: 8,
                                child: GestureDetector(
                                  onTap: () =>
                                      feedEditProvider.removeMedia(index),
                                  child: Container(
                                    padding: EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.7),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.close,
                                      color: WHITE,
                                      size: 18,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
