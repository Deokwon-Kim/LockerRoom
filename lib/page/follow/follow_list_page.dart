import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:contained_tab_bar_view/contained_tab_bar_view.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/page/follow/follower_list_page.dart';
import 'package:lockerroom/page/follow/following_list_page.dart';
import 'package:lockerroom/provider/follow_provider.dart';
import 'package:lockerroom/provider/user_provider.dart';
import 'package:provider/provider.dart';
import 'package:lockerroom/provider/team_provider.dart';

class FollowListPage extends StatefulWidget {
  final String userId;
  final int initialIndex;
  const FollowListPage({
    super.key,
    required this.userId,
    this.initialIndex = 0,
  });

  @override
  State<FollowListPage> createState() => _FollowListPageState();
}

class _FollowListPageState extends State<FollowListPage> {
  @override
  Widget build(BuildContext context) {
    final userName = FirebaseAuth.instance.currentUser?.displayName;
    final teamProvider = context.watch<TeamProvider>();
    final teamColor = teamProvider.selectedTeam?.color;
    final fp = context.watch<FollowProvider>();
    final isSelf = widget.userId == FirebaseAuth.instance.currentUser?.uid;
    return Scaffold(
      backgroundColor: BACKGROUND_COLOR,
      appBar: AppBar(
        backgroundColor: BACKGROUND_COLOR,
        title: isSelf
            ? Text(
                // 자신의 페이지면 UserProvider 닉네임 > Firebase DisplayName 우선
                context.watch<UserProvider>().nickname ?? (userName ?? '사용자'),
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              )
            : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(widget.userId)
                    .snapshots(),
                builder: (context, snap) {
                  if (!snap.hasData) {
                    return SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: teamColor,
                        strokeWidth: 2,
                      ),
                    );
                  }
                  final name =
                      snap.data!.data()?['username'] as String? ?? '사용자';
                  return Text(
                    name,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  );
                },
              ),
      ),
      body: Container(
        decoration: BoxDecoration(
          color: BACKGROUND_COLOR,
          borderRadius: BorderRadius.circular(10),
        ),
        child: ContainedTabBarView(
          initialIndex: widget.initialIndex,
          tabs: [
            StreamBuilder<int>(
              stream: fp.getFollowersCountStream(widget.userId),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  final color =
                      context.read<TeamProvider>().selectedTeam?.color ??
                      BUTTON;
                  return CircularProgressIndicator(color: color);
                }
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${snapshot.data}',
                      style: TextStyle(color: Colors.black),
                    ),
                    SizedBox(width: 5),
                    Text('팔로워', style: TextStyle(color: Colors.black)),
                  ],
                );
              },
            ),
            StreamBuilder<int>(
              stream: fp.getFollowCountStream(widget.userId),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  final color =
                      context.read<TeamProvider>().selectedTeam?.color ??
                      BUTTON;
                  return CircularProgressIndicator(color: color);
                }
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${snapshot.data}',
                      style: TextStyle(color: Colors.black),
                    ),
                    SizedBox(width: 5),
                    Text('팔로잉', style: TextStyle(color: Colors.black)),
                  ],
                );
              },
            ),
          ],
          tabBarProperties: TabBarProperties(
            indicatorColor: teamColor,
            indicatorSize: TabBarIndicatorSize.tab,
            indicatorWeight: 3.0,
            unselectedLabelColor: GRAYSCALE_LABEL_500,
          ),
          views: [
            FollowerListPage(userId: widget.userId),
            FollowingListPage(userId: widget.userId),
          ],
          onChange: (index) => print(index),
        ),
      ),
    );
  }
}
