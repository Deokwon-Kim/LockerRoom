import 'package:flutter/material.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/provider/user_provider.dart';
import 'package:provider/provider.dart';

class Mypage extends StatefulWidget {
  const Mypage({super.key});

  @override
  State<Mypage> createState() => _MypageState();
}

class _MypageState extends State<Mypage> {
  @override
  void initState() {
    super.initState();
    // 페이지 로드 시 사용자 정보 새로고침
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<UserProvider>(context, listen: false).refreshUserInfo();
    });
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final userName =
        userProvider.nickname ?? userProvider.currentUser?.displayName ?? '사용자';

    // 디버깅용 출력
    print('UserProvider - nickname: ${userProvider.nickname}');
    print('UserProvider - currentUser: ${userProvider.currentUser?.uid}');
    print(
      'UserProvider - displayName: ${userProvider.currentUser?.displayName}',
    );
    print('UserProvider - email: ${userProvider.currentUser?.email}');
    print('Final userName: $userName');
    return Scaffold(
      backgroundColor: BACKGROUND_COLOR,
      appBar: AppBar(
        title: Text(
          '프로필',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: BLACK,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () {},
            icon: Icon(Icons.menu_rounded, color: BLACK),
          ),
        ],
        backgroundColor: BACKGROUND_COLOR,
      ),
      body: Padding(
        padding: const EdgeInsets.only(top: 20.0, left: 20.0, right: 20.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  userName,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                // 사용자 프로필 이미지
                ClipRRect(
                  borderRadius: BorderRadius.circular(50),
                  child: Container(
                    width: 70,
                    height: 70,
                    color: Colors.grey[300],
                    child: Icon(
                      Icons.person,
                      color: Colors.grey[600],
                      size: 30,
                    ),
                  ),
                ),
              ],
            ),
            ElevatedButton(
              onPressed: () async {
                await userProvider.signOut();
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  'signIn',
                  (route) => false,
                );
              },
              child: Text('로그아웃'),
            ),
          ],
        ),
      ),
    );
  }
}
