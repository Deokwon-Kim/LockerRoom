import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/scheduler.dart';
import 'package:intl/intl.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/model/meetup_model.dart';
import 'package:lockerroom/model/user_model.dart';
import 'package:lockerroom/page/alert/confirm_diallog.dart';
import 'package:lockerroom/page/meetup/poll_detail_page.dart';
import 'package:lockerroom/provider/chat_provider.dart';
import 'package:lockerroom/provider/meetup_provider.dart';
import 'package:lockerroom/provider/team_provider.dart';
import 'package:lockerroom/provider/user_provider.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:toastification/toastification.dart';

class ChatRoomPage extends StatefulWidget {
  final String meetupId;
  final String meetupTitle;
  final MeetupModel meetup;

  const ChatRoomPage({
    super.key,
    required this.meetupId,
    required this.meetupTitle,
    required this.meetup,
  });

  @override
  State<ChatRoomPage> createState() => _ChatRoomPageState();
}

class _ChatRoomPageState extends State<ChatRoomPage> {
  late types.User _user;
  late InMemoryChatController _chatController;
  Message? _replyMessage;
  Message? _editingMessage;
  final TextEditingController _textController = TextEditingController();
  List<Message> _serverMessages = [];
  final List<Message> _pendingMessages = [];
  List<UserModel> _participantsInfos = [];
  MeetupModel? _latestMeetup;

  StreamSubscription? _meetupSubscription;
  StreamSubscription? _messagesSubscription;
  StreamSubscription? _participantsSubscription;

