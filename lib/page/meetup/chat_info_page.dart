import 'dart:async';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/model/meetup_model.dart';
import 'package:lockerroom/model/user_model.dart';
import 'package:lockerroom/page/alert/confirm_diallog.dart';
import 'package:lockerroom/page/feed/fullscreen_image_viewer.dart';
import 'package:lockerroom/page/meetup/chat_media_page.dart';
import 'package:lockerroom/provider/chat_provider.dart';
import 'package:lockerroom/provider/meetup_provider.dart';
import 'package:lockerroom/provider/profile_provider.dart';
import 'package:provider/provider.dart';
import 'package:lockerroom/page/myPage/user_detail_page.dart';
import 'package:toastification/toastification.dart';

class ChatInfoPage extends StatefulWidget {
  final MeetupModel meetup;
  const ChatInfoPage({super.key, required this.meetup});

  @override
  State<ChatInfoPage> createState() => _ChatInfoPageState();
}

class _ChatInfoPageState extends State<ChatInfoPage> {
  MeetupModel? _latestMeetup;
  List<types.Message> _serverMessages = [];
  final List<types.Message> _pendingMessages = [];
  List<UserModel> _participantsInfos = [];
  StreamSubscription? _messagesSubscription;
  StreamSubscription? _participantsSubscription;

  @override
  void initState() {
    super.initState();
    // 메시지 스트림 구독하여 이미지 불러오기
    _messagesSubscription = context
        .read<ChatProvider>()
        .getMessagesStream(widget.meetup.id)
        .listen(
          (messages) {
            if (mounted) {
              setState(() {
                // ChatProvider에서 이미 types.Message로 변환됨
                _serverMessages = messages.cast<types.Message>().toList();
              });
            }
          },
          onError: (e) {
            debugPrint('채팅 정보 메시지 구독 오류: $e');
          },
        );
    _loadParticipantInfos();
    _setupParticipantsListener();
  }

  void _setupParticipantsListener() {
    _participantsSubscription = context
        .read<MeetupProvider>()
        .getChatParticipantIdsStream(widget.meetup.id)
        .listen(
          (ids) async {
            // 강제 퇴장 여부 확인
            final currentUserId = FirebaseAuth.instance.currentUser?.uid;
            final isHost = widget.meetup.userId == currentUserId;
            final isParticipant = ids.contains(currentUserId);

            if (!isHost && !isParticipant && mounted) {
              Navigator.of(context).pop();
              return;
            }

            final infos = await context
                .read<MeetupProvider>()
                .getParticipantsInfo(ids);
            if (mounted) {
              setState(() {
                _participantsInfos = infos;
              });
            }
          },
          onError: (e) {
            debugPrint('채팅 정보 참여자 구독 오류: $e');
          },
        );
  }

  Future<void> _loadParticipantInfos() async {
    final meetupProvider = context.read<MeetupProvider>();

    final latestMeetup = await meetupProvider.getMeetupById(widget.meetup.id);
    if (latestMeetup == null) return;

    final infos = await meetupProvider.getParticipantsInfo(
      latestMeetup.participants,
    );
    if (mounted) {
      setState(() {
        _participantsInfos = infos;
      });
    }
  }

