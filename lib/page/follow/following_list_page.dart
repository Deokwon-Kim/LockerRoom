import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/model/user_model.dart';
import 'package:lockerroom/page/myPage/user_detail_page.dart';
import 'package:lockerroom/provider/feed_provider.dart';
import 'package:lockerroom/provider/follow_provider.dart';
import 'package:provider/provider.dart';
import 'package:lockerroom/provider/team_provider.dart';

class FollowingListPage extends StatefulWidget {
  const FollowingListPage({super.key});

  @override
  State<FollowingListPage> createState() => _FollowingListPageState();
}

class _FollowingListPageState extends State<FollowingListPage> {
  final TextEditingController _searchController = TextEditingController();
  final targetUserId = FirebaseAuth.instance.currentUser!.uid;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BACKGROUND_COLOR,
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(10),
              child: TextFormField(
                controller: _searchController,
                cursorColor: BUTTON,
                cursorHeight: 18,
                minLines: 1,
                maxLines: 3,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
                enableIMEPersonalizedLearning: true,
                style: TextStyle(decoration: TextDecoration.none),
                onChanged: (value) => Provider.of<FeedProvider>(
                  context,
                  listen: false,
                ).setQuery(value),
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 10,
                  ),
                  labelText: '검색어를 입력해주세요',
                  labelStyle: TextStyle(color: Colors.grey, fontSize: 13),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: GRAYSCALE_LABEL_400),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: GRAYSCALE_LABEL_400),
                  ),
                ),
              ),
            ),
            SizedBox(height: 10),

            Expanded(
              child: StreamBuilder<List<UserModel>>(
                stream: context.read<FollowProvider>().followingUsers(
                  targetUserId,
                ),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    final color =
                        context.read<TeamProvider>().selectedTeam?.color ??
                        BUTTON;
                    return Center(
                      child: CircularProgressIndicator(color: color),
                    );
                  }
                  final users = snapshot.data!;
                  if (users.isEmpty)
                    return const Center(child: Text('팔로워가 없습니다'));
                  return ListView.builder(
                    itemCount: users.length,
                    itemBuilder: (_, i) {
                      final u = users[i];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: GRAYSCALE_LABEL_300,
                          backgroundImage: (u.profileImage?.isNotEmpty ?? false)
                              ? NetworkImage(u.profileImage!)
                              : null,
                          child: (u.profileImage?.isEmpty ?? true)
                              ? const Icon(Icons.person, color: Colors.black)
                              : null,
                        ),
                        title: Text(
                          u.username,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  UserDetailPage(targetUserId: u.uid),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
