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
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    itemCount: provider.notifications.length,

                    itemBuilder: (context, index) {
                      final n = provider.notifications[index];
                      return FutureBuilder<
                        DocumentSnapshot<Map<String, dynamic>>
                      >(
                        future: FirebaseFirestore.instance
                            .collection('users')
                            .doc(n.fromUserId)
                            .get(),
                        builder: (context, snap) {
                          final data = snap.data?.data() ?? {};
                          final name = (data['username'] as String?) ?? '...';
                          final imageUrl =
                              (data['profileImage'] as String?) ?? '';

                          return ListTile(
                            subtitle: Row(
                              children: [
                                CircleAvatar(
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
                                SizedBox(width: 10),
                                Text(name),

                                Text(
                                  '님 이 회원님을 팔로우 하기 시작했습니다',
                                  style: TextStyle(color: Colors.black),
                                ),
                              ],
                            ),
                          );
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
