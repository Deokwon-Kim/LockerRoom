import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/page/alert/diallog.dart';
import 'package:lockerroom/provider/profile_provider.dart';
import 'package:lockerroom/provider/user_provider.dart';
import 'package:provider/provider.dart';
import 'package:toastification/toastification.dart';

class Mypage extends StatelessWidget {
  const Mypage({super.key});

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final userName =
        userProvider.nickname ?? userProvider.currentUser?.displayName ?? '사용자';
    final userEmail =
        userProvider.email ?? userProvider.currentUser?.email ?? '정보없음';
    final profileProvider = Provider.of<ProfileProvider>(context);
    final user = FirebaseAuth.instance.currentUser;

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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      userName,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      userEmail,
                      style: TextStyle(
                        color: GRAYSCALE_LABEL_500,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                // 사용자 프로필 이미지
                if (profileProvider.isLoading)
                  const CircularProgressIndicator()
                else
                  CircleAvatar(
                    radius: 50,
                    backgroundImage: profileProvider.profileImageUrl != null
                        ? NetworkImage(profileProvider.profileImageUrl!)
                        : null,
                    child: profileProvider.profileImageUrl == null
                        ? const Icon(Icons.person, size: 50)
                        : null,
                  ),
                SizedBox(height: 20),
              ],
            ),

            Row(
              children: [
                ElevatedButton(
                  onPressed: () {
                    profileProvider.updateProfilePickture();
                  },
                  child: Text('프로필 수정'),
                ),
                SizedBox(width: 10),
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
          ],
        ),
      ),
    );
  }
}
