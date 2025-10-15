import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/provider/notification_provider.dart';
import 'package:provider/provider.dart';
import 'package:lockerroom/provider/team_provider.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  @override
  void initState() {
    super.initState();
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<NotificationProvider>().listen(userId);
      });
    }
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _formatRelative(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inSeconds < 60) {
      return '방금 전';
    }
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}분 전';
    }
    if (diff.inHours < 24) {
      return '${diff.inHours}시간 전';
    }
    return '${diff.inDays}일 전';
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NotificationProvider>();
    final selectedColor =
        context.watch<TeamProvider>().selectedTeam?.color ?? BUTTON;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '알림',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
        backgroundColor: BACKGROUND_COLOR,
        foregroundColor: BLACK,
        elevation: 0,
      ),
      backgroundColor: BACKGROUND_COLOR,
      body: provider.isLoading
          ? Center(child: CircularProgressIndicator(color: selectedColor))
          : provider.notifications.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.notifications_none,
                    color: GRAYSCALE_LABEL_400,
                    size: 40,
                  ),
                  SizedBox(height: 8),
                  Text(
                    '새 알림이 없습니다',
                    style: TextStyle(color: GRAYSCALE_LABEL_500, fontSize: 14),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    itemCount: provider.notifications.length,
                    itemBuilder: (context, index) {
                      final n = provider.notifications[index];
                      final createdAt = n.createdAt ?? DateTime.now();
                      final bool showHeader = index == 0
                          ? true
                          : !_isSameDay(
                              createdAt,
                              (provider.notifications[index - 1].createdAt ??
                                  DateTime.now()),
                            );
                      return FutureBuilder<
                        DocumentSnapshot<Map<String, dynamic>>
                      >(
                        future: FirebaseFirestore.instance
                            .collection('users')
                            .doc(n.fromUserId)
                            .get(),
                        builder: (context, snap) {
                          final data = snap.data?.data() ?? {};
                          final fetchedName = (data['username'] as String?)
                              ?.trim();
                          final name =
                              (n.userName.isNotEmpty
                                      ? n.userName
                                      : (fetchedName ?? '...'))
                                  .trim();
                          final imageUrl =
                              (data['profileImage'] as String?) ?? '';

                          final tile = ListTile(
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 6,
                            ),
                            leading: CircleAvatar(
                              radius: 20,
                              backgroundColor: GRAYSCALE_LABEL_300,
                              backgroundImage: imageUrl.isNotEmpty
                                  ? NetworkImage(imageUrl)
                                  : null,
                              child: imageUrl.isEmpty
                                  ? Icon(
                                      Icons.person,
                                      color: GRAYSCALE_LABEL_500,
                                    )
                                  : null,
                            ),
                            title: RichText(
                              text: TextSpan(
                                style: TextStyle(color: BLACK, fontSize: 14),
                                children: [
                                  TextSpan(
                                    text: name,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  TextSpan(text: '님이 '),
                                  TextSpan(text: '회원님'),
                                  TextSpan(text: '을 '),
                                  TextSpan(text: '팔로우'),
                                  TextSpan(text: '하기 시작했습니다.'),
                                ],
                              ),
                            ),
                            subtitle: Text(
                              _formatRelative(createdAt),
                              style: TextStyle(
                                color: GRAYSCALE_LABEL_500,
                                fontSize: 12,
                              ),
                            ),
                          );

                          if (showHeader) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  child: Text(
                                    _formatRelative(createdAt),
                                    style: TextStyle(
                                      fontSize: 17,
                                      color: BLACK,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                tile,
                              ],
                            );
                          }
                          return tile;
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
