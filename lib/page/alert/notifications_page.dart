import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/provider/notification_provider.dart';
import 'package:provider/provider.dart';

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

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NotificationProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text('알림'),
        backgroundColor: BACKGROUND_COLOR,
        foregroundColor: BLACK,
        elevation: 0,
      ),
      backgroundColor: BACKGROUND_COLOR,
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: ListView.separated(
                    itemCount: provider.notifications.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final n = provider.notifications[index];
                      final isUnread = !n.isRead;
                      String title;
                      if (n.type == 'follow') {
                        title = '새로운 팔로워가 생겼습니다';
                      } else {
                        title = '알림';
                      }
                      return ListTile(
                        tileColor: isUnread ? GRAYSCALE_LABEL_50 : Colors.white,
                        title: Text(
                          title,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text('from: ${n.fromUserId}'),
                        trailing: isUnread
                            ? TextButton(
                                onPressed: () async {
                                  final userId =
                                      FirebaseAuth.instance.currentUser?.uid;
                                  if (userId != null) {
                                    await context
                                        .read<NotificationProvider>()
                                        .markAsRead(userId, n.id);
                                  }
                                },
                                child: const Text('읽음'),
                              )
                            : null,
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
