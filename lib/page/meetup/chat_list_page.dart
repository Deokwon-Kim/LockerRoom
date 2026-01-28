import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/model/meetup_model.dart';
import 'package:lockerroom/page/meetup/chat_room_page.dart';
import 'package:lockerroom/provider/chat_provider.dart';
import 'package:lockerroom/provider/meetup_provider.dart';
import 'package:lockerroom/provider/team_provider.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

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
        final readData = readSnapshot.data?.data() as Map<String, dynamic>?;
        final lastReadAt = readData?['lastReadAt'] as Timestamp?;

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
          builder: (context, msgSnapshot) {
            final docs = msgSnapshot.data?.docs ?? [];
            int unreadCount = docs
                .where(
                  (doc) =>
                      (doc.data() as Map<String, dynamic>)['authorId'] !=
                      currentUserId,
                )
                .length;

            return ListTile(
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
                  if (meetup.lastMessageAt != null)
                    Text(
                      _formatChatTime(meetup.lastMessageAt),
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
                      meetup.lastMessage ?? '대화 내용이 없습니다.',
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
            );
          },
        );
      },
    );
  }
}
