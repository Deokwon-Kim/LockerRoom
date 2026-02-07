import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/model/meetup_model.dart';
import 'package:lockerroom/page/meetup/chat_room_page.dart';
import 'package:lockerroom/provider/chat_provider.dart';
import 'package:lockerroom/provider/meetup_provider.dart';
import 'package:lockerroom/provider/team_provider.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:lockerroom/page/alert/confirm_diallog.dart';

class ChatListPage extends StatelessWidget {
  const ChatListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final teamProvider = context.read<TeamProvider>();
    return Scaffold(
      backgroundColor: BACKGROUND_COLOR,
      appBar: AppBar(
        backgroundColor: BACKGROUND_COLOR,
        foregroundColor: BLACK,
        scrolledUnderElevation: 0,
        title: Text(
          '채팅',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<List<MeetupModel>>(
        stream: context.read<MeetupProvider>().getJoinedMeetupStream(
          currentUserId,
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(
                color: teamProvider.selectedTeam?.color,
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Text(
                '참가 중인 채팅방이 없습니다.',
                style: TextStyle(color: GRAYSCALE_LABEL_400),
              ),
            );
          }
          final meetups = snapshot.data!;

          return ListView.builder(
            itemCount: meetups.length,
            itemBuilder: (context, index) {
              return ChatListItem(
                meetup: meetups[index],
                currentUserId: currentUserId,
              );
            },
          );
        },
      ),
    );
  }
}

class ChatListItem extends StatelessWidget {
  final MeetupModel meetup;
  final String currentUserId;
  const ChatListItem({
    super.key,
    required this.meetup,
    required this.currentUserId,
  });

  String _formatChatTime(String? isoString) {
    if (isoString == null) return '';
    try {
      final dateTime = DateTime.parse(isoString);
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inDays == 0) {
        return DateFormat('a h:mm', 'ko_KR').format(dateTime);
      } else if (difference.inDays == 1) {
        return '어제';
      } else if (difference.inDays < 7) {
        return DateFormat('E', 'ko_KR').format(dateTime);
      } else {
        return DateFormat('M월 d일', 'ko_KR').format(dateTime);
      }
    } catch (e) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .collection('readStatus')
          .doc(meetup.id)
          .snapshots(),
      builder: (context, readSnapshot) {
        if (readSnapshot.hasError) return const SizedBox.shrink();
        final readData = readSnapshot.data?.data() as Map<String, dynamic>?;
        final lastReadAt = readData?['lastReadAt'] as Timestamp?;

        // 1. 읽지 않은 메시지 카운트용 스트림
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('meetups')
              .doc(meetup.id)
              .collection('messages')
              .where(
                'createdAt',
                isGreaterThan:
                    lastReadAt ?? Timestamp.fromMillisecondsSinceEpoch(0),
              )
              .snapshots(),
          builder: (context, unreadSnapshot) {
            if (unreadSnapshot.hasError) return const SizedBox.shrink();
            final unreadDocs = unreadSnapshot.data?.docs ?? [];
            int unreadCount = unreadDocs
                .where(
                  (doc) =>
                      (doc.data() as Map<String, dynamic>)['authorId'] !=
                      currentUserId,
                )
                .length;

            // 2. 마지막 메시지 요약용 실시간 스트림 (삭제/수정 반영)
            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('meetups')
                  .doc(meetup.id)
                  .collection('messages')
                  .orderBy('createdAt', descending: true)
                  .limit(1)
                  .snapshots(),
              builder: (context, lastMsgSnapshot) {
                if (lastMsgSnapshot.hasError) return const SizedBox.shrink();
                String? displayMessage = meetup.lastMessage;
                String? displayTime = meetup.lastMessageAt;

                if (lastMsgSnapshot.hasData &&
                    lastMsgSnapshot.data!.docs.isNotEmpty) {
                  final lastMsgData =
                      lastMsgSnapshot.data!.docs.first.data()
                          as Map<String, dynamic>;
                  final type = lastMsgData['type'];

                  if (type == 'image') {
                    displayMessage = '사진을 보냈습니다.';
                  } else if (type == 'custom') {
                    displayMessage = '투표가 올라왔습니다.';
                  } else {
                    displayMessage = lastMsgData['text'] ?? '';
                  }

                  final createdAt = lastMsgData['createdAt'] as Timestamp?;
                  displayTime = createdAt?.toDate().toIso8601String();
                } else if (lastMsgSnapshot.hasData &&
                    lastMsgSnapshot.data!.docs.isEmpty) {
                  // 메시지가 하나도 없는 경우
                  displayMessage = '대화 내용이 없습니다.';
                  displayTime = null;
                }

                return Slidable(
                  key: ValueKey(meetup.id),
                  endActionPane: ActionPane(
                    motion: const ScrollMotion(),
                    children: [
                      SlidableAction(
                        onPressed: (context) {
                          showDialog(
                            context: context,
                            builder: (context) {
                              return ConfirmationDialog(
                                title: '채팅방 나가기',
                                content:
                                    '${meetup.title} 채팅방을 나가시겠습니까?\n채팅방에서 나가도 대화 내용은 유지됩니다.',
                                confirmText: '나가기',
                                confirmColor: Colors.red,
                                onConfirm: () async {
                                  await context
                                      .read<MeetupProvider>()
                                      .leaveMeetup(meetup.id);
                                },
                              );
                            },
                          );
                        },
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        icon: Icons.exit_to_app,
                        label: '나가기',
                      ),
                    ],
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    onTap: () {
                      context.read<ChatProvider>().markAsRead(
                        meetup.id,
                        currentUserId,
                      );

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatRoomPage(
                            meetupId: meetup.id,
                            meetupTitle: meetup.title,
                            meetup: meetup,
                          ),
                        ),
                      );
                    },
                    leading: CircleAvatar(
                      radius: 28,
                      backgroundColor: GRAYSCALE_LABEL_100,
                      backgroundImage: meetup.images.isNotEmpty
                          ? NetworkImage(meetup.images[0])
                          : null,
                      child: meetup.images.isEmpty
                          ? const Icon(Icons.groups, color: GRAYSCALE_LABEL_400)
                          : null,
                    ),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            meetup.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (displayTime != null)
                          Text(
                            _formatChatTime(displayTime),
                            style: const TextStyle(
                              color: GRAYSCALE_LABEL_400,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                    subtitle: Row(
                      children: [
                        Expanded(
                          child: Text(
                            displayMessage ?? '대화 내용이 없습니다.',
                            style: TextStyle(
                              color: GRAYSCALE_LABEL_600,
                              fontSize: 13,
                              fontWeight: unreadCount > 0
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (unreadCount > 0)
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              unreadCount > 99 ? '99+' : '$unreadCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
