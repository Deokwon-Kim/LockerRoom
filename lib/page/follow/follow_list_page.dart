import 'package:contained_tab_bar_view/contained_tab_bar_view.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/page/follow/follower_list_page.dart';
import 'package:lockerroom/page/follow/following_list_page.dart';
import 'package:lockerroom/provider/follow_provider.dart';
import 'package:lockerroom/provider/team_provider.dart';
import 'package:provider/provider.dart';

class FollowListPage extends StatefulWidget {
  final String userId;
  const FollowListPage({super.key, required this.userId});

  @override
  State<FollowListPage> createState() => _FollowListPageState();
}

class _FollowListPageState extends State<FollowListPage> {
  @override
  Widget build(BuildContext context) {
    final userName = FirebaseAuth.instance.currentUser?.displayName;
    final teamProvider = context.watch<TeamProvider>();
    final selectedTeam = teamProvider.selectedTeam?.color;
    final fp = context.watch<FollowProvider>();
    return Scaffold(
      backgroundColor: BACKGROUND_COLOR,
      appBar: AppBar(
        backgroundColor: BACKGROUND_COLOR,
        title: Text(
          userName!,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
      ),
      body: Expanded(
        child: Container(
          decoration: BoxDecoration(
            color: BACKGROUND_COLOR,
            borderRadius: BorderRadius.circular(10),
          ),
          child: ContainedTabBarView(
            tabs: [
              StreamBuilder<int>(
                stream: fp.getFollowersCountStream(widget.userId),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return CircularProgressIndicator();
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
                  if (!snapshot.hasData) return CircularProgressIndicator();
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
              indicatorColor: selectedTeam,
              indicatorSize: TabBarIndicatorSize.tab,
              indicatorWeight: 3.0,
              unselectedLabelColor: GRAYSCALE_LABEL_500,
            ),
            views: [FollowerListPage(), FollowingListPage()],
            onChange: (index) => print(index),
          ),
        ),
      ),
    );
  }
}