  @override
  void initState() {
    super.initState();
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    _user = types.User(id: currentUserId);
    _chatController = InMemoryChatController();

    // 부모 위젯 빌드 완료 후 시스템 메시지 전송 (중복 전송 방지를 위해 프레임 대기)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final userProvider = context.read<UserProvider>();
      final myNickName =
          userProvider.nickname ??
          FirebaseAuth.instance.currentUser?.displayName ??
          '누군가';

      context.read<ChatProvider>().sendEntryMessageOnce(
        widget.meetupId,
        _user.id,
        myNickName,
      );
    });

    // 메시지 스트림 구독 시작
    // 메시지 스트림 구독 시작
    _messagesSubscription = context
        .read<ChatProvider>()
        .getMessagesStream(widget.meetupId)
        .listen((messages) {
          if (mounted) {
            _serverMessages = messages.map(_convertMessage).toList();
            _updateDisplayMessages();
          }
        });
    _loadParticipantInfos();

    _setupParticipantsListener();
    _setupMeetupListener();
  }

  void _setupMeetupListener() {
    _meetupSubscription = context
        .read<MeetupProvider>()
        .getMeetupStream(widget.meetupId)
        .listen((updated) {
          if (updated != null && mounted) {
            setState(() {
              _latestMeetup = updated;
            });
          }
        });
  }

  void _setupParticipantsListener() {
    _participantsSubscription = context
        .read<MeetupProvider>()
        .getChatParticipantIdsStream(widget.meetupId)
        .listen((ids) async {
          final infos = await context
              .read<MeetupProvider>()
              .getParticipantsInfo(ids);
          if (mounted) {
            setState(() {
              _participantsInfos = infos;
            });
          }
        });
  }

  Future<void> _loadParticipantInfos() async {
    final meetupProvider = context.read<MeetupProvider>();

    final latestMeetup = await meetupProvider.getMeetupById(widget.meetupId);
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
    _participantsSubscription?.cancel();
    _messagesSubscription?.cancel();
    _chatController.dispose();
    _textController.dispose();
    _meetupSubscription?.cancel();
    super.dispose();
  }

  void _updateDisplayMessages() {
    if (!mounted) return;

    final allMessages = [..._serverMessages, ..._pendingMessages];

    final ids = <String>{};
    final uniqueMessages = allMessages.where((m) => ids.add(m.id)).toList();

    uniqueMessages.sort((a, b) {
      final aTime = a.createdAt?.millisecondsSinceEpoch ?? 0;
      final bTime = b.createdAt?.millisecondsSinceEpoch ?? 0;
      return aTime.compareTo(bTime);
    });

    // 메시지 업데이트 시 컨트롤러를 재생성하여 SliverAnimatedList 에러 방지
    _chatController.dispose();
    _chatController = InMemoryChatController();
    _chatController.setMessages(uniqueMessages);

    if (mounted) setState(() {});
  }

  void _handleSendPressed(String text) {
    if (_editingMessage != null) {
      final oldMessage = _editingMessage!;
      // 1. Firestore 업데이트 시작
      context.read<ChatProvider>().updateMessage(
        widget.meetupId,
        oldMessage.id,
        text,
      );

      // 2. 로컬 컨트롤러 즉시 업데이트 (Optimistic UI)
      if (oldMessage is TextMessage) {
        final newMessage = oldMessage.copyWith(
          text: text,
          updatedAt: DateTime.now(),
        );
        _chatController.updateMessage(oldMessage, newMessage);
      }

      setState(() {
        _editingMessage = null;
      });
      _textController.clear();
      return;
    }

    final textMessage = types.TextMessage(
      author: _user,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      id: '',
      text: text,
      metadata: _replyMessage != null
          ? {
              'replyToId': _replyMessage!.id,
              'replyText': _replyMessage is TextMessage
                  ? (_replyMessage as TextMessage).text
                  : '이미지',
              'replyAuthorId': _replyMessage!.authorId,
            }
          : null,
    );
    context.read<ChatProvider>().sendMessage(widget.meetupId, textMessage);
    setState(() {
      _replyMessage = null;
    });
    _textController.clear();
  }

  // 카메라로 바로 전송
  void _handleCameraSend() async {
    final chatProvider = context.read<ChatProvider>();
    final imageResult = await ImagePicker().pickImage(
      source: ImageSource.camera,
    );
    if (imageResult != null) {
      final file = File(imageResult.path);

      // 즉시 화면에 보여주기 위한 임시 메시지 생성 (Optimistic UI)
      final tempMessage = Message.image(
        id: 'temp-${file.path.hashCode}',
        authorId: _user.id,
        source: file.path,
        size: file.lengthSync(),
        createdAt: DateTime.now(),
        metadata: {'isLocal': true},
      );

      setState(() {
        _pendingMessages.add(tempMessage);
        _updateDisplayMessages();
      });

      // 실제 업로드 시작 (단일 파일을 리스트로 감싸서 전달)
      try {
        await chatProvider.sendImageMessages(widget.meetupId, _user.id, [file]);
      } catch (e) {
        debugPrint('카메라 업로드 실패: $e');
      } finally {
        if (mounted) {
          _pendingMessages.remove(tempMessage);
          _updateDisplayMessages();
        }
      }
    }
  }

  // 이미지 선택 및 전송
  void _handleImageSelection() async {
    final chatProvider = context.read<ChatProvider>();
    final result = await ImagePicker().pickMultiImage(limit: 4);
    if (result.isNotEmpty) {
      final files = result.map((res) => File(res.path)).toList();

      // 즉시 화면에 보여주기 위한 임시 메시지 생성
      final tempMessages = files.map((file) {
        return Message.image(
          id: 'temp-${file.path.hashCode}',
          authorId: _user.id,
          source: file.path,
          size: file.lengthSync(),
          createdAt: DateTime.now(),
          metadata: {'isLocal': true},
        );
      }).toList();

      _pendingMessages.addAll(tempMessages);
      _updateDisplayMessages();

      // 실제 업로드 시작
      try {
        await chatProvider.sendImageMessages(widget.meetupId, _user.id, files);
      } catch (e) {
        debugPrint('업로드 실패: $e');
      } finally {
        // 업로드 완료 후 임시 메시지 제거
        if (mounted) {
          _pendingMessages.removeWhere((m) => tempMessages.contains(m));
          _updateDisplayMessages();
        }
      }
    }
  }

  void _handlePollCreate(String question, List<String> options) {
    final Map<String, List<String>> initialVotes = {
      for (var opt in options) opt: [],
    };

    // 로컬에 즉시 보여주기 위한 임시 메시지 생성 (Optimistic UI)
    final tempPollMessage = types.CustomMessage(
      author: types.User(id: _user.id),
      id: 'temp-${DateTime.now().millisecondsSinceEpoch}',
      createdAt: DateTime.now().millisecondsSinceEpoch,
      metadata: {
        'question': question,
        'options': options,
        'votes': initialVotes,
        'isLocal': true,
      },
    );

    setState(() {
      _pendingMessages.add(_convertMessage(tempPollMessage));
      _updateDisplayMessages();
    });

    // 백그라운드에서 Firebase에 저장
    context.read<ChatProvider>().sendPollMessage(
      widget.meetupId,
      _user.id,
      question,
      options,
    );
  }

  void _showAttachmentMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: WHITE,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
        height: 150,
        child: GridView.count(
          crossAxisCount: 3,
          mainAxisSpacing: 20,
          children: [
            _buildMenuIcon(
              Icons.camera_alt,
              '카메라',
              const Color(0xFF4A90E2),
              _handleCameraSend,
            ),
            _buildMenuIcon(
              Icons.image,
              '사진',
              const Color(0xFF7ED321),
              _handleImageSelection,
            ),
            _buildMenuIcon(
              Icons.how_to_vote,
              '투표',
              const Color(0xFFF5A623),
              _showPollCreateSheet,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuIcon(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Icon(icon, color: WHITE, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: GRAYSCALE_LABEL_700),
          ),
        ],
      ),
    );
  }

  void _showPollCreateSheet() {
    final questionController = TextEditingController();
    final optionControllers = [
      TextEditingController(),
      TextEditingController(),
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '투표 만들기',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: questionController,
                decoration: const InputDecoration(
                  hintText: '질문을 입력하세요',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 15),
              ...optionControllers.asMap().entries.map((entry) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: TextField(
                    controller: entry.value,
                    decoration: InputDecoration(
                      hintText: '항목 ${entry.key + 1}',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                );
              }),
              if (optionControllers.length < 5)
                TextButton.icon(
                  onPressed: () => setSheetState(() {
                    optionControllers.add(TextEditingController());
                  }),
                  icon: const Icon(Icons.add),
                  label: const Text('항목 추가'),
                ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        context.read<TeamProvider>().selectedTeam?.color ??
                        ORANGE_PRIMARY_500,
                    foregroundColor: WHITE,
                  ),
                  onPressed: () {
                    final question = questionController.text.trim();
                    final options = optionControllers
                        .map((c) => c.text.trim())
                        .where((t) => t.isNotEmpty)
                        .toList();

                    if (question.isNotEmpty && options.length >= 2) {
                      Navigator.pop(context);
                      _handlePollCreate(question, options);
                    }
                  },
                  child: const Text('등록하기'),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // types.Message를 core.Message로 변환
  Message _convertMessage(types.Message typesMsg) {
    if (typesMsg is types.TextMessage) {
      return Message.text(
        id: typesMsg.id,
        authorId: typesMsg.author.id,
        text: typesMsg.text,
        createdAt: DateTime.fromMillisecondsSinceEpoch(typesMsg.createdAt ?? 0),
        updatedAt: typesMsg.updatedAt != null
            ? DateTime.fromMillisecondsSinceEpoch(typesMsg.updatedAt!)
            : null,
        metadata: typesMsg.metadata,
      );
    } else if (typesMsg is types.ImageMessage) {
      return Message.image(
        id: typesMsg.id,
        authorId: typesMsg.author.id,
        source: typesMsg.uri,
        size: typesMsg.size.toInt(),
        createdAt: DateTime.fromMillisecondsSinceEpoch(typesMsg.createdAt ?? 0),
        updatedAt: typesMsg.updatedAt != null
            ? DateTime.fromMillisecondsSinceEpoch(typesMsg.updatedAt!)
            : null,
        metadata: typesMsg.metadata,
      );
    } else if (typesMsg is types.CustomMessage) {
      return Message.text(
        id: typesMsg.id,
        authorId: typesMsg.author.id,
        text: '',
        createdAt: DateTime.fromMillisecondsSinceEpoch(typesMsg.createdAt ?? 0),
        updatedAt: typesMsg.updatedAt != null
            ? DateTime.fromMillisecondsSinceEpoch(typesMsg.updatedAt!)
            : null,
        metadata: typesMsg.metadata,
      );
    }
    // 기본값으로 텍스트 메시지 반환
    return Message.text(
      id: typesMsg.id,
      authorId: typesMsg.author.id,
      text: '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(typesMsg.createdAt ?? 0),
      updatedAt: typesMsg.updatedAt != null
          ? DateTime.fromMillisecondsSinceEpoch(typesMsg.updatedAt!)
          : null,
      metadata: typesMsg.metadata,
    );
  }

  @override
  Widget build(BuildContext context) {
    final chatProvider = context.read<ChatProvider>();
    final selectedTeam = context.watch<TeamProvider>().selectedTeam;
    final meetup = _latestMeetup ?? widget.meetup;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.meetupTitle,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        backgroundColor: selectedTeam?.color,
        foregroundColor: WHITE,
        elevation: 0.5,
        scrolledUnderElevation: 0,
      ),
      endDrawer: Drawer(
        backgroundColor: BACKGROUND_COLOR,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(
                      top: 80,
                      left: 20,
                      right: 20,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${widget.meetup.homeTeam} vs ${widget.meetup.awayTeam}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: GRAYSCALE_LABEL_500,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          widget.meetupTitle,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildPictureGallery(),
                  Divider(height: 1, color: GRAYSCALE_LABEL_300),

                  // 대화 상대 목록
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Text(
                          '대화 상대',
                          style: TextStyle(
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
            _buildLeaveButton(),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildAnnouncementBar(meetup),
          Expanded(
            child: Chat(
              key: ValueKey(
                _serverMessages.length.toString() +
                    _serverMessages.map((m) => m.id).join() +
                    _serverMessages.map((m) => m.metadata.toString()).join(),
              ),
              currentUserId: _user.id,
              chatController: _chatController,
              resolveUser: (id) => chatProvider.resolveUser(id),
              onMessageSend: _handleSendPressed,
              onAttachmentTap: _showAttachmentMenu,
              onMessageLongPress:
                  (context, message, {required index, required details}) =>
                      _onMessageLongPress(message),
              decoration: BoxDecoration(
                color: selectedTeam?.color ?? WHITE,
                image: selectedTeam?.logoPath != null
                    ? DecorationImage(
                        image: AssetImage(selectedTeam!.logoPath),
                        alignment: const Alignment(0.0, -0.3),
                        opacity: 0.2, // 투명도를 조절하여 메시지 가독성 확보
                        fit: BoxFit.contain,
                      )
                    : null,
              ),
              theme: ChatTheme.light().copyWith(
                colors: ChatColors.light().copyWith(
                  primary: selectedTeam?.color ?? ORANGE_PRIMARY_500,
                ),
              ),
              builders: Builders(
                chatMessageBuilder:
                    (
                      context,
                      message,
                      index,
                      animation,
                      child, {
                      isRemoved,
                      required isSentByMe,
                      groupStatus,
                    }) {
                      final bool isSystem =
                          message.metadata?['isSystem'] == true;

                      if (isSystem) {
                        return Center(
                          child: Container(
                            margin: EdgeInsets.symmetric(vertical: 10),
                            padding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              (message as TextMessage).text,
                              style: TextStyle(fontSize: 12, color: BLACK),
                            ),
                          ),
                        );
                      }
                      bool showDateDivider = false;
                      final messages = _chatController.messages;
                      if (index == 0) {
                        showDateDivider = true;
                      } else if (index < messages.length) {
                        final previousMessage = messages[index - 1];
                        if (!_isSameDay(
                          message.createdAt ?? DateTime.now(),
                          previousMessage.createdAt ?? DateTime.now(),
                        )) {
                          showDateDivider = true;
                        }
                      }

                      return Dismissible(
                        key: ValueKey('dismissible_${message.id}'),
                        direction: DismissDirection.horizontal,
                        confirmDismiss: (direction) async {
                          setState(() {
                            _replyMessage = message;
                          });
                          return false;
                        },
                        background: Container(
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.only(left: 20),
                          child: const Icon(Icons.reply, color: WHITE),
                        ),
                        child: Column(
                          children: [
                            if (showDateDivider)
                              _buildDateDivider(
                                message.createdAt ?? DateTime.now(),
                              ),
                            ChatMessage(
                              message: message,
                              index: index,
                              animation: animation,
                              isRemoved: isRemoved,
                              groupStatus: groupStatus,
                              verticalPadding: 12,
                              verticalGroupedPadding: 10,
                              leadingWidget: isSentByMe
                                  ? _buildTimeWidget(message.createdAt)
                                  : null,
                              trailingWidget: !isSentByMe
                                  ? _buildTimeWidget(message.createdAt)
                                  : null,
                              headerWidget:
                                  (!isSentByMe &&
                                      (groupStatus?.isFirst != false))
                                  ? Padding(
                                      padding: const EdgeInsets.only(
                                        left: 12,
                                        bottom: 0,
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Avatar(
                                            userId: message.authorId,
                                            size: 35,
                                          ),
                                          SizedBox(width: 8),
                                          Transform.translate(
                                            offset: Offset(0, -5),
                                            child: Username(
                                              userId: message.authorId,
                                              style: TextStyle(
                                                color: WHITE,
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  : null,
                              topWidget: _buildReplySource(message, isSentByMe),
                              child: Padding(
                                padding: EdgeInsets.only(
                                  left: isSentByMe ? 5.0 : 40.0,
                                  right: isSentByMe ? 10.0 : 5.0,
                                ),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 2,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSentByMe
                                        ? Color(0xFFFBE54D)
                                        : WHITE,
                                    borderRadius: BorderRadius.only(
                                      topLeft: const Radius.circular(16),
                                      topRight: const Radius.circular(16),
                                      bottomLeft: Radius.circular(
                                        isSentByMe ? 16 : 4,
                                      ),
                                      bottomRight: Radius.circular(
                                        isSentByMe ? 4 : 16,
                                      ),
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: BLACK.withOpacity(0.1),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: child,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                textMessageBuilder:
                    (
                      context,
                      message,
                      index, {
                      required isSentByMe,
                      groupStatus,
                    }) {
                      // 텍스트 메시지이지만 metadata에 투표 정보가 있으면 투표 위젯 렌더링
                      if (message.metadata?['question'] != null) {
                        final metadata = message.metadata!;
                        return _buildPollPreview(
                          messageId: message.id,
                          question: metadata['question'] as String,
                          options: List<String>.from(metadata['options'] ?? []),
                          votes: Map<String, dynamic>.from(
                            metadata['votes'] ?? {},
                          ),
                          deadLine: metadata['deadLine'] as Timestamp?,
                        );
                      }

                      return SimpleTextMessage(
                        message: message,
                        index: index,
                        showTime: false,
                        sentBackgroundColor: Colors.transparent,
                        receivedBackgroundColor: Colors.transparent,
                        sentTextStyle: const TextStyle(
                          color: BLACK,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        receivedTextStyle: const TextStyle(
                          color: BLACK,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      );
                    },
                imageMessageBuilder:
                    (
                      context,
                      message,
                      index, {
                      required isSentByMe,
                      groupStatus,
                    }) {
                      final bool isLocal = message.metadata?['isLocal'] == true;
                      final teamProvider = context.read<TeamProvider>();
                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 200,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: isLocal
                                  ? Image.file(
                                      File(message.source),
                                      fit: BoxFit.cover,
                                      cacheWidth: 400,
                                    )
                                  : Image.network(
                                      message.source,
                                      fit: BoxFit.cover,
                                      cacheWidth: 400,
                                      loadingBuilder:
                                          (context, child, loadingProgress) {
                                            if (loadingProgress == null)
                                              return child;
                                            return Center(
                                              child: CircularProgressIndicator(
                                                color: teamProvider
                                                    .selectedTeam
                                                    ?.color,
                                              ),
                                            );
                                          },
                                    ),
                            ),
                          ),
                          if (isLocal)
                            Container(
                              width: 200,
                              height: 150,
                              color: Colors.black26,
                              child: Center(
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                composerBuilder: (context) => Theme(
                  data: Theme.of(context).copyWith(
                    textSelectionTheme: TextSelectionThemeData(
                      cursorColor: selectedTeam?.color ?? ORANGE_PRIMARY_500,
                      selectionColor:
                          (selectedTeam?.color ?? ORANGE_PRIMARY_500)
                              .withOpacity(0.3),
                      selectionHandleColor:
                          selectedTeam?.color ?? ORANGE_PRIMARY_500,
                    ),
                  ),
                  child: Composer(
                    textEditingController: _textController,
                    hintText: '메시지를 입력하세요',
                    backgroundColor: WHITE,
                    attachmentIcon: const Icon(Icons.add, color: BLACK),
                    sendIconColor: selectedTeam?.color ?? ORANGE_PRIMARY_500,
                    topWidget: _editingMessage != null
                        ? _buildEditPreview()
                        : (_replyMessage != null ? _buildReplyPreview() : null),
                  ),
                ),
                emptyChatListBuilder: (context) => const EmptyChatList(
                  text: '아직 메시지가 없습니다',
                  textStyle: TextStyle(
                    color: WHITE,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateDivider(DateTime date) {
    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Row(
        children: [
          const Expanded(child: Divider(color: GRAYSCALE_LABEL_300)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              DateFormat('yyyy년 MM월 dd일 (E)', 'ko').format(date),
              style: const TextStyle(
                color: WHITE,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const Expanded(child: Divider(color: GRAYSCALE_LABEL_300)),
        ],
      ),
    );
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  void _onMessageLongPress(Message message) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        actions: [
          if (message is TextMessage)
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(context);
                context.read<MeetupProvider>().updateAnnouncement(
                  widget.meetupId,
                  {
                    'text': message.text,
                    'id': message.id,
                    'authorId': message.authorId,
                  },
                );
              },
              child: Text('공지 등록', style: TextStyle(color: BLACK)),
            ),

          if (message.authorId == _user.id) ...[
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(context);
                final coreMessage = _chatController.messages.firstWhere(
                  (m) => m.id == message.id,
                );
                if (coreMessage is TextMessage) {
                  setState(() {
                    _editingMessage = coreMessage;
                    _textController.text = coreMessage.text;
                  });
                }
              },
              child: const Text('수정', style: TextStyle(color: BLACK)),
            ),
            CupertinoActionSheetAction(
              isDestructiveAction: true,
              onPressed: () {
                Navigator.pop(context);
                _showDeleteConfirmDialog(message.id);
              },
              child: const Text('삭제'),
            ),
          ],
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소', style: TextStyle(color: BLACK)),
        ),
      ),
    );
  }

  void _showDeleteConfirmDialog(String messageId) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('메시지 삭제'),
        content: const Text('이 메시지를 삭제하시겠습니까?'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(context);
              context.read<ChatProvider>().deleteMessage(
                widget.meetupId,
                messageId,
              );
            },
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }

  Widget _buildEditPreview() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: WHITE,
        border: Border(top: BorderSide(color: GRAYSCALE_LABEL_300, width: 0.5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.edit, size: 20, color: ORANGE_PRIMARY_500),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              '메시지 수정 중...',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: ORANGE_PRIMARY_500,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20, color: GRAYSCALE_LABEL_500),
            onPressed: () {
              setState(() {
                _editingMessage = null;
                _textController.clear();
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTimeWidget(DateTime? time) {
    if (time == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        DateFormat('HH:mm').format(time),
        style: const TextStyle(color: WHITE, fontSize: 10),
      ),
    );
  }

  Widget _buildReplyPreview() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: WHITE,
        border: Border(top: BorderSide(color: GRAYSCALE_LABEL_300, width: 0.5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.reply, size: 20, color: GRAYSCALE_LABEL_500),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '답장 보내는 중...',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: ORANGE_PRIMARY_500,
                  ),
                ),
                Text(
                  _replyMessage is TextMessage
                      ? (_replyMessage as TextMessage).text
                      : '이미지 메시지',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: GRAYSCALE_LABEL_500,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20, color: GRAYSCALE_LABEL_500),
            onPressed: () => setState(() => _replyMessage = null),
          ),
        ],
      ),
    );
  }

  Widget? _buildReplySource(Message message, bool isSentByMe) {
    final replyToId = message.metadata?['replyToId'];
    if (replyToId == null) return null;

    final replyText = message.metadata?['replyText'] ?? '';
    final replyAuthorId = message.metadata?['replyAuthorId'];

    return GestureDetector(
      onTap: () {
        _chatController.scrollToMessage(replyToId);
      },
      child: Padding(
        padding: const EdgeInsets.only(top: 10, left: 5, bottom: 6),
        child: Column(
          crossAxisAlignment: isSentByMe
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isSentByMe)
                  Text('회원', style: TextStyle(color: WHITE, fontSize: 10))
                else if (replyAuthorId != null)
                  Username(
                    userId: replyAuthorId,
                    style: TextStyle(color: WHITE, fontSize: 10),
                  ),
                Text('님이 보낸 답장', style: TextStyle(color: WHITE, fontSize: 10)),
              ],
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(isSentByMe ? 16 : 4),
                border: isSentByMe
                    ? null
                    : const Border(
                        left: BorderSide(color: GRAYSCALE_LABEL_300, width: 3),
                      ),
              ),
              child: Text(
                replyText,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: BLACK, fontSize: 11),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 사진 가로 스크롤 위젯
  Widget _buildPictureGallery() {
    final allImages = [
      ..._serverMessages,
      ..._pendingMessages,
    ].whereType<ImageMessage>().take(5).toList();

    if (allImages.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Text(
            '사진 모아보기',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: GRAYSCALE_LABEL_500,
            ),
          ),
        ),
        SizedBox(
          height: 100,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: allImages.length,
            itemBuilder: (context, index) {
              final msg = allImages[index];
              final bool isLocal =
                  msg.metadata?['isLocal'] == true ||
                  msg.source.startsWith('/');

              return Padding(
                padding: const EdgeInsets.all(4),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: isLocal
                      ? Image.file(
                          File(msg.source),
                          width: 100,
                          height: 100,
                          fit: BoxFit.cover,
                        )
                      : Image.network(
                          msg.source,
                          width: 100,
                          height: 100,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(
                                width: 100,
                                height: 100,
                                color: Colors.grey[200],
                                child: const Icon(Icons.broken_image, size: 20),
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

    return ListTile(
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
          Text(user.userNickName),
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
    );
  }

  // 나가기 버튼
  Widget _buildLeaveButton() {
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
        child: Row(
          children: [
            const Icon(Icons.logout, color: GRAYSCALE_LABEL_500, size: 20),
            const SizedBox(width: 10),
            const Text(
              '채팅방 나가기',
              style: TextStyle(
                color: GRAYSCALE_LABEL_500,
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
        title: '채팅방 나가기',
        content: '정말 이 채팅방에서 나가시겠습니까?\n나간 이후에는 다시 참여해야 대화가 가능합니다.',
        confirmText: '나가기',
        onConfirm: () async {
          final success = await context.read<MeetupProvider>().leaveMeetup(
            widget.meetup.id,
          );
          if (success && mounted) {
            navigator.pop();
            navigator.pop();
          }
        },
      ),
    );
  }

  Widget _buildAnnouncementBar(MeetupModel? meetup) {
    if (meetup?.noticeMessageId == null) return const SizedBox.shrink();

    // 공지 메시지 찾기
    Message? noticeMessage;
    // 1. 서버 메시지에서 찾기
    try {
      noticeMessage = _serverMessages.firstWhere(
        (m) => m.id == meetup!.noticeMessageId,
      );
    } catch (_) {}

    // 2. 없으면 pending에서 찾기
    if (noticeMessage == null) {
      try {
        noticeMessage = _pendingMessages.firstWhere(
          (m) => m.id == meetup!.noticeMessageId,
        );
      } catch (_) {}
    }

    if (noticeMessage == null) return const SizedBox.shrink();

    // 메시지 내용 추출
    String content = '';
    bool isPoll = false;

    // 투표 메시지인지 확인 (metadata에 question이 있는지)
    if (noticeMessage.metadata?['question'] != null) {
      isPoll = true;
      final questionText = noticeMessage.metadata!['question'];
      content = '[투표] $questionText';
      print('DEBUG: Poll notice - question: $questionText'); // 디버깅용
    } else {
      // 텍스트 메시지 처리 - dynamic으로 접근하여 text 속성 확인
      try {
        if (noticeMessage is types.TextMessage) {
          content = (noticeMessage as types.TextMessage).text;
        } else {
          // types.TextMessage가 아닌 경우, dynamic으로 text 속성에 접근 시도
          final dynamic msg = noticeMessage;
          if (msg.text != null) {
            content = msg.text;
          } else {
            content = '[메시지]';
          }
        }
      } catch (e) {
        print('DEBUG: Failed to extract text - ${noticeMessage.runtimeType}');
        content = '[알 수 없는 메시지]';
      }
    }

    print('DEBUG: Announcement content: $content, isPoll: $isPoll'); // 디버깅용

    return InkWell(
      onTap: () {
        if (isPoll && noticeMessage?.metadata?['question'] != null) {
          // 투표인 경우 PollDetailPage로 이동
          final metadata = noticeMessage!.metadata!;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PollDetailPage(
                meetupId: widget.meetupId,
                messageId: noticeMessage!.id,
                question: metadata['question'] as String,
                options: List<String>.from(metadata['options'] ?? []),
                votes: Map<String, dynamic>.from(metadata['votes'] ?? {}),
                deadLine: metadata['deadLine'] as Timestamp?,
              ),
            ),
          );
        }
        // 일반 메시지는 스크롤 기능을 현재 지원하지 않음
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: WHITE.withOpacity(0.95),
          border: Border(
            bottom: BorderSide(color: GRAYSCALE_LABEL_300, width: 0.5),
          ),
        ),
        child: Row(
          children: [
            Icon(
              isPoll ? Icons.how_to_vote : Icons.campaign,
              color: ORANGE_PRIMARY_500,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                content,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: BLACK,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            IconButton(
              padding: EdgeInsets.zero,
              constraints: BoxConstraints(),
              onPressed: () => context.read<MeetupProvider>().clearAnnouncement(
                widget.meetupId,
              ),
              icon: Icon(Icons.close, size: 18, color: GRAYSCALE_LABEL_500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPollPreview({
    required String messageId,
    required String question,
    required List<String> options,
    required Map<String, dynamic> votes,
    required Timestamp? deadLine,
  }) {
    final now = DateTime.now();
    final endTime = deadLine?.toDate() ?? now;
    final isExpired = now.isAfter(endTime);
    final remainingTime = endTime.difference(now);

    int totalVotes = 0;
    votes.forEach((key, value) {
      totalVotes += (value as List).length;
    });

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PollDetailPage(
              meetupId: widget.meetupId,
              messageId: messageId,
              question: question,
              options: options,
              votes: votes,
              deadLine: deadLine,
            ),
          ),
        );
      },
      child: Container(
        width: 250,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: WHITE,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.how_to_vote, color: BLACK, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    question,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: BLACK,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // 옵션 리스트 표시 (상위 3개만 표시하거나 전체 표시)
            ...options.map((option) {
              final voters = votes[option] ?? [];
              final percent = totalVotes > 0
                  ? (voters.length / totalVotes).toDouble()
                  : 0.0;
              final isMyVote = voters.contains(_user.id);
              final selectedTeam = context.read<TeamProvider>().selectedTeam;
              final teamColor = selectedTeam?.color ?? ORANGE_PRIMARY_500;

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          option,
                          style: TextStyle(
                            fontSize: 13,
                            color: isMyVote ? teamColor : BLACK,
                            fontWeight: isMyVote
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        Text(
                          '${voters.length}명',
                          style: const TextStyle(
                            fontSize: 11,
                            color: GRAYSCALE_LABEL_500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: percent,
                        minHeight: 6,
                        backgroundColor: GRAYSCALE_LABEL_50,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isMyVote ? teamColor : GRAYSCALE_LABEL_300,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
            const Divider(height: 20),
            Text(
              '총 $totalVotes명 참여',
              style: const TextStyle(fontSize: 13, color: GRAYSCALE_LABEL_500),
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  isExpired ? Icons.lock : Icons.timer,
                  size: 14,
                  color: isExpired ? GRAYSCALE_LABEL_400 : ORANGE_PRIMARY_500,
                ),
                SizedBox(width: 4),
                Text(
                  isExpired ? '마감됨' : _formatRemaining(remainingTime),
                  style: TextStyle(
                    fontSize: 12,
                    color: isExpired ? GRAYSCALE_LABEL_400 : ORANGE_PRIMARY_500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatRemaining(Duration duration) {
    if (duration.inHours > 0) {
      return '${duration.inHours}시간 남음';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}분 남음';
    } else {
      return '곧 마감';
    }
  }
}