  @override
  void dispose() {
    _messagesSubscription?.cancel();
    _participantsSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final meetup = _latestMeetup ?? widget.meetup;
    return Scaffold(
      backgroundColor: BACKGROUND_COLOR,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildInfoHeader(meetup),
                _buildPictureGallery(),
                Divider(height: 1, color: GRAYSCALE_LABEL_300),

                // 대화 상대 목록
                Padding(
                  padding: const EdgeInsets.only(left: 20, right: 20, top: 18),
                  child: Row(
                    children: [
                      Text(
                        '대화 상대',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: GRAYSCALE_LABEL_500,
                        ),
                      ),
                      SizedBox(width: 8),
                      Text(
                        '${_participantsInfos.length}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: GRAYSCALE_LABEL_500,
                        ),
                      ),
                    ],
                  ),
                ),
                ..._participantsInfos.map(
                  (user) => _buildParticipantTile(user),
                ),
              ],
            ),
          ),
          _buildBottomActions(),
        ],
      ),
    );
  }

  Widget _buildInfoHeader(MeetupModel meetup) {
    return Stack(
      children: [
        // 배경 이미지
        meetup.images.isNotEmpty
            ? SizedBox(
                width: double.infinity,
                height: 250,
                child: Image.network(meetup.images[0], fit: BoxFit.cover),
              )
            : Container(
                width: double.infinity,
                height: 250,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [GRAYSCALE_LABEL_400, GRAYSCALE_LABEL_300],
                  ),
                ),
                child: Icon(
                  Icons.group_sharp,
                  color: WHITE.withOpacity(0.5),
                  size: 80,
                ),
              ),
        // 그라데이션 오버레이 (텍스트 가독성 확보)
        Container(
          height: 250,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withOpacity(0.4),
                Colors.transparent,
                Colors.transparent,
                Colors.black.withOpacity(0.7),
              ],
              stops: const [0.0, 0.3, 0.6, 1.0],
            ),
          ),
        ),

        // 모임 정보 텍스트
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${meetup.awayTeam} vs ${meetup.homeTeam}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: WHITE.withOpacity(0.9),
                  ),
                ),
                SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        widget.meetup.title,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: WHITE,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    StreamBuilder<bool>(
                      stream: context
                          .read<MeetupProvider>()
                          .getMuteStatusStream(widget.meetup.id),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return const SizedBox.shrink();
                        }
                        final isMuted = snapshot.data ?? false;
                        return IconButton(
                          onPressed: () {
                            context.read<MeetupProvider>().toggleMeetupMute(
                              widget.meetup.id,
                              !isMuted,
                            );
                          },
                          icon: Icon(
                            isMuted
                                ? CupertinoIcons.bell_slash_fill
                                : CupertinoIcons.bell_fill,
                            color: WHITE,
                            size: 20,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        // 닫기 버튼
        Positioned(
          top: MediaQuery.of(context).padding.top + 0,
          left: 10,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(50),
              color: BLACK.withOpacity(0.5),
            ),
            child: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: Icon(CupertinoIcons.xmark, color: WHITE),
            ),
          ),
        ),
      ],
    );
  }

  // 사진 가로 스크롤 위젯
  Widget _buildPictureGallery() {
    final galleryImages = [
      ..._serverMessages,
      ..._pendingMessages,
    ].whereType<types.ImageMessage>().toList();

    if (galleryImages.isEmpty) return const SizedBox.shrink();

    final previewImages = galleryImages.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ChatMediaPage(images: galleryImages),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '사진 모아보기',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: GRAYSCALE_LABEL_500,
                  ),
                ),
                Row(
                  children: [
                    Text(
                      '${galleryImages.length}',
                      style: const TextStyle(
                        fontSize: 15,
                        color: GRAYSCALE_LABEL_400,
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: GRAYSCALE_LABEL_400,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        SizedBox(
          height: 100,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: previewImages.length,
            itemBuilder: (context, index) {
              final msg = previewImages[index];
              final bool isLocal =
                  msg.metadata?['isLocal'] == true || msg.uri.startsWith('/');

              return GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => FullscreenImageViewer(
                        imageUrls: galleryImages.map((m) => m.uri).toList(),
                        initialIndex: index,
                      ),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Hero(
                      tag: 'chat_media_preview_${msg.id}',
                      child: isLocal
                          ? Image.file(
                              File(msg.uri),
                              width: 100,
                              height: 100,
                              fit: BoxFit.cover,
                            )
                          : Image.network(
                              msg.uri,
                              width: 100,
                              height: 100,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Container(
                                    width: 100,
                                    height: 100,
                                    color: Colors.grey[200],
                                    child: const Icon(
                                      Icons.broken_image,
                                      size: 20,
                                    ),
                                  ),
                            ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  // 참여자 타일 (방장 표시 및 강퇴)
  Widget _buildParticipantTile(UserModel user) {
    final bool isHost = user.uid == widget.meetup.userId;
    final bool amIHost =
        FirebaseAuth.instance.currentUser?.uid == widget.meetup.userId;

    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => UserDetailPage(userId: user.uid),
          ),
        );
      },
      child: ListTile(
        leading: CircleAvatar(
          backgroundImage:
              (user.profileImage != null && user.profileImage!.isNotEmpty)
              ? NetworkImage(user.profileImage!)
              : null,
          child: (user.profileImage == null || user.profileImage!.isEmpty)
              ? CircleAvatar(
                  backgroundColor: GRAYSCALE_LABEL_300,
                  child: Icon(Icons.person, color: BLACK),
                )
              : null,
        ),
        title: Row(
          children: [
            Consumer<ProfileProvider>(
              builder: (context, profileProvider, child) {
                profileProvider.subscribeUserProfile(user.uid);
                final nickname =
                    profileProvider.userNicknames[user.uid] ??
                    user.userNickName;
                return Text(nickname);
              },
            ),
            if (isHost) ...[
              SizedBox(width: 4),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.amber,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '방장',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        trailing: (amIHost && !isHost)
            ? IconButton(
                onPressed: () => _showKickDialog(user),
                icon: Icon(Icons.exit_to_app, color: RED_DANGER_TEXT_50),
              )
            : null,
      ),
    );
  }

  // 하단 액션 버튼 (모임 탈퇴하기)
  Widget _buildBottomActions() {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final bool isHost = currentUserId == widget.meetup.userId;

    // 방장에게는 탈퇴 버튼을 보여주지 않음
    if (isHost) return const SizedBox.shrink();

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 15,
        bottom: MediaQuery.of(context).padding.bottom + 15,
      ),
      decoration: BoxDecoration(
        color: GRAYSCALE_LABEL_100,
        border: Border(top: BorderSide(color: GRAYSCALE_LABEL_300, width: 0.5)),
      ),
      child: InkWell(
        onTap: _showLeaveDialog,
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.logout, color: RED_DANGER_TEXT_50, size: 20),
            const SizedBox(width: 10),
            const Text(
              '모임 탈퇴하기',
              style: TextStyle(
                color: RED_DANGER_TEXT_50,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showKickDialog(UserModel user) {
    showDialog(
      context: context,
      builder: (context) => ConfirmationDialog(
        title: '사용자 강제퇴장',
        content: '${user.userNickName}님을 정말로 모임에서 퇴장시키겠습니까?',
        confirmText: '퇴장',
        onConfirm: () async {
          final success = await context.read<MeetupProvider>().kickParticipant(
            widget.meetup.id,
            user.uid,
          );
          if (success && mounted) {
            _loadParticipantInfos();
            toastification.show(
              context: context,
              type: ToastificationType.success,
              alignment: Alignment.bottomCenter,
              autoCloseDuration: const Duration(seconds: 2),
              title: Text('${user.userNickName}님을 퇴장조치 했습니다.'),
            );
          }
        },
      ),
    );
  }

  void _showLeaveDialog() {
    final navigator = Navigator.of(context);

    showDialog(
      context: context,
      builder: (context) => ConfirmationDialog(
        title: '모임 나가기',
        content: '정말 이 모임을 나가시겠습니까?\n나간 이후에는 참여자 명단에서 제외됩니다.',
        confirmText: '나가기',
        onConfirm: () async {
          final success = await context.read<MeetupProvider>().leaveMeetup(
            widget.meetup.id,
          );
          if (success && mounted) {
            toastification.show(
              context: context,
              type: ToastificationType.success,
              alignment: Alignment.bottomCenter,
              autoCloseDuration: const Duration(seconds: 2),
              title: const Text('모임에서 나갔습니다.'),
            );
            navigator.popUntil(
              (route) =>
                  route.settings.name == 'MeetupDetailPage' || route.isFirst,
            );
          }
        },
      ),
    );
  }
}
