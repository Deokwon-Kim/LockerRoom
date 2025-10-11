import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:contained_tab_bar_view/contained_tab_bar_view.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/model/post_model.dart';
import 'package:lockerroom/model/team_model.dart';
import 'package:lockerroom/my_post/user_market_post_page.dart';
import 'package:lockerroom/my_post/user_post_page.dart';
import 'package:lockerroom/page/follow/follow_list_page.dart';
import 'package:lockerroom/provider/feed_provider.dart';
import 'package:lockerroom/provider/follow_provider.dart';
import 'package:provider/provider.dart';
import 'package:lockerroom/provider/team_provider.dart';

class UserDetailPage extends StatefulWidget {
  final String userId;
  final PostModel? post;
  const UserDetailPage({super.key, required this.userId, this.post});

  @override
  State<UserDetailPage> createState() => _UserDetailPageState();
}

class _UserDetailPageState extends State<UserDetailPage> {
  String timeAgo(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inSeconds < 60) return '${diff.inSeconds}s 전';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    return '${diff.inDays}일 전';
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => context.read<FollowProvider>().loadFollowingStatus(widget.userId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final fp = context.watch<FollowProvider>();
    final tp = context.watch<TeamProvider>();
    final teamColor = tp.selectedTeam?.color;
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          final color =
              context.read<TeamProvider>().selectedTeam?.color ?? BUTTON;
          return Center(child: CircularProgressIndicator(color: color));
        }
        final data = snap.data!.data() ?? {};
        final name = (data['username'] as String?) ?? '';
        final teamName = data['team'] as String?;
        if (teamName == null || teamName.isEmpty)
          return const SizedBox.shrink();

        final teams = context.read<TeamProvider>().getTeam('team');
        TeamModel? teamModel;
        try {
          teamModel = teams.firstWhere(
            (t) => t.name == teamName || t.symplename == teamName,
          );
        } catch (_) {}
        final imageUrl = (data['profileImage'] as String?) ?? '';

        return Scaffold(
          backgroundColor: BACKGROUND_COLOR,
          appBar: AppBar(
            backgroundColor: BACKGROUND_COLOR,
            title: Row(
              children: [
                Transform.translate(
                  offset: Offset(-15, 0),
                  child: Text(
                    name,
                    style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
                  ),
                ),
                SizedBox(width: 5),
                Transform.translate(
                  offset: Offset(-15, 5),
                  child: Text(
                    teamName,
                    style: TextStyle(
                      color: teamModel?.color,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              if (currentUserId != widget.userId)
                Padding(
                  padding: const EdgeInsets.only(right: 16.0),
                  child: GestureDetector(
                    onTap: () {
                      fp.toggleFollow(widget.userId);
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 5, vertical: 5),
                      decoration: BoxDecoration(
                        color: fp.isFollowingUser(widget.userId)
                            ? BACKGROUND_COLOR
                            : teamColor,
                        border: Border.all(color: Colors.black),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        fp.isFollowingUser(widget.userId) ? '팔로잉' : '팔로우',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: fp.isFollowingUser(widget.userId)
                              ? Colors.black
                              : Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(15.0),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: GRAYSCALE_LABEL_300,
                      radius: 40,
                      backgroundImage: imageUrl.isNotEmpty
                          ? NetworkImage(imageUrl)
                          : null,
                      child: imageUrl.isEmpty
                          ? const Icon(Icons.person, color: Colors.black)
                          : null,
                    ),
                    SizedBox(width: 20),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 5),
                        Row(
                          children: [
                            StreamBuilder<List<PostModel>>(
                              stream: context
                                  .read<FeedProvider>()
                                  .listenUserPosts(widget.userId),
                              builder: (context, snapshot) {
                                final count =
                                    (snapshot.data ?? const []).length;
                                return Column(
                                  children: [Text('$count'), Text('게시물')],
                                );
                              },
                            ),

                            SizedBox(width: 50),
                            StreamBuilder<int>(
                              stream: fp.getFollowersCountStream(widget.userId),
                              builder: (context, snapshot) {
                                if (!snapshot.hasData) {
                                  final color =
                                      context
                                          .read<TeamProvider>()
                                          .selectedTeam
                                          ?.color ??
                                      BUTTON;
                                  return CircularProgressIndicator(
                                    color: color,
                                  );
                                }
                                return GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => FollowListPage(
                                          userId: widget.userId,
                                          initialIndex: 0,
                                        ),
                                      ),
                                    );
                                  },
                                  child: Column(
                                    children: [
                                      Text('${snapshot.data}'),
                                      Text("팔로워"),
                                    ],
                                  ),
                                );
                              },
                            ),
                            SizedBox(width: 50),
                            StreamBuilder<int>(
                              stream: fp.getFollowCountStream(widget.userId),
                              builder: (context, snapshot) {
                                if (!snapshot.hasData) {
                                  final color =
                                      context
                                          .read<TeamProvider>()
                                          .selectedTeam
                                          ?.color ??
                                      BUTTON;
                                  return CircularProgressIndicator(
                                    color: color,
                                  );
                                }
                                return GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => FollowListPage(
                                          userId: widget.userId,
                                          initialIndex: 1,
                                        ),
                                      ),
                                    );
                                  },
                                  child: Column(
                                    children: [
                                      Text('${snapshot.data}'),
                                      Text('팔로잉'),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(height: 10),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: BACKGROUND_COLOR,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: ContainedTabBarView(
                    tabs: [
                      Text('게시글', style: TextStyle(color: BLACK)),
                      Text('마켓', style: TextStyle(color: BLACK)),
                    ],
                    tabBarProperties: TabBarProperties(
                      indicatorColor: teamColor,
                      indicatorSize: TabBarIndicatorSize.tab,
                      indicatorWeight: 3.0,
                      unselectedLabelColor: GRAYSCALE_LABEL_500,
                    ),
                    views: [
                      UserPostPage(userId: widget.userId),
                      UserMarketPostPage(userId: widget.userId),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
