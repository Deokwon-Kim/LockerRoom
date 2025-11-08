import 'package:flutter/material.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/model/post_model.dart';
import 'package:lockerroom/model/user_model.dart';
import 'package:lockerroom/page/myPage/user_detail_page.dart';
import 'package:lockerroom/provider/block_provider.dart';
import 'package:lockerroom/provider/follow_provider.dart';
import 'package:provider/provider.dart';
import 'package:lockerroom/provider/team_provider.dart';

class FollowerListPage extends StatefulWidget {
  final String userId;
  final PostModel? post;
  const FollowerListPage({super.key, required this.userId, this.post});

  @override
  State<FollowerListPage> createState() => _FollowerListPageState();
}

class _FollowerListPageState extends State<FollowerListPage> {
  final TextEditingController _searchController = TextEditingController();
  late FollowProvider _followProvider;
  BlockProvider? _blockProvider;
  VoidCallback? _blockListener;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _followProvider = context.read<FollowProvider>();
      _blockProvider = context.read<BlockProvider>();

      // 초기 동기화
      _followProvider.setBlockedUsers(_blockProvider!.blockedUserIds);

      // 차단 목록 변경 리스너
      _blockListener = () {
        if (mounted) {
          _followProvider.setBlockedUsers(_blockProvider!.blockedUserIds);
        }
      };
      _blockProvider!.addListener(_blockListener!);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    if (_blockListener != null && _blockProvider != null) {
      _blockProvider!.removeListener(_blockListener!);
    }
    super.dispose();
  }

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
                onChanged: (value) => Provider.of<FollowProvider>(
                  context,
                  listen: false,
                ).setUserSearchQuery(value),
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
            Text('모든팔로워'),
            SizedBox(height: 10),
            Expanded(
              child: StreamBuilder<List<UserModel>>(
                stream: context.read<FollowProvider>().followersUsers(
                  widget.userId,
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
                  final filltered = context.watch<FollowProvider>().filterUsers(
                    users,
                  );
                  return ListView.builder(
                    itemCount: filltered.length,
                    itemBuilder: (_, i) {
                      final u = filltered[i];
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
                          u.userNickName,
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
                                  UserDetailPage(userId: u.uid),
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
